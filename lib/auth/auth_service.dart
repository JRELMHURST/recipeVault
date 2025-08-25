// lib/auth/auth_service.dart
// Auth + identity glue that keeps FirebaseAuth, Firestore, and RevenueCat in lockstep.

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/data/services/user_preference_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Allow serverClientId via --dart-define to support secure auth code flow (optional).
  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  // On mobile, use google_sign_in package; on web we use FirebaseAuth popups.
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleServerClientId.isEmpty
        ? null
        : _googleServerClientId,
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn =>
      currentUser != null && !(currentUser?.isAnonymous ?? true);

  /// Reads a locally saved preferred recipe locale (optional).
  Future<String?> _getPreferredRecipeLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('preferredRecipeLocale');
    } catch (_) {
      return null;
    }
  }

  /// Simple platform label for Firestore (allowed by rules)
  static String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      // ignore: avoid_catches_without_on_clauses
    }
    return 'unknown';
  }

  // ───────────────── SIGN IN / REGISTER ─────────────────

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Sign-in succeeded but no user was returned.');
    }

    await _postAuthHousekeeping(user);
    return credential;
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    if (displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }
    await _postAuthHousekeeping(user);
    return credential;
  }

  /// Google Sign‑In (web uses Firebase popup; mobile uses google_sign_in).
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final cred = await _auth.signInWithPopup(provider);
        await _postAuthHousekeeping(cred.user!);
        return cred;
      }

      // Mobile / desktop
      if (!(Platform.isAndroid || Platform.isIOS)) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Google sign-in is only set up for Android/iOS/Web.');
        }
        return null;
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _postAuthHousekeeping(userCredential.user!);
      return userCredential;
    } catch (e, stack) {
      debugPrint('🔴 Google sign-in failed: $e\n$stack');
      return null;
    }
  }

  /// Sign in with Apple (supported on iOS). Returns null if not supported or canceled.
  Future<UserCredential?> signInWithApple() async {
    try {
      if (kIsWeb || !Platform.isIOS) {
        debugPrint('ℹ️ Apple sign-in is only supported on iOS.');
        return null;
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      if (appleCredential.identityToken == null) {
        debugPrint('🔴 Apple sign-in failed: identityToken is null');
        return null;
      }

      final oauth = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauth);
      await _postAuthHousekeeping(userCredential.user!);
      return userCredential;
    } catch (e, stack) {
      debugPrint('🔴 Apple sign-in failed: $e\n$stack');
      return null;
    }
  }

  // ───────────────── SIGN OUT / RESET ─────────────────

  Future<void> signOut() async {
    // Keep RevenueCat + local state consistent with “signed out”
    try {
      await SubscriptionService().setAppUserId(null); // safely logs out RC
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ setAppUserId(null) failed: $e');
    }

    // Best-effort sign-out of Google client on mobile
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        /* ignore */
      }
    }

    await _auth.signOut();
  }

  /// Full app logout + local data purge (use with care).
  Future<void> fullLogout() async {
    final uid = currentUser?.uid;
    await signOut();

    if (uid != null) {
      try {
        await _deleteLocalUserData(uid);
        debugPrint('✅ Signed out and cleared local data for $uid');
      } catch (e) {
        debugPrint('⚠️ Failed to clear local user data: $e');
      }
    }
  }

  Future<void> _deleteLocalUserData(String uid) async {
    final boxNames = [
      'recipes_$uid',
      'categories_$uid',
      'customCategories_$uid',
      'userPrefs_$uid',
    ];
    for (final name in boxNames) {
      try {
        if (Hive.isBoxOpen(name)) {
          final box = Hive.box(name);
          await box.clear();
          await box.close();
          await Hive.deleteBoxFromDisk(name);
        } else if (await Hive.boxExists(name)) {
          await Hive.deleteBoxFromDisk(name);
        }
      } catch (e) {
        debugPrint('⚠️ Failed to delete Hive box "$name": $e');
      }
    }
    try {
      await UserPreferencesService.clearAllPreferences(uid);
    } catch (e) {
      debugPrint('⚠️ Failed to clear SharedPreferences for $uid: $e');
    }
  }

  // ───────────────── Firestore User Doc ─────────────────
  // Writes ONLY fields allowed by Firestore rules for the owner:
  //   email, platform, preferredRecipeLocale

  static Future<bool> ensureUserDocument(User user) async {
    if (user.isAnonymous) return false; // guard

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();

    final preferredLocale = await AuthService()._getPreferredRecipeLocale();
    final platform = _platformLabel();

    final data = <String, dynamic>{
      'email': (user.email ?? '').trim(),
      'platform': platform,
      if (preferredLocale != null && preferredLocale.trim().isNotEmpty)
        'preferredRecipeLocale': preferredLocale.trim(),
    };

    if (!snap.exists) {
      // Create with safe fields only; seed function will backfill server-only fields.
      await ref.set(data, SetOptions(merge: true));
      debugPrint('📝 Created Firestore user doc (safe fields) → $data');
      return true;
    } else {
      // Merge safe fields; backend owns entitlement/timestamps.
      await ref.set(data, SetOptions(merge: true));
      return false;
    }
  }

  Future<bool> ensureUserDocumentInstance(User user) =>
      ensureUserDocument(user);

  // ───────────────── Post‑auth glue (single place) ─────────────────

  Future<void> _postAuthHousekeeping(User user) async {
    // Anonymous sessions should NOT bind RC or write user docs
    if (user.isAnonymous) {
      if (kDebugMode) {
        debugPrint('↪️ Skipping post-auth hooks for anonymous user.');
      }
      return;
    }

    // 1) Tie RevenueCat to Firebase UID and refresh subs
    try {
      await SubscriptionService().setAppUserId(user.uid);
      await SubscriptionService().refresh();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Subscriptions refresh failed: $e');
    }

    // 2) Ensure/merge Firestore user doc (safe fields only; seed CF adds server fields)
    try {
      await ensureUserDocument(user);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ ensureUserDocument failed: $e');
    }

    // 3) No client-side reconcile; rely on webhook/callable + RC listener/router.
  }

  // ───────────────── Debug helpers ─────────────────

  void logCurrentUser() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      debugPrint('🔐 No real user currently signed in (null or anonymous).');
    } else {
      debugPrint(
        '👤 Logged in as: ${user.email ?? user.displayName ?? user.uid}',
      );
      debugPrint('📧 Email: ${user.email}');
      debugPrint('🆔 UID: ${user.uid}');
      debugPrint(
        '🔗 Providers: ${user.providerData.map((p) => p.providerId).join(', ')}',
      );
    }
  }

  static DocumentReference<Map<String, dynamic>>? userDocRefCurrent() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.isAnonymous) return null;
    return FirebaseFirestore.instance.collection('users').doc(u.uid);
  }
}

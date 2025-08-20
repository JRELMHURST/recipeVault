// lib/auth/auth_service.dart
// Auth + identity glue that keeps FirebaseAuth, Firestore, and RevenueCat in lockstep.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/data/services/user_preference_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Reads a locally saved preferred recipe locale (optional).
  Future<String?> _getPreferredRecipeLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('preferredRecipeLocale');
    } catch (_) {
      return null;
    }
  }

  // ───────────────── SIGN IN / REGISTER ─────────────────

  /// Email + Password (named params to match call-sites in UI).
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await _postAuthHousekeeping(user, forceCreateUserDoc: false);
    return credential;
  }

  /// Register with Email + Password (optionally set displayName).
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
    await _postAuthHousekeeping(user, forceCreateUserDoc: true);
    return credential;
  }

  /// Google sign-in.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      await _postAuthHousekeeping(user, forceCreateUserDoc: true);
      return userCredential;
    } catch (e, stack) {
      debugPrint('🔴 Google sign-in failed: $e\n$stack');
      return null;
    }
  }

  /// Apple sign-in.
  Future<UserCredential?> signInWithApple() async {
    try {
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
      final user = userCredential.user!;
      await _postAuthHousekeeping(user, forceCreateUserDoc: true);
      return userCredential;
    } catch (e, stack) {
      debugPrint('🔴 Apple sign-in failed: $e\n$stack');
      return null;
    }
  }

  // ───────────────── SIGN OUT / RESET ─────────────────

  Future<void> signOut() async {
    // Keep RevenueCat + local state consistent with “signed out”.
    try {
      await SubscriptionService().setAppUserId(
        null,
      ); // handles RC logOut safely
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ setAppUserId(null) failed: $e');
    }

    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // ignore
    }
    await _auth.signOut();
  }

  /// Full local cleanup (use for destructive flows like delete-account).
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
      if (Hive.isBoxOpen(name)) {
        final box = Hive.box(name);
        await box.clear();
        await box.close();
        await Hive.deleteBoxFromDisk(name);
      } else if (await Hive.boxExists(name)) {
        await Hive.deleteBoxFromDisk(name);
      }
    }
    await UserPreferencesService.clearAllPreferences(uid);
  }

  // ───────────────── Firestore User Doc ─────────────────

  /// Create/merge the user document; idempotent.
  static Future<bool> ensureUserDocument(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();

    final preferredLocale = await AuthService()._getPreferredRecipeLocale();

    final data = <String, dynamic>{
      'email': user.email,
      'productId': 'none',
      'tier': 'none',
      if (preferredLocale != null) 'preferredRecipeLocale': preferredLocale,
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      await ref.set(data);
      debugPrint('📝 Created Firestore user doc → $data');
      return true;
    } else {
      await ref.set({
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return false;
    }
  }

  /// Non‑static proxy so other code calling `AuthService().ensureUserDocument(...)`
  /// won’t break.
  Future<bool> ensureUserDocumentInstance(User user) =>
      ensureUserDocument(user);

  // ───────────────── RevenueCat ↔ Server reconcile ─────────────────

  Future<void> _reconcileFromRC(User user) async {
    try {
      await user.getIdToken(true); // fresh token
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west2');
      final callable = functions.httpsCallable('reconcileUserFromRC');

      int attempts = 3;
      while (attempts-- > 0) {
        try {
          await callable.call(<String, dynamic>{});
          if (kDebugMode) {
            debugPrint('✅ Forced reconcile from RC for ${user.uid}');
          }
          break;
        } on FirebaseFunctionsException catch (e) {
          // In practice this throws 'unauthenticated' if token is stale.
          if (e.code == 'unauthenticated' && attempts > 0) {
            await Future.delayed(const Duration(milliseconds: 400));
            await user.getIdToken(true);
            continue;
          }
          rethrow;
        }
      }
    } catch (e, stack) {
      debugPrint('⚠️ Failed reconcile from RC: $e');
      if (kDebugMode) debugPrint('$stack');
    }
  }

  // ───────────────── Post‑auth glue (single place) ─────────────────

  Future<void> _postAuthHousekeeping(
    User user, {
    required bool forceCreateUserDoc,
  }) async {
    // 1) Tie RevenueCat to Firebase UID (and refresh subscription state).
    try {
      await SubscriptionService().setAppUserId(user.uid);
      // init() already ran at app boot; refresh is enough here.
      await SubscriptionService().refresh();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Subscriptions refresh failed: $e');
    }

    // 2) Ensure/merge Firestore user doc.
    try {
      if (forceCreateUserDoc) {
        await ensureUserDocument(user);
      } else {
        // merge-only update lastLogin for existing user
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ ensureUserDocument failed: $e');
    }

    // 3) Ask the backend to reconcile RC → Firestore (best effort).
    await _reconcileFromRC(user);
  }

  // ───────────────── Debug helpers ─────────────────

  void logCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('🔐 No user currently signed in.');
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }
}

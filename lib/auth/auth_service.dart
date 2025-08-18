import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/data/services/user_preference_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/billing/tier_utils.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:collection/collection.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Reads locally saved preferred recipe locale
  Future<String?> _getPreferredRecipeLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('preferredRecipeLocale');
    } catch (_) {
      return null;
    }
  }

  /// Safe RC entitlement fetch
  Future<String?> _getActiveEntitlementIdSafe() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.values.firstOrNull?.identifier;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ RC getCustomerInfo failed: $e');
      return null;
    }
  }

  Future<void> _logInRevenueCat(String uid) async {
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ RC logIn failed for $uid: $e');
    }
  }

  // ── SIGN IN & REGISTER ─────────────────────────────

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await _logInRevenueCat(user.uid);
    await ensureUserDocument(user); // unified
    return credential;
  }

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await _logInRevenueCat(user.uid);
    await ensureUserDocument(user); // unified
    return credential;
  }

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
      await _logInRevenueCat(user.uid);
      await ensureUserDocument(user); // unified
      return userCredential;
    } catch (e, stack) {
      debugPrint('🔴 Google sign-in failed: $e\n$stack');
      return null;
    }
  }

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

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user!;
      await _logInRevenueCat(user.uid);
      await ensureUserDocument(user); // unified
      return userCredential;
    } catch (e, stack) {
      debugPrint('🔴 Apple sign-in failed: $e\n$stack');
      return null;
    }
  }

  // ── SIGN OUT ─────────────────────────────

  Future<void> signOut() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ RC logOut failed: $e');
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> fullLogout() async {
    final uid = currentUser?.uid;
    await signOut();

    if (uid != null) {
      try {
        await _deleteLocalUserData(uid);
        debugPrint('✅ Signed out and cleared local data for $uid');

        await Hive.deleteFromDisk(); // nukes all boxes
        debugPrint('🧹 All Hive data deleted from disk');
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
        await box.close();
        await box.deleteFromDisk();
      } else if (await Hive.boxExists(name)) {
        await Hive.deleteBoxFromDisk(name);
      }
    }

    await UserPreferencesService.clearAllPreferences(uid);
  }

  // ── FIRESTORE USER DOCUMENT (UNIFIED) ─────────────────────────────

  static Future<bool> ensureUserDocument(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    final service = AuthService();
    final entitlementId = await service._getActiveEntitlementIdSafe();
    final resolvedTier = resolveTier(entitlementId ?? 'none');
    final preferredLocale = await service._getPreferredRecipeLocale();

    final updateData = <String, dynamic>{
      'email': user.email,
      'entitlementId': entitlementId ?? 'none',
      'tier': resolvedTier,
      if (preferredLocale != null) 'preferredRecipeLocale': preferredLocale,
      if (!doc.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (!doc.exists) {
      await docRef.set(updateData);
      debugPrint('📝 Created Firestore user doc → $updateData');
      try {
        await UserPreferencesService.markAsNewUser();
      } catch (e) {
        debugPrint('⚠️ Failed to mark new user prefs: $e');
      }
      return true;
    } else {
      final existing = doc.data() ?? {};
      final needsUpdate =
          existing['tier'] != resolvedTier ||
          existing['entitlementId'] != entitlementId ||
          (preferredLocale != null &&
              existing['preferredRecipeLocale'] != preferredLocale);

      if (needsUpdate) {
        await docRef.set(updateData, SetOptions(merge: true));
        debugPrint('♻️ Updated Firestore user doc → $updateData');
      }
      return false;
    }
  }

  // ── Debug helpers ─────────────────────────────

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

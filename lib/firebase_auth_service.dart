import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/rev_cat/tier_utils.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  /// 🔐 Email sign-in
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await Purchases.logIn(credential.user!.uid);
    await _ensureUserDocument(credential.user!);
    return credential;
  }

  /// 🆕 Email registration
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await Purchases.logIn(credential.user!.uid);
    await _ensureUserDocument(credential.user!);
    return credential;
  }

  /// 🔓 Google Sign-In
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
      await Purchases.logIn(userCredential.user!.uid);
      await _ensureUserDocument(userCredential.user!);
      return userCredential;
    } catch (e, stack) {
      debugPrint('🔴 Google sign-in failed: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  /// 🍏 Apple Sign-In
  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      await Purchases.logIn(userCredential.user!.uid);
      await _ensureUserDocument(userCredential.user!);
      return userCredential;
    } catch (e, stack) {
      debugPrint('🔴 Apple sign-in failed: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  /// 🚪 Sign out and RevenueCat logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await Purchases.logOut();
  }

  /// 🧹 Full logout + local storage reset (per user only)
  Future<void> fullLogout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

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

  /// 🔄 Clears local Hive + user-specific prefs for a specific UID
  Future<void> _deleteLocalUserData(String uid) async {
    final boxNames = [
      'recipes_$uid',
      'categories_$uid',
      'customCategories_$uid',
      'userPrefs_$uid',
    ];

    for (final boxName in boxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).deleteFromDisk();
      } else if (await Hive.boxExists(boxName)) {
        await Hive.deleteBoxFromDisk(boxName);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = [
      'viewMode_$uid',
      'hasShownBubblesOnce_$uid',
      'vaultTutorialComplete_$uid',
      'isNewUser_$uid',
    ];

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  /// 🔧 Ensure Firestore user doc exists and sync tier/entitlement
  Future<void> _ensureUserDocument(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    final customerInfo = await Purchases.getCustomerInfo();
    final entitlementId =
        customerInfo.entitlements.active.values.firstOrNull?.productIdentifier;
    final resolvedTier = resolveTier(entitlementId ?? 'free');

    final updateData = {
      'email': user.email,
      'entitlementId': entitlementId ?? 'none',
      'tier': resolvedTier,
      'trialActive': false,
      if (!doc.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (!doc.exists) {
      await docRef.set(updateData);
      debugPrint('📝 Created Firestore user doc → Tier: $resolvedTier');
      try {
        await UserPreferencesService.markAsNewUser();
        debugPrint('🎈 Onboarding flags reset for new user');
      } catch (e) {
        debugPrint('⚠️ Failed to mark user as new in preferences: $e');
      }
    } else {
      final existing = doc.data() ?? {};
      final needsUpdate =
          existing['tier'] != resolvedTier ||
          existing['entitlementId'] != entitlementId;

      if (needsUpdate) {
        await docRef.set(updateData, SetOptions(merge: true));
        debugPrint('♻️ Updated Firestore user doc → Tier: $resolvedTier');
      } else {
        debugPrint('ℹ️ Firestore user doc already up to date.');
      }
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west2',
      ).httpsCallable('refreshGlobalRecipesForUser');
      final result = await callable();
      final count = result.data['copiedCount'];
      debugPrint('🍽 Global recipes refreshed: $count item(s) copied');
    } catch (e, stack) {
      debugPrint('⚠️ Failed to refresh global recipes: $e');
      debugPrint(stack.toString());
    }
  }

  static Future<bool> ensureUserDocumentIfMissing(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlementId = customerInfo
          .entitlements
          .active
          .values
          .firstOrNull
          ?.productIdentifier;
      final resolvedTier = resolveTier(entitlementId ?? 'free');

      final updateData = {
        'email': user.email,
        'entitlementId': entitlementId ?? 'none',
        'tier': resolvedTier,
        'trialActive': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(updateData);
      debugPrint('📝 Created Firestore user doc → Tier: $resolvedTier');
      try {
        await UserPreferencesService.markAsNewUser();
        debugPrint('🎈 Onboarding flags reset for new user');
      } catch (e) {
        debugPrint('⚠️ Failed to mark user as new in preferences: $e');
      }

      try {
        final callable = FirebaseFunctions.instanceFor(
          region: 'europe-west2',
        ).httpsCallable('refreshGlobalRecipesForUser');
        final result = await callable();
        final count = result.data['copiedCount'];
        debugPrint('🍽 Global recipes refreshed: $count item(s) copied');
      } catch (e, stack) {
        debugPrint('⚠️ Failed to refresh global recipes: $e');
        debugPrint(stack.toString());
      }

      return true;
    } else {
      final existing = doc.data() ?? {};
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlementId = customerInfo
          .entitlements
          .active
          .values
          .firstOrNull
          ?.productIdentifier;
      final resolvedTier = resolveTier(entitlementId ?? 'free');

      final needsUpdate =
          existing['tier'] != resolvedTier ||
          existing['entitlementId'] != entitlementId;

      if (needsUpdate) {
        await docRef.set({
          'tier': resolvedTier,
          'entitlementId': entitlementId ?? 'none',
        }, SetOptions(merge: true));
        debugPrint('♻️ Updated Firestore user doc → Tier: $resolvedTier');
      } else {
        debugPrint('ℹ️ Firestore user doc already up to date.');
      }

      return false;
    }
  }

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

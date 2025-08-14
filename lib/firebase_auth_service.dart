import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ NEW
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/rev_cat/tier_utils.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:collection/collection.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  /// Reads the locally saved preferred recipe locale (set by LanguageProvider)
  Future<String?> _getPreferredRecipeLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('preferredRecipeLocale'); // e.g. 'en-GB', 'pl'
    } catch (_) {
      return null;
    }
  }

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

        final boxName = 'recipes_$uid';
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).close();
          debugPrint('📦 Box closed early: $boxName');
        }

        await Hive.deleteFromDisk();
        debugPrint('🧹 All Hive data deleted from disk');
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
        await Hive.box(boxName).close();
        await Hive.box(boxName).deleteFromDisk();
      } else if (await Hive.boxExists(boxName)) {
        await Hive.deleteBoxFromDisk(boxName);
      }
    }

    await UserPreferencesService.clearAllPreferences(uid);
  }

  /// 🔧 Ensure Firestore user doc exists and sync tier/entitlement + preferred locale
  Future<void> _ensureUserDocument(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    final customerInfo = await Purchases.getCustomerInfo();
    final entitlementId =
        customerInfo.entitlements.active.values.firstOrNull?.identifier;
    final resolvedTier = resolveTier(entitlementId ?? 'free');

    // pull preferred locale from device prefs (written by LanguageProvider)
    final preferredLocale = await _getPreferredRecipeLocale();

    final updateData = <String, dynamic>{
      'email': user.email,
      'entitlementId': entitlementId ?? 'none',
      'tier': resolvedTier,
      if (preferredLocale != null) 'preferredRecipeLocale': preferredLocale,
      if (!doc.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (!doc.exists) {
      await docRef.set(updateData);
      debugPrint(
        '📝 Created Firestore user doc → Tier: $resolvedTier, Entitlement: $entitlementId, PrefLocale: ${preferredLocale ?? '(none)'}',
      );
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
          existing['entitlementId'] != entitlementId ||
          (preferredLocale != null &&
              existing['preferredRecipeLocale'] != preferredLocale);

      if (needsUpdate) {
        await docRef.set(updateData, SetOptions(merge: true));
        debugPrint(
          '♻️ Updated Firestore user doc → Tier: $resolvedTier, Entitlement: $entitlementId, PrefLocale: ${preferredLocale ?? '(unchanged)'}',
        );
      } else {
        debugPrint('ℹ️ Firestore user doc already up to date.');
      }
    }

    // Optionally refresh seeded/global recipes to ensure user's vault is current
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west2',
      ).httpsCallable('refreshGlobalRecipesForUser');
      final result = await callable();
      debugPrint(
        '🍽 Global recipes refreshed: ${result.data['copiedCount']} item(s) copied',
      );
    } catch (e, stack) {
      debugPrint('⚠️ Failed to refresh global recipes: $e');
      debugPrint(stack.toString());
    }
  }

  static Future<bool> ensureUserDocumentIfMissing(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    final customerInfo = await Purchases.getCustomerInfo();
    final entitlementId =
        customerInfo.entitlements.active.values.firstOrNull?.identifier;
    final resolvedTier = resolveTier(entitlementId ?? 'free');

    // read the local preferred locale
    String? preferredLocale;
    try {
      final prefs = await SharedPreferences.getInstance();
      preferredLocale = prefs.getString('preferredRecipeLocale');
    } catch (_) {}

    if (!doc.exists) {
      final updateData = <String, dynamic>{
        'email': user.email,
        'entitlementId': entitlementId ?? 'none',
        'tier': resolvedTier,
        if (preferredLocale != null) 'preferredRecipeLocale': preferredLocale,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(updateData);
      debugPrint(
        '📝 Created Firestore user doc → Tier: $resolvedTier, Entitlement: $entitlementId, PrefLocale: ${preferredLocale ?? '(none)'}',
      );
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
        debugPrint(
          '🍽 Global recipes refreshed: ${result.data['copiedCount']} item(s) copied',
        );
      } catch (e, stack) {
        debugPrint('⚠️ Failed to refresh global recipes: $e');
        debugPrint(stack.toString());
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
        await docRef.set({
          'tier': resolvedTier,
          'entitlementId': entitlementId ?? 'none',
          if (preferredLocale != null) 'preferredRecipeLocale': preferredLocale,
        }, SetOptions(merge: true));
        debugPrint(
          '♻️ Updated Firestore user doc → Tier: $resolvedTier, Entitlement: $entitlementId, PrefLocale: ${preferredLocale ?? '(unchanged)'}',
        );
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

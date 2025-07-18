import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/model/category_model.dart';
import 'package:recipe_vault/rev_cat/tier_utils.dart';

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

  /// 🚪 Sign out and RevenueCat logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await Purchases.logOut();
  }

  /// 🧹 Full logout + local storage reset
  Future<void> fullLogout() async {
    await signOut();
    try {
      await _safeClearBox<RecipeCardModel>('recipes');
      await _safeClearBox<CategoryModel>('categories');
      await _safeClearBox<String>('customCategories');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ Signed out and cleared local storage.');
    } catch (e) {
      debugPrint('⚠️ Error clearing Hive or preferences: $e');
    }
  }

  /// 🔧 Ensure Firestore user doc exists and sync tier/entitlement
  Future<void> _ensureUserDocument(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    final customerInfo = await Purchases.getCustomerInfo();
    final entitlementId =
        customerInfo.entitlements.active.values.firstOrNull?.productIdentifier;
    final resolvedTier = resolveTier(entitlementId);

    final updateData = {
      'email': user.email,
      'entitlementId': entitlementId ?? 'none',
      'tier': resolvedTier,
      'trialActive': false, // Manual opt-in only
      if (!doc.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (!doc.exists) {
      await docRef.set(updateData);
      debugPrint('📝 Created Firestore user doc → Tier: $resolvedTier');
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
  }

  /// 🔄 Safely clears a Hive box
  Future<void> _safeClearBox<T>(String boxName) async {
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box<T>(boxName)
        : await Hive.openBox<T>(boxName);
    await box.clear();
  }

  /// 🐞 Debug log
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
}

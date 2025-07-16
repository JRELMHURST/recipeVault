import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/model/category_model.dart';
import 'package:recipe_vault/services/user_session_service.dart';
import 'package:recipe_vault/rev_cat/tier_utils.dart'; // ✅ Import shared tier logic

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 🔄 Emits auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// ✅ Get current user
  User? get currentUser => _auth.currentUser;
  User? getCurrentUser() => _auth.currentUser;

  /// 🧠 Check if user is logged in
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('🔐 AuthService: Google Sign-In cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await Purchases.logIn(userCredential.user!.uid);
      await _ensureUserDocument(userCredential.user!);
      return userCredential;
    } catch (e, stack) {
      debugPrint('🔐 AuthService: Google Sign-In failed: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  /// 🚪 Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await Purchases.logOut();
  }

  /// 🧹 Full logout + clear local storage
  Future<void> fullLogout() async {
    await signOut();

    try {
      await _safeClearBox<RecipeCardModel>('recipes');
      await _safeClearBox<CategoryModel>('categories');
      await _safeClearBox<String>('customCategories');

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      debugPrint(
        '🔐 AuthService: Signed out + cleared Hive + SharedPreferences',
      );
    } catch (e) {
      debugPrint('🔐 AuthService: Error clearing Hive boxes: $e');
    }
  }

  /// 🔧 Ensures user Firestore doc exists and syncs RevenueCat entitlement
  Future<void> _ensureUserDocument(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    final entitlementInfo = await Purchases.getCustomerInfo();
    final entitlementId =
        entitlementInfo.entitlements.active.values.firstOrNull?.identifier;
    String tier = resolveTier(entitlementId); // ✅ Now uses shared function

    if (!doc.exists) {
      await docRef.set({
        'email': user.email,
        'entitlementId': entitlementId ?? 'taster',
        'tier': tier,
        'trialActive': tier == 'taster',
        'trialStartDate': tier == 'taster'
            ? FieldValue.serverTimestamp()
            : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '🔐 AuthService: Created Firestore user doc with resolved tier: $tier',
      );
    } else {
      debugPrint('🔐 AuthService: Firestore user doc already exists.');

      final isTaster = tier == 'taster';
      final updateData = {
        'entitlementId': entitlementId ?? 'taster',
        'tier': tier,
        'trialActive': isTaster,
      };

      if (isTaster) {
        updateData['trialStartDate'] = FieldValue.serverTimestamp();
      }

      await docRef.set(updateData, SetOptions(merge: true));
    }

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await UserSessionService.syncRevenueCatEntitlement();
      debugPrint(
        '🔐 AuthService: Synced entitlement to Firestore via UserSessionService.',
      );
    } catch (e, stack) {
      debugPrint('🔐 AuthService: Failed to sync RevenueCat entitlement: $e');
      debugPrint(stack.toString());
    }
  }

  /// 🧼 Safely opens and clears a Hive box
  Future<void> _safeClearBox<T>(String boxName) async {
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box<T>(boxName)
        : await Hive.openBox<T>(boxName);
    await box.clear();
  }

  /// 🐞 Debug
  void logCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('🔐 AuthService: No user currently signed in.');
    } else {
      debugPrint(
        '🔐 AuthService: Logged in: ${user.displayName ?? user.email ?? user.uid}',
      );
      debugPrint('🔐 AuthService: Email: ${user.email}');
      debugPrint('🔐 AuthService: UID: ${user.uid}');
      debugPrint(
        '🔐 AuthService: Providers: ${user.providerData.map((p) => p.providerId).join(', ')}',
      );
    }
  }
}

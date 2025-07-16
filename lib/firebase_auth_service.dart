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
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
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

    await _ensureUserDocument(credential.user!);
    return credential;
  }

  /// 🔓 Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ Google Sign-In cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _ensureUserDocument(userCredential.user!);
      return userCredential;
    } catch (e, stack) {
      debugPrint('❌ Google Sign-In failed: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  /// 🚪 Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await Purchases.logOut(); // ✅ Also log out from RevenueCat
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

      debugPrint('✅ Signed out + cleared Hive + SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Error clearing Hive boxes: $e');
    }
  }

  /// 🔧 Ensures user Firestore doc exists and syncs RevenueCat entitlement
  Future<void> _ensureUserDocument(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'email': user.email,
        'tier': 'taster',
        'trialStartDate': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🆕 Created Firestore user doc with trialStartDate.');
    } else {
      debugPrint('📄 Firestore user doc already exists.');
    }

    // ✅ Sync RevenueCat entitlement after auth settles
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await UserSessionService.syncRevenueCatEntitlement();
      debugPrint('🔄 Synced entitlement to Firestore via UserSessionService.');
    } catch (e, stack) {
      debugPrint('⚠️ Failed to sync RevenueCat entitlement: $e');
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
      debugPrint('❌ No user currently signed in.');
    } else {
      debugPrint('✅ Logged in: ${user.displayName ?? user.email ?? user.uid}');
      debugPrint('📧 Email: ${user.email}');
      debugPrint('🆔 UID: ${user.uid}');
      debugPrint(
        '🔗 Providers: ${user.providerData.map((p) => p.providerId).join(', ')}',
      );
    }
  }
}

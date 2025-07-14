import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/model/category_model.dart';

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

    return credential;
  }

  /// 🚪 Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// 🧹 Full logout + clear local storage
  Future<void> fullLogout() async {
    await signOut();
    await Hive.box<RecipeCardModel>('recipes').clear();
    await Hive.box<CategoryModel>('categories').clear();
    await Hive.box<String>('customCategories').clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('✅ Signed out + cleared Hive + SharedPreferences');
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
      return userCredential;
    } catch (e, stack) {
      debugPrint('❌ Google Sign-In failed: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  /// 🔍 Debug log
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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/model/category_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 🔄 Emits auth state changes (logged in / out)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// ✅ Get currently logged in user
  User? get currentUser => _auth.currentUser;

  /// ✅ Getter-style method (for compatibility with old code)
  User? getCurrentUser() => _auth.currentUser;

  /// 🧠 Check login state
  bool get isLoggedIn => _auth.currentUser != null;

  /// 🔐 Email & Password Sign In
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// 🆕 Register new user and sync RevenueCat
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await Purchases.logIn(credential.user!.uid);
    await SubscriptionService().refresh();

    return credential;
  }

  /// 🚪 Sign out from all sessions
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// 🧹 Full logout (including local cleanup)
  Future<void> fullLogout() async {
    await Purchases.logOut();
    await signOut();
    await Hive.box<RecipeCardModel>('recipes').clear();
    await Hive.box<CategoryModel>('categories').clear();
    await Hive.box<String>('customCategories').clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('✅ Signed out + Cleared Hive + Cleared SharedPreferences');
  }

  /// 🔓 Google Sign-In Flow
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.standard();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

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

      await Purchases.logIn(userCredential.user!.uid);
      await SubscriptionService().refresh();

      return userCredential;
    } catch (e, stackTrace) {
      debugPrint('❌ Google Sign-In failed: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// 🪪 Log current user info to console
  void logCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ No user currently signed in.');
    } else {
      debugPrint(
        '✅ Logged in user: ${user.displayName ?? user.email ?? user.uid}',
      );
      debugPrint('📧 Email: ${user.email}');
      debugPrint('🆔 UID: ${user.uid}');
      debugPrint(
        '🔗 Provider(s): ${user.providerData.map((p) => p.providerId).join(', ')}',
      );
    }
  }
}

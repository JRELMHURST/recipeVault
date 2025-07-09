import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 🔄 Emits auth state changes (logged in / out)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// ✅ Get currently logged in user
  User? get currentUser => _auth.currentUser;

  /// ✅ Getter-style method (for compatibility with old code)
  User? getCurrentUser() => _auth.currentUser;

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

    // 👉 Link to RevenueCat
    await Purchases.logIn(credential.user!.uid);

    // 👉 Refresh subscription info for immediate tier detection
    await SubscriptionService().refresh();

    return credential;
  }

  /// 🚪 Sign out from all sessions
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// 🔓 Google Sign-In Flow
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.standard();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      // ❌ User cancelled login – exit early
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

      // 🔗 Link to RevenueCat
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

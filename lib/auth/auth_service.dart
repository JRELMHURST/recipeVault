import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/data/services/user_preference_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Reads locally saved preferred recipe locale.
  Future<String?> _getPreferredRecipeLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('preferredRecipeLocale');
    } catch (_) {
      return null;
    }
  }

  // ── SIGN IN & REGISTER ─────────────────────────────

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await ensureUserDocument(user);
    await _reconcileFromRC(user);
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
    await ensureUserDocument(user);
    await _reconcileFromRC(user);
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
      await ensureUserDocument(user);
      await _reconcileFromRC(user);
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
      await ensureUserDocument(user);
      await _reconcileFromRC(user);
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
        await Hive.deleteFromDisk();
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

  // ── FIRESTORE USER DOCUMENT (SIMPLE) ─────────────────────────────

  static Future<bool> ensureUserDocument(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    final preferredLocale = await AuthService()._getPreferredRecipeLocale();

    final updateData = <String, dynamic>{
      'email': user.email,
      'productId': 'none',
      'tier': 'none',
      if (preferredLocale != null) 'preferredRecipeLocale': preferredLocale,
      if (!doc.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (!doc.exists) {
      await docRef.set(updateData);
      debugPrint('📝 Created Firestore user doc → $updateData');
      try {
        await UserPreferencesService.markAsNewUser();
      } catch (_) {}
      return true;
    }
    return false;
  }

  // ── SERVER-SIDE RECONCILE ─────────────────────────────

  Future<void> _reconcileFromRC(User user) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: "europe-west2");
      final callable = functions.httpsCallable("reconcileUserFromRC");
      await callable.call({"uid": user.uid});
      debugPrint("✅ Forced reconcile from RC for ${user.uid}");
    } catch (e) {
      debugPrint("⚠️ Failed reconcile from RC: $e");
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

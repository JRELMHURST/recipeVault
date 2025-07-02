import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Signs in anonymously if not already signed in.
  static Future<User> signInAnonymously() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return currentUser;

    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'NULL_USER',
          message: 'Anonymous sign-in returned null user.',
        );
      }
      return user;
    } catch (e) {
      rethrow; // Forward error to caller
    }
  }

  /// Returns the current Firebase user, if signed in.
  static User? get currentUser => _auth.currentUser;

  /// Whether the user is signed in anonymously.
  static bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Signs out the current user.
  static Future<void> signOut() => _auth.signOut();
}

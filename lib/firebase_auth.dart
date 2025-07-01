import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Signs in anonymously if not already signed in.
  static Future<User> signInAnonymously() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return currentUser;

    final userCredential = await _auth.signInAnonymously();
    return userCredential.user!;
  }

  /// Returns the current Firebase user, if signed in.
  static User? get currentUser => _auth.currentUser;

  /// Whether the user is signed in anonymously.
  static bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Signs out the current user.
  static Future<void> signOut() => _auth.signOut();
}

import 'package:firebase_auth/firebase_auth.dart';

/// Provides a safe, centralised UID getter for logged-in users.
/// Throws if no user is logged in.
class UIDProvider {
  static String requireUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('❌ No logged in user — UID required.');
    }
    return uid;
  }
}

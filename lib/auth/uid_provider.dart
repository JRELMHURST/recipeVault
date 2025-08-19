import 'package:firebase_auth/firebase_auth.dart';

class UIDProvider {
  static String requireUid() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw StateError('❌ No logged in user — UID required.');
    }
    return u.uid;
  }

  static String? uidOrNull() => FirebaseAuth.instance.currentUser?.uid;
}

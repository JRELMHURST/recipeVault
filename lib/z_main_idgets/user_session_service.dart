import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/services/category_service.dart';

class UserSessionService {
  static User? _lastSyncedUser;

  /// Should be called whenever the Firebase user changes.
  static Future<void> handleUserChange(User? user) async {
    if (user != null) {
      await Purchases.logIn(user.uid);

      if (_lastSyncedUser?.uid != user.uid) {
        _lastSyncedUser = user;
        await CategoryService.syncFromFirestore();
      }
    } else {
      await Purchases.logOut();
      _lastSyncedUser = null;
    }
  }
}

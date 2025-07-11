import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class UserSessionService {
  static Future<void> handleUserChange(User? user) async {
    if (user == null) return;

    try {
      // 🔗 Link to RevenueCat by UID
      await Purchases.logIn(user.uid);

      // 🔄 Refresh Subscription Tier + SuperUser flag
      await SubscriptionService().refresh();

      // 🔄 Sync categories from Firestore (optional)
      await CategoryService.syncFromFirestore();

      // 🧪 Debug output
      final sub = SubscriptionService();
      if (sub.isSuperUser) {
        if (kDebugMode) {
          print('🟢 Super user mode enabled.');
        }
      } else {
        if (kDebugMode) {
          print('⚪ Standard user mode.');
        }
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ Error in UserSessionService.handleUserChange: $e');
      }
      if (kDebugMode) {
        print(stack);
      }
    }
  }
}

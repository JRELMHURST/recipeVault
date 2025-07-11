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

      // 🔄 Refresh Subscription Tier
      await SubscriptionService().refresh();

      // 🔄 Sync categories from Firestore
      await CategoryService.syncFromFirestore();

      // 🧾 Debug output
      if (kDebugMode) {
        print(
          '🟢 User session initialised with tier: '
          '${SubscriptionService().getCurrentTierName()}',
        );
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ Error in UserSessionService.handleUserChange: $e');
        print(stack);
      }
    }
  }
}

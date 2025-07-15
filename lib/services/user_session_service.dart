import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class UserSessionService {
  static Future<void> syncRevenueCatEntitlement() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlementId =
          info.entitlements.active.values.firstOrNull?.identifier;
      final userId = info.originalAppUserId;

      if (entitlementId != null && userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'entitlementId': entitlementId,
        }, SetOptions(merge: true));
        if (kDebugMode) {
          print('✅ Synced entitlementId to Firestore: $entitlementId');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ No active entitlement found to sync');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync entitlement to Firestore: $e');
      }
    }
  }
}

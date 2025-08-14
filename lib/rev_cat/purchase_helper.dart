import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // <-- needed for PlatformException
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/rev_cat/tier_utils.dart'; // ✅ Shared tier logic

class PurchaseHelper {
  /// Initialise RevenueCat with the public API key
  static Future<void> initRevenueCat(String apiKey, {String? appUserId}) async {
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(
      PurchasesConfiguration(apiKey)..appUserID = appUserId,
    );
  }

  /// Get current customer info (entitlements, active subscriptions, etc.)
  static Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  /// Get available offerings from RevenueCat dashboard
  static Future<Offerings> getOfferings() async {
    return await Purchases.getOfferings();
  }

  /// Purchase a selected package
  static Future<CustomerInfo> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      await syncEntitlementToFirestore(customerInfo);
      return customerInfo;
    } on PlatformException {
      // Forward to caller so UI can handle cancelled/failed cases
      rethrow;
    }
  }

  /// Shorthand for purchasing – used in PaywallScreen
  static Future<void> purchase(Package package) async {
    await purchasePackage(package);
  }

  /// Restore previous purchases
  static Future<CustomerInfo> restorePurchases() async {
    final customerInfo = await Purchases.restorePurchases();
    await syncEntitlementToFirestore(customerInfo);
    return customerInfo;
  }

  /// Check if a given entitlement is active
  static bool hasActiveEntitlement(CustomerInfo info, String entitlementId) {
    return info.entitlements.active.containsKey(entitlementId);
  }

  /// Get the currently active entitlement ID (if any)
  static String? getActiveEntitlementId(CustomerInfo info) {
    if (info.entitlements.active.isEmpty) return null;
    return info.entitlements.active.values.first.identifier;
  }

  /// 🔄 Sync entitlementId and tier to Firestore (used for backend resolution)
  static Future<void> syncEntitlementToFirestore(CustomerInfo info) async {
    final entitlement = info.entitlements.active.values.isNotEmpty
        ? info.entitlements.active.values.first
        : null;

    final entitlementId = entitlement?.identifier ?? 'none';
    final tier = resolveTier(entitlementId);
    final userId = info.originalAppUserId;

    if (userId.isEmpty) return;

    final updateData = {
      'entitlementId': entitlementId,
      'tier': tier,
      'willRenew': entitlement?.willRenew ?? false,
      'originalPurchaseDate': entitlement?.originalPurchaseDate,
      'expirationDate': entitlement?.expirationDate,
      'store': entitlement?.store,
      'periodType': entitlement?.periodType.name, // "trial", "intro", "normal"
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(updateData, SetOptions(merge: true));

      if (kDebugMode) {
        print(
          '✅ Synced entitlementId "$entitlementId", tier "$tier", '
          'willRenew=${updateData['willRenew']}, '
          'periodType=${updateData['periodType']}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync entitlement data: $e');
      }
    }
  }
}

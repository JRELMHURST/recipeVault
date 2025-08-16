import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // PlatformException
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/rev_cat/tier_utils.dart'; // resolveTier(productId)

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

  /// Check if a given entitlement KEY is active (e.g. "pro", "premium")
  static bool hasActiveEntitlement(CustomerInfo info, String entitlementKey) {
    return info.entitlements.active.containsKey(entitlementKey);
  }

  /// Get the currently active **product id** (e.g. "home_chef_monthly")
  /// This is what the rest of the app expects for tier resolution.
  static String? getActiveProductId(CustomerInfo info) {
    if (info.entitlements.active.isEmpty) return null;
    // Pick the first active entitlement; adapt if you manage multiple keys.
    final EntitlementInfo e = info.entitlements.active.values.first;
    return e.productIdentifier; // <-- product id (what resolveTier expects)
  }

  /// (Kept for backward compatibility) – previously returned the entitlement key.
  /// Now returns the product id so existing callers keep working.
  static String? getActiveEntitlementId(CustomerInfo info) {
    return getActiveProductId(info);
  }

  /// 🔄 Sync entitlement to Firestore for backend/analytics.
  ///
  /// Fields written:
  /// - entitlementId:  PRODUCT ID (e.g. "home_chef_monthly")  ✅ used by your app
  /// - entitlementKey: ENTITLEMENT KEY (e.g. "pro")           📝 optional, informational
  /// - tier:           resolved from product id
  static Future<void> syncEntitlementToFirestore(CustomerInfo info) async {
    final EntitlementInfo? e = info.entitlements.active.values.isNotEmpty
        ? info.entitlements.active.values.first
        : null;

    final String entitlementKey = e?.identifier ?? 'none'; // RC entitlement key
    final String productId = e?.productIdentifier ?? 'none'; // RC product id
    final String tier = resolveTier(productId); // your mapping
    final String userId = info.originalAppUserId; // must be set in configure()

    if (userId.isEmpty) return;

    final updateData = {
      // Keep this name for compatibility: your code expects product id here.
      'entitlementId': productId,
      // Also store the RC entitlement key (nice to have).
      'entitlementKey': entitlementKey,

      'tier': tier,
      'willRenew': e?.willRenew ?? false,
      'originalPurchaseDate': e?.originalPurchaseDate,
      'expirationDate': e?.expirationDate,
      'store': e?.store,
      'periodType': e?.periodType.name, // "trial", "intro", "normal"
      'lastSyncedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(updateData, SetOptions(merge: true));

      if (kDebugMode) {
        print(
          '✅ Synced RC → {entitlementId(product)="$productId", '
          'entitlementKey="$entitlementKey", tier="$tier", '
          'willRenew=${updateData['willRenew']}, '
          'periodType=${updateData['periodType']}}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync entitlement data: $e');
      }
    }
  }
}

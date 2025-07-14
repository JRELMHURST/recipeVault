import 'package:purchases_flutter/purchases_flutter.dart';

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
      return customerInfo;
    } on PurchasesErrorCode {
      rethrow;
    }
  }

  /// Shorthand for purchasing – used in PaywallScreen
  static Future<void> purchase(Package package) async {
    await purchasePackage(package);
  }

  /// Restore previous purchases
  static Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
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
}

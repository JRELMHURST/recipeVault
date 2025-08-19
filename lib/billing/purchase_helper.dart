import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // PlatformException
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PurchaseHelper {
  /// Initialise RevenueCat with the public API key.
  /// Pass the Firebase UID if you have it to avoid anonymous RC ids.
  static Future<void> initRevenueCat(String apiKey, {String? appUserId}) async {
    await Purchases.setLogLevel(LogLevel.debug);
    final config = PurchasesConfiguration(apiKey);
    if (appUserId != null && appUserId.isNotEmpty) {
      config.appUserID = appUserId;
    }
    await Purchases.configure(config);
  }

  /// Current customer info (entitlements, subscriptions).
  static Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  /// All offerings from RC.
  static Future<Offerings> getOfferings() => Purchases.getOfferings();

  /// Purchase a selected package and then trigger backend reconcile.
  static Future<CustomerInfo> purchasePackage(Package package) async {
    try {
      final info = await Purchases.purchasePackage(package);
      await _triggerBackendReconcile();
      return info;
    } on PlatformException {
      rethrow; // let UI handle cancelled/failed states
    }
  }

  /// Shorthand used in UIs.
  static Future<void> purchase(Package package) async {
    await purchasePackage(package);
  }

  /// Restore previous purchases and trigger backend reconcile.
  static Future<CustomerInfo> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    await _triggerBackendReconcile();
    return info;
  }

  /// Optimistic: check RC immediately without waiting for backend.
  static String? getActiveProductId(CustomerInfo info) {
    if (info.entitlements.active.isEmpty) return null;
    final EntitlementInfo e = info.entitlements.active.values.first;
    return e.productIdentifier;
  }

  static String? getActiveEntitlementKey(CustomerInfo info) {
    if (info.entitlements.active.isEmpty) return null;
    final EntitlementInfo e = info.entitlements.active.values.first;
    return e.identifier;
  }

  /// Optional: call when the Firebase user changes to link RC explicitly.
  static Future<void> identifyIfNeeded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await Purchases.logIn(uid);
      await Purchases.invalidateCustomerInfoCache();
      await _triggerBackendReconcile();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ RevenueCat identify failed: $e');
    }
  }

  /// Optional: unlink RC user when signing out.
  static Future<void> logOutRc() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ RevenueCat logOut failed: $e');
    }
  }

  /// 🔄 Trigger backend reconcile (Firestore is updated only by backend).
  static Future<void> _triggerBackendReconcile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final functions = FirebaseFunctions.instanceFor(region: "europe-west2");
      final callable = functions.httpsCallable("reconcileUserFromRC");
      await callable.call({"uid": uid});
      if (kDebugMode) debugPrint("✅ Reconcile triggered for $uid");
    } catch (e) {
      if (kDebugMode) debugPrint("⚠️ Failed to trigger reconcile: $e");
    }
  }

  /// ✅ Public wrapper for backend reconcile (for external calls).
  static Future<void> triggerBackendReconcile() => _triggerBackendReconcile();
}

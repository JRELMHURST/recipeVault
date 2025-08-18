import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // PlatformException
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/billing/tier_utils.dart'; // resolveTier(productId)

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

  /// Purchase a selected package and sync to Firestore.
  static Future<CustomerInfo> purchasePackage(Package package) async {
    try {
      final info = await Purchases.purchasePackage(package);
      await syncEntitlementToFirestore(info);
      return info;
    } on PlatformException {
      rethrow; // let UI handle cancelled/failed states
    }
  }

  /// Shorthand used in UIs.
  static Future<void> purchase(Package package) async {
    await purchasePackage(package);
  }

  /// Restore previous purchases and sync.
  static Future<CustomerInfo> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    await syncEntitlementToFirestore(info);
    return info;
  }

  /// True if a given entitlement KEY is active (RC entitlement identifier, e.g. "pro").
  static bool hasActiveEntitlement(CustomerInfo info, String entitlementKey) {
    return info.entitlements.active.containsKey(entitlementKey);
  }

  /// Active product id (e.g. "home_chef_monthly") — what resolveTier() expects.
  static String? getActiveProductId(CustomerInfo info) {
    if (info.entitlements.active.isEmpty) return null;
    final EntitlementInfo e = info.entitlements.active.values.first;
    return e.productIdentifier;
  }

  /// Back-compat alias; returns product id (not entitlement key).
  static String? getActiveEntitlementId(CustomerInfo info) {
    return getActiveProductId(info);
  }

  /// 🔄 Push RC → Firestore so backend/analytics can see current tier.
  ///
  /// Written fields:
  /// - entitlementId: product id (e.g. "home_chef_monthly")  ✅ canonical for app logic
  /// - entitlementKey: RC entitlement key (optional, informational)
  /// - tier: derived via resolveTier(productId)
  /// - willRenew, originalPurchaseDate, expirationDate, store, periodType, lastSyncedAt
  static Future<void> syncEntitlementToFirestore(CustomerInfo info) async {
    final EntitlementInfo? e = info.entitlements.active.values.isNotEmpty
        ? info.entitlements.active.values.first
        : null;

    final String productId = e?.productIdentifier ?? 'none'; // RC product id
    final String entitlementKey = e?.identifier ?? 'none'; // RC entitlement key
    final String tier = resolveTier(productId);

    // Prefer Firebase UID; fall back to RC app user id.
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final String userId = (uid != null && uid.isNotEmpty)
        ? uid
        : (info.originalAppUserId.isNotEmpty ? info.originalAppUserId : '');

    if (userId.isEmpty) {
      if (kDebugMode) {
        print('⚠️ syncEntitlementToFirestore skipped: no user id available.');
      }
      return;
    }

    final updateData = <String, dynamic>{
      // Your app reads product id from this field name.
      'entitlementId': productId,
      // Keep entitlement key too (useful for dashboards).
      'entitlementKey': entitlementKey,

      'tier': tier,
      'willRenew': e?.willRenew ?? false,
      // Firestore SDK accepts DateTime and converts to Timestamp.
      'originalPurchaseDate': e?.originalPurchaseDate,
      'expirationDate': e?.expirationDate,
      'store': e?.store, // enum name string
      'periodType': e?.periodType.name, // "trial" | "intro" | "normal"
      'lastSyncedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(updateData, SetOptions(merge: true));

      if (kDebugMode) {
        print(
          '✅ RC sync → users/$userId '
          '{product="$productId", key="$entitlementKey", tier="$tier", '
          'renew=${updateData['willRenew']}, period=${updateData['periodType']}}',
        );
      }
    } catch (err) {
      if (kDebugMode) {
        print('❌ Failed to sync entitlement to Firestore: $err');
      }
    }
  }

  /// Optional: call when the Firebase user changes to link RC to that user explicitly.
  static Future<void> identifyIfNeeded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await Purchases.logIn(uid);
      final info = await Purchases.getCustomerInfo();
      await syncEntitlementToFirestore(info);
    } catch (e) {
      if (kDebugMode) print('⚠️ RevenueCat identify failed: $e');
    }
  }

  /// Optional: unlink RC user when signing out.
  static Future<void> logOutRc() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      if (kDebugMode) print('⚠️ RevenueCat logOut failed: $e');
    }
  }
}

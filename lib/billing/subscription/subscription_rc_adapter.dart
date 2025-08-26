// lib/billing/subscription/subscription_rc_adapter.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Thin adapter around RevenueCat calls (easier to mock/test)
class RcAdapter {
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> logIn(String appUserId) async {
    if (!isSupported) return;
    await Purchases.logIn(appUserId);
  }

  Future<void> logOutSafe() async {
    if (!isSupported) return;
    try {
      await Purchases.logOut();
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.logOutWithAnonymousUserError) rethrow;
      debugPrint('RC: already anonymous; ignoring logOut.');
    }
  }

  Future<CustomerInfo> getCustomerInfo() async {
    if (!isSupported) return CustomerInfo.fromJson(const {});
    return Purchases.getCustomerInfo();
  }

  Future<void> invalidateCache() async {
    if (!isSupported) return;
    await Purchases.invalidateCustomerInfoCache();
  }

  void addCustomerInfoListener(void Function(CustomerInfo) onUpdate) {
    if (!isSupported) return;
    Purchases.addCustomerInfoUpdateListener(onUpdate);
  }

  Future<Offerings> getOfferings() async {
    if (!isSupported) {
      // Your SDK expects Offerings(Map<String, Offering> all)
      return Offerings(const <String, Offering>{});
    }
    return Purchases.getOfferings();
  }
}

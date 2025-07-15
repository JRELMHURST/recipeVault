import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  String _tier = 'none';
  bool _isSuperUser = false;
  EntitlementInfo? _activeEntitlement;
  CustomerInfo? _customerInfo;

  String get tier => _tier;
  bool get isSuperUser => _isSuperUser;

  bool get isTaster => _tier == 'taster';
  bool get isHomeChef => _tier == 'home_chef';
  bool get isMasterChef => _tier == 'master_chef';

  bool get hasActiveSubscription => isHomeChef || isMasterChef;

  bool get allowTranslation => isMasterChef || isHomeChef;
  bool get allowImageUpload => isMasterChef || isHomeChef;
  bool get allowSaveToVault => isMasterChef || isHomeChef || isTaster;

  bool get isTasterTrialActive {
    final entitlement = _customerInfo?.entitlements.active.values.firstOrNull;
    return entitlement?.periodType == PeriodType.intro &&
        entitlement?.productIdentifier == 'master_chef_monthly';
  }

  bool get isTasterTrialExpired {
    final entitlement = _customerInfo?.entitlements.active.values.firstOrNull;
    final isTrial =
        entitlement?.periodType == PeriodType.intro ||
        entitlement?.periodType == PeriodType.trial;
    final trialEnded = isTrial && entitlement?.willRenew == false;
    return trialEnded && isTaster;
  }

  bool get isTrialExpired => !isTasterTrialActive && isTaster;

  // Package references for the paywall
  Package? homeChefPackage;
  Package? masterChefMonthlyPackage;

  void updateSuperUser(bool value) {
    _isSuperUser = value;
    notifyListeners();
  }

  Future<void> init() async {
    await Purchases.invalidateCustomerInfoCache();
    await loadSubscriptionStatus();
    await _loadAvailablePackages();
  }

  Future<void> refresh() async {
    await Purchases.invalidateCustomerInfoCache();
    await loadSubscriptionStatus();
    notifyListeners();
  }

  Future<void> loadSubscriptionStatus() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      final entitlements = _customerInfo!.entitlements.active;
      debugPrint('🧾 Active entitlements: ${entitlements.keys}');

      if (entitlements.keys.any((k) => k.startsWith('master_chef'))) {
        _tier = 'master_chef';
        _activeEntitlement = entitlements.entries
            .firstWhere((e) => e.key.startsWith('master_chef'))
            .value;
      } else if (entitlements.keys.any((k) => k.startsWith('home_chef'))) {
        _tier = 'home_chef';
        _activeEntitlement = entitlements.entries
            .firstWhere((e) => e.key.startsWith('home_chef'))
            .value;
      } else if (entitlements.containsKey('taster_trial')) {
        _tier = 'taster';
        _activeEntitlement = entitlements['taster_trial'];
      } else {
        _tier = 'none';
        _activeEntitlement = null;
      }

      debugPrint('🎯 Subscription tier resolved as: $_tier');
      notifyListeners();
    } catch (e) {
      debugPrint('🔴 Error loading subscription status: $e');
      _tier = 'none';
      _activeEntitlement = null;
      notifyListeners();
    }
  }

  Future<void> _loadAvailablePackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current != null) {
        homeChefPackage = current.availablePackages.firstWhere(
          (pkg) => pkg.identifier == 'home_chef_monthly',
          orElse: () => current.availablePackages.first,
        );
        masterChefMonthlyPackage = current.availablePackages.firstWhere(
          (pkg) => pkg.identifier == 'master_chef_monthly',
          orElse: () => current.availablePackages.first,
        );
      }
    } catch (e) {
      debugPrint('🔴 Error loading available packages: $e');
    }
  }

  String get currentEntitlement => _tier;

  String get trialEndDateFormatted {
    final date = trialEndDate;
    if (date != null) {
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }

  DateTime? get trialEndDate {
    final expiry = _activeEntitlement?.expirationDate;
    if (_activeEntitlement?.periodType == PeriodType.trial && expiry != null) {
      return DateTime.tryParse(expiry);
    }
    return null;
  }

  void reset() {
    _tier = 'none';
    _activeEntitlement = null;
    _isSuperUser = false;
    notifyListeners();
  }

  Future<void> syncRevenueCatEntitlement() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final active = customerInfo.entitlements.active;

      _customerInfo = customerInfo;
      _activeEntitlement = active.values.firstOrNull;
      _tier = _mapEntitlementToTier(_activeEntitlement?.identifier);
      _isSuperUser = await _fetchSuperUserFlag();

      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'tier': _tier,
              'lastSynced': FieldValue.serverTimestamp(),
            });
      }

      debugPrint('🔁 RevenueCat entitlement synced: $_tier');
    } catch (e, stack) {
      debugPrint('❌ Failed to sync RevenueCat entitlement: $e');
      debugPrint(stack.toString());
    }
  }

  String _mapEntitlementToTier(String? entitlementId) {
    switch (entitlementId) {
      case 'home_chef':
      case 'home_chef_monthly':
        return 'home_chef';
      case 'master_chef':
      case 'master_chef_monthly':
      case 'master_chef_yearly':
        return 'master_chef';
      case 'taster':
        return 'taster';
      default:
        return 'none';
    }
  }

  Future<bool> _fetchSuperUserFlag() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data()?['isSuperUser'] == true;
  }
}

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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

      if (entitlements.containsKey('master_chef')) {
        _tier = 'master_chef';
        _activeEntitlement = entitlements['master_chef'];
      } else if (entitlements.containsKey('home_chef')) {
        _tier = 'home_chef';
        _activeEntitlement = entitlements['home_chef'];
      } else {
        _tier = 'taster';
        _activeEntitlement = null;
      }

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

  bool get isTrialExpired {
    final expiry = trialEndDate;
    return expiry != null && expiry.isBefore(DateTime.now());
  }

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
}

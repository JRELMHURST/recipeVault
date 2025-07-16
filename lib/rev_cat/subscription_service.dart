import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

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
  bool get allowTranslation => isHomeChef || isMasterChef;
  bool get allowImageUpload => isHomeChef || isMasterChef;
  bool get allowSaveToVault => isTaster || isHomeChef || isMasterChef;

  Package? homeChefPackage;
  Package? masterChefMonthlyPackage;

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

  void updateSuperUser(bool value) {
    _isSuperUser = value;
    notifyListeners();
  }

  void reset() {
    _tier = 'none';
    _activeEntitlement = null;
    _isSuperUser = false;
    notifyListeners();
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

  Future<void> init() async {
    await Purchases.invalidateCustomerInfoCache();
    await loadSubscriptionStatus();
    await _loadAvailablePackages();
  }

  Future<void> refresh() async {
    await Purchases.invalidateCustomerInfoCache();
    await loadSubscriptionStatus();

    // 🕒 Handle sandbox expiry (e.g. entitlement expired after 5 mins)
    final now = DateTime.now();
    final expiryString = _activeEntitlement?.expirationDate;

    if (expiryString != null) {
      final expiryDate = DateTime.tryParse(expiryString);
      if (expiryDate != null && now.isAfter(expiryDate)) {
        debugPrint('⚠️ Sandbox entitlement expired – resetting tier to none.');
        _tier = 'none';
        _activeEntitlement = null;
      }
    }

    notifyListeners();
  }

  /// ✅ Restore this method to resolve UI call from SubscriptionSettingsScreen
  Future<void> restoreAndSync() async {
    await refresh();
  }

  Future<void> loadSubscriptionStatus() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      final entitlements = _customerInfo!.entitlements.active;
      debugPrint('🧾 Active entitlements: ${entitlements.keys}');

      _tier = _resolveTierFromEntitlements(entitlements);

      switch (_tier) {
        case 'master_chef':
          _activeEntitlement = entitlements.entries
              .firstWhereOrNull((e) => e.key.contains('master_chef'))
              ?.value;
          break;
        case 'home_chef':
          _activeEntitlement = entitlements.entries
              .firstWhereOrNull((e) => e.key.contains('home_chef'))
              ?.value;
          break;
        case 'taster':
          _activeEntitlement = entitlements['taster_trial'];
          break;
        default:
          _activeEntitlement = null;
      }

      debugPrint('🎯 Subscription tier resolved as: $_tier');
      _isSuperUser = await _fetchSuperUserFlag();
    } catch (e) {
      debugPrint('🔴 Error loading subscription status: $e');
      _tier = 'none';
      _activeEntitlement = null;
    }
  }

  String _resolveTierFromEntitlements(
    Map<String, EntitlementInfo> entitlements,
  ) {
    if (entitlements.keys.any((k) => k.contains('master_chef'))) {
      return 'master_chef';
    }
    if (entitlements.keys.any((k) => k.contains('home_chef'))) {
      return 'home_chef';
    }
    if (entitlements.containsKey('taster_trial')) return 'taster';
    return 'none';
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
}

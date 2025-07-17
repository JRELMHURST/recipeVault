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
  String _entitlementId = 'none';
  bool? _firestoreTrialActive;

  String get tier => _tier;
  String get entitlementId => _entitlementId;
  bool get isSuperUser => _isSuperUser;
  bool get isLoaded => _tier != 'none';

  bool get isTaster => _tier == 'taster';
  bool get isHomeChef => _tier == 'home_chef';
  bool get isMasterChef => _tier == 'master_chef';

  bool get hasActiveSubscription => isHomeChef || isMasterChef;
  bool get allowTranslation => _isSuperUser || isMasterChef;
  bool get allowImageUpload => _isSuperUser || isMasterChef;
  bool get allowSaveToVault =>
      isTaster || hasActiveSubscription || _isSuperUser;

  Package? homeChefPackage;
  Package? masterChefMonthlyPackage;
  Package? masterChefYearlyPackage;

  bool get isTasterTrialActive => isTaster && (_firestoreTrialActive == true);
  bool get isTasterTrialExpired => isTaster && (_firestoreTrialActive == false);
  bool get isTrialExpired => isTasterTrialExpired;

  void updateSuperUser(bool value) {
    _isSuperUser = value;
    notifyListeners();
  }

  void reset() {
    _tier = 'none';
    _activeEntitlement = null;
    _customerInfo = null;
    _isSuperUser = false;
    _entitlementId = 'none';
    _firestoreTrialActive = null;
    notifyListeners();
  }

  String get currentEntitlement => _tier;

  String get trialEndDateFormatted {
    final date = trialEndDate;
    return date != null ? '${date.day}/${date.month}/${date.year}' : 'N/A';
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

    final now = DateTime.now();
    final expiryString = _activeEntitlement?.expirationDate;
    if (expiryString != null) {
      final expiryDate = DateTime.tryParse(expiryString);
      if (expiryDate != null && now.isAfter(expiryDate)) {
        debugPrint('⚠️ Sandbox entitlement expired – resetting tier to none.');
        _tier = 'none';
        _activeEntitlement = null;
        _entitlementId = 'none';
      }
    }

    notifyListeners();
  }

  Future<void> restoreAndSync() async {
    await refresh();
  }

  Future<void> loadSubscriptionStatus() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      _customerInfo = await Purchases.getCustomerInfo();
      final entitlements = _customerInfo!.entitlements.active;

      _tier = _resolveTierFromEntitlements(entitlements);
      _activeEntitlement = _getActiveEntitlement(entitlements, _tier);
      _entitlementId = _activeEntitlement?.productIdentifier ?? 'none';

      if (kDebugMode) {
        debugPrint(
          '🧾 [SubscriptionService] Entitlements: ${entitlements.keys} → Tier: $_tier',
        );
      }

      // Firestore fallback
      if (_tier == 'none' || _tier == 'taster') {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        final data = doc.data();
        if (data != null) {
          _tier = data['tier'] ?? _tier;
          _firestoreTrialActive = data['trialActive'] == true;

          if (kDebugMode) {
            debugPrint(
              '📄 Firestore fallback → Tier: $_tier, TrialActive: $_firestoreTrialActive',
            );
          }
        }
      }

      _isSuperUser = await _fetchSuperUserFlag();
    } catch (e) {
      debugPrint('🔴 Error loading subscription status: $e');
      _tier = 'none';
      _activeEntitlement = null;
      _entitlementId = 'none';
    }
  }

  String _resolveTierFromEntitlements(
    Map<String, EntitlementInfo> entitlements,
  ) {
    for (final entry in entitlements.entries) {
      final id = entry.value.productIdentifier;
      if (id == 'master_chef_monthly' || id == 'master_chef_yearly') {
        return 'master_chef';
      } else if (id == 'home_chef_monthly') {
        return 'home_chef';
      } else if (entry.key == 'taster_trial') {
        return 'taster';
      }
    }
    return 'none';
  }

  EntitlementInfo? _getActiveEntitlement(
    Map<String, EntitlementInfo> entitlements,
    String tier,
  ) {
    switch (tier) {
      case 'master_chef':
        return entitlements.entries
            .firstWhereOrNull(
              (e) =>
                  e.value.productIdentifier == 'master_chef_monthly' ||
                  e.value.productIdentifier == 'master_chef_yearly',
            )
            ?.value;
      case 'home_chef':
        return entitlements.entries
            .firstWhereOrNull(
              (e) => e.value.productIdentifier == 'home_chef_monthly',
            )
            ?.value;
      case 'taster':
        return entitlements['taster_trial'];
      default:
        return null;
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

        masterChefYearlyPackage = current.availablePackages.firstWhere(
          (pkg) => pkg.identifier == 'master_chef_yearly',
          orElse: () => current.availablePackages.first,
        );
      }
    } catch (e) {
      debugPrint('🔴 Error loading available packages: $e');
    }
  }

  /// 🧩 Emoji icon for tier-based visual branding
  String get tierIcon {
    switch (_tier) {
      case 'master_chef':
        return '👑';
      case 'home_chef':
        return '👨‍🍳';
      case 'taster':
        return '🥄';
      default:
        return '❓';
    }
  }
}

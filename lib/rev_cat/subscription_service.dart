import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:recipe_vault/services/user_preference_service.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final ValueNotifier<String> tierNotifier = ValueNotifier('free');

  // 🔐 Internal state
  String _tier = 'free';
  String _entitlementId = 'none';
  bool? _firestoreTrialActive;
  bool _isLoadingTier = false;
  String? _lastLoggedTier;

  CustomerInfo? _customerInfo;
  EntitlementInfo? _activeEntitlement;

  // 🎟️ Available packages
  Package? homeChefPackage;
  Package? masterChefMonthlyPackage;
  Package? masterChefYearlyPackage;

  // 🧾 Tier accessors
  String get tier => _tier;
  String get entitlementId => _entitlementId;
  String get currentEntitlement => _tier;
  bool get isLoaded => _customerInfo != null;

  // 🔓 Tier checkers
  bool get isFree => _tier == 'free';
  bool get isTaster => _tier == 'taster';
  bool get isHomeChef => _tier == 'home_chef';
  bool get isMasterChef => _tier == 'master_chef';

  bool get hasActiveSubscription => isHomeChef || isMasterChef;
  bool get isTasterTrialActive => isTaster && (_firestoreTrialActive == true);
  bool get isTasterTrialExpired => isTaster && (_firestoreTrialActive == false);
  bool get isTrialExpired => isTasterTrialExpired;

  // 🧠 Access control logic
  bool get allowTranslation => isTaster || isHomeChef || isMasterChef;
  bool get allowImageUpload => isTaster || isHomeChef || isMasterChef;
  bool get allowSaveToVault => !isFree;

  bool get allowCategoryCreation {
    return switch (_tier) {
      'master_chef' => true,
      'home_chef' => true,
      _ => false,
    };
  }

  bool get canStartTrial => tier == 'free' && !isTasterTrialActive;

  String get tierIcon {
    return switch (_tier) {
      'master_chef' => '👑',
      'home_chef' => '👨‍🍳',
      'taster' => '🥄',
      'free' => '🆓',
      _ => '❓',
    };
  }

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
        debugPrint('⚠️ Sandbox entitlement expired – resetting tier to free.');
        _tier = 'free';
        _entitlementId = 'none';
        _activeEntitlement = null;
        tierNotifier.value = _tier;
      }
    }

    // ✅ Sync to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'tier': _tier,
        'entitlementId': _entitlementId,
        'trialActive': isTasterTrialActive,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    notifyListeners();
  }

  Future<void> restoreAndSync() async => refresh();

  Future<void> reset() async {
    _tier = 'free';
    _entitlementId = 'none';
    _activeEntitlement = null;
    _customerInfo = null;
    _firestoreTrialActive = null;
    tierNotifier.value = _tier;

    await Purchases.invalidateCustomerInfoCache();
    notifyListeners();
  }

  Future<void> loadSubscriptionStatus() async {
    if (_isLoadingTier) return;
    _isLoadingTier = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _customerInfo = await Purchases.getCustomerInfo();
      final entitlements = _customerInfo!.entitlements.active;

      _tier = _resolveTierFromEntitlements(entitlements);
      _activeEntitlement = _getActiveEntitlement(entitlements, _tier);
      _entitlementId = _activeEntitlement?.productIdentifier ?? 'none';
      tierNotifier.value = _tier;

      _logTierOnce();

      if (kDebugMode) {
        debugPrint(
          '🧾 [SubscriptionService] Entitlements: ${entitlements.keys} → Tier: $_tier',
        );
      }

      // 🔁 Fallback for Taster tier via Firestore
      if (_tier == 'free' || _tier == 'taster') {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();

        if (data != null) {
          final fallbackTier = data['tier'];
          if (fallbackTier != null && fallbackTier != _tier) {
            debugPrint('📄 Firestore fallback tier override → $fallbackTier');
            _tier = fallbackTier;
            tierNotifier.value = _tier;
          }

          _firestoreTrialActive = data['trialActive'] == true;
          debugPrint('📄 Firestore trialActive: $_firestoreTrialActive');
        }
      }

      await UserPreferencesService.ensureBubbleFlagTriggeredIfEligible(_tier);
      notifyListeners();
    } catch (e) {
      debugPrint('🔴 Error loading subscription status: $e');
    } finally {
      _isLoadingTier = false;
    }
  }

  Future<void> _loadAvailablePackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;

      if (current != null) {
        homeChefPackage = current.availablePackages.firstWhereOrNull(
          (pkg) => pkg.identifier == 'home_chef_monthly',
        );
        masterChefMonthlyPackage = current.availablePackages.firstWhereOrNull(
          (pkg) => pkg.identifier == 'master_chef_monthly',
        );
        masterChefYearlyPackage = current.availablePackages.firstWhereOrNull(
          (pkg) => pkg.identifier == 'master_chef_yearly',
        );
      }
    } catch (e) {
      debugPrint('🔴 Error loading available packages: $e');
    }
  }

  String _resolveTierFromEntitlements(
    Map<String, EntitlementInfo> entitlements,
  ) {
    for (final entry in entitlements.entries) {
      final id = entry.value.productIdentifier;
      if (['master_chef_monthly', 'master_chef_yearly'].contains(id)) {
        return 'master_chef';
      }
      if (id == 'home_chef_monthly') return 'home_chef';
      if (entry.key == 'taster_trial') return 'taster';
    }
    return 'free';
  }

  EntitlementInfo? _getActiveEntitlement(
    Map<String, EntitlementInfo> entitlements,
    String tier,
  ) {
    switch (tier) {
      case 'master_chef':
        return entitlements.entries
            .firstWhereOrNull(
              (e) => [
                'master_chef_monthly',
                'master_chef_yearly',
              ].contains(e.value.productIdentifier),
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

  void _logTierOnce() {
    if (_lastLoggedTier != _tier) {
      debugPrint('📦 Tier changed → $_tier');
      _lastLoggedTier = _tier;
    }
  }

  bool get hasAccess => allowSaveToVault;
  String get currentTier => _tier;
}

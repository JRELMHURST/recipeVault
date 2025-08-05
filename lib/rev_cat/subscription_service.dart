// ignore_for_file: deprecated_member_use

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

  String _tier = 'free';
  String _entitlementId = 'none';
  bool _hasSpecialAccess = false;
  bool _isLoadingTier = false;
  String? _lastLoggedTier;

  CustomerInfo? _customerInfo;
  EntitlementInfo? _activeEntitlement;

  Package? homeChefPackage;
  Package? masterChefMonthlyPackage;
  Package? masterChefYearlyPackage;

  final Map<String, Map<String, int>> _usageData = {
    'aiUsage': {},
    'translationUsage': {},
  };

  String get tier => _tier;
  String get entitlementId => _entitlementId;
  String get currentEntitlement => _tier;
  bool get isLoaded => _customerInfo != null;

  bool get isFree => _tier == 'free';
  bool get isHomeChef => _tier == 'home_chef';
  bool get isMasterChef => _tier == 'master_chef';

  bool get hasActiveSubscription => isHomeChef || isMasterChef;

  bool get allowTranslation => hasActiveSubscription;
  bool get allowImageUpload => hasActiveSubscription;
  bool get allowSaveToVault => !isFree;

  bool get allowCategoryCreation => isMasterChef || isHomeChef;
  bool get hasSpecialAccess => _hasSpecialAccess;

  String get tierIcon => switch (_tier) {
    'master_chef' => '👑',
    'home_chef' => '👨‍🍳',
    'free' => '🆓',
    _ => '❓',
  };

  String get entitlementLabel => switch (entitlementId) {
    'master_chef_monthly' => 'Master Chef – Monthly',
    'master_chef_yearly' => 'Master Chef – Yearly',
    'home_chef_monthly' => 'Home Chef – Monthly',
    _ => 'Free Plan',
  };

  bool get isYearly => entitlementId.endsWith('_yearly');
  String get billingCycle => isYearly ? 'Yearly' : 'Monthly';

  DateTime? get trialEndDate {
    final expiry = _activeEntitlement?.expirationDate;
    if (_activeEntitlement?.periodType == PeriodType.trial && expiry != null) {
      return DateTime.tryParse(expiry);
    }
    return null;
  }

  String get trialEndDateFormatted {
    final date = trialEndDate;
    return date != null ? '${date.day}/${date.month}/${date.year}' : 'N/A';
  }

  void updateTier(String newTier) {
    if (_tier != newTier) {
      _tier = newTier;
      tierNotifier.value = newTier;
      _logTierOnce(source: 'updateTier');
      notifyListeners();

      if (kDebugMode) {
        debugPrint('🧾 [SubscriptionService] Tier manually updated → $_tier');
      }
    }
  }

  Future<void> init() async {
    await Purchases.invalidateCustomerInfoCache();
    await loadSubscriptionStatus();
    await _loadAvailablePackages();
  }

  Future<void> refreshAndNotify() async {
    await refresh();
    notifyListeners();
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

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'tier': _tier,
        'entitlementId': _entitlementId,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> syncRevenueCatEntitlement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = _getActiveEntitlement(
        customerInfo.entitlements.active,
        _tier,
      );
      final entitlementId = entitlement?.productIdentifier ?? 'none';

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'tier': _tier,
        'entitlementId': entitlementId,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _logTierOnce(source: 'syncRevenueCatEntitlement');
    } catch (e) {
      debugPrint('⚠️ Failed to sync entitlement to Firestore: $e');
    }
  }

  Future<void> restoreAndSync() async => refresh();

  Future<void> reset() async {
    _tier = 'free';
    _entitlementId = 'none';
    _activeEntitlement = null;
    _customerInfo = null;
    _hasSpecialAccess = false;
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

      _logTierOnce(source: 'loadSubscriptionStatus');

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

        _hasSpecialAccess = data['specialAccess'] == true;
        debugPrint('📄 Firestore specialAccess: $_hasSpecialAccess');

        if (_hasSpecialAccess && _tier == 'free') {
          _tier = 'home_chef';
          tierNotifier.value = _tier;
          debugPrint('🎁 specialAccess override → Home Chef tier');
        }
      }

      try {
        final usageDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('aiUsage')
            .doc('usage')
            .get();
        _usageData['aiUsage'] = Map<String, int>.from(usageDoc.data() ?? {});
      } catch (e) {
        debugPrint('⚠️ Failed to load AI usage data: $e');
      }

      try {
        final translationDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('translationUsage')
            .doc('usage')
            .get();
        _usageData['translationUsage'] = Map<String, int>.from(
          translationDoc.data() ?? {},
        );
      } catch (e) {
        debugPrint('⚠️ Failed to load translation usage data: $e');
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
      default:
        return null;
    }
  }

  void _logTierOnce({String source = 'unknown'}) {
    if (_lastLoggedTier != _tier) {
      debugPrint('📦 Tier changed → $_tier (source: $source)');
      _lastLoggedTier = _tier;
    }
  }

  bool get hasAccess => allowSaveToVault;
  String get currentTier => _tier;

  int get aiUsage {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _usageData['aiUsage']?[key] ?? 0;
  }

  int get translationUsage {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _usageData['translationUsage']?[key] ?? 0;
  }

  Future<String> getResolvedTier() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'free';

    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    final customerInfo = await Purchases.getCustomerInfo();
    final entitlements = customerInfo.entitlements.active;
    final rcTier = _resolveTierFromEntitlements(entitlements);
    final entitlementId =
        _getActiveEntitlement(entitlements, rcTier)?.productIdentifier ??
        'none';

    final doc = await firestore.collection('users').doc(uid).get();
    final fsTier = doc.data()?['tier'] as String? ?? 'free';

    final resolvedTier = fsTier != 'free' ? fsTier : rcTier;
    updateTier(resolvedTier);

    await firestore.collection('users').doc(uid).set({
      'tier': resolvedTier,
      'entitlementId': entitlementId,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return resolvedTier;
  }
}

// Full updated SubscriptionService.dart
// [Refreshed August 2025] - resolves Home Chef always displaying issue

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

  // ───── Public Getters ─────
  String get tier => _tier;
  String get entitlementId => _entitlementId;
  bool get isLoaded => _customerInfo != null;

  bool get isFree => _tier == 'free';
  bool get isHomeChef => _tier == 'home_chef';
  bool get isMasterChef => _tier == 'master_chef';

  bool get hasActiveSubscription => isHomeChef || isMasterChef;

  bool get allowTranslation => hasActiveSubscription;
  bool get allowImageUpload => hasActiveSubscription;
  bool get allowSaveToVault => !isFree;

  bool get allowCategoryCreation => hasActiveSubscription;
  bool get hasSpecialAccess => _hasSpecialAccess;

  String get tierIcon => switch (_tier) {
    'master_chef' => '👑',
    'home_chef' => '👨‍🍳',
    'free' => '🆓',
    _ => '❓',
  };

  String get entitlementLabel => switch (_entitlementId) {
    'master_chef_monthly' => 'Master Chef – Monthly',
    'master_chef_yearly' => 'Master Chef – Yearly',
    'home_chef_monthly' => 'Home Chef – Monthly',
    _ => 'Free Plan',
  };

  bool get isYearly => _entitlementId.endsWith('_yearly');
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

  // ───── Lifecycle Methods ─────

  Future<void> init() async {
    await Purchases.invalidateCustomerInfoCache();
    await loadSubscriptionStatus();
    await _loadAvailablePackages();
  }

  Future<void> refresh() async {
    await Purchases.invalidateCustomerInfoCache();
    await loadSubscriptionStatus();
  }

  Future<void> refreshAndNotify() async {
    await refresh();
    notifyListeners();
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

  void updateTier(String newTier) {
    if (_tier != newTier) {
      _tier = newTier;
      tierNotifier.value = newTier;
      _logTierOnce(source: 'updateTier');
      notifyListeners();
    }
  }

  // ───── Subscription Loading ─────

  Future<void> loadSubscriptionStatus() async {
    if (_isLoadingTier) return;
    _isLoadingTier = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _customerInfo = await Purchases.getCustomerInfo();
      final entitlements = _customerInfo!.entitlements.active;

      final rcTier = _resolveTierFromEntitlements(entitlements);
      final activeEntitlement = _getActiveEntitlement(entitlements, rcTier);
      final rcEntitlementId = activeEntitlement?.productIdentifier ?? 'none';

      _tier = rcTier;
      _entitlementId = rcEntitlementId;
      _activeEntitlement = activeEntitlement;
      tierNotifier.value = _tier;

      _logTierOnce(source: 'loadSubscriptionStatus');

      // Firestore override check
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();

      if (data != null) {
        final fsTier = data['tier'];
        if (fsTier != null && fsTier != _tier && fsTier != 'free') {
          debugPrint('📄 Firestore override → $fsTier');
          _tier = fsTier;
          tierNotifier.value = _tier;
        }

        _hasSpecialAccess = data['specialAccess'] == true;
        if (_hasSpecialAccess && _tier == 'free') {
          _tier = 'home_chef';
          tierNotifier.value = _tier;
          debugPrint('🎁 Special Access: forcing Home Chef tier');
        }
      }

      await _loadUsageData(user.uid);
      await UserPreferencesService.ensureBubbleFlagTriggeredIfEligible(_tier);

      notifyListeners();
    } catch (e) {
      debugPrint('🔴 Failed to load subscription: $e');
    } finally {
      _isLoadingTier = false;
    }
  }

  Future<void> _loadUsageData(String uid) async {
    try {
      final aiSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiUsage')
          .doc('usage')
          .get();
      _usageData['aiUsage'] = Map<String, int>.from(aiSnap.data() ?? {});
    } catch (e) {
      debugPrint('⚠️ Failed to load AI usage: $e');
    }

    try {
      final txSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('translationUsage')
          .doc('usage')
          .get();
      _usageData['translationUsage'] = Map<String, int>.from(
        txSnap.data() ?? {},
      );
    } catch (e) {
      debugPrint('⚠️ Failed to load translation usage: $e');
    }
  }

  // ───── RevenueCat Package Logic ─────

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
      debugPrint('🔴 Error loading packages: $e');
    }
  }

  // ───── Helper Logic ─────

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
      debugPrint('📦 Tier updated → $_tier (from: $source)');
      _lastLoggedTier = _tier;
    }
  }

  // ───── Tier Resolution Public Method ─────

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
    final fsTier = doc.data()?['tier'] ?? 'free';

    final resolved = fsTier != 'free' ? fsTier : rcTier;
    updateTier(resolved);

    await firestore.collection('users').doc(uid).set({
      'tier': resolved,
      'entitlementId': entitlementId,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return resolved;
  }

  Future<void> syncRevenueCatEntitlement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final customerInfo = await Purchases.getCustomerInfo();
    final entitlements = customerInfo.entitlements.active;
    final rcTier = _resolveTierFromEntitlements(entitlements);
    final entitlementId =
        _getActiveEntitlement(entitlements, rcTier)?.productIdentifier ??
        'none';

    _tier = rcTier;
    _entitlementId = entitlementId;
    _activeEntitlement = _getActiveEntitlement(entitlements, rcTier);
    tierNotifier.value = _tier;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'tier': rcTier,
      'entitlementId': entitlementId,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _logTierOnce(source: 'syncRevenueCatEntitlement');
    notifyListeners();
  }
}

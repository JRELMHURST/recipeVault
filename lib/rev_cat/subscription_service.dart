// SubscriptionService.dart
// Refreshed Aug 2025 — single source of truth is Firebase UID + RevenueCat product IDs.
// Tier values: 'none' | 'home_chef' | 'master_chef'

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/services/user_preference_service.dart';

class SubscriptionService extends ChangeNotifier {
  // Singleton
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // ── Public state/notifiers ────────────────────────────────────────────────
  final ValueNotifier<String> tierNotifier = ValueNotifier('none');

  String _tier = 'none'; // 'none' | 'home_chef' | 'master_chef'
  String _entitlementId = 'none'; // RevenueCat productIdentifier or 'none'
  bool _hasSpecialAccess = false;

  bool _isLoadingTier = false;
  bool _isInitialising = false;
  String? _lastLoggedTier;

  CustomerInfo? _customerInfo;
  EntitlementInfo? _activeEntitlement;

  // Cached packages (optional convenience)
  Package? homeChefPackage;
  Package? masterChefMonthlyPackage;
  Package? masterChefYearlyPackage;

  // Usage (per yyyy-mm)
  final Map<String, Map<String, int>> _usageData = {
    'aiUsage': {},
    'translationUsage': {},
  };

  // ── Getters ───────────────────────────────────────────────────────────────
  String get tier => _tier;
  String get entitlementId => _entitlementId;
  bool get isLoaded => _customerInfo != null;

  bool get isHomeChef => _tier == 'home_chef';
  bool get isMasterChef => _tier == 'master_chef';
  bool get hasActiveSubscription => isHomeChef || isMasterChef;

  // Capability gates (keep simple: paid == allowed)
  bool get allowTranslation => hasActiveSubscription;
  bool get allowImageUpload => hasActiveSubscription;
  bool get allowSaveToVault => hasActiveSubscription;
  bool get allowCategoryCreation => hasActiveSubscription;

  bool get hasSpecialAccess => _hasSpecialAccess;

  String get tierIcon => switch (_tier) {
    'master_chef' => '👑',
    'home_chef' => '👨‍🍳',
    'none' => '🚫',
    _ => '❓',
  };

  String get entitlementLabel => switch (_entitlementId) {
    'master_chef_monthly' => 'Master Chef – Monthly',
    'master_chef_yearly' => 'Master Chef – Yearly',
    'home_chef_monthly' => 'Home Chef – Monthly',
    _ => 'No active subscription',
  };

  bool get isYearly => _entitlementId.endsWith('_yearly');

  String get billingCycle {
    if (_entitlementId.contains('yearly')) return 'Yearly';
    if (_entitlementId.contains('monthly')) return 'Monthly';
    return 'None';
  }

  DateTime? get trialEndDate {
    final e = _activeEntitlement;
    if (e == null || e.periodType != PeriodType.trial) return null;
    final raw = e.expirationDate;
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  String get trialEndDateFormatted {
    final d = trialEndDate;
    return d != null ? DateFormat('d/M/yyyy').format(d) : 'N/A';
    // UK day/month/year as requested
  }

  bool get isInTrial {
    final end = trialEndDate;
    return end != null && DateTime.now().isBefore(end);
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

  bool get showUsageWidget => hasActiveSubscription;
  bool get trackUsage => hasActiveSubscription;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_isInitialising) return;
    _isInitialising = true;
    try {
      await Purchases.invalidateCustomerInfoCache();
      await loadSubscriptionStatus();
      await _loadAvailablePackages();
    } finally {
      _isInitialising = false;
    }
  }

  Future<void> refresh() async {
    if (_isLoadingTier) return;
    await Purchases.invalidateCustomerInfoCache();
    await loadSubscriptionStatus();
  }

  Future<void> refreshAndNotify() async {
    await refresh();
    notifyListeners();
  }

  Future<void> reset() async {
    _tier = 'none';
    _entitlementId = 'none';
    _activeEntitlement = null;
    _customerInfo = null;
    _hasSpecialAccess = false;
    tierNotifier.value = _tier;
    await Purchases.invalidateCustomerInfoCache();
    notifyListeners();
  }

  void updateTier(String newTier) {
    if (_tier == newTier) return;
    _tier = newTier;
    tierNotifier.value = newTier;
    if (newTier != 'none') _logTierOnce(source: 'updateTier');
    notifyListeners();
  }

  // ── Core load path ────────────────────────────────────────────────────────
  Future<void> loadSubscriptionStatus() async {
    if (_isLoadingTier) return;
    _isLoadingTier = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // New users sometimes need brief retries for RC provisioning.
      _customerInfo = await _getCustomerInfoWithRetry(
        preferRetry: _isBrandNewUser(user),
      );

      final entitlements = _customerInfo?.entitlements.active ?? const {};
      final rcTier = _resolveTierFromEntitlements(entitlements);
      final activeEntitlement = _getActiveEntitlement(entitlements, rcTier);
      final rcEntitlementId = activeEntitlement?.productIdentifier ?? 'none';

      _tier = rcTier;
      _entitlementId = rcEntitlementId;
      _activeEntitlement = activeEntitlement;
      tierNotifier.value = _tier;
      _logTierOnce(source: 'loadSubscriptionStatus');

      // Firestore overrides (admin/specialAccess)
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();

      if (data != null) {
        final fsTier = (data['tier'] as String?)?.trim();
        if (fsTier != null &&
            fsTier.isNotEmpty &&
            fsTier != 'none' &&
            fsTier != _tier) {
          debugPrint('📄 Firestore override → $fsTier');
          _tier = fsTier;
          tierNotifier.value = _tier;
        }

        _hasSpecialAccess = data['specialAccess'] == true;
        if (_hasSpecialAccess && _tier == 'none') {
          _tier = 'home_chef';
          tierNotifier.value = _tier;
          debugPrint('🎁 Special Access: forcing Home Chef tier');
        }
      }

      await _loadUsageData(user.uid);

      // Keep onboarding flags consistent regardless of tier
      await UserPreferencesService.ensureBubbleFlagTriggeredIfEligible();

      notifyListeners();
    } catch (e) {
      debugPrint('🔴 Failed to load subscription: $e');
    } finally {
      _isLoadingTier = false;
    }
  }

  // ── Usage fetch ───────────────────────────────────────────────────────────
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

  // ── RevenueCat package cache (optional) ───────────────────────────────────
  Future<void> _loadAvailablePackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;

      if (current != null) {
        // You can also filter by product identifiers, but in RC v5 the safer
        // discriminator is storeProduct.identifier or the package identifier
        homeChefPackage = current.availablePackages.firstWhereOrNull(
          (pkg) =>
              pkg.identifier == 'home_chef_monthly' ||
              pkg.storeProduct.identifier == 'home_chef_monthly',
        );
        masterChefMonthlyPackage = current.availablePackages.firstWhereOrNull(
          (pkg) =>
              pkg.identifier == 'master_chef_monthly' ||
              pkg.storeProduct.identifier == 'master_chef_monthly',
        );
        masterChefYearlyPackage = current.availablePackages.firstWhereOrNull(
          (pkg) =>
              pkg.identifier == 'master_chef_yearly' ||
              pkg.storeProduct.identifier == 'master_chef_yearly',
        );
      }
    } catch (e) {
      debugPrint('🔴 Error loading packages: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _resolveTierFromEntitlements(Map<String, EntitlementInfo> ents) {
    for (final entry in ents.entries) {
      final id = entry.value.productIdentifier;
      if (id == 'home_chef_monthly') return 'home_chef';
      if (id == 'master_chef_monthly' || id == 'master_chef_yearly') {
        return 'master_chef';
      }
    }
    return 'none';
  }

  EntitlementInfo? _getActiveEntitlement(
    Map<String, EntitlementInfo> ents,
    String tier,
  ) {
    switch (tier) {
      case 'master_chef':
        return ents.values.firstWhereOrNull(
          (e) =>
              e.productIdentifier == 'master_chef_monthly' ||
              e.productIdentifier == 'master_chef_yearly',
        );
      case 'home_chef':
        return ents.values.firstWhereOrNull(
          (e) => e.productIdentifier == 'home_chef_monthly',
        );
      default:
        return null;
    }
  }

  void _logTierOnce({String source = 'unknown'}) {
    if (_lastLoggedTier == _tier) return;
    debugPrint('📦 Tier updated → $_tier (from: $source)');
    _lastLoggedTier = _tier;
  }

  bool _isBrandNewUser(User user) {
    final created = user.metadata.creationTime;
    final last = user.metadata.lastSignInTime;
    return created != null && last != null && created.isAtSameMomentAs(last);
  }

  Future<CustomerInfo> _getCustomerInfoWithRetry({
    required bool preferRetry,
  }) async {
    int attempts = preferRetry ? 3 : 1;
    Duration delay = const Duration(milliseconds: 400);

    CustomerInfo info = await Purchases.getCustomerInfo();
    while (attempts > 1 && info.entitlements.active.isEmpty) {
      await Future.delayed(delay);
      info = await Purchases.getCustomerInfo();
      attempts--;
      delay = Duration(
        milliseconds: (delay.inMilliseconds * 2).clamp(400, 1600),
      );
      debugPrint('⏳ Retrying RevenueCat fetch… remaining=$attempts');
    }
    return info;
  }

  // ── Tier resolution API (used around the app) ─────────────────────────────
  Future<String> getResolvedTier({bool forceRefresh = false}) async {
    if (!forceRefresh && _tier != 'none') return _tier;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'none';

    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    final customerInfo = await _getCustomerInfoWithRetry(
      preferRetry: _isBrandNewUser(user),
    );
    final entitlements = customerInfo.entitlements.active;
    final rcTier = _resolveTierFromEntitlements(entitlements);
    final entitlementId =
        _getActiveEntitlement(entitlements, rcTier)?.productIdentifier ??
        'none';

    // Firestore may carry an admin override
    final doc = await firestore.collection('users').doc(uid).get();
    final fsTier = (doc.data()?['tier'] as String?)?.trim() ?? 'none';

    final resolved = fsTier != 'none' ? fsTier : rcTier;
    updateTier(resolved);

    await firestore.collection('users').doc(uid).set({
      'tier': resolved,
      'entitlementId': entitlementId,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return resolved;
  }

  Future<void> syncRevenueCatEntitlement({bool forceRefresh = false}) async {
    if (!forceRefresh && _tier != 'none') return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final customerInfo = await _getCustomerInfoWithRetry(
      preferRetry: _isBrandNewUser(user),
    );
    final entitlements = customerInfo.entitlements.active;
    final rcTier = _resolveTierFromEntitlements(entitlements);
    final entitlementId =
        _getActiveEntitlement(entitlements, rcTier)?.productIdentifier ??
        'none';

    debugPrint('📦 RevenueCat entitlementId resolved: $entitlementId');

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

// lib/billing/subscription_service.dart
// Refreshed Aug 2025 — single source of truth is Firebase UID + RevenueCat product IDs.
// Tier values: 'none' | 'home_chef' | 'master_chef'

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:hive/hive.dart';

enum EntitlementStatus { checking, active, inactive }

class SubscriptionService extends ChangeNotifier {
  // Singleton
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // ── Public state/notifiers ────────────────────────────────────────────────
  final ValueNotifier<String> tierNotifier = ValueNotifier('none');
  String _tier = 'none';
  String _entitlementId = 'none'; // RevenueCat productIdentifier or 'none'
  bool _hasSpecialAccess = false;

  bool _isLoadingTier = false;
  bool _isInitialising = false;
  String? _lastLoggedTier;

  CustomerInfo? _customerInfo;
  EntitlementInfo? _activeEntitlement; // cached active entitlement

  /// Expose entitlement safely for trial/expiry info etc.
  EntitlementInfo? get activeEntitlement => _activeEntitlement;

  /// Is the user in a RevenueCat trial?
  bool get isInTrial => _activeEntitlement?.periodType == PeriodType.trial;

  /// Expiration date of the current entitlement (if any).
  DateTime? get expirationDate {
    final exp = _activeEntitlement?.expirationDate;
    return exp != null ? DateTime.tryParse(exp) : null;
  }

  /// Will return true if entitlement is still active but expiring soon (< 7 days).
  bool get isExpiringSoon {
    final exp = expirationDate;
    if (exp == null) return false;
    return exp.isAfter(DateTime.now()) &&
        exp.isBefore(DateTime.now().add(const Duration(days: 7)));
  }

  // Cached packages (optional helpers for paywall)
  Package? homeChefPackage;
  Package? masterChefMonthlyPackage;
  Package? masterChefYearlyPackage;

  // Usage (per yyyy-mm) — mirror backend keys
  final Map<String, Map<String, int>> _usageData = {
    'recipeUsage': {},
    'translatedRecipeUsage': {},
    'imageUsage': {},
  };

  // Tier limits (loaded from Firestore)
  final Map<String, int> _tierLimits = {
    'recipeUsage': 0,
    'translatedRecipeUsage': 0,
    'imageUsage': 0,
  };

  // RC listener guard
  bool _rcListenerAttached = false;

  // ── Local cache (Hive) ────────────────────────────────────────────────────
  static String _prefsBoxName(String uid) => 'userPrefs_$uid';
  static const _kCachedTier = 'cachedTier';
  static const _kCachedStatus = 'cachedStatus'; // 'active' | 'inactive'
  static const _kCachedSpecial = 'cachedSpecialAccess';
  static const _kEverHadAccess = 'everHadAccess'; // bool

  Future<void> _saveCache(
    String uid,
    String tier, {
    required bool active,
  }) async {
    try {
      final boxName = _prefsBoxName(uid);
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box<dynamic>(boxName)
          : await Hive.openBox<dynamic>(boxName);
      await box.put(_kCachedTier, tier);
      await box.put(_kCachedStatus, active ? 'active' : 'inactive');
      await box.put(_kCachedSpecial, _hasSpecialAccess);
      if (active) {
        await box.put(_kEverHadAccess, true);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to cache tier: $e');
    }
  }

  Future<void> _seedFromCacheIfAny(String uid) async {
    try {
      final boxName = _prefsBoxName(uid);
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box<dynamic>(boxName)
          : await Hive.openBox<dynamic>(boxName);

      final cachedTier = (box.get(_kCachedTier) as String?)?.trim();
      final cachedSpecial = box.get(_kCachedSpecial) as bool?;
      bool changed = false;

      if (cachedTier != null && cachedTier.isNotEmpty && cachedTier != _tier) {
        _tier = cachedTier;
        changed = true;
      }
      if (cachedSpecial != null) {
        _hasSpecialAccess = cachedSpecial;
      }

      if (changed) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          tierNotifier.value = _tier;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to seed tier from cache: $e');
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  String get tier => _tier;
  String get productId => _entitlementId;
  bool get isLoaded => _customerInfo != null;

  bool get isHomeChef => _tier == 'home_chef';
  bool get isMasterChef => _tier == 'master_chef';
  bool get hasActiveSubscription => isHomeChef || isMasterChef;

  EntitlementStatus get status {
    if (_isInitialising || _isLoadingTier || _customerInfo == null) {
      return EntitlementStatus.checking;
    }
    if (hasActiveSubscription || _hasSpecialAccess) {
      return EntitlementStatus.active;
    }
    return EntitlementStatus.inactive;
  }

  bool get ready => status != EntitlementStatus.checking;

  Future<bool> get everHadAccess async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final boxName = _prefsBoxName(uid);
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
    return (box.get(_kEverHadAccess) as bool?) ?? false;
  }

  // Capability gates — PAID ONLY
  bool get allowTranslation => hasActiveSubscription || _hasSpecialAccess;
  bool get allowImageUpload => hasActiveSubscription || _hasSpecialAccess;
  bool get allowSaveToVault => hasActiveSubscription || _hasSpecialAccess;
  bool get allowCategoryCreation => hasActiveSubscription || _hasSpecialAccess;

  bool get hasSpecialAccess => _hasSpecialAccess;

  // ── Usage getters (current month) ─────────────────────────────────────────
  int _getUsage(String kind) {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _usageData[kind]?[key] ?? 0;
  }

  int get recipeUsage => _getUsage('recipeUsage');
  int get translatedRecipeUsage => _getUsage('translatedRecipeUsage');
  int get imageUsage => _getUsage('imageUsage');

  // Tier limits
  int get aiLimit => _tierLimits['recipeUsage'] ?? 0;
  int get translatedRecipeLimit => _tierLimits['translatedRecipeUsage'] ?? 0;
  int get imageLimit => _tierLimits['imageUsage'] ?? 0;

  bool get showUsageWidget => hasActiveSubscription || _hasSpecialAccess;
  bool get trackUsage => hasActiveSubscription || _hasSpecialAccess;

  // 🆕 Extra compatibility getters (aliases only)
  int get translationUsage => translatedRecipeUsage;
  String getResolvedTier() => _tier;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_isInitialising) return;
    _isInitialising = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _seedFromCacheIfAny(user.uid);
      }

      if (!_rcListenerAttached) {
        Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
        _rcListenerAttached = true;
      }

      await Purchases.invalidateCustomerInfoCache();
      await loadSubscriptionStatus();
      await _loadAvailablePackages();
    } finally {
      _isInitialising = false;
    }
  }

  Future<void> setAppUserId(String? firebaseUid) async {
    try {
      if (firebaseUid == null) {
        try {
          await Purchases.logOut();
        } on PlatformException catch (e) {
          final code = e.code;
          final readable = (e.details is Map)
              ? (e.details['readableErrorCode'] as String?)
              : null;
          if (code != '22' && readable != 'LOGOUT_CALLED_WITH_ANONYMOUS_USER') {
            rethrow;
          }
          debugPrint('RC: already anonymous; ignoring logOut.');
        }
        await reset();
        return;
      }

      await _seedFromCacheIfAny(firebaseUid);
      await Purchases.logIn(firebaseUid);
      await refresh();
    } catch (e) {
      debugPrint('RevenueCat setAppUserId error: $e');
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

  /// 🆕 Legacy shim for UI code that still calls this.
  Future<void> syncRevenueCatEntitlement({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _activeEntitlement = null;
      _tier = 'none';
      _entitlementId = 'none';
      await refresh();
      notifyListeners();
    } else {
      await refreshAndNotify();
    }
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

      _customerInfo = await _getCustomerInfoWithRetry(
        preferRetry: _isBrandNewUser(user),
      );

      final ents = _customerInfo?.entitlements.active ?? const {};
      final rcTier = _resolveTierFromEntitlements(ents);
      final activeEntitlement = _getActiveEntitlement(ents, rcTier);
      final rcEntitlementId = (activeEntitlement?.productIdentifier ?? 'none')
          .toLowerCase();

      _tier = rcTier;
      _entitlementId = rcEntitlementId;
      _activeEntitlement = activeEntitlement;
      tierNotifier.value = _tier;
      _logTierOnce(source: 'loadSubscriptionStatus');

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
      await _saveCache(user.uid, _tier, active: hasActiveSubscription);

      notifyListeners();
    } catch (e) {
      debugPrint('🔴 Failed to load subscription: $e');
    } finally {
      _isLoadingTier = false;
    }
  }

  // ── Usage fetch ───────────────────────────────────────────────────────────
  Future<void> _loadUsageData(String uid) async {
    for (final kind in _usageData.keys) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection(kind)
            .doc('usage')
            .get();
        _usageData[kind] = Map<String, int>.from(snap.data() ?? {});
      } catch (e) {
        debugPrint('⚠️ Failed to load $kind: $e');
        _usageData[kind] = {};
      }
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('tierLimits')
          .doc(_tier)
          .get();
      if (snap.exists) {
        _tierLimits.addAll(Map<String, int>.from(snap.data() ?? {}));
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load tier limits: $e');
    }
  }

  // ── RevenueCat push updates ───────────────────────────────────────────────
  void _onCustomerInfo(CustomerInfo info) async {
    _customerInfo = info;

    final ents = info.entitlements.active;
    final rcTier = _resolveTierFromEntitlements(ents);
    final activeEntitlement = _getActiveEntitlement(ents, rcTier);
    final rcEntitlementId = (activeEntitlement?.productIdentifier ?? 'none')
        .toLowerCase();

    final changedTier = _tier != rcTier;
    final changedEnt = _entitlementId != rcEntitlementId;

    _tier = rcTier;
    _entitlementId = rcEntitlementId;
    _activeEntitlement = activeEntitlement;

    if (changedTier) {
      tierNotifier.value = _tier;
      _logTierOnce(source: 'rc-listener');
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _saveCache(uid, _tier, active: hasActiveSubscription);
      }
    }
    if (changedTier || changedEnt) notifyListeners();
  }

  // ── RevenueCat package cache ──────────────────────────────────────────────
  Future<void> _loadAvailablePackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;

      if (current != null) {
        homeChefPackage = current.availablePackages.firstWhereOrNull(
          (pkg) =>
              pkg.identifier.toLowerCase() == 'home_chef_monthly' ||
              pkg.storeProduct.identifier.toLowerCase() == 'home_chef_monthly',
        );

        masterChefMonthlyPackage = current.availablePackages.firstWhereOrNull(
          (pkg) =>
              pkg.identifier.toLowerCase() == 'master_chef_monthly' ||
              pkg.storeProduct.identifier.toLowerCase() ==
                  'master_chef_monthly',
        );

        masterChefYearlyPackage = current.availablePackages.firstWhereOrNull(
          (pkg) =>
              pkg.identifier.toLowerCase() == 'master_chef_yearly' ||
              pkg.storeProduct.identifier.toLowerCase() == 'master_chef_yearly',
        );
      }
    } catch (e) {
      debugPrint('🔴 Error loading packages: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _resolveTierFromEntitlements(Map<String, EntitlementInfo> ents) {
    for (final e in ents.values) {
      final id = e.productIdentifier.toLowerCase();
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
        return ents.values.firstWhereOrNull((e) {
          final id = e.productIdentifier.toLowerCase();
          return id == 'master_chef_monthly' || id == 'master_chef_yearly';
        });
      case 'home_chef':
        return ents.values.firstWhereOrNull(
          (e) => e.productIdentifier.toLowerCase() == 'home_chef_monthly',
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
}

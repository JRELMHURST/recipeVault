// lib/billing/subscription_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Mapping helper — ideally generated from backend (TS ⇆ Dart)
String productToTier(String productId) {
  final id = productId.toLowerCase();
  if (id.contains('home_chef')) return 'home_chef';
  if (id.contains('master_chef')) return 'master_chef';
  return 'none';
}

enum EntitlementStatus { checking, active, inactive }

class SubscriptionService extends ChangeNotifier {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // RevenueCat platform support (avoid calls on web/desktop)
  bool get _rcSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  // ── Public state/notifiers ────────────────────────────────────────────────
  final ValueNotifier<String> tierNotifier = ValueNotifier('none');
  final ValueNotifier<String?> subscriptionErrorNotifier = ValueNotifier(null);

  String _tier = 'none';
  String _entitlementId = 'none';
  bool _hasSpecialAccess = false;

  bool _isLoadingTier = false;
  bool _isInitialising = false;
  String? _lastLoggedTier;

  CustomerInfo? _customerInfo;
  EntitlementInfo? _activeEntitlement;

  // Firestore listener subscription
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _fsSubSubscription;

  /// Expose entitlement safely for trial/expiry info etc.
  EntitlementInfo? get activeEntitlement => _activeEntitlement;

  bool get isInTrial => _activeEntitlement?.periodType == PeriodType.trial;

  DateTime? get expirationDate {
    final exp = _activeEntitlement?.expirationDate;
    return exp != null ? DateTime.tryParse(exp) : null;
  }

  bool get isExpiringSoon {
    final exp = expirationDate;
    if (exp == null) return false;
    return exp.isAfter(DateTime.now()) &&
        exp.isBefore(DateTime.now().add(const Duration(days: 7)));
  }

  // Cached packages (paywall helper)
  Package? homeChefPackage;
  Package? masterChefMonthlyPackage;
  Package? masterChefYearlyPackage;

  // Usage (per yyyy-mm)
  final Map<String, Map<String, int>> _usageData = {
    'recipeUsage': {},
    'translatedRecipeUsage': {},
    'imageUsage': {},
  };

  final Map<String, int> _tierLimits = {
    'recipeUsage': 0,
    'translatedRecipeUsage': 0,
    'imageUsage': 0,
  };

  bool _rcListenerAttached = false;

  // ── Local cache (Hive) ────────────────────────────────────────────────────
  static String _prefsBoxName(String uid) => 'userPrefs_$uid';
  static const _kCachedTier = 'cachedTier';
  static const _kCachedStatus = 'cachedStatus';
  static const _kCachedSpecial = 'cachedSpecialAccess';
  static const _kEverHadAccess = 'everHadAccess';

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

  /// Canonical getter — safe resolved tier (inc. specialAccess fallback)
  String get resolvedTier {
    if (_tier.isEmpty || _tier == 'none') {
      if (_hasSpecialAccess) return 'home_chef';
      return 'none';
    }
    return _tier;
  }

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

  // Capability gates
  bool get allowTranslation =>
      (hasActiveSubscription || _hasSpecialAccess) &&
      translatedRecipeUsage < translatedRecipeLimit;

  bool get allowImageUpload =>
      (hasActiveSubscription || _hasSpecialAccess) && imageUsage < imageLimit;

  bool get allowSaveToVault =>
      (hasActiveSubscription || _hasSpecialAccess) && recipeUsage < aiLimit;

  bool get allowCategoryCreation => hasActiveSubscription || _hasSpecialAccess;

  bool get hasSpecialAccess => _hasSpecialAccess;

  // ── Usage getters ─────────────────────────────────────────────────────────
  int _getUsage(String kind) {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _usageData[kind]?[key] ?? 0;
  }

  int get recipeUsage => _getUsage('recipeUsage');
  int get translatedRecipeUsage => _getUsage('translatedRecipeUsage');
  int get imageUsage => _getUsage('imageUsage');

  int get aiLimit => _tierLimits['recipeUsage'] ?? 0;
  int get translatedRecipeLimit => _tierLimits['translatedRecipeUsage'] ?? 0;
  int get imageLimit => _tierLimits['imageUsage'] ?? 0;

  bool get showUsageWidget => hasActiveSubscription || _hasSpecialAccess;
  bool get trackUsage => hasActiveSubscription || _hasSpecialAccess;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_isInitialising) return;
    _isInitialising = true;
    try {
      final user = FirebaseAuth.instance.currentUser;

      // 🛡️ Defensive: if user is deleted, log them out and reset
      if (user != null) {
        try {
          await user.getIdToken(true); // throws if disabled/deleted
          await _seedFromCacheIfAny(user.uid);
          _attachFirestoreListener(user.uid);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found' || e.code == 'user-disabled') {
            debugPrint('⚠️ Current user no longer exists. Forcing logout.');
            await FirebaseAuth.instance.signOut();
            await reset();
            return;
          } else {
            rethrow;
          }
        }
      }

      if (_rcSupported && !_rcListenerAttached) {
        Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
        _rcListenerAttached = true;
      }

      if (_rcSupported) {
        await Purchases.invalidateCustomerInfoCache();
        await loadSubscriptionStatus();
        await _loadAvailablePackages();
      } else {
        // On unsupported platforms, still try to read overrides + usage.
        if (user != null) {
          await _loadUsageData(user.uid);
          notifyListeners();
        }
      }
    } finally {
      _isInitialising = false;
    }
  }

  Future<void> setAppUserId(String? firebaseUid) async {
    try {
      if (!_rcSupported) {
        // Still clear local state if logging out.
        if (firebaseUid == null) await reset();
        return;
      }

      if (firebaseUid == null) {
        try {
          await Purchases.logOut();
        } on PlatformException catch (e) {
          // Use helper to read error code (avoid magic numbers)
          final code = PurchasesErrorHelper.getErrorCode(e);
          if (code != PurchasesErrorCode.logOutWithAnonymousUserError) {
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
      subscriptionErrorNotifier.value = 'Failed to set AppUserId: $e';
      debugPrint('RevenueCat setAppUserId error: $e');
    }
  }

  Future<void> refresh() async {
    if (_isLoadingTier) return;
    if (!_rcSupported) return;
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

    // Cancel Firestore listener when logging out or resetting
    await _fsSubSubscription?.cancel();
    _fsSubSubscription = null;

    if (_rcSupported) {
      await Purchases.invalidateCustomerInfoCache();
    }
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

      if (_rcSupported) {
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
      }

      // Firestore overrides + special access
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

      // Cache after we’ve applied overrides
      await _saveCache(user.uid, _tier, active: hasActiveSubscription);

      notifyListeners();
    } catch (e) {
      subscriptionErrorNotifier.value = 'Failed to load subscription: $e';
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
  Future<void> _reconcileWithBackend() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint("⚠️ Skipping reconcile: no signed-in user");
      return;
    }

    try {
      final functions = FirebaseFunctions.instanceFor(region: "europe-west2");
      final fn = functions.httpsCallable('reconcileUserFromRC');
      final resp = await fn.call(); // auth context carries the UID
      debugPrint("🔄 Reconcile success: ${resp.data}");
    } catch (e, st) {
      debugPrint("❌ Reconcile failed: $e\n$st");
    }
  }

  void _onCustomerInfo(CustomerInfo info) async {
    if (!_rcSupported) return;

    _customerInfo = info;
    final ents = info.entitlements.active;

    debugPrint(
      'RC Entitlements: ${ents.entries.map((e) => '${e.key} => ${e.value.productIdentifier}').join(', ')}',
    );

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
        await _reconcileWithBackend(); // keep Firestore in sync
      }
    }
    if (changedTier || changedEnt) notifyListeners();
  }

  // ── Firestore drift listener ──────────────────────────────────────────────
  void _attachFirestoreListener(String uid) {
    // Clean up any previous subscription
    _fsSubSubscription?.cancel();
    _fsSubSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
          final data = doc.data();
          if (data == null) return;

          final fsTier = (data['tier'] as String?)?.trim();
          final fsSpecial = data['specialAccess'] == true;

          bool changed = false;

          if (fsTier != null && fsTier.isNotEmpty && fsTier != _tier) {
            debugPrint('🔄 Firestore drift → applying $fsTier');
            _tier = fsTier;
            tierNotifier.value = _tier;
            changed = true;
          }
          if (fsSpecial != _hasSpecialAccess) {
            _hasSpecialAccess = fsSpecial;
            changed = true;
          }

          if (changed) notifyListeners();
        });
  }

  // ── RevenueCat package cache ──────────────────────────────────────────────
  Future<void> _loadAvailablePackages() async {
    if (!_rcSupported) return;
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;

      if (current != null) {
        homeChefPackage = current.availablePackages.firstWhereOrNull(
          (pkg) => productToTier(pkg.identifier) == 'home_chef',
        );

        masterChefMonthlyPackage = current.availablePackages.firstWhereOrNull(
          (pkg) =>
              productToTier(pkg.identifier) == 'master_chef' &&
              pkg.identifier.toLowerCase().contains('monthly'),
        );

        masterChefYearlyPackage = current.availablePackages.firstWhereOrNull(
          (pkg) =>
              productToTier(pkg.identifier) == 'master_chef' &&
              pkg.identifier.toLowerCase().contains('yearly'),
        );
      }
    } catch (e) {
      debugPrint('🔴 Error loading packages: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _resolveTierFromEntitlements(Map<String, EntitlementInfo> ents) {
    for (final e in ents.values) {
      final tier = productToTier(e.productIdentifier);
      if (tier != 'none') return tier;
    }
    return 'none';
  }

  EntitlementInfo? _getActiveEntitlement(
    Map<String, EntitlementInfo> ents,
    String tier,
  ) {
    return ents.values.firstWhereOrNull(
      (e) => productToTier(e.productIdentifier) == tier,
    );
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
    if (!_rcSupported) return CustomerInfo.fromJson(const {}); // no-op
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

  // ── Cleanup ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _fsSubSubscription?.cancel();
    _fsSubSubscription = null;
    tierNotifier.dispose();
    subscriptionErrorNotifier.dispose();
    super.dispose();
  }
}

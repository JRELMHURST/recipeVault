import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/billing/tier_limits.dart';
import 'package:recipe_vault/billing/subscription/subscription_types.dart';
import 'package:recipe_vault/billing/subscription/subscription_cache.dart';
import 'package:recipe_vault/billing/subscription/subscription_rc_adapter.dart';
import 'package:recipe_vault/billing/subscription/subscription_usage_repo.dart';
import 'package:recipe_vault/data/services/user_session_service.dart';

class SubscriptionService extends ChangeNotifier {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // ── Collaborators ─────────────────────────────────────────────────────────
  final _rc = RcAdapter();
  final _cache = SubscriptionCache();
  final _usageRepo = UsageRepo(FirebaseFirestore.instance);

  // ── Public state/notifiers ────────────────────────────────────────────────
  final ValueNotifier<String> tierNotifier = ValueNotifier('none');
  final ValueNotifier<String?> subscriptionErrorNotifier = ValueNotifier(null);

  // ── State ─────────────────────────────────────────────────────────────────
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

  // Reconcile de-bounce
  Timer? _reconcileDebounce;
  bool _didStartupReconcile = false;

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

  // ── Getters (public API preserved) ────────────────────────────────────────
  String get tier => _tier;

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
    return _cache.everHadAccess(uid);
  }

  // Usage getters
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

  /// Whether to show the usage widget in the UI
  bool get showUsageWidget => hasActiveSubscription || _hasSpecialAccess;

  /// Whether to actively track usage (read from Firestore etc.)
  bool get trackUsage => hasActiveSubscription || _hasSpecialAccess;

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

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_isInitialising) return;
    _isInitialising = true;
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        try {
          await user.getIdToken(true); // throws if disabled/deleted
          await _seedFromCacheIfAny(user.uid);
          _attachFirestoreListener(user.uid);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found' || e.code == 'user-disabled') {
            debugPrint('⚠️ Current user no longer exists. Forcing logout.');
            await UserSessionService.signOut();
            await FirebaseAuth.instance.authStateChanges().firstWhere(
              (u) => u == null,
            );
            await reset();
            return;
          } else {
            rethrow;
          }
        }
      }

      if (_rc.isSupported && !_rcListenerAttached) {
        _rc.addCustomerInfoListener(_onCustomerInfo);
        _rcListenerAttached = true;
      }

      if (_rc.isSupported) {
        await _rc.invalidateCache();
        await loadSubscriptionStatus();
        await _loadAvailablePackages(); // <-- now implemented
      } else {
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
      if (!_rc.isSupported) {
        if (firebaseUid == null) await reset();
        return;
      }

      if (firebaseUid == null) {
        await _rc.logOutSafe();
        await reset();
        return;
      }

      await _seedFromCacheIfAny(firebaseUid);
      await _rc.logIn(firebaseUid);
      await refresh();
    } catch (e) {
      subscriptionErrorNotifier.value = 'Failed to set AppUserId: $e';
      debugPrint('RevenueCat setAppUserId error: $e');
    }
  }

  Future<void> refresh() async {
    if (_isLoadingTier) return;
    if (!_rc.isSupported) return;
    await _rc.invalidateCache();
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

    for (final k in _usageData.keys) {
      _usageData[k]?.clear();
    }
    _tierLimits
      ..['recipeUsage'] = 0
      ..['translatedRecipeUsage'] = 0
      ..['imageUsage'] = 0;

    tierNotifier.value = _tier;
    await _fsSubSubscription?.cancel();
    _fsSubSubscription = null;

    if (_rc.isSupported) {
      await _rc.invalidateCache();
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

    final startUid = FirebaseAuth.instance.currentUser?.uid;
    if (startUid == null) {
      _isLoadingTier = false;
      return;
    }

    try {
      if (_rc.isSupported) {
        _customerInfo = await _getCustomerInfoWithRetry(
          preferRetry: _isBrandNewUser(FirebaseAuth.instance.currentUser!),
        );

        if (startUid != FirebaseAuth.instance.currentUser?.uid) return;

        final ents = _customerInfo?.entitlements.active ?? const {};

        // Do not downgrade to 'none' on an initial empty ping
        if (ents.isEmpty && _tier != 'none') {
          debugPrint('RC empty on first load — keeping cached/FS tier.');
        } else {
          final rcTier = EntitlementUtils.resolveTier(ents);
          final activeEntitlement = EntitlementUtils.activeForTier(
            ents,
            rcTier,
          );
          final rcEntitlementId =
              (activeEntitlement?.productIdentifier ?? 'none').toLowerCase();

          _tier = rcTier;
          _entitlementId = rcEntitlementId;
          _activeEntitlement = activeEntitlement;

          _applyFallbackLimitsIfAny();
          tierNotifier.value = _tier;
          _logTierOnce(source: 'loadSubscriptionStatus');
        }
      }

      // Firestore overrides
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(startUid)
          .get();

      if (startUid != FirebaseAuth.instance.currentUser?.uid) return;

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

      await _loadUsageData(startUid);

      await _cache.save(
        uid: startUid,
        tier: _tier,
        active: hasActiveSubscription,
        hasSpecialAccess: _hasSpecialAccess,
      );

      _queueReconcile();

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
    final loaded = await _usageRepo.loadAll(uid);
    _usageData
      ..['recipeUsage'] = loaded['recipeUsage'] ?? {}
      ..['translatedRecipeUsage'] = loaded['translatedRecipeUsage'] ?? {}
      ..['imageUsage'] = loaded['imageUsage'] ?? {};

    if (_tier == 'none' || _tier.isEmpty) {
      _tierLimits
        ..['recipeUsage'] = 0
        ..['translatedRecipeUsage'] = 0
        ..['imageUsage'] = 0;
      return;
    }

    final limits = await _usageRepo.loadTierLimits(_tier);
    if (limits.isEmpty) {
      _applyFallbackLimitsIfAny();
    } else {
      _tierLimits.addAll(limits);
    }
  }

  void _applyFallbackLimitsIfAny() {
    final fb = TierLimitsFallback.forTier(_tier);
    if (fb != null) {
      _tierLimits
        ..['recipeUsage'] = fb['recipeUsage']!
        ..['translatedRecipeUsage'] = fb['translatedRecipeUsage']!
        ..['imageUsage'] = fb['imageUsage']!;
    }
  }

  // ── Reconcile ─────────────────────────────────────────────────────────────
  void _queueReconcile() {
    if (!hasActiveSubscription && !_hasSpecialAccess) return;
    if (_didStartupReconcile) return;

    _reconcileDebounce?.cancel();
    _reconcileDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (_didStartupReconcile) return;
      await _reconcileWithBackend();
      _didStartupReconcile = true;
    });
  }

  Future<void> _reconcileWithBackend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("⚠️ Skipping reconcile: no signed-in user");
      return;
    }

    try {
      await user.getIdToken(true);
      final functions = FirebaseFunctions.instanceFor(region: "europe-west2");
      final fn = functions.httpsCallable('reconcileUserFromRC');
      final resp = await fn.call();
      debugPrint("🔄 Reconcile success: ${resp.data}");
    } on FirebaseAuthException catch (e) {
      debugPrint("⚠️ Auth error during reconcile: ${e.code} → ${e.message}");
    } catch (e, st) {
      debugPrint("❌ Reconcile failed: $e\n$st");
    }
  }

  // ── RC live updates ───────────────────────────────────────────────────────
  void _onCustomerInfo(CustomerInfo info) async {
    if (!_rc.isSupported) return;

    // Ignore during sign-out
    if (UserSessionService.isSigningOut) {
      debugPrint('RC update ignored: app is signing out');
      return;
    }

    // Ignore if no Firebase user (post-logout)
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      debugPrint('RC update ignored: no signed-in user (post-logout)');
      return;
    }

    _customerInfo = info;
    final ents = info.entitlements.active;

    debugPrint(
      'RC Entitlements: ${ents.entries.map((e) => '${e.key} => ${e.value.productIdentifier}').join(', ')}',
    );

    // Guard: ignore empty ping to avoid flashing to none.
    if (ents.isEmpty) {
      debugPrint('RC entitlements empty — ignoring downgrade, retrying…');
      Future<void>.delayed(const Duration(milliseconds: 600), () async {
        if (FirebaseAuth.instance.currentUser?.uid == currentUid) {
          await refresh();
        }
      });
      return;
    }

    final rcTier = EntitlementUtils.resolveTier(ents);
    final activeEntitlement = EntitlementUtils.activeForTier(ents, rcTier);
    final rcEntitlementId = (activeEntitlement?.productIdentifier ?? 'none')
        .toLowerCase();

    final changedTier = _tier != rcTier;
    final changedEnt = _entitlementId != rcEntitlementId;

    _tier = rcTier;
    _entitlementId = rcEntitlementId;
    _activeEntitlement = activeEntitlement;

    _applyFallbackLimitsIfAny();

    if (changedTier) {
      tierNotifier.value = _tier;
      _logTierOnce(source: 'rc-listener');
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _cache.save(
          uid: uid,
          tier: _tier,
          active: hasActiveSubscription,
          hasSpecialAccess: _hasSpecialAccess,
        );
        _queueReconcile();
      }
    }
    if (changedTier || changedEnt) notifyListeners();
  }

  // ── Firestore drift listener ──────────────────────────────────────────────
  void _attachFirestoreListener(String uid) {
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

  // ── RC package loading (paywall helper) ───────────────────────────────────
  Future<void> _loadAvailablePackages() async {
    if (!_rc.isSupported) return;
    try {
      final offerings = await _rc.getOfferings();
      final current = offerings.current;
      if (current == null) return;

      Package? _find(bool Function(Package p) test) {
        for (final p in current.availablePackages) {
          if (test(p)) return p;
        }
        return null;
      }

      final id = (Package p) => p.identifier.toLowerCase();

      homeChefPackage = _find((p) => id(p).contains('home_chef'));

      masterChefMonthlyPackage = _find(
        (p) => id(p).contains('master_chef') && id(p).contains('monthly'),
      );

      masterChefYearlyPackage = _find(
        (p) => id(p).contains('master_chef') && id(p).contains('yearly'),
      );
    } catch (e) {
      debugPrint('🔴 Error loading RC packages: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<void> _seedFromCacheIfAny(String uid) async {
    try {
      final seed = await _cache.seed(uid);
      bool changed = false;
      if (seed.tier != null && seed.tier!.isNotEmpty && seed.tier != _tier) {
        _tier = seed.tier!;
        changed = true;
      }
      if (seed.special != null) {
        _hasSpecialAccess = seed.special!;
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

  bool _isBrandNewUser(User user) {
    final created = user.metadata.creationTime;
    final last = user.metadata.lastSignInTime;
    return created != null && last != null && created.isAtSameMomentAs(last);
  }

  Future<CustomerInfo> _getCustomerInfoWithRetry({
    required bool preferRetry,
  }) async {
    if (!_rc.isSupported) return CustomerInfo.fromJson(const {});
    int attempts = preferRetry ? 3 : 1;
    Duration delay = const Duration(milliseconds: 400);

    CustomerInfo info = await _rc.getCustomerInfo();
    while (attempts > 1 && info.entitlements.active.isEmpty) {
      await Future.delayed(delay);
      info = await _rc.getCustomerInfo();
      attempts--;
      delay = Duration(
        milliseconds: (delay.inMilliseconds * 2).clamp(400, 1600),
      );
      debugPrint('⏳ Retrying RevenueCat fetch… remaining=$attempts');
    }
    return info;
  }

  void _logTierOnce({String source = 'unknown'}) {
    if (_lastLoggedTier == _tier) return;
    debugPrint('📦 Tier updated → $_tier (from: $source)');
    _lastLoggedTier = _tier;
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _fsSubSubscription?.cancel();
    _fsSubSubscription = null;
    _reconcileDebounce?.cancel();
    tierNotifier.dispose();
    subscriptionErrorNotifier.dispose();
    super.dispose();
  }
}

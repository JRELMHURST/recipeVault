// ignore_for_file: use_build_context_synchronously, unnecessary_null_checks

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/auth/auth_service.dart';
import 'package:recipe_vault/features/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/data/services/user_preference_service.dart';
import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/data/services/category_service.dart';
import 'package:hive/hive.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';

class UserSessionService {
  static bool _isInitialised = false;
  static Completer<void>? _bubbleFlagsReady;
  static StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  static StreamSubscription<DocumentSnapshot>? _aiUsageSub;
  static StreamSubscription<DocumentSnapshot>? _translationSub;

  static bool get isInitialised => _isInitialised;

  static bool get isSignedIn =>
      FirebaseAuth.instance.currentUser != null &&
      !FirebaseAuth.instance.currentUser!.isAnonymous;

  static Future<bool> shouldShowTrialEndedScreen() async {
    try {
      final sub = SubscriptionService();
      await sub.refresh();

      if (sub.isInTrial || sub.hasActiveSubscription) return false;

      final info = await Purchases.getCustomerInfo();
      if (info.entitlements.active.isEmpty) return false;

      final e = info.entitlements.active.values.first;

      // If active and not a trial → no “trial ended” screen
      if (e.isActive && e.periodType != PeriodType.trial) return false;

      if (e.periodType == PeriodType.trial) {
        final expiryStr = e.expirationDate;
        if (expiryStr == null) return false;
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry == null) return false;

        final trialEnded = DateTime.now().isAfter(expiry);
        final wontRenew = e.willRenew == false;
        return trialEnded && wontRenew;
      }

      return false;
    } catch (e) {
      _logDebug('⚠️ Error checking trial ended state (default=false): $e');
      return false;
    }
  }

  static Future<void> syncEntitlementAndRefreshSession() async {
    _logDebug('🔄 Manually syncing entitlement + refreshing session...');
    await SubscriptionService().syncRevenueCatEntitlement();
    await init();
  }

  static Future<void> init() async {
    if (_isInitialised) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _logDebug('⚠️ No valid signed-in user – skipping session init');
      return;
    }

    if (_userDocSubscription != null) {
      _logDebug('🛑 User doc listener already active – skipping re-init');
      return;
    }

    _bubbleFlagsReady = Completer<void>();
    _logDebug('👤 Initialising session for UID: ${user.uid}');

    await _cancelAllStreams();

    final uid = user.uid;
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());

    try {
      // Ensure prefs box is ready
      await UserPreferencesService.init();
      if (!Hive.isBoxOpen('userPrefs_$uid')) {
        await Hive.openBox('userPrefs_$uid');
      }

      final resolvedTier = await SubscriptionService().getResolvedTier();
      _logDebug('🧾 Tier resolved via getResolvedTier(): $resolvedTier');

      // ✅ Ensure/merge Firestore user doc via unified AuthService
      final isNewUser = await AuthService.ensureUserDocument(user);
      if (isNewUser) {
        try {
          await UserPreferencesService.resetBubbles();
        } catch (e, stack) {
          _logDebug('⚠️ Failed to mark user as new: $e');
          if (kDebugMode) print(stack);
        }
      }

      // ── User doc listener ──
      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen(
            (snapshot) {
              if (FirebaseAuth.instance.currentUser?.uid != uid) return;
              if (!snapshot.exists || snapshot.data() == null) {
                _logDebug('⚠️ User doc snapshot missing or null');
                return;
              }
              _logDebug('📡 User doc listener received update');
            },
            onError: (error) => _logDebug('⚠️ User doc listener error: $error'),
          );

      // ── AI usage stream ──
      _aiUsageSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiUsage')
          .doc('usage')
          .snapshots()
          .listen((doc) async {
            if (FirebaseAuth.instance.currentUser?.uid != uid) return;
            final data = doc.data();
            if (data == null) {
              _logDebug('⚠️ AI usage doc has no data');
              return;
            }
            final used = (data[monthKey] ?? 0) as int;
            _logDebug('📊 AI usage [$monthKey]: $used');
            if (!UserPreferencesService.isBoxOpen) {
              await UserPreferencesService.init();
            }
            await UserPreferencesService.setCachedUsage(
              ai: used,
              translations: null,
            );
          }, onError: (error) => _logDebug('⚠️ AI usage stream error: $error'));

      // ── Translation usage stream ──
      _translationSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('translationUsage')
          .doc('usage')
          .snapshots()
          .listen(
            (doc) async {
              if (FirebaseAuth.instance.currentUser?.uid != uid) return;
              final data = doc.data();
              if (data == null) {
                _logDebug('⚠️ Translation usage doc has no data');
                return;
              }
              final used = (data[monthKey] ?? 0) as int;
              _logDebug('🌐 Translation usage [$monthKey]: $used');
              if (!UserPreferencesService.isBoxOpen) {
                await UserPreferencesService.init();
              }
              await UserPreferencesService.setCachedUsage(
                ai: null,
                translations: used,
              );
            },
            onError: (error) =>
                _logDebug('⚠️ Translation usage stream error: $error'),
          );

      final tier = SubscriptionService().tier;
      _logDebug('🎟️ Tier resolved: $tier');

      // Complete to unblock any awaiters
      _bubbleFlagsReady?.complete();

      // ── Data loading ──
      _logDebug('📂 Loading categories...');
      await CategoryService.load();

      _logDebug('📂 Loading vault recipes...');
      await VaultRecipeService.load();

      _logDebug('📡 Starting vault listener...');
      if (FirebaseAuth.instance.currentUser?.uid == uid) {
        VaultRecipeService.listenToVaultChanges(() {
          debugPrint('📡 Vault changed!');
        });
      }

      _isInitialised = true;
      _logDebug('✅ User session init complete');
    } catch (e, stack) {
      _logDebug('❌ Error during session init: $e');
      if (kDebugMode) print(stack);
    }
  }

  static Future<void> logoutReset() async {
    _logDebug('👋 Logging out + resetting session...');

    try {
      await Purchases.logOut();
      _logDebug('🛒 RevenueCat logged out');
    } catch (e) {
      _logDebug('❌ RevenueCat logout failed: $e');
    }

    await _cancelAllStreams();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final boxName = 'recipes_$uid';
      if (Hive.isBoxOpen(boxName)) {
        try {
          final box = Hive.box<RecipeCardModel>(boxName);
          await box.clear();
          await box.close();
          _logDebug('📦 Cleared & closed box: $boxName');
        } catch (e, stack) {
          _logDebug('⚠️ Error clearing box $boxName: $e');
          if (kDebugMode) print(stack);
        }
      } else {
        try {
          await Hive.deleteBoxFromDisk(boxName);
          _logDebug('🧹 Deleted unopened Hive box: $boxName');
        } catch (e) {
          _logDebug('⚠️ Failed to delete unopened Hive box: $e');
        }
      }

      try {
        if (!Hive.isBoxOpen('userPrefs_$uid')) {
          await Hive.openBox('userPrefs_$uid');
        }
        await UserPreferencesService.clearAllUserData(uid);
      } catch (e) {
        _logDebug('⚠️ Failed to clear userPrefs: $e');
      }
    }

    await CategoryService.clearCache();
    await SubscriptionService().reset();
    VaultRecipeService.cancelVaultListener();

    _isInitialised = false;
    _bubbleFlagsReady = null;
    _logDebug('🧹 Session fully cleared');
  }

  static Future<void> _cancelAllStreams() async {
    await _userDocSubscription?.cancel();
    await _aiUsageSub?.cancel();
    await _translationSub?.cancel();

    _userDocSubscription = null;
    _aiUsageSub = null;
    _translationSub = null;

    VaultRecipeService.cancelVaultListener();
  }

  static Future<void> reset() async {
    _isInitialised = false;
    _bubbleFlagsReady = null;
    _logDebug('🔄 Session reset');
  }

  /// (Optional helper) Replaces old PurchaseHelper-based sync.
  /// Fetches RC info, asks backend to reconcile Firestore, then refreshes our SubscriptionService.
  static Future<void> syncRevenueCatEntitlement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1) Ensure RC cache is fresh and read latest entitlements (for logging/diagnostics)
      await Purchases.invalidateCustomerInfoCache();
      final customerInfo = await Purchases.getCustomerInfo();
      final active = customerInfo.entitlements.active.values
          .map((e) => e.productIdentifier)
          .join(', ');
      _logDebug('🧾 Active RC products: [$active]');

      // 2) Trigger backend reconcile (Cloud Function) — Firestore is updated server-side
      try {
        final functions = FirebaseFunctions.instanceFor(region: "europe-west2");
        final callable = functions.httpsCallable("reconcileUserFromRC");
        await callable.call(<String, dynamic>{}); // uid inferred from auth
        _logDebug('☁️ Reconcile triggered successfully');
      } catch (e) {
        _logDebug('⚠️ Failed to trigger reconcile: $e');
      }

      // 3) Pull fresh state into the app (updates router/UI via notifiers)
      await SubscriptionService().refresh();
    } catch (e, stack) {
      _logDebug('⚠️ Failed to sync entitlement via backend: $e');
      if (kDebugMode) print(stack);
    }
  }

  static Future<void> waitForBubbleFlags() =>
      _bubbleFlagsReady?.future ?? Future.value();

  static void _logDebug(String message) {
    if (kDebugMode) {
      print('🔐 [UserSessionService] $message');
    }
  }
}

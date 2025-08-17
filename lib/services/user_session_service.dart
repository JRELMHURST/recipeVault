// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:hive/hive.dart';

import 'package:recipe_vault/core/feature_flags.dart';
import 'package:recipe_vault/firebase_auth_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/rev_cat/purchase_helper.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/rev_cat/tier_utils.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';

class UserSessionService {
  static bool _isInitialised = false;
  static Completer<void>? _bubbleFlagsReady;

  static StreamSubscription<DocumentSnapshot>? _userDocSub;
  static StreamSubscription<DocumentSnapshot>? _aiUsageSub;
  static StreamSubscription<DocumentSnapshot>? _translationSub;

  static bool get isInitialised => _isInitialised;

  static bool get isSignedIn {
    final u = FirebaseAuth.instance.currentUser;
    return u != null && !u.isAnonymous;
  }

  /// Trial ended screen: true only if user had an entitlement in trial which is now expired and not renewing.
  static Future<bool> shouldShowTrialEndedScreen() async {
    try {
      final sub = SubscriptionService();
      await sub.refresh();
      if (sub.isInTrial || sub.hasActiveSubscription) return false;

      final info = await Purchases.getCustomerInfo();
      if (info.entitlements.active.isEmpty) return false;

      final e = info.entitlements.active.values.first;
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
      _log('⚠️ trial check failed (default=false): $e');
      return false;
    }
  }

  static Future<void> syncEntitlementAndRefreshSession() async {
    _log('🔄 Manual entitlement sync + session refresh…');
    await SubscriptionService().syncRevenueCatEntitlement();
    await init();
  }

  /// Boot the signed-in user session (idempotent).
  static Future<void> init() async {
    if (_isInitialised) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _log('⚠️ No valid signed-in user – skip init');
      return;
    }

    // prevent duplicate listeners
    if (_userDocSub != null) {
      _log('🛑 User doc listener already active – skip re-init');
      return;
    }

    await _cancelAllStreams();
    _bubbleFlagsReady = Completer<void>();

    final uid = user.uid;
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
    _log('👤 Initialising session for $uid');

    try {
      // Ensure user-scoped prefs box is ready
      await UserPreferencesService.init();

      // Ensure the Firestore user doc exists and detect "new user"
      final isNewUser = await AuthService.ensureUserDocumentIfMissing(user);
      if (isNewUser) {
        // Clean slate onboarding flags for brand new users
        try {
          await UserPreferencesService.markAsNewUser();
          await UserPreferencesService.resetBubbles();
        } catch (e, st) {
          _log('⚠️ Failed to mark new user: $e');
          if (kDebugMode) print(st);
        }
      }

      // RevenueCat tier snapshot to log (service keeps source of truth)
      final resolvedTier = await SubscriptionService().getResolvedTier();
      _log('🧾 Resolved tier: $resolvedTier');

      // User doc listener (lightweight; extend if needed later)
      _userDocSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((snap) {
            if (FirebaseAuth.instance.currentUser?.uid != uid) return;
            if (!snap.exists || snap.data() == null) {
              _log('⚠️ user doc missing/null');
              return;
            }
            _log('📡 user doc update received');
          }, onError: (e) => _log('⚠️ user doc stream error: $e'));

      // Usage: AI
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
              _log('⚠️ AI usage doc empty');
              return;
            }
            final used = (data[monthKey] ?? 0) as int;
            _log('📊 AI usage [$monthKey]=$used');
            await UserPreferencesService.setCachedUsage(ai: used);
          }, onError: (e) => _log('⚠️ AI usage stream error: $e'));

      // Usage: Translations
      _translationSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('translationUsage')
          .doc('usage')
          .snapshots()
          .listen((doc) async {
            if (FirebaseAuth.instance.currentUser?.uid != uid) return;
            final data = doc.data();
            if (data == null) {
              _log('⚠️ Translation usage doc empty');
              return;
            }
            final used = (data[monthKey] ?? 0) as int;
            _log('🌐 Translation usage [$monthKey]=$used');
            await UserPreferencesService.setCachedUsage(translations: used);
          }, onError: (e) => _log('⚠️ Translation usage stream error: $e'));

      // Onboarding bubbles – NEW USER ONLY (feature-flag driven)
      if (kOnboardingBubblesEnabled) {
        final hasShownOnce = await UserPreferencesService.hasShownBubblesOnce;
        final tutorialComplete =
            await UserPreferencesService.hasCompletedVaultTutorial();

        if (isNewUser && !hasShownOnce && !tutorialComplete) {
          await UserPreferencesService.markBubblesShown();
          _log('🌟 Onboarding flagged for first show (new user)');
        } else {
          _log(
            '🫧 Skip onboarding (isNew=$isNewUser shown=$hasShownOnce done=$tutorialComplete)',
          );
        }
      } else {
        _log('🚫 Onboarding disabled by feature flag');
      }
      _bubbleFlagsReady?.complete();

      // Categories (local + sync)
      _log('📂 Loading categories…');
      await CategoryService.load();

      // Vault load + live listener
      _log('📂 Loading vault…');
      await VaultRecipeService.load();

      _log('📡 Starting vault listener…');
      if (FirebaseAuth.instance.currentUser?.uid == uid) {
        VaultRecipeService.listenToVaultChanges(() {
          if (kDebugMode) debugPrint('📡 Vault changed!');
        });
      }

      _isInitialised = true;
      _log('✅ Session init complete');
    } catch (e, st) {
      _log('❌ Session init error: $e');
      if (kDebugMode) print(st);
      // Still complete the bubble future so callers don’t hang.
      _bubbleFlagsReady?.complete();
    }
  }

  static Future<void> logoutReset() async {
    _log('👋 Logging out + resetting session…');

    try {
      await Purchases.logOut();
      _log('🛒 RevenueCat logged out');
    } catch (e) {
      _log('⚠️ RevenueCat logout failed: $e');
    }

    await _cancelAllStreams();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Clear recipes_<uid>
      final boxName = 'recipes_$uid';
      if (Hive.isBoxOpen(boxName)) {
        try {
          final box = Hive.box<RecipeCardModel>(boxName);
          await box.clear();
          await box.close();
          _log('📦 Cleared & closed $boxName');
        } catch (e, st) {
          _log('⚠️ Clear/close $boxName failed: $e');
          if (kDebugMode) print(st);
        }
      } else {
        try {
          await Hive.deleteBoxFromDisk(boxName);
          _log('🧹 Deleted unopened $boxName from disk');
        } catch (e) {
          _log('⚠️ Delete unopened $boxName failed: $e');
        }
      }

      // Clear userPrefs_<uid>
      try {
        await UserPreferencesService.clearAllUserData(uid);
      } catch (e) {
        _log('⚠️ Failed to clear userPrefs: $e');
      }
    }

    await CategoryService.clearCache();
    await SubscriptionService().reset();
    VaultRecipeService.cancelVaultListener();

    _isInitialised = false;
    _bubbleFlagsReady = null;
    _log('🧹 Session fully cleared');
  }

  static Future<void> reset() async {
    _isInitialised = false;
    _bubbleFlagsReady = null;
    _log('🔄 Session reset');
  }

  static Future<void> retryEntitlementSync() async {
    _log('🔁 Retrying entitlement sync…');
    await SubscriptionService().refresh();
    await syncRevenueCatEntitlement();
    // Onboarding remains new-user only.
  }

  static Future<void> syncRevenueCatEntitlement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final info = await Purchases.getCustomerInfo();
    final entitlementId = PurchaseHelper.getActiveEntitlementId(info);
    final tier = resolveTier(entitlementId);
    SubscriptionService().updateTier(tier);

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      _log('☁️ Writing entitlement → Firestore: tier=$tier id=$entitlementId');
      await ref.set({
        'tier': tier,
        'entitlementId': entitlementId ?? 'none',
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _log('☁️ Entitlement synced');
    } catch (e) {
      _log('⚠️ Firestore entitlement sync failed: $e');
    }
  }

  static Future<void> waitForBubbleFlags() =>
      _bubbleFlagsReady?.future ?? Future.value();

  // ── internals ──────────────────────────────────────────────────────────────

  static Future<void> _cancelAllStreams() async {
    await _userDocSub?.cancel();
    await _aiUsageSub?.cancel();
    await _translationSub?.cancel();
    _userDocSub = null;
    _aiUsageSub = null;
    _translationSub = null;

    VaultRecipeService.cancelVaultListener();
  }

  static void _log(String msg) {
    if (kDebugMode) print('🔐 [UserSessionService] $msg');
  }
}

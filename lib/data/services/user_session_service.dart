// lib/data/services/user_session_service.dart
// ignore_for_file: use_build_context_synchronously, unnecessary_null_checks

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/app/routes.dart';

import 'package:recipe_vault/auth/auth_service.dart';
import 'package:recipe_vault/features/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/data/services/user_preference_service.dart';
import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/data/services/category_service.dart';
import 'package:hive/hive.dart';

/// Central user session lifecycle handler
class UserSessionService {
  static bool _isInitialised = false;
  static Completer<void>? _bubbleFlagsReady;
  static StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  static StreamSubscription<DocumentSnapshot>? _recipeUsageSub;
  static StreamSubscription<DocumentSnapshot>? _translatedRecipeUsageSub;
  static StreamSubscription<DocumentSnapshot>? _imageUsageSub;

  // ── Sign-out guard (prevents router / services from bouncing during teardown)
  static final ValueNotifier<bool> _signingOut = ValueNotifier<bool>(false);
  static bool get isSigningOut => _signingOut.value;
  static ValueListenable<bool> get signingOutListenable => _signingOut;

  /// Call when you start a sign-out flow (optional; logoutReset also sets this)
  static void beginSignOut() {
    if (!_signingOut.value) _signingOut.value = true;
  }

  /// Call after you’ve landed on the login screen (optional; logoutReset clears too)
  static void endSignOut() {
    if (_signingOut.value) _signingOut.value = false;
  }

  // ───────────────────────────────────────────────────────────────────────────

  static bool get isInitialised => _isInitialised;

  static bool get isSignedIn =>
      FirebaseAuth.instance.currentUser != null &&
      !FirebaseAuth.instance.currentUser!.isAnonymous;

  /// Decide which route to send the user to after boot
  static String? getRedirectRoute(String loc) {
    // If we are tearing down a session, force login to avoid Vault/Paywall bounce
    if (isSigningOut) return AppRoutes.login;

    final isLoggedIn =
        FirebaseAuth.instance.currentUser != null &&
        !FirebaseAuth.instance.currentUser!.isAnonymous;

    if (!isLoggedIn) {
      final onAuthPage = loc == AppRoutes.login || loc == AppRoutes.register;
      return onAuthPage ? null : AppRoutes.login;
    }
    return null;
  }

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
      _logDebug('⚠️ Error checking trial ended state (default=false): $e');
      return false;
    }
  }

  static Future<void> syncEntitlementAndRefreshSession() async {
    _logDebug('🔄 Manually syncing entitlement + refreshing session...');
    try {
      await Purchases.invalidateCustomerInfoCache();
      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.active.values
          .map((e) => e.productIdentifier)
          .join(', ');
      _logDebug('🧾 Active RC products: [$active]');

      try {
        final functions = FirebaseFunctions.instanceFor(region: "europe-west2");
        final callable = functions.httpsCallable("reconcileUserFromRC");
        unawaited(
          callable.call().then<void>(
            (_) => _logDebug('☁️ Reconcile triggered (best effort)'),
            onError: (err) => _logDebug('⚠️ Reconcile failed to trigger: $err'),
          ),
        );
      } catch (e) {
        _logDebug('⚠️ Failed to trigger reconcile: $e');
      }

      await SubscriptionService().refresh();
      await init();
    } catch (e, stack) {
      _logDebug('⚠️ Failed to sync entitlement: $e');
      if (kDebugMode) print(stack);
    }
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
      await UserPreferencesService.init();
      if (!Hive.isBoxOpen('userPrefs_$uid')) {
        await Hive.openBox('userPrefs_$uid');
      }

      final tier = SubscriptionService().tier;
      _logDebug('🧾 Tier resolved: $tier');

      final isNewUser = await AuthService.ensureUserDocument(user);
      if (isNewUser) {
        try {
          // place for any first-run per-user seeding if needed
        } catch (e, stack) {
          _logDebug('⚠️ Failed to mark user as new: $e');
          if (kDebugMode) print(stack);
        }
      }

      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen(
            (snapshot) {
              // 🛡️ Ignore late events if auth moved on
              if (FirebaseAuth.instance.currentUser?.uid != uid) return;
              if (!snapshot.exists || snapshot.data() == null) {
                _logDebug('⚠️ User doc snapshot missing or null');
                return;
              }
              _logDebug('📡 User doc listener received update');
            },
            onError: (error) => _logDebug('⚠️ User doc listener error: $error'),
          );

      // recipeUsage
      _recipeUsageSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('recipeUsage')
          .doc('usage')
          .snapshots()
          .listen(
            (doc) async {
              if (FirebaseAuth.instance.currentUser?.uid != uid) return;
              final data = doc.data();
              if (data == null) {
                _logDebug('⚠️ Recipe usage doc has no data');
                return;
              }
              final used = (data[monthKey] ?? 0) as int;
              _logDebug('📊 Recipe usage [$monthKey]: $used');
              if (!UserPreferencesService.isBoxOpen) {
                await UserPreferencesService.init();
              }
              await UserPreferencesService.setCachedUsage(recipes: used);
            },
            onError: (error) =>
                _logDebug('⚠️ Recipe usage stream error: $error'),
          );

      // translatedRecipeUsage
      _translatedRecipeUsageSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('translatedRecipeUsage')
          .doc('usage')
          .snapshots()
          .listen(
            (doc) async {
              if (FirebaseAuth.instance.currentUser?.uid != uid) return;
              final data = doc.data();
              if (data == null) {
                _logDebug('⚠️ Translated recipe usage doc has no data');
                return;
              }
              final used = (data[monthKey] ?? 0) as int;
              _logDebug('🌐 Translated recipe usage [$monthKey]: $used');
              if (!UserPreferencesService.isBoxOpen) {
                await UserPreferencesService.init();
              }
              await UserPreferencesService.setCachedUsage(
                translatedRecipes: used,
              );
            },
            onError: (error) =>
                _logDebug('⚠️ Translated recipe usage stream error: $error'),
          );

      // imageUsage
      _imageUsageSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('imageUsage')
          .doc('usage')
          .snapshots()
          .listen(
            (doc) async {
              if (FirebaseAuth.instance.currentUser?.uid != uid) return;
              final data = doc.data();
              if (data == null) {
                _logDebug('⚠️ Image usage doc has no data');
                return;
              }
              final used = (data[monthKey] ?? 0) as int;
              _logDebug('🖼️ Image usage [$monthKey]: $used');
              if (!UserPreferencesService.isBoxOpen) {
                await UserPreferencesService.init();
              }
              await UserPreferencesService.setCachedUsage(images: used);
            },
            onError: (error) =>
                _logDebug('⚠️ Image usage stream error: $error'),
          );

      _bubbleFlagsReady?.complete();

      await CategoryService.load();
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

  /// Full teardown of the local session state.
  /// - Idempotent and re-entrancy safe.
  /// - Sets a global "signing out" flag to help router/redirects.
  static Future<void> logoutReset() async {
    // prevent double execution if button pressed twice
    if (_signingOut.value) {
      _logDebug('↪️ logoutReset already in progress — skipping.');
      return;
    }
    beginSignOut();

    _logDebug('👋 Logging out + resetting session...');

    try {
      // 1) Cancel listeners ASAP to avoid late Firestore tier/usage events.
      await _cancelAllStreams();

      // 2) Reset subscription state (cancels its Firestore listener first).
      await SubscriptionService().reset();

      // 3) Log out from RevenueCat (best effort).
      try {
        await Purchases.logOut();
        _logDebug('🛒 RevenueCat logged out');
      } catch (e) {
        _logDebug('❌ RevenueCat logout failed: $e');
      }

      // 4) Close / purge per-user local stores.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _safeCloseBox('recipes_$uid');
        await _safeCloseBox('userPrefs_$uid');
        await _safeCloseBox('customCategories_$uid');
        await _safeCloseBox('hiddenDefaultCategories_$uid');

        try {
          await UserPreferencesService.clearAllUserData(uid);
        } catch (e) {
          _logDebug('⚠️ Failed to clear userPrefs service: $e');
        }
      }

      // 5) Clear caches and detach vault.
      await CategoryService.clearCache();
      VaultRecipeService.cancelVaultListener();

      _isInitialised = false;
      _bubbleFlagsReady = null;

      _logDebug('🧹 Session fully cleared');
    } finally {
      // Keep the guard set until the caller finishes FirebaseAuth.signOut()
      // and navigates to Login. If they don’t, release it to avoid a stuck state.
      // Callers can explicitly end via UserSessionService.endSignOut() after nav.
      // To be safe, auto-release after a short delay.
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (_signingOut.value) endSignOut();
      });
    }
  }

  static Future<void> _safeCloseBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      try {
        await Hive.box(name).close();
        _logDebug('📦 Safely closed Hive box: $name');
      } catch (e) {
        _logDebug('⚠️ Failed to close Hive box $name: $e');
      }
    } else {
      try {
        await Hive.deleteBoxFromDisk(name);
        _logDebug('🧹 Deleted unopened Hive box: $name');
      } catch (e) {
        _logDebug('⚠️ Failed to delete unopened Hive box $name: $e');
      }
    }
  }

  static Future<void> _cancelAllStreams() async {
    await _userDocSubscription?.cancel();
    await _recipeUsageSub?.cancel();
    await _translatedRecipeUsageSub?.cancel();
    await _imageUsageSub?.cancel();

    _userDocSubscription = null;
    _recipeUsageSub = null;
    _translatedRecipeUsageSub = null;
    _imageUsageSub = null;

    VaultRecipeService.cancelVaultListener();
  }

  static Future<void> reset() async {
    _isInitialised = false;
    _bubbleFlagsReady = null;
    _logDebug('🔄 Session reset');
  }

  static Future<void> waitForBubbleFlags() =>
      _bubbleFlagsReady?.future ?? Future.value();

  static void _logDebug(String message) {
    if (kDebugMode) {
      print('🔐 [UserSessionService] $message');
    }
  }
}

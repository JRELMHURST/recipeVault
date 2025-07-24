import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:recipe_vault/firebase_auth_service.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/services/category_service.dart';

class UserSessionService {
  static bool _isInitialised = false;
  static Completer<void>? _bubbleFlagsReady;

  static bool get isInitialised => _isInitialised;

  /// Call on app launch or login
  static Future<void> init() async {
    if (_isInitialised) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _logDebug('⚠️ No valid signed-in user – skipping session init');
      return;
    }

    _bubbleFlagsReady = Completer<void>();
    _logDebug('👤 Initialising session for UID: ${user.uid}');

    try {
      // 🧹 Close guest box if still open
      if (Hive.isBoxOpen('userPrefs_guest')) {
        await Hive.box('userPrefs_guest').close();
        _logDebug('🧹 Closed guest box (login detected)');
      }

      // 📦 Open correct Hive prefs box
      await UserPreferencesService.init();

      // ✅ Ensure Firestore user doc exists
      await AuthService.ensureUserDocumentIfMissing(user);

      // 🎟️ Sync entitlements
      await syncRevenueCatEntitlement();
      await SubscriptionService().refresh();

      final tier = SubscriptionService().tier;
      _logDebug('🎟️ Tier resolved: $tier');

      // 🫧 Check and trigger onboarding bubbles
      _logDebug('🫧 Checking onboarding bubble trigger...');
      await UserPreferencesService.ensureBubbleFlagTriggeredIfEligible(tier);
      _bubbleFlagsReady?.complete();
      _logDebug('✅ Bubble trigger check complete');

      // 📂 Load categories + vault
      _logDebug('📂 Loading categories...');
      await CategoryService.load();

      _logDebug('📂 Loading vault recipes...');
      await VaultRecipeService.load();

      _isInitialised = true;
      _logDebug('✅ User session initialisation complete');
    } catch (e, stack) {
      _logDebug('❌ Error during UserSession init: $e');
      if (kDebugMode) print(stack);
    }
  }

  static Future<void> reset() async {
    _isInitialised = false;
    _bubbleFlagsReady = null;
    _logDebug('🔄 Session reset');
  }

  /// Call on logout
  static Future<void> logoutReset() async {
    _logDebug('👋 Logging out and resetting session...');
    await VaultRecipeService.clearCache();
    await CategoryService.clearCache();
    await SubscriptionService().reset();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final boxName = 'userPrefs_$uid';
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).close();
    }

    _isInitialised = false;
    _bubbleFlagsReady = null;
    _logDebug('🧹 Session fully cleared for user: $uid');
  }

  /// 🧾 Retry syncing entitlements (e.g. after paywall purchase)
  static Future<void> retryEntitlementSync() async {
    _logDebug('🔁 Retrying entitlement sync...');
    await syncRevenueCatEntitlement();
    await SubscriptionService().refresh();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final tier = SubscriptionService().tier;
      final hasShown = await UserPreferencesService.hasShownBubblesOnce;
      _logDebug('🎟️ Tier after retry: $tier, HasShownBubblesOnce: $hasShown');
      if (tier == 'free' && !hasShown) {
        _logDebug('🧪 Marking bubbles shown after retry');
        await UserPreferencesService.markBubblesShown();
      }
    }
  }

  /// ✅ Push tier to Firestore if RevenueCat changed
  static Future<void> syncRevenueCatEntitlement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tier = SubscriptionService().tier;
    final entitlement = SubscriptionService().currentEntitlement;

    final docRef = AuthService.userDocRefCurrent();
    if (docRef == null) return;

    await docRef.set({
      'tier': tier,
      'entitlement': entitlement,
    }, SetOptions(merge: true));

    _logDebug('☁️ Synced tier to Firestore: $tier');
  }

  /// ⏳ Wait for bubble flags to be initialised
  static Future<void> waitForBubbleFlags() =>
      _bubbleFlagsReady?.future ?? Future.value();

  static void _logDebug(String message) {
    if (kDebugMode) {
      print('🔐 [UserSessionService] $message');
    }
  }
}

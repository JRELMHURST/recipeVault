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
  static bool isInitialised = false;

  static bool get hasInitialised => isInitialised;

  /// Call on app launch or login
  static Future<void> init() async {
    if (isInitialised) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🚫 Ensure we're not still using the guest box
    if (Hive.isBoxOpen('userPrefs_guest')) {
      await Hive.box('userPrefs_guest').close();
      if (kDebugMode) print('🧹 Closed guest box (login detected)');
    }

    // 🧠 Reopen correct Hive box for current UID
    await UserPreferencesService.init();

    _logDebug('👤 Initialising session for UID: ${user.uid}');

    try {
      // ✅ Ensure Firestore user doc exists
      await AuthService.ensureUserDocumentIfMissing(user);

      // 🧾 Sync entitlements
      await syncRevenueCatEntitlement();
      await SubscriptionService().refresh();

      final tier = SubscriptionService().tier;
      _logDebug('🎟️ Tier resolved: $tier');

      // 🧠 Check and trigger bubble tutorial
      _logDebug('🫧 Checking onboarding bubble trigger...');
      await UserPreferencesService.ensureBubbleFlagTriggeredIfEligible(tier);
      _logDebug('✅ Bubble trigger check complete');

      // 📂 Preload local data
      _logDebug('📂 Loading categories...');
      await CategoryService.load();

      _logDebug('📂 Loading vault recipes...');
      await VaultRecipeService.load();

      // ✅ Fully initialised
      isInitialised = true;
      _logDebug('✅ User session initialisation complete');
    } catch (e) {
      _logDebug('❌ Error during UserSession init: $e');
    }
  }

  static Future<void> reset() async {
    isInitialised = false;
    _logDebug('🔄 Session reset');
  }

  static void _logDebug(String message) {
    if (kDebugMode) {
      print('🔐 [UserSessionService] $message');
    }
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
}

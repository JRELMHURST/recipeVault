import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    isInitialised = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _logDebug('👤 Initialising session for UID: ${user.uid}');

    // ✅ Ensure user doc exists before syncing entitlements
    await AuthService.ensureUserDocumentIfMissing(user);

    // 🧾 RevenueCat sync
    await syncRevenueCatEntitlement();
    await SubscriptionService().refresh();

    final tier = SubscriptionService().tier;
    _logDebug('🎟️ Tier: $tier');

    // 🧠 Bubble tutorial check
    _logDebug('🔍 Checking if onboarding bubbles should be triggered...');
    await UserPreferencesService.ensureBubbleFlagTriggeredIfEligible(tier);
    _logDebug('🧼 Bubble trigger check complete');

    // 📦 Preload local category + recipe data
    await CategoryService.load();
    await VaultRecipeService.load();
  }

  static Future<void> reset() async {
    isInitialised = false;
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
      await UserPreferencesService.ensureBubbleFlagTriggeredIfEligible(tier);
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

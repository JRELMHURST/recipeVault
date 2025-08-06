// ignore_for_file: use_build_context_synchronously, unnecessary_null_checks

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/firebase_auth_service.dart';
import 'package:recipe_vault/rev_cat/purchase_helper.dart';
import 'package:recipe_vault/rev_cat/tier_utils.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:hive/hive.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class UserSessionService {
  static bool _isInitialised = false;
  static Completer<void>? _bubbleFlagsReady;
  static StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  static StreamSubscription<DocumentSnapshot>? _aiUsageSub;
  static StreamSubscription<DocumentSnapshot>? _translationSub;
  static StreamSubscription<QuerySnapshot>? _vaultListener;

  static bool get isInitialised => _isInitialised;

  static bool get isSignedIn =>
      FirebaseAuth.instance.currentUser != null &&
      !FirebaseAuth.instance.currentUser!.isAnonymous;

  static Future<void> syncEntitlementAndRefreshSession() async {
    _logDebug('🔄 Manually syncing entitlement and refreshing session...');
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
      await UserPreferencesService.init();
      if (!Hive.isBoxOpen('userPrefs_$uid')) {
        await Hive.openBox('userPrefs_$uid');
      }

      final resolvedTier = await SubscriptionService().getResolvedTier();
      _logDebug('🧾 Tier resolved via getResolvedTier(): $resolvedTier');

      final isNewUser = await AuthService.ensureUserDocumentIfMissing(user);
      if (isNewUser) {
        try {
          await UserPreferencesService.markUserAsNew();
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
              if (FirebaseAuth.instance.currentUser?.uid != uid) return;
              if (!snapshot.exists || snapshot.data() == null) {
                _logDebug('⚠️ User doc snapshot missing or null');
                return;
              }
              _logDebug('📡 User doc listener received update');
            },
            onError: (error) => _logDebug('⚠️ User doc listener error: $error'),
          );

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

      _logDebug('🫧 Checking onboarding bubble trigger...');
      await UserPreferencesService.ensureBubbleFlagTriggeredIfEligible(tier);
      _bubbleFlagsReady?.complete();
      _logDebug('✅ Bubble trigger check complete');

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
      _logDebug('✅ User session initialisation complete');
    } catch (e, stack) {
      _logDebug('❌ Error during UserSession init: $e');
      if (kDebugMode) print(stack);
    }
  }

  static Future<void> logoutReset() async {
    _logDebug('👋 Logging out and resetting session...');

    try {
      await Purchases.logOut(); // ✅ Ensure RC session is cleared
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
          _logDebug('📦 Safely cleared & closed box: $boxName');
        } catch (e, stack) {
          _logDebug('⚠️ Error clearing box $boxName: $e');
          if (kDebugMode) print(stack);
        }
      } else {
        try {
          await Hive.deleteBoxFromDisk(boxName);
          _logDebug('🧹 Deleted unopened Hive box from disk: $boxName');
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

    _isInitialised = false;
    _bubbleFlagsReady = null;
    _logDebug('🧹 Session fully cleared');
  }

  static Future<void> _cancelAllStreams() async {
    await _userDocSubscription?.cancel();
    await _aiUsageSub?.cancel();
    await _translationSub?.cancel();
    await _vaultListener?.cancel();

    _userDocSubscription = null;
    _aiUsageSub = null;
    _translationSub = null;
    _vaultListener = null;
  }

  static Future<void> reset() async {
    _isInitialised = false;
    _bubbleFlagsReady = null;
    _logDebug('🔄 Session reset');
  }

  static Future<void> retryEntitlementSync() async {
    _logDebug('🔁 Retrying entitlement sync...');
    await SubscriptionService().refresh();
    await syncRevenueCatEntitlement();

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

  static Future<void> syncRevenueCatEntitlement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final customerInfo = await Purchases.getCustomerInfo();
    final entitlementId = PurchaseHelper.getActiveEntitlementId(customerInfo);
    final tier = resolveTier(entitlementId);
    SubscriptionService().updateTier(tier);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      _logDebug(
        '☁️ Updating Firestore with tier: $tier and entitlementId: $entitlementId',
      );

      await docRef.set({
        'tier': tier,
        'entitlementId': entitlementId ?? 'none',
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _logDebug(
        '☁️ Synced entitlement to Firestore: {tier: $tier, entitlementId: $entitlementId}',
      );
    } catch (e) {
      _logDebug('⚠️ Failed to sync entitlement to Firestore: $e');
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/firebase_auth_service.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/rev_cat/tier_utils.dart';
import 'package:recipe_vault/services/user_preference_service.dart';

class UserSessionService {
  static bool _hasInitialised = false;
  static bool _retryInProgress = false;

  /// 🏁 Initialise RevenueCat + Firestore sync
  static Future<void> init() async {
    if (_hasInitialised) return;
    _hasInitialised = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logDebug('⚠️ No Firebase user found during init');
      _hasInitialised = false;
      return;
    }

    try {
      await Purchases.logIn(user.uid);
      await Purchases.restorePurchases();

      final info = await Purchases.getCustomerInfo();

      if (info.entitlements.active.isEmpty) {
        _logDebug('⏳ No entitlements yet — retrying in 2s...');
        _retryEntitlementSync(user.uid);
        return;
      }

      await syncRevenueCatEntitlement();
      await SubscriptionService().refresh();
      await AuthService.ensureUserDocumentIfMissing(user);

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final userDoc = await docRef.get();
      final userData = userDoc.data() ?? {};
      final tier = userData['tier'] ?? 'free';

      final prefsBox = Hive.box('userPrefs');
      final hasSeenTutorial =
          prefsBox.get('vaultTutorialComplete', defaultValue: false) as bool;

      // ✅ Trigger bubbles only once for free users
      if (tier == 'free' && !hasSeenTutorial) {
        await UserPreferencesService.resetBubbles();
        _logDebug('🆕 Bubbles triggered for free tier (first time only)');
      }

      _logDebug('✅ UserSessionService initialised for ${user.uid}');
    } catch (e) {
      debugPrint('❌ UserSessionService init failed: $e');
      _hasInitialised = false;
    }
  }

  /// 🔄 Sync RevenueCat entitlement to Firestore
  static Future<void> syncRevenueCatEntitlement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logDebug('⚠️ No Firebase user logged in');
      return;
    }

    try {
      final info = await Purchases.getCustomerInfo();
      final entitlementId =
          info.entitlements.active.values.firstOrNull?.productIdentifier;
      final resolvedTier = resolveTier(entitlementId);

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final doc = await docRef.get();
      final data = doc.data() ?? {};

      final trialStart = data['trialStartDate'];
      final trialActive =
          resolvedTier == 'taster' && _isTrialActive(trialStart);

      final shouldUpdate =
          data['tier'] != resolvedTier ||
          data['entitlementId'] != entitlementId ||
          data['trialActive'] != trialActive;

      if (shouldUpdate) {
        await docRef.set({
          'tier': resolvedTier,
          'entitlementId': entitlementId ?? '',
          'trialActive': trialActive,
        }, SetOptions(merge: true));

        _logDebug('✅ Synced tier → Firestore: $resolvedTier');
      } else {
        _logDebug('ℹ️ Firestore already up to date with tier: $resolvedTier');
      }

      _logEntitlementSummary(info, resolvedTier);
    } catch (e) {
      debugPrint('❌ Failed to sync entitlement to Firestore: $e');
    }
  }

  static Future<void> restoreAndSyncEntitlement() async {
    try {
      await Purchases.restorePurchases();
      await syncRevenueCatEntitlement();
    } catch (e) {
      debugPrint('❌ restoreAndSyncEntitlement() failed: $e');
    }
  }

  static void _retryEntitlementSync(String userId) {
    if (_retryInProgress) return;
    _retryInProgress = true;

    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final retryInfo = await Purchases.getCustomerInfo();

        if (retryInfo.entitlements.active.isNotEmpty) {
          await syncRevenueCatEntitlement();
          await SubscriptionService().loadSubscriptionStatus();
          await SubscriptionService().refresh();

          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await AuthService.ensureUserDocumentIfMissing(user);
          }

          _logDebug('✅ Retried entitlement sync succeeded for $userId');
        } else {
          _logDebug('❌ Entitlements still empty after retry');
        }
      } catch (e) {
        debugPrint('❌ Retry failed: $e');
      } finally {
        _retryInProgress = false;
      }
    });
  }

  static bool _isTrialActive(dynamic trialStart) {
    try {
      final start = trialStart is Timestamp
          ? trialStart.toDate()
          : DateTime.parse(trialStart.toString());
      return DateTime.now().difference(start).inDays < 7;
    } catch (_) {
      return false;
    }
  }

  static void _logEntitlementSummary(
    CustomerInfo info,
    String tier, {
    String context = 'UserSession',
  }) {
    if (!kDebugMode) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final entitlements = info.entitlements.active.keys.join(', ');
    debugPrint('👤 [$context] Firebase UID: $uid');
    debugPrint('🧾 [$context] RC AppUserID: ${info.originalAppUserId}');
    debugPrint('🧾 [$context] Entitlements: $entitlements');
    debugPrint('🎯 [$context] Resolved Tier: $tier');
  }

  static void _logDebug(String message) {
    if (kDebugMode) debugPrint(message);
  }
}

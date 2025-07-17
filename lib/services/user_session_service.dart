import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../rev_cat/subscription_service.dart';
import '../rev_cat/tier_utils.dart';

class UserSessionService {
  /// 🏁 Initialise session: log in to RevenueCat, sync entitlement, refresh subscription state
  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) print('⚠️ No Firebase user found during init');
      return;
    }

    try {
      await Purchases.logIn(user.uid);
      await Purchases.restorePurchases();

      final info = await Purchases.getCustomerInfo();
      final entitlements = info.entitlements.active;

      if (entitlements.isEmpty) {
        if (kDebugMode) {
          print('⏳ No entitlements yet – will retry sync in 2s...');
        }
        _retryEntitlementSync(user.uid);
        return;
      }

      await syncRevenueCatEntitlement();
      await SubscriptionService().refresh();

      if (kDebugMode) {
        print('✅ UserSessionService initialised for ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ UserSessionService init failed: $e');
      }
    }
  }

  /// 🔄 Sync active RevenueCat entitlement to Firestore if data changed
  static Future<void> syncRevenueCatEntitlement() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) print('⚠️ No Firebase user logged in');
        return;
      }

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

      final isSame =
          data['tier'] == resolvedTier &&
          data['entitlementId'] == entitlementId &&
          data['trialActive'] == trialActive;

      if (!isSame) {
        await docRef.set({
          'tier': resolvedTier,
          'entitlementId': entitlementId ?? '',
          'trialActive': trialActive,
        }, SetOptions(merge: true));

        if (kDebugMode) {
          print('✅ Synced tier → Firestore: $resolvedTier');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ Firestore already up to date with tier: $resolvedTier');
        }
      }

      if (kDebugMode) {
        _logEntitlementSummary(info, resolvedTier);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync RevenueCat entitlement to Firestore: $e');
      }
    }
  }

  /// ♻️ Restore purchases and re-sync entitlement to Firestore
  static Future<void> restoreAndSyncEntitlement() async {
    try {
      await Purchases.restorePurchases();
      await syncRevenueCatEntitlement();
    } catch (e) {
      if (kDebugMode) {
        print('❌ restoreAndSyncEntitlement() failed: $e');
      }
    }
  }

  /// ⏱ Retry sync after delay (for first-load entitlements)
  static void _retryEntitlementSync(String userId) {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final retryInfo = await Purchases.getCustomerInfo();
        if (retryInfo.entitlements.active.isNotEmpty) {
          await syncRevenueCatEntitlement();
          await SubscriptionService().loadSubscriptionStatus();
          await SubscriptionService().refresh();

          if (kDebugMode) {
            print('✅ Retried entitlement sync succeeded for $userId');
          }
        } else {
          debugPrint('❌ Entitlements still empty after retry – skipping sync');
        }
      } catch (e) {
        debugPrint('❌ Retry failed: $e');
      }
    });
  }

  /// 🧪 Trial still active if within 7 days
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

  /// 🧾 Debug entitlement summary
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
    debugPrint('🧾 [$context] Entitlements: ($entitlements)');
    debugPrint('🎯 [$context] Resolved Tier: $tier');
  }
}

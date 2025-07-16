import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../rev_cat/subscription_service.dart';
import '../rev_cat/tier_utils.dart';

class UserSessionService {
  /// 🏁 Call once on startup to initialise user session and sync subscription state
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
      if (info.entitlements.active.isEmpty) {
        if (kDebugMode) {
          print('⏳ No entitlements loaded yet – retrying sync in 2s...');
        }

        // ⏱ Retry after delay (best effort)
        Future.delayed(const Duration(seconds: 2), () async {
          final retryInfo = await Purchases.getCustomerInfo();
          if (retryInfo.entitlements.active.isNotEmpty) {
            await syncRevenueCatEntitlement();
            await SubscriptionService().refresh();
          } else {
            debugPrint(
              '❌ Entitlements still empty after retry – skipping sync',
            );
          }
        });

        return; // Exit for now; retry will happen in background
      }

      // ✅ Immediate sync if entitlements are already ready
      await syncRevenueCatEntitlement();
      await SubscriptionService().refresh();

      if (kDebugMode) {
        print('✅ UserSessionService initialised for ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialise UserSessionService: $e');
      }
    }
  }

  /// 🔄 Syncs active RevenueCat entitlement + tier/trial info to Firestore
  static Future<void> syncRevenueCatEntitlement() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final userId = firebaseUser?.uid;
      if (userId == null || userId.isEmpty) {
        if (kDebugMode) print('⚠️ No Firebase user logged in');
        return;
      }

      await Purchases.logIn(userId);
      final info = await Purchases.getCustomerInfo();
      final entitlementId =
          info.entitlements.active.values.firstOrNull?.productIdentifier;
      final resolvedTier = resolveTier(entitlementId);

      if (kDebugMode) {
        print('👤 Firebase UID: $userId');
        print('🧾 RevenueCat originalAppUserId: ${info.originalAppUserId}');
        print('🧾 Active entitlements: ${info.entitlements.active.keys}');
        print('🎯 Subscription tier resolved as: $resolvedTier');
      }

      final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final doc = await docRef.get();
      final trialStart = doc.data()?['trialStartDate'];

      final trialActive =
          resolvedTier == 'taster' && _isTrialActive(trialStart);

      final updateData = <String, dynamic>{
        'entitlementId': entitlementId ?? '',
        'trialActive': trialActive,
      };

      updateData['tier'] = resolvedTier;

      await docRef.set(updateData, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ Synced entitlementId, tier, and trialActive to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync entitlement to Firestore: $e');
      }
    }
  }

  /// ♻️ Restore purchases and re-sync subscription data
  static Future<void> restoreAndSyncEntitlement() async {
    try {
      await Purchases.restorePurchases();
      await syncRevenueCatEntitlement();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to restore and sync entitlements: $e');
      }
    }
  }

  /// 🧪 Determine if trial is still active based on Firestore `trialStartDate`
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
}

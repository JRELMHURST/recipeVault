import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class UserSessionService {
  /// Manually syncs active RevenueCat entitlement + tier/trial flags to Firestore
  static Future<void> syncRevenueCatEntitlement() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final userId = firebaseUser?.uid;

      if (userId == null || userId.isEmpty) {
        if (kDebugMode) print('⚠️ No Firebase user logged in');
        return;
      }

      // ✅ Ensure RevenueCat uses Firebase UID
      await Purchases.logIn(userId);

      final info = await Purchases.getCustomerInfo();
      final entitlementId =
          info.entitlements.active.values.firstOrNull?.identifier;

      if (kDebugMode) {
        print('👤 Firebase UID: $userId');
        print('🧾 RevenueCat originalAppUserId: ${info.originalAppUserId}');
      }

      if (entitlementId != null) {
        final tier = _resolveTier(entitlementId);

        // 🔍 Fetch Firestore user doc to check for trial start
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final startStr = userDoc.data()?['trialStartDate'];
        final trialActive = _isTrialActive(startStr);

        // 💾 Save to Firestore
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'entitlementId': entitlementId,
          'tier': tier,
          'trialActive': trialActive,
        }, SetOptions(merge: true));

        if (kDebugMode) {
          print('✅ Synced entitlementId, tier, and trialActive to Firestore');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ No active entitlement to sync');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync entitlement to Firestore: $e');
      }
    }
  }

  /// Restores purchases and syncs entitlement and tier info to Firestore
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

  /// 🔍 Resolves tier from RevenueCat entitlementId
  static String _resolveTier(String entitlementId) {
    switch (entitlementId) {
      case 'master_chef_monthly':
      case 'master_chef_yearly':
        return 'masterChef';
      case 'home_chef_monthly':
        return 'homeChef';
      default:
        return 'taster';
    }
  }

  /// 🧪 Checks if trial is active based on trialStartDate
  static bool _isTrialActive(String? startStr) {
    if (startStr == null) return false;

    try {
      final start = DateTime.parse(startStr);
      final now = DateTime.now();
      final diff = now.difference(start).inDays;
      return diff < 7;
    } catch (_) {
      return false;
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../rev_cat/subscription_service.dart'; // Ensure this path is correct

class UserSessionService {
  /// 🏁 Call this once on app startup to initialise user session and sync subscription status
  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) print('⚠️ No Firebase user found during init');
      return;
    }

    try {
      await Purchases.logIn(user.uid);

      // 1️⃣ Restore purchases
      await Purchases.restorePurchases();

      // 2️⃣ Wait for active entitlements to be loaded
      final info = await Purchases.getCustomerInfo();
      if (info.entitlements.active.isEmpty) {
        if (kDebugMode) print('⏳ No entitlements loaded yet – skipping sync');
        return;
      }

      // 3️⃣ Now safe to sync
      await syncRevenueCatEntitlement();

      // 4️⃣ Refresh tier info in memory
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
      final entitlements = info.entitlements.active;
      if (entitlements.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ No active entitlements found — skipping sync');
        }
        return;
      }

      final entitlementId = entitlements.values.first.productIdentifier;

      if (kDebugMode) {
        print('👤 Firebase UID: $userId');
        print('🧾 RevenueCat originalAppUserId: ${info.originalAppUserId}');
      }

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
        return 'master_chef';
      case 'home_chef_monthly':
        return 'home_chef';
      case 'taster_trial':
        return 'taster';
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

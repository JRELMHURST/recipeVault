import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../rev_cat/subscription_service.dart';
import '../rev_cat/tier_utils.dart';
import '../firebase_auth_service.dart'; // For ensureUserDocumentIfMissing

class UserSessionService {
  /// 🏁 Initialise RevenueCat + Firestore sync
  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logDebug('⚠️ No Firebase user found during init');
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

      // 🔁 Ensure Firestore user doc + refresh global recipes
      await AuthService.ensureUserDocumentIfMissing(user);

      _logDebug('✅ UserSessionService initialised for ${user.uid}');
    } catch (e) {
      debugPrint('❌ UserSessionService init failed: $e');
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

  /// ♻️ Restore and re-sync RevenueCat entitlement
  static Future<void> restoreAndSyncEntitlement() async {
    try {
      await Purchases.restorePurchases();
      await syncRevenueCatEntitlement();
    } catch (e) {
      debugPrint('❌ restoreAndSyncEntitlement() failed: $e');
    }
  }

  /// ⏱ Retry sync after short delay
  static void _retryEntitlementSync(String userId) {
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
      }
    });
  }

  /// 🧪 Check if taster trial is still active (within 7 days)
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

  /// 📋 Debug log for entitlement/tier resolution
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

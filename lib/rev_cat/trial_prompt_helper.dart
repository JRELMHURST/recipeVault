// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class TrialPromptHelper {
  static bool _hasPromptedThisSession = false;

  /// Call this to check and optionally log trial/upgrade prompt.
  static Future<void> checkAndPromptTrial(
    BuildContext context, {
    bool showDialogInstead = true, // Kept for compatibility
  }) async {
    if (_hasPromptedThisSession) return;

    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );

    if (!subscriptionService.isLoaded) {
      await subscriptionService.refresh();
    }

    final tier = subscriptionService.tier;

    _hasPromptedThisSession = true;

    // 🔍 Track the skip event
    await FirebaseAnalytics.instance.logEvent(
      name: 'paywall_prompt_skipped',
      parameters: {'tier': tier},
    );

    // ⚠️ No dialog or navigation triggered — UI handles this now
  }

  /// Direct users to the paywall if feature is gated.
  static Future<void> showIfTryingRestrictedFeature(
    BuildContext context,
  ) async {
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );

    if (!subscriptionService.isLoaded) {
      await subscriptionService.refresh();
    }

    // Navigate to paywall unconditionally for now
    Navigator.pushNamed(context, '/paywall');
  }

  /// Resets the in-session prompt flag
  static void resetPromptFlag() {
    _hasPromptedThisSession = false;
  }
}

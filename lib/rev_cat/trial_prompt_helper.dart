import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class TrialPromptHelper {
  static bool _hasPromptedThisSession = false;

  /// Call this to check and optionally prompt the user to upgrade or start a trial.
  static Future<void> checkAndPromptTrial(
    BuildContext context, {
    bool showDialogInstead = true, // Kept for API consistency
  }) async {
    if (_hasPromptedThisSession) return;

    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );

    // ✅ Only refresh if needed
    if (!subscriptionService.isLoaded) {
      await subscriptionService.refresh();
    }

    final tier = subscriptionService.tier;
    final trialExpired = subscriptionService.isTasterTrialExpired;

    _hasPromptedThisSession = true;

    // 🔍 Analytics tracking only
    await FirebaseAnalytics.instance.logEvent(
      name: 'paywall_prompt_skipped',
      parameters: {'tier': tier, 'trial_expired': trialExpired.toString()},
    );

    // 👇 NO dialog or navigation shown
  }

  /// Show the correct screen (trial or paywall) based on tier access.
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

    final tier = subscriptionService.tier;
    final canStartTrial = subscriptionService.canStartTrial;

    if (tier == 'none' && canStartTrial) {
      // Optionally redirect here
      // context.go('/trial');
    } else {
      // context.go('/paywall');
    }
  }

  /// Reset the session flag to allow another prompt (e.g. after logout or reauth).
  static void resetPromptFlag() {
    _hasPromptedThisSession = false;
  }
}

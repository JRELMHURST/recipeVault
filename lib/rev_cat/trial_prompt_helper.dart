// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class TrialPromptHelper {
  static bool _hasPromptedThisSession = false;

  /// Checks if the user should be shown a trial or upgrade prompt.
  /// Only runs once per session unless reset.
  static Future<void> checkAndPromptTrial(
    BuildContext context, {
    bool showDialogInstead = true, // Legacy compatibility only
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

    // Log skip event for analytics tracking
    await FirebaseAnalytics.instance.logEvent(
      name: 'paywall_prompt_skipped',
      parameters: {'tier': tier},
    );

    // No UI trigger – UI flow is handled externally
  }

  /// Navigates to the paywall screen if user tries to access restricted features.
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

    Navigator.pushNamed(context, '/paywall');
  }

  /// Resets the flag so that the prompt can be shown again this session.
  static void resetPromptFlag() {
    _hasPromptedThisSession = false;
  }
}

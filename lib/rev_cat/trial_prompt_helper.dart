// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:go_router/go_router.dart';

class TrialPromptHelper {
  static bool _hasPromptedThisSession = false;

  /// Call this to check and optionally prompt the user to upgrade or start a trial.
  /// - If [showDialogInstead] is true, shows a modal dialog.
  /// - Otherwise, pushes the full-screen paywall.
  static Future<void> checkAndPromptTrial(
    BuildContext context, {
    bool showDialogInstead = true,
  }) async {
    if (_hasPromptedThisSession) return;

    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    await subscriptionService.refresh();

    final tier = subscriptionService.tier;
    final isDev = subscriptionService.isSuperUser;
    final trialExpired = subscriptionService.isTasterTrialExpired;

    final shouldPrompt =
        !isDev && (tier == 'free' || (tier == 'taster' && trialExpired));

    if (!shouldPrompt) return;

    _hasPromptedThisSession = true;

    // 🔍 Analytics event for tracking user gating
    await FirebaseAnalytics.instance.logEvent(
      name: 'paywall_prompt_shown',
      parameters: {'tier': tier, 'trial_expired': trialExpired.toString()},
    );

    // Delay the popup by 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    if (showDialogInstead) {
      _showUpgradeDialog(context, trialExpired);
    } else {
      Navigator.of(context).pop(); // close current
      context.go('/paywall');
    }
  }

  /// Show the correct screen (trial or paywall) based on tier access.
  static Future<void> showIfTryingRestrictedFeature(
    BuildContext context,
  ) async {
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    await subscriptionService.refresh();

    final tier = subscriptionService.tier;
    final canStartTrial = subscriptionService.canStartTrial;

    if (tier == 'none' && canStartTrial) {
      context.go('/trial');
    } else {
      context.go('/paywall');
    }
  }

  static void _showUpgradeDialog(BuildContext context, bool trialExpired) {
    final title = trialExpired ? 'Trial Ended' : 'Free Plan';
    final message = trialExpired
        ? 'Your 7-day Taster Trial has ended.\n\nTo continue using RecipeVault’s AI tools, please upgrade to a paid plan.'
        : 'You’re currently on the free plan. AI-powered tools are locked.\n\nStart a free trial or upgrade to access scanning, translation, and more.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/paywall');
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  /// Reset the session flag to allow another prompt (e.g. after logout or reauth).
  static void resetPromptFlag() {
    _hasPromptedThisSession = false;
  }
}

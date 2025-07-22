// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class TrialPromptHelper {
  static bool _hasPromptedThisSession = false;

  /// Call this to check and optionally prompt the user to upgrade.
  /// If [showDialogInstead] is true, shows a dialog. Otherwise, pushes to full-screen paywall.
  static Future<void> showIfTryingRestrictedFeature(
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

    if (shouldPrompt) {
      _hasPromptedThisSession = true;

      // 🔍 Track event
      await FirebaseAnalytics.instance.logEvent(
        name: 'paywall_prompt_shown',
        parameters: {'tier': tier, 'trial_expired': trialExpired},
      );

      if (showDialogInstead) {
        _showUpgradeDialog(context, trialExpired: trialExpired);
      } else {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamed(context, '/paywall');
        });
      }
    }
  }

  static void _showUpgradeDialog(
    BuildContext context, {
    required bool trialExpired,
  }) {
    final title = trialExpired ? 'Trial Ended' : 'Free Plan';
    final message = trialExpired
        ? 'Your 7-day Taster Trial has ended.\n\nTo continue using RecipeVault’s AI tools, please upgrade to a paid plan.'
        : 'You’re currently on the free plan. AI-powered tools are locked.\n\nTo access scanning, translation, and more, please upgrade.';

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

  /// 🔄 Reset between sessions or tier changes if needed
  static void resetPromptFlag() {
    _hasPromptedThisSession = false;
  }
}

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class TrialPromptHelper {
  static bool _hasPromptedThisSession = false;

  /// Call this to check and optionally prompt the user to upgrade if their trial has expired.
  /// By default, shows a small dialog. Pass [showDialogInstead: false] to push full-screen paywall.
  static Future<void> showIfTryingRestrictedFeature(
    BuildContext context, {
    bool showDialogInstead = true,
  }) async {
    if (_hasPromptedThisSession) return;

    final subscriptionService = SubscriptionService();
    await subscriptionService.refresh();

    final trialExpired = subscriptionService.isTasterTrialExpired;
    final hasNoActiveSub = !subscriptionService.hasActiveSubscription;
    final isDev = subscriptionService.isSuperUser;

    if (trialExpired && hasNoActiveSub && !isDev) {
      _hasPromptedThisSession = true;

      if (showDialogInstead) {
        _showTrialEndedDialog(context);
      } else {
        context.push('/trial-ended');
      }
    }
  }

  static void _showTrialEndedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Trial Ended'),
        content: const Text(
          'Your 7-day trial has ended.\n\nTo continue using RecipeVault’s AI tools, please upgrade to a paid plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/paywall');
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }
}

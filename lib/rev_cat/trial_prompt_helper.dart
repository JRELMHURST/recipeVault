// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class TrialPromptHelper {
  static bool _hasPromptedThisSession = false;

  /// Call this to check and optionally prompt the user to upgrade or start a trial.
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

    final isFree = subscriptionService.tier == 'free';
    final trialExpired = subscriptionService.isTasterTrialExpired;
    final hasNoActiveSub = !subscriptionService.hasActiveSubscription;
    final isDev = subscriptionService.isSuperUser;

    final shouldPrompt = (isFree || trialExpired) && hasNoActiveSub && !isDev;

    if (shouldPrompt) {
      _hasPromptedThisSession = true;

      if (showDialogInstead) {
        _showUpgradeDialog(context, isFree: isFree);
      } else {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamed(context, isFree ? '/trial' : '/paywall');
        });
      }
    }
  }

  static void _showUpgradeDialog(BuildContext context, {required bool isFree}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isFree ? 'Free Plan' : 'Trial Ended'),
        content: Text(
          isFree
              ? 'You’re currently on the free plan. AI-powered tools are locked.\n\nStart your 7-day Taster Trial to unlock scanning, translation, and more.'
              : 'Your 7-day Taster Trial has ended.\n\nTo continue using RecipeVault’s AI tools, please upgrade to a paid plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, isFree ? '/trial' : '/paywall');
            },
            child: Text(isFree ? 'Start Free Trial' : 'View Plans'),
          ),
        ],
      ),
    );
  }
}

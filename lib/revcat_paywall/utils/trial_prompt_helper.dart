import 'package:flutter/material.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';
import 'package:recipe_vault/revcat_paywall/widgets/taster_trial_dialog.dart';

class TrialPromptHelper {
  static bool _shown = false;

  static Future<void> checkAndPromptTrial(BuildContext context) async {
    if (_shown) return;

    final sub = SubscriptionService();
    final hasAccess = sub.hasAccess;
    final isTrialTier = sub.isTrialActive();

    if (!hasAccess && !isTrialTier) {
      // Ensure dialog is shown only once per session
      _shown = true;

      await Future.delayed(const Duration(milliseconds: 600)); // Optional delay
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => const TasterTrialDialog(),
        );
      }
    }
  }
}

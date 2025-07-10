import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

class TasterTrialDialog extends StatelessWidget {
  const TasterTrialDialog({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Try RecipeVault Pro Free'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Get full access to AI recipes, translation, and more for 7 days.\nNo credit card required.',
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.lock_open_rounded, size: 20),
              SizedBox(width: 8),
              Text('No credit card needed'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.timer_rounded, size: 20),
              SizedBox(width: 8),
              Text('7-day trial, auto-expires'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await SubscriptionService().activateTasterTrial();
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Taster trial activated!'),
                    duration: Duration(seconds: 2),
                  ),
                );
                context.go('/home');
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Failed to start trial: $e'),
                    backgroundColor: Colors.red[400],
                  ),
                );
              }
            }
          },
          child: const Text('Start Free Trial'),
        ),
      ],
    );
  }
}

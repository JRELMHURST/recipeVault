import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

class SubscriptionSuccessScreen extends StatelessWidget {
  const SubscriptionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tier = SubscriptionService().currentTier;
    final tierName = SubscriptionService().getCurrentTierName();

    String subtitle;
    switch (tier) {
      case Tier.homeChef:
        subtitle =
            'You’ve unlocked Home Chef!\n'
            'Enjoy 20 AI recipes per month, translation tools and smart features.';
        break;
      case Tier.masterChef:
        subtitle =
            'Welcome, Master Chef!\n'
            'You now have unlimited AI recipes, premium tools and lifetime access.';
        break;
      case Tier.tasterTrial:
        subtitle =
            'Taster Trial activated!\n'
            'Try out RecipeVault AI for 7 days, with unlimited access.';
        break;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 20),
                Text(
                  'Subscription Activated!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Plan: $tierName',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Start Creating Recipes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

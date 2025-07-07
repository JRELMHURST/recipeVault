import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/payment_tiers/services/subscription_service.dart';

class SubscriptionSuccessScreen extends StatelessWidget {
  const SubscriptionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierName = SubscriptionService().getCurrentTierName();

    String subtitle;
    switch (tierName) {
      case 'Home Chef':
        subtitle =
            'You’ve unlocked Home Chef!\nEnjoy 20 AI recipes per month, translation tools and smart features.';
        break;
      case 'Master Chef':
        subtitle =
            'Welcome, Master Chef!\nYou now have unlimited AI recipes, premium features and lifetime access.';
        break;
      default:
        subtitle = 'You’ve upgraded your RecipeVault plan!';
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
                const Icon(Icons.emoji_events, size: 72, color: Colors.amber),
                const SizedBox(height: 20),
                Text(
                  'Subscription Activated!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
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
                  onPressed: () => context.go('/'),
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

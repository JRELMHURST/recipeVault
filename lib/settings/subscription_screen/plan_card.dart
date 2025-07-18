import 'package:flutter/material.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class PlanCard extends StatelessWidget {
  final SubscriptionService subscriptionService;

  const PlanCard({required this.subscriptionService, super.key});

  @override
  Widget build(BuildContext context) {
    final tier = subscriptionService.tier;
    final entitlementId = subscriptionService.entitlementId;
    final theme = Theme.of(context);

    final suffix = switch (entitlementId) {
      'master_chef_yearly' => ' (Yearly)',
      'master_chef_monthly' => ' (Monthly)',
      _ => '',
    };

    final label = switch (tier) {
      'master_chef' => '👑 Master Chef Plan$suffix',
      'home_chef' => '👨‍🍳 Home Chef Plan',
      'taster' => '🥄 Taster Plan',
      'free' => '🔓 Free Plan',
      _ => '🔓 Free Plan',
    };

    final description = switch (tier) {
      'master_chef' => 'Unlimited access to everything RecipeVault offers.',
      'home_chef' => 'All core features unlocked, with light limits.',
      'taster' => 'A free trial plan to explore core RecipeVault features.',
      'free' =>
        'Limited access — upgrade to unlock more AI and storage features.',
      _ =>
        'You’re currently on the Free Plan — upgrade to unlock more features!',
    };

    final isTrial = subscriptionService.isTaster;
    final trialEnd = subscriptionService.trialEndDateFormatted;

    final benefits = switch (tier) {
      'master_chef' => [
        '🧠 Unlimited AI recipe cards',
        '🌐 Unlimited translations',
        '📷 Unlimited image uploads',
        '📤 Save and share recipes to your vault',
        '📁 Unlimited category creation',
      ],
      'home_chef' => [
        '🧠 20 AI recipe cards per month',
        '🌐 5 translations per month',
        '📷 20 image uploads per month',
        '📤 Vault saving and cloud storage',
        '📁 Up to 3 custom categories',
      ],
      'taster' => [
        '🧠 5 AI recipe cards (trial only)',
        '🌐 1 translation included',
        '📷 5 image uploads',
        '📤 Vault saving (local only)',
        '📁 No category creation',
      ],
      'free' => [
        '🧠 Limited AI recipe cards (manual trial opt-in)',
        '🌐 No translation access',
        '📷 No image uploads',
        '📤 Vault saving (local only)',
        '📁 No category creation',
      ],
      _ => [],
    };

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
            if (isTrial) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Trial ends: $trialEnd',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            if (benefits.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Included in your plan:',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...benefits.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

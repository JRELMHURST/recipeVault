import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class SubscriptionSettingsScreen extends StatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  State<SubscriptionSettingsScreen> createState() =>
      _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState
    extends State<SubscriptionSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionService>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionService = context.watch<SubscriptionService>();

    final tierLabel = switch (subscriptionService.tier) {
      'master_chef' => '👨‍🍳 Master Chef Plan',
      'home_chef' => '👩‍🍳 Home Chef Plan',
      'taster' => '🍽️ Taster Trial',
      _ => '🧽 Pot Wash Plan',
    };

    final description = switch (subscriptionService.tier) {
      'master_chef' => 'Unlimited access to everything RecipeVault offers.',
      'home_chef' => 'All core features unlocked, with light limits.',
      'taster' => 'A limited-time trial to test everything out.',
      _ =>
        'You’re currently on the Pot Wash Plan — upgrade to unlock the full kitchen!',
    };

    final isSubscribed =
        subscriptionService.hasActiveSubscription ||
        subscriptionService.isTaster;

    return Scaffold(
      appBar: AppBar(title: const Text('My Plan')),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlanCard(
              tier: subscriptionService.tier,
              tierLabel: tierLabel,
              description: description,
              trialEnd: subscriptionService.trialEndDateFormatted,
              isTrial: subscriptionService.isTaster,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.upgrade_outlined),
              label: Text(isSubscribed ? 'View Plans' : 'Upgrade Plan'),
              onPressed: () => Navigator.pushNamed(context, '/paywall'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String tier;
  final String tierLabel;
  final String description;
  final String trialEnd;
  final bool isTrial;

  const _PlanCard({
    required this.tier,
    required this.tierLabel,
    required this.description,
    required this.trialEnd,
    required this.isTrial,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<String> benefits = switch (tier) {
      'master_chef' => [
        '🧠 Unlimited recipe scans and AI formatting',
        '🌐 Translate recipes from any language',
        '📷 Upload images and attach them to cards',
        '📤 Share recipes',
        '📁 Unlimited category organisation',
        '⭐ Favourite recipes and quick filtering',
        '🔒 Priority access to new AI features',
      ],
      'home_chef' => [
        '🔍 10 recipe scans per month',
        '🌐 Translate up to 5 recipes/month',
        '⭐ Favourite recipes',
      ],
      'taster' => [
        '🍽️ 5 recipe scans',
        '🧠 Try AI formatting',
        '⚠️ Translation not included',
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
              tierLabel,
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
                  padding: const EdgeInsets.only(bottom: 6.0),
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

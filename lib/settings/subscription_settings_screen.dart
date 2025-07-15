import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

class SubscriptionSettingsScreen extends StatelessWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subscriptionService = context.watch<SubscriptionService>();

    final tierLabel = switch (subscriptionService.tier) {
      'master_chef' => '👨‍🍳 Master Chef',
      'home_chef' => '👩‍🍳 Home Chef',
      'taster' => '🍽️ Taster (Trial)',
      _ => '🚫 None',
    };

    final entitlementLabel = subscriptionService.hasActiveSubscription
        ? subscriptionService.tier
        : 'None';

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const _SectionHeader('CURRENT PLAN'),
            ListTile(
              leading: const Icon(Icons.card_membership_outlined),
              title: const Text('Subscription Tier'),
              subtitle: Text(tierLabel),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Active Entitlements'),
              subtitle: Text(entitlementLabel),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Trial Ends'),
              subtitle: Text(
                subscriptionService.trialEndDateFormatted.isNotEmpty
                    ? subscriptionService.trialEndDateFormatted
                    : 'N/A',
              ),
            ),
            const ListTile(
              leading: Icon(Icons.cancel_outlined),
              title: Text('Cancel Anytime'),
              subtitle: Text(
                'Manage or cancel your plan anytime from your App Store account.',
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('ACTIONS'),
            ListTile(
              leading: const Icon(Icons.upgrade_outlined),
              title: const Text('Change Plan'),
              onTap: () {
                Navigator.pushNamed(context, '/paywall');
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Restore Purchases'),
              onTap: () async {
                await subscriptionService.refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Purchases restored.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

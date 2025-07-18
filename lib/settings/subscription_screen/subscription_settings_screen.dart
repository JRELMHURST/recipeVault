// Only handles high-level screen layout and state
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/settings/subscription_screen/plan_card.dart';

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
    final sub = context.watch<SubscriptionService>();

    if (!sub.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Plan')),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlanCard(subscriptionService: sub),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.upgrade_outlined),
              label: Text(
                sub.hasActiveSubscription || sub.isTaster
                    ? 'View Plans'
                    : 'Upgrade Plan',
              ),
              onPressed: () => Navigator.pushNamed(context, '/paywall'),
            ),
          ],
        ),
      ),
    );
  }
}

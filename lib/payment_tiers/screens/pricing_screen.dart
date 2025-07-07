// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/payment_tiers/widgets/tier_card.dart';
import 'package:recipe_vault/payment_tiers/services/subscription_service.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade Your Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TierCard(
            emoji: '🥄',
            title: 'Taster (Trial)',
            subtitle: 'Free for 7 days – full access',
            features: const [
              '✅ Unlimited AI recipe creations (7 days)',
              '✅ Full feature preview',
              '✅ Recipe image upload & crop',
              '✅ Save & favourite recipes',
              '✅ Smart GPT categorisation',
              '✅ Offline access',
              '✅ Unlimited translations (7 days)',
            ],
            buttonLabel: 'Start Free Trial',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trial starts on first recipe creation'),
                ),
              );
              context.pop(); // Or navigate elsewhere
            },
          ),
          const SizedBox(height: 24),
          TierCard(
            emoji: '🍳',
            title: 'Home Chef',
            subtitle: '£2.99 / month',
            features: const [
              '20 AI recipe creations per month',
              'Recipe image upload & crop',
              'Save & favourite recipes',
              'Smart GPT categorisation',
              'Offline access',
              '🌍 Translate up to 5 recipes/month',
            ],
            buttonLabel: 'Go Home Chef',
            onPressed: () {
              () async {
                await SubscriptionService().activateHomeChef();
                context.go('/subscription-success');
              }();
            },
          ),
          const SizedBox(height: 24),
          TierCard(
            emoji: '👨‍🍳',
            title: 'Master Chef',
            subtitle: '£4.99 / month or £24.99 lifetime',
            features: const [
              'Unlimited AI recipe creations',
              'Priority processing',
              'Everything in Home Chef included',
              '🌍 Unlimited recipe translations',
              'Lifetime access option',
            ],
            buttonLabel: 'Unlock Master Chef',
            onPressed: () {
              () async {
                await SubscriptionService().activateMasterChef();
                context.go('/subscription-success');
              }();
            },
          ),
        ],
      ),
    );
  }
}

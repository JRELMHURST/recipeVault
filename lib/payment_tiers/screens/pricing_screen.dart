// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/payment_tiers/widgets/tier_card.dart';
import 'package:recipe_vault/payment_tiers/services/subscription_service.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  late Tier _currentTier;

  @override
  void initState() {
    super.initState();
    _currentTier = _subscriptionService.currentTier;
  }

  void _refreshTier() {
    setState(() {
      _currentTier = _subscriptionService.currentTier;
    });
  }

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
            onPressed: _currentTier == Tier.tasterTrial
                ? null
                : () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      context.push('/login');
                      return;
                    }

                    await SubscriptionService().activateTrial();

                    _refreshTier();

                    final prefs = await SharedPreferences.getInstance();
                    final hasSeenWelcome =
                        prefs.getBool('hasSeenWelcome') ?? false;

                    context.go(hasSeenWelcome ? '/home' : '/welcome');
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
            onPressed: _currentTier == Tier.homeChef
                ? null
                : () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      context.push('/login');
                      return;
                    }

                    await _subscriptionService.activateHomeChef();
                    _refreshTier();
                    context.go('/upgrade-success');
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
            onPressed: _currentTier == Tier.masterChef
                ? null
                : () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      context.push('/login');
                      return;
                    }

                    await _subscriptionService.activateMasterChef();
                    _refreshTier();
                    context.go('/upgrade-success');
                  },
          ),
        ],
      ),
    );
  }
}

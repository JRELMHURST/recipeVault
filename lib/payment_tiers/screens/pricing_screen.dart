import 'package:flutter/material.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade Your Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          TierCard(
            emoji: '🥄',
            title: 'Taster',
            subtitle: 'Free for 7 days',
            features: [
              '3 AI recipe creations',
              'Full feature preview',
              'Save recipes locally',
            ],
            buttonLabel: 'Start Free Trial',
          ),
          SizedBox(height: 24),
          TierCard(
            emoji: '🍳',
            title: 'Home Chef',
            subtitle: '£2.99 / month',
            features: [
              '20 AI recipe creations per month',
              'Recipe image upload & crop',
              'Save & favourite recipes',
              'Smart GPT categorisation',
              'Offline access',
            ],
            buttonLabel: 'Go Home Chef',
          ),
          SizedBox(height: 24),
          TierCard(
            emoji: '👨‍🍳',
            title: 'Master Chef',
            subtitle: '£4.99 / month or £24.99 lifetime',
            features: [
              'Unlimited AI recipe creations',
              'Priority processing',
              'Everything in Home Chef included',
              'Lifetime access option',
            ],
            buttonLabel: 'Unlock Master Chef',
          ),
        ],
      ),
    );
  }
}

class TierCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<String> features;
  final String buttonLabel;

  const TierCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$emoji $title', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ...features.map(
              (f) => Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(onPressed: () {}, child: Text(buttonLabel)),
            ),
          ],
        ),
      ),
    );
  }
}

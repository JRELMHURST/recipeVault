import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UpgradeBlockedScreen extends StatelessWidget {
  const UpgradeBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 72, color: Colors.redAccent),
              const SizedBox(height: 20),
              Text(
                'Recipe Limit Reached',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'You’ve reached your monthly recipe creation limit for your current plan.\n\nUpgrade to unlock more recipes and continue using RecipeVault AI.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => context.push('/pricing'),
                icon: const Icon(Icons.upgrade),
                label: const Text('See Plans & Pricing'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

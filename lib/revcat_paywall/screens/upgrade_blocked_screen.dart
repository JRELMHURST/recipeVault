import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

/// Shows when the user hits a usage or feature limit on their plan.
class UpgradeBlockedScreen extends StatefulWidget {
  final String reason; // e.g. 'recipe', 'translation', 'cloud sync'

  const UpgradeBlockedScreen({super.key, this.reason = 'feature'});

  @override
  State<UpgradeBlockedScreen> createState() => _UpgradeBlockedScreenState();
}

class _UpgradeBlockedScreenState extends State<UpgradeBlockedScreen> {
  bool _checkingAccess = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    await SubscriptionService().refresh();
    if (SubscriptionService().hasAccess && mounted) {
      context.go('/home'); // Auto-dismiss if upgraded elsewhere
    } else {
      setState(() => _checkingAccess = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Capitalise reason
    final reasonCapitalised =
        widget.reason[0].toUpperCase() + widget.reason.substring(1);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔒', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              Text(
                '$reasonCapitalised Limit Reached',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You’ve hit your current plan’s ${widget.reason} limit.\n\nUpgrade to unlock more and keep cooking with RecipeVault!',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/pricing');
                },
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

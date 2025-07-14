import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/rev_cat/pricing_card.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class TrialEndedScreen extends StatefulWidget {
  const TrialEndedScreen({super.key});

  @override
  State<TrialEndedScreen> createState() => _TrialEndedScreenState();
}

class _TrialEndedScreenState extends State<TrialEndedScreen> {
  final _subscriptionService = SubscriptionService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    await _subscriptionService.init();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handlePurchase(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      await _subscriptionService.refresh();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Purchase failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox(),
        centerTitle: true,
        title: Text(
          'Trial Ended',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'Your 7-day free trial has ended',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Continue enjoying RecipeVault with one of our plans below:',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              Expanded(
                child: ListView(
                  children: [
                    if (_subscriptionService.homeChefPackage != null)
                      PricingCard(
                        package: _subscriptionService.homeChefPackage!,
                        onTap: () => _handlePurchase(
                          _subscriptionService.homeChefPackage!,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_subscriptionService.masterChefMonthlyPackage != null)
                      PricingCard(
                        package: _subscriptionService.masterChefMonthlyPackage!,
                        onTap: () => _handlePurchase(
                          _subscriptionService.masterChefMonthlyPackage!,
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Add yearly plan support here when available
                  ],
                ),
              ),

              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Limited Free Access'),
                      content: const Text(
                        'RecipeVault will still allow limited viewing and access. However, new recipe processing and translation features will be locked.\n\nUpgrade to continue enjoying full functionality. 🙂',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'Want to continue with limited access?',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

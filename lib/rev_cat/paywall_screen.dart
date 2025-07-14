import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/rev_cat/pricing_card.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = true;
  bool _isPurchasing = false;
  SubscriptionService? _subscriptionService;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    final service = SubscriptionService();
    await service.init();
    if (!mounted) return;
    setState(() {
      _subscriptionService = service;
      _isLoading = false;
    });
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isPurchasing = true);
    try {
      await Purchases.purchasePackage(package);
      await _subscriptionService?.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Subscription successful!')),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Purchase failed: $e')));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading || _subscriptionService == null) {
      return const LoadingOverlay();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Upgrade Your RecipeVault'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Enjoy unlimited access to powerful AI recipe tools, image uploads, category sorting, and more!',
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 24),

              // Home Chef
              if (_subscriptionService!.homeChefPackage != null)
                PricingCard(
                  package: _subscriptionService!.homeChefPackage!,
                  onTap: _isPurchasing
                      ? () {}
                      : () => _handlePurchase(
                          _subscriptionService!.homeChefPackage!,
                        ),
                ),
              const SizedBox(height: 16),

              // Master Chef
              if (_subscriptionService!.masterChefMonthlyPackage != null)
                PricingCard(
                  package: _subscriptionService!.masterChefMonthlyPackage!,
                  onTap: _isPurchasing
                      ? () {}
                      : () => _handlePurchase(
                          _subscriptionService!.masterChefMonthlyPackage!,
                        ),
                ),
              const SizedBox(height: 16),

              // Taster (if still active)
              if (_subscriptionService!.isTaster &&
                  !_subscriptionService!.isTrialExpired)
                PricingCard(
                  package: _subscriptionService!.homeChefPackage!,
                  onTap: () {}, // Disabled
                  isDisabled: true,
                  badge: 'Trial',
                ),
            ],
          ),

          if (_isPurchasing) const LoadingOverlay(),
        ],
      ),
    );
  }
}

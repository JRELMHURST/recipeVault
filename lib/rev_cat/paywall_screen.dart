// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/rev_cat/pricing_card.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  bool _isPurchasing = false;
  List<Package> _availablePackages = [];

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    await _subscriptionService.init();

    try {
      final offerings = await Purchases.getOfferings();

      final homeChef = offerings.getOffering('home_chef_plan');
      final masterChef = offerings.getOffering('master_chef_plan');

      _availablePackages = [
        ...?homeChef?.availablePackages,
        ...?masterChef?.availablePackages,
      ];

      // Move annual Master Chef to the top
      _availablePackages.sort((a, b) {
        final isBAnnual = b.storeProduct.subscriptionPeriod == 'P1Y';
        return isBAnnual ? 1 : -1;
      });
    } catch (e) {
      debugPrint('❌ Failed to load offerings: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isPurchasing = true);
    try {
      await Purchases.purchasePackage(package);
      await _subscriptionService.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Subscription successful!')),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
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

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Chef Mode: ON'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ResponsiveWrapper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enjoy unlimited access to powerful AI recipe tools, image uploads, category sorting, and more!',
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 24),

                    ..._availablePackages.map((pkg) {
                      final isAnnual =
                          pkg.storeProduct.subscriptionPeriod == 'P1Y';
                      final badge = isAnnual ? 'Best Value' : null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PricingCard(
                          package: pkg,
                          onTap: () {
                            if (!_isPurchasing) _handlePurchase(pkg);
                          },
                          isDisabled: false,
                          badge: badge,
                        ),
                      );
                    }),

                    if (_availablePackages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'No subscription plans are currently available. Please try again later.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (_isPurchasing) const LoadingOverlay(),
        ],
      ),
    );
  }
}

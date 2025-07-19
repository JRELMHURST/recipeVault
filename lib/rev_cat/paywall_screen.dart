// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/rev_cat/pricing_card.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/services/user_session_service.dart';
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

      _availablePackages.sort((a, b) {
        final isBAnnual = b.storeProduct.subscriptionPeriod == 'P1Y';
        return isBAnnual ? 1 : -1;
      });
    } catch (e) {
      debugPrint('❌ Failed to load offerings: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isPurchasing = true);

    try {
      await Purchases.purchasePackage(package);
      await UserSessionService.syncRevenueCatEntitlement();
      await _subscriptionService.refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Subscription successful!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacementNamed(context, '/home');
    } on PlatformException catch (e) {
      if (!mounted) return;

      final isCancelled =
          e.code == '1' ||
          e.message?.toLowerCase().contains('cancelled') == true;

      final message = isCancelled
          ? 'Purchase was cancelled. No changes were made.'
          : 'Purchase failed: ${e.message ?? 'Unknown error'}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

    final tier = _subscriptionService.tier;
    final currentEntitlement = _subscriptionService.entitlementId;
    final isFree = tier == 'free';
    final isTaster = _subscriptionService.isTaster;
    final trialExpired = _subscriptionService.isTasterTrialExpired;
    final trialActive = _subscriptionService.isTasterTrialActive;

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
                    if (isFree)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '🔓 Free Plan Access',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'You currently have access to a selection of sample global recipes.\n\nTo scan your own, upload images, use AI tools, or save favourites — you’ll need to upgrade.',
                            ),
                          ],
                        ),
                      )
                    else if (isTaster && trialActive)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🎁 You’re currently on a free 7-day trial. Upgrade to keep full access after it ends.',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      )
                    else if (isTaster && trialExpired)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⚠️ Your free trial has ended. Some features are now limited. Upgrade to unlock full access.',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),

                    const SizedBox(height: 24),
                    Text(
                      'Enjoy unlimited access to powerful AI recipe tools, image uploads, category sorting, and more!',
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 24),

                    ..._availablePackages.map((pkg) {
                      final isAnnual =
                          pkg.storeProduct.subscriptionPeriod == 'P1Y';
                      final isCurrent = currentEntitlement == pkg.identifier;
                      final badge = isCurrent
                          ? 'Current Plan'
                          : isAnnual
                          ? 'Best Value'
                          : '7-Day Free Trial';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PricingCard(
                          package: pkg,
                          onTap: () {
                            if (!_isPurchasing && !isCurrent) {
                              _handlePurchase(pkg);
                            }
                          },
                          isDisabled: isCurrent,
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

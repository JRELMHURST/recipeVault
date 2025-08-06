import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePurchase(Package package) async {
    LoadingOverlay.show(context);
    try {
      await Purchases.purchasePackage(package);
      await _subscriptionService.syncRevenueCatEntitlement();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Purchase failed: $e')));
    } finally {
      LoadingOverlay.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeChef = _subscriptionService.homeChefPackage;
    final masterChef = _subscriptionService.masterChefMonthlyPackage;

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your free trial has ended',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'To continue using RecipeVault AI features like scanning, translation, and image uploads, please choose a plan below.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (homeChef != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PricingCard(
                              package: homeChef,
                              onTap: () => _handlePurchase(homeChef),
                            ),
                          ),
                        if (masterChef != null)
                          PricingCard(
                            package: masterChef,
                            onTap: () => _handlePurchase(masterChef),
                          ),
                        if (homeChef == null && masterChef == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'No subscription options available at this time.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 32),
                        TextButton.icon(
                          onPressed: () async {
                            LoadingOverlay.show(context);
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );
                            if (!context.mounted) return;
                            LoadingOverlay.hide();
                            Navigator.pushNamed(context, '/paywall');
                          },
                          icon: const Icon(Icons.arrow_forward_ios),
                          label: const Text('See all plan options'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ignore_for_file: deprecated_member_use

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/rev_cat/pricing_card.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/services/user_session_service.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

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

      final homeChefPackages = homeChef?.availablePackages ?? [];
      final masterChefPackages = masterChef?.availablePackages ?? [];

      final masterMonthly = masterChefPackages.firstWhere(
        (p) =>
            p.storeProduct.subscriptionPeriod?.toLowerCase().contains('m') ==
            true,
        orElse: () => masterChefPackages.isNotEmpty
            ? masterChefPackages.first
            : throw Exception('No Master Chef Monthly plan found'),
      );

      final masterAnnual = masterChefPackages.firstWhere(
        (p) =>
            p.storeProduct.subscriptionPeriod?.toLowerCase().contains('y') ==
            true,
        orElse: () => throw Exception('No Master Chef Annual plan found'),
      );

      _availablePackages = [...homeChefPackages, masterMonthly, masterAnnual];
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Chef Mode: ON')),
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
                      _buildNoticeCard(
                        context,
                        title: '🔓 Free Plan Access',
                        content:
                            'You currently have access to a selection of sample global recipes.\n\nTo scan your own, upload images, use AI tools, or save favourites — you’ll need to upgrade.',
                        background: Colors.orange.shade50,
                        border: Colors.orange.shade300,
                      )
                    else if (isTaster && trialActive)
                      _buildNoticeCard(
                        context,
                        title: '🎁 Trial Active',
                        content:
                            'You’re currently on a free 7-day trial. Upgrade to keep full access after it ends.',
                        background: Colors.green.shade50,
                        border: Colors.green.shade300,
                      )
                    else if (isTaster && trialExpired)
                      _buildNoticeCard(
                        context,
                        title: '⚠️ Trial Ended',
                        content:
                            'Your free trial has ended. Some features are now limited. Upgrade to unlock full access.',
                        background: Colors.orange.shade50,
                        border: Colors.orange.shade300,
                      ),

                    const SizedBox(height: 24),
                    Text(
                      'Enjoy unlimited access to powerful AI recipe tools, image uploads, category sorting, and more!',
                      style: theme.textTheme.bodyMedium,
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

                    const SizedBox(height: 32),
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: theme.textTheme.bodySmall,
                          children: [
                            const TextSpan(
                              text: 'By subscribing, you agree to our ',
                            ),
                            TextSpan(
                              text: 'Terms of Use',
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                  Uri.parse(
                                    'https://badger-creations.co.uk/terms',
                                  ),
                                ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                  Uri.parse(
                                    'https://badger-creations.co.uk/privacy',
                                  ),
                                ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
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

  Widget _buildNoticeCard(
    BuildContext context, {
    required String title,
    required String content,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(content, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

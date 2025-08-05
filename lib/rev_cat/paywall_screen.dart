// ignore_for_file: deprecated_member_use, use_build_context_synchronously

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
      final current = offerings.current;
      if (current == null) throw Exception('No current offering available');

      final currentId = _subscriptionService.entitlementId;
      _availablePackages = current.availablePackages;

      _availablePackages.sort((a, b) {
        final aIsCurrent =
            a.storeProduct.identifier == currentId || a.identifier == currentId;
        final bIsCurrent =
            b.storeProduct.identifier == currentId || b.identifier == currentId;
        if (aIsCurrent && !bIsCurrent) return -1;
        if (!aIsCurrent && bIsCurrent) return 1;
        return 0;
      });
    } catch (e) {
      debugPrint('❌ Failed to load offerings: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isPurchasing = true);
    LoadingOverlay.show(context);

    try {
      await Purchases.purchasePackage(package);
      await SubscriptionService().refresh();
      await UserSessionService.syncRevenueCatEntitlement();
      await UserSessionService.init();

      if (!mounted) return;
      LoadingOverlay.hide();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Subscription successful!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } on PlatformException catch (e) {
      if (!mounted) return;
      LoadingOverlay.hide();

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
      LoadingOverlay.hide();

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
    final entitlementId = _subscriptionService.entitlementId;
    final isFree = tier == 'free' || tier == 'none';

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(title: const Text('Chef Mode: ON')),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Unlock AI-powered recipes, image uploads, translation, and more!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                            ),
                          const SizedBox(height: 24),
                          ..._availablePackages.map((pkg) {
                            final isCurrent =
                                pkg.storeProduct.identifier == entitlementId ||
                                pkg.identifier == entitlementId ||
                                pkg.offeringIdentifier == entitlementId;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: PricingCard(
                                package: pkg,
                                onTap: isCurrent
                                    ? () {}
                                    : () {
                                        if (!_isPurchasing) {
                                          _handlePurchase(pkg);
                                        }
                                      },
                                isDisabled: isCurrent,
                                badge: isCurrent
                                    ? '✅ Current Plan'
                                    : pkg.storeProduct.subscriptionPeriod ==
                                          'P1Y'
                                    ? 'Best Value'
                                    : '7-Day Free Trial',
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
                            child: Column(
                              children: [
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: theme.textTheme.bodySmall,
                                    children: [
                                      const TextSpan(
                                        text:
                                            'By subscribing, you agree to our ',
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
                                const SizedBox(height: 12),
                                Text(
                                  'Subscriptions auto-renew unless cancelled 24h before the end of the period.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage or cancel anytime via your Apple ID settings.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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

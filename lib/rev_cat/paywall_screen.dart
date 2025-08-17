// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/rev_cat/pricing_card.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final SubscriptionService _subscriptionService;
  bool _isLoading = true;
  bool _isPurchasing = false;
  List<Package> _availablePackages = [];
  VoidCallback? _tierListener;

  @override
  void initState() {
    super.initState();
    _subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    _attachTierListener();
    _loadSubscriptionData();
  }

  void _attachTierListener() {
    // If tier flips from free → paid while we’re on this screen, redirect.
    _tierListener = () {
      final tier = _subscriptionService.tierNotifier.value;
      if (tier != 'free' && mounted) {
        _redirectHome();
      }
    };
    _subscriptionService.tierNotifier.addListener(_tierListener!);
  }

  @override
  void dispose() {
    if (_tierListener != null) {
      _subscriptionService.tierNotifier.removeListener(_tierListener!);
    }
    super.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    await _subscriptionService.init();
    try {
      final offerings = await Purchases.getOfferings();
      final entitlementId = _subscriptionService.entitlementId;

      final packages = <Package>[];
      final seen = <String>{};

      offerings.all.forEach((_, offering) {
        for (final pkg in offering.availablePackages) {
          final id = pkg.storeProduct.identifier;
          if (seen.add(id)) packages.add(pkg);
        }
      });

      packages.sort((a, b) {
        final priority = [
          'home_chef_monthly',
          'master_chef_monthly',
          'master_chef_yearly',
        ];

        bool isCurrent(Package pkg) =>
            entitlementId.isNotEmpty &&
            (pkg.storeProduct.identifier == entitlementId ||
                pkg.identifier == entitlementId ||
                pkg.offeringIdentifier == entitlementId);

        if (isCurrent(a) && !isCurrent(b)) return -1;
        if (!isCurrent(a) && isCurrent(b)) return 1;

        int aIndex = priority.indexWhere(
          (id) => a.storeProduct.identifier.toLowerCase().contains(id),
        );
        int bIndex = priority.indexWhere(
          (id) => b.storeProduct.identifier.toLowerCase().contains(id),
        );
        if (aIndex == -1) aIndex = priority.length;
        if (bIndex == -1) bIndex = priority.length;
        return aIndex.compareTo(bIndex);
      });

      _availablePackages = packages;
    } catch (e) {
      debugPrint('❌ Failed to load offerings: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isPurchasing = true);
    LoadingOverlay.show(context);

    try {
      final info = await Purchases.purchasePackage(package);

      // Sync local state + Firestore regardless.
      await _subscriptionService.syncRevenueCatEntitlement(forceRefresh: true);
      await _subscriptionService.loadSubscriptionStatus();

      if (!mounted) return;
      LoadingOverlay.hide();

      // If entitlement is already active, go home. If not, the tier listener will catch the flip.
      final hasEntitlement =
          info.entitlements.active.isNotEmpty ||
          _subscriptionService.hasActiveSubscription;
      if (hasEntitlement) {
        _redirectHome();
      }
    } on PlatformException {
      if (!mounted) return;
      LoadingOverlay.hide(); // Silent: no snackbars
    } catch (_) {
      if (!mounted) return;
      LoadingOverlay.hide(); // Silent: no snackbars
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _redirectHome() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/home', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entitlementId = _subscriptionService.entitlementId;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(title: Text(loc.chefModeTitle)),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  loc.paywallHeader,
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
                          const SizedBox(height: 24),
                          ..._availablePackages.map((pkg) {
                            final isCurrent =
                                entitlementId.isNotEmpty &&
                                (pkg.storeProduct.identifier == entitlementId ||
                                    pkg.identifier == entitlementId ||
                                    pkg.offeringIdentifier == entitlementId);

                            final badge = isCurrent
                                ? loc.badgeCurrentPlan
                                : (pkg.storeProduct.subscriptionPeriod == 'P1Y'
                                      ? loc.badgeBestValue
                                      : loc.badgeFreeTrial);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: PricingCard(
                                package: pkg,
                                onTap: () {
                                  if (!isCurrent && !_isPurchasing) {
                                    _handlePurchase(pkg);
                                  }
                                },
                                isDisabled: isCurrent,
                                badge: badge,
                              ),
                            );
                          }),
                          if (_availablePackages.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Text(
                                loc.noPlans,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          const SizedBox(height: 32),
                          Center(child: _buildLegalNotice(context)),
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

  Widget _buildLegalNotice(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.textTheme.bodySmall,
            children: [
              TextSpan(text: loc.legalAgreePrefix),
              TextSpan(
                text: loc.legalTerms,
                style: const TextStyle(decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(
                    Uri.parse('https://badger-creations.co.uk/terms'),
                  ),
              ),
              TextSpan(text: loc.legalAnd),
              TextSpan(
                text: loc.legalPrivacy,
                style: const TextStyle(decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(
                    Uri.parse('https://badger-creations.co.uk/privacy'),
                  ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          loc.legalAutoRenew,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          loc.legalManageApple,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () async {
            const url = 'https://support.apple.com/en-gb/HT202039';
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            }
          },
          icon: const Icon(Icons.cancel_outlined),
          label: Text(loc.manageOrCancelCta),
        ),
      ],
    );
  }
}

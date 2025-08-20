// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/billing/pricing_card.dart';
import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/app/routes.dart';
import 'package:recipe_vault/navigation/nav_utils.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final SubscriptionService _subscriptionService;

  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _loadFailed = false;

  List<Package> _availablePackages = [];
  // explicit manage flow (?manage=1)
  bool _isManaging = false;

  // ⬇️ Active product identifiers from RevenueCat (lowercased)
  Set<String> _activeProductIds = const {};

  @override
  void initState() {
    super.initState();
    _subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    _loadSubscriptionData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = GoRouterState.of(context);
    _isManaging = state.uri.queryParameters['manage'] == '1';
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    // Ensure RC/Firestore are current.
    await _subscriptionService.refresh();

    try {
      final offerings = await Purchases.getOfferings();
      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.active.values;
      _activeProductIds = {
        for (final e in active)
          if (e.productIdentifier.isNotEmpty) e.productIdentifier.toLowerCase(),
      };

      final packages = <Package>[];
      final seen = <String>{};

      // offerings.all can be empty; guard null/empty
      offerings.all.forEach((_, offering) {
        for (final pkg in offering.availablePackages) {
          final id = pkg.storeProduct.identifier;
          if (seen.add(id)) packages.add(pkg);
        }
      });

      // Sort: current entitlement first, then by priority
      final productId = _subscriptionService.productId;
      packages.sort((a, b) {
        bool isCurrentPkg(Package p) => _isPackageCurrent(p, productId);
        if (isCurrentPkg(a) && !isCurrentPkg(b)) return -1;
        if (!isCurrentPkg(a) && isCurrentPkg(b)) return 1;

        const priority = [
          'home_chef_monthly',
          'master_chef_monthly',
          'master_chef_yearly',
        ];
        int ix(String s) =>
            priority.indexWhere((key) => s.toLowerCase().contains(key));
        int aIx = ix(a.storeProduct.identifier);
        int bIx = ix(b.storeProduct.identifier);
        if (aIx == -1) aIx = priority.length;
        if (bIx == -1) bIx = priority.length;
        return aIx.compareTo(bIx);
      });

      if (!mounted) return;
      _availablePackages = packages;
    } catch (e) {
      debugPrint('❌ Failed to load offerings: $e');
      _loadFailed = true;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ✅ Lenient “current package” detection:
  bool _isPackageCurrent(Package pkg, String productId) {
    final pid = pkg.storeProduct.identifier.toLowerCase();

    // (1) match RC product ids
    if (_activeProductIds.isNotEmpty) {
      if (_activeProductIds.any(
        (p) => p == pid || p.contains(pid) || pid.contains(p),
      )) {
        return true;
      }
    }

    // (2) fallback: match entitlement keyword against product id
    final ent = productId.toLowerCase();
    if (ent.isNotEmpty) {
      if (ent.contains('master') && pid.contains('master')) return true;
      if (ent.contains('home') && pid.contains('home')) return true;
    }

    return false;
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isPurchasing = true);
    LoadingOverlay.show(context);
    try {
      // Direct RC purchase (no PurchaseHelper)
      final info = await Purchases.purchasePackage(package);

      // 🔄 Force backend reconcile (RC → Firestore) just like before
      try {
        final functions = FirebaseFunctions.instanceFor(region: "europe-west2");
        final callable = functions.httpsCallable("reconcileUserFromRC");
        await callable.call(<String, dynamic>{}); // auth context supplies uid
        if (kDebugMode) debugPrint("✅ Reconcile triggered after purchase");
      } catch (e) {
        if (kDebugMode) debugPrint("⚠️ Failed to trigger reconcile: $e");
      }

      // Pull fresh RC + FS state into the app.
      await _subscriptionService.refresh();

      if (!mounted) return;
      LoadingOverlay.hide();

      final hasEntitlement =
          info.entitlements.active.isNotEmpty ||
          _subscriptionService.hasActiveSubscription;

      // Router redirect will move us if entitled; otherwise inform the user.
      if (!hasEntitlement && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase completed but not active yet.'),
          ),
        );
      }
    } on PlatformException {
      if (!mounted) return;
      LoadingOverlay.hide(); // user cancelled
    } catch (_) {
      if (!mounted) return;
      LoadingOverlay.hide(); // silent errors
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    final status = context.watch<SubscriptionService>().status;

    // While subscriptions are resolving, keep the spinner up (also matches router guard).
    final isResolving = status == EntitlementStatus.checking;
    final showSpinner = _isLoading || isResolving;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(loc.chefModeTitle),
        leading: _isManaging
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (context.canPop()) {
                    safePop(context);
                  } else {
                    safeGo(context, AppRoutes.settings);
                  }
                },
              )
            : null,
        actions: [
          if (!showSpinner)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadSubscriptionData,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: showSpinner
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context, theme, loc),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    AppLocalizations loc,
  ) {
    final productId = _subscriptionService.productId;

    return Column(
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

                    // Packages list OR empty/failure state
                    if (_availablePackages.isNotEmpty) ...[
                      ..._availablePackages.map((pkg) {
                        final isCurrent = _isPackageCurrent(pkg, productId);
                        final isYearly =
                            (pkg.storeProduct.subscriptionPeriod ?? '')
                                .toUpperCase() ==
                            'P1Y';

                        final String? badge = isCurrent
                            ? loc.badgeCurrentPlan
                            : (isYearly ? loc.badgeBestValue : null);

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
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          children: [
                            Text(
                              _loadFailed
                                  ? 'Couldn’t load plans.'
                                  : loc.noPlans,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _loadSubscriptionData,
                              icon: const Icon(Icons.refresh),
                              // Replaced missing loc.retry with a safe literal
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    Center(child: _buildLegalNotice(context)),
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
                    mode: LaunchMode.externalApplication,
                  ),
              ),
              TextSpan(text: loc.legalAnd),
              TextSpan(
                text: loc.legalPrivacy,
                style: const TextStyle(decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(
                    Uri.parse('https://badger-creations.co.uk/privacy'),
                    mode: LaunchMode.externalApplication,
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
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.cancel_outlined),
          label: Text(loc.manageOrCancelCta),
        ),
      ],
    );
  }
}

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

      // 🔁 No need to call UserSessionService.init() here anymore –
      // authStateChanges() listener in main.dart will handle it.
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
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
          'Limited Access',
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
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '⚠️ You’re currently on Free access. AI-powered features like recipe scanning, formatting, and translation are disabled. You can still access saved recipes in your vault.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Upgrade to continue using RecipeVault AI:',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PricingCard(
                              package: masterChef,
                              onTap: () => _handlePurchase(masterChef),
                            ),
                          ),
                        if (homeChef == null && masterChef == null)
                          const Text(
                            'No subscription packages available at the moment. Please try again later.',
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Limited Free Access'),
                                content: const Text(
                                  'You can still access your previously saved recipes.\n\n'
                                  'However, features like recipe scanning and translation are now locked.\n'
                                  'To continue using RecipeVault AI, please subscribe.',
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
                            'Continue with limited access',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
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

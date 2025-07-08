// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart'; // ✅ Needed for PlatformException

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllPackages();
  }

  Future<void> _loadAllPackages() async {
    try {
      final offerings = await Purchases.getOfferings();

      final seen = <String>{};
      final uniquePackages = <Package>[];

      for (final offering in offerings.all.values) {
        for (final pkg in offering.availablePackages) {
          final id = pkg.storeProduct.identifier;
          if (!seen.contains(id)) {
            seen.add(id);
            uniquePackages.add(pkg);
          }
        }
      }

      setState(() {
        _packages = uniquePackages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load plans.';
        _isLoading = false;
      });
    }
  }

  Future<void> _purchase(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      if (mounted) context.go('/upgrade-success');
    } on PlatformException catch (e) {
      if (e.code == '1' ||
          e.message?.toLowerCase().contains('cancelled') == true) {
        debugPrint('🟡 Purchase cancelled by user.');
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
      }
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await Purchases.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore purchases: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    final homeChef = _packages
        .where((pkg) => pkg.storeProduct.title.toLowerCase().contains('home'))
        .toList();

    final masterChef = _packages
        .where((pkg) => pkg.storeProduct.title.toLowerCase().contains('master'))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (homeChef.isNotEmpty) ...[
                  Text(
                    '🏠 Home Chef Plan',
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...homeChef.map((pkg) => _buildPackageCard(pkg, theme)),
                  const SizedBox(height: 24),
                ],
                if (masterChef.isNotEmpty) ...[
                  Text(
                    '👨‍🍳 Master Chef Plans',
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...masterChef.map((pkg) => _buildPackageCard(pkg, theme)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _restorePurchases,
            child: const Text('Restore Purchases'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Package pkg, ThemeData theme) {
    final planBenefits = _getPlanBenefits(pkg);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(pkg.storeProduct.title, style: theme.textTheme.titleLarge),
        subtitle: Text(pkg.storeProduct.priceString),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final benefit in planBenefits) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(benefit)),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _purchase(pkg),
                  child: const Text('Subscribe'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getPlanBenefits(Package pkg) {
    final title = pkg.storeProduct.title.toLowerCase();
    if (title.contains('home')) {
      return [
        '5 AI translations per month',
        '20 AI recipe creations',
        'Recipe image uploads',
        'Cancel anytime',
      ];
    } else if (title.contains('master')) {
      return [
        'Unlimited AI translations',
        'Priority processing queue',
        'Advanced recipe filtering',
        'All Home Chef features included',
        'Cancel anytime',
      ];
    } else {
      return [
        'Full access for 7 days',
        'Unlimited AI recipe creations',
        'Recipe image upload support',
        'Cancel anytime',
      ];
    }
  }
}

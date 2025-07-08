import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:go_router/go_router.dart';

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
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

    // Group plans
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pkg.storeProduct.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              pkg.storeProduct.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _purchase(pkg),
              child: Text(pkg.storeProduct.priceString),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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
    _loadUniquePackages();
  }

  Future<void> _loadUniquePackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final Map<String, Package> dedupedPackages = {};

      for (final offering in offerings.all.values) {
        for (final pkg in offering.availablePackages) {
          dedupedPackages[pkg.identifier] = pkg;
        }
      }

      setState(() {
        _packages = dedupedPackages.values.toList();
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
    Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final pkg = _packages[index];
                return SubscriptionCard(
                  title: pkg.storeProduct.title,
                  description: pkg.storeProduct.description,
                  price: pkg.storeProduct.priceString,
                  onTap: () => _purchase(pkg),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _restorePurchases,
            child: const Text(
              'Restore Purchases',
              style: TextStyle(fontSize: 16, color: Colors.deepPurple),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class SubscriptionCard extends StatelessWidget {
  final String title;
  final String description;
  final String price;
  final VoidCallback onTap;

  const SubscriptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD5C9F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(price, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

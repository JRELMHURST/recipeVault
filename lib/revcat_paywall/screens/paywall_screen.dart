import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:go_router/go_router.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      setState(() {
        _offerings = offerings;
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

    final packages = _offerings?.current?.availablePackages ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: packages.length,
              itemBuilder: (context, index) {
                final pkg = packages[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg.storeProduct.title,
                          style: theme.textTheme.titleLarge,
                        ),
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
              },
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
}

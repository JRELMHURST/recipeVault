// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

class SubscriptionSettingsScreen extends StatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  State<SubscriptionSettingsScreen> createState() =>
      _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState
    extends State<SubscriptionSettingsScreen> {
  String _currentTier = 'Loading...';
  String _entitlements = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadSubscriptionInfo();
  }

  Future<void> _loadSubscriptionInfo() async {
    final tier = SubscriptionService().getCurrentTierName();
    final isSuperUser = SubscriptionService().isSuperUser;
    final info = await Purchases.getCustomerInfo();
    final entitlements = info.entitlements.active.keys.join(', ');

    setState(() {
      _currentTier = isSuperUser ? '$tier (Super User)' : tier;
      _entitlements = entitlements.isEmpty ? 'None' : entitlements;
    });
  }

  Future<void> _restorePurchases() async {
    try {
      await Purchases.restorePurchases();
      _loadSubscriptionInfo();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Purchases restored.")));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to restore purchases.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Subscription')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('CURRENT PLAN'),
          ListTile(
            leading: const Icon(Icons.card_membership_outlined),
            title: const Text('Subscription Tier'),
            subtitle: Text(_currentTier),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Active Entitlements'),
            subtitle: Text(_entitlements),
          ),
          const ListTile(
            leading: Icon(Icons.cancel_outlined),
            title: Text('Cancel Anytime'),
            subtitle: Text(
              'Manage or cancel your plan anytime from your App Store account.',
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('ACTIONS'),
          ListTile(
            leading: const Icon(Icons.upgrade_outlined),
            title: const Text('Change Plan'),
            onTap: () => context.push('/pricing'),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Restore Purchases'),
            onTap: _restorePurchases,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

class DevTestingScreen extends StatefulWidget {
  const DevTestingScreen({super.key});

  @override
  State<DevTestingScreen> createState() => _DevTestingScreenState();
}

class _DevTestingScreenState extends State<DevTestingScreen> {
  String _status = 'Idle';
  String _tier = 'Unknown';

  Future<void> _resetAppState() async {
    setState(() => _status = 'Resetting...');
    await FirebaseAuth.instance.signOut();
    await SubscriptionService().refresh();
    final tier = SubscriptionService().getCurrentTierName();
    setState(() {
      _status = 'App state cleared';
      _tier = tier;
    });
  }

  Future<void> _printEntitlements() async {
    setState(() => _status = 'Fetching entitlements...');
    final info = await Purchases.getCustomerInfo();
    setState(() {
      _status = 'Entitlements: ${info.entitlements.active.keys.join(", ")}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dev Testing Tools')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader('🛠 Dev Actions'),
            _buildButton(
              label: 'Reset App State (Logout + Clear + Hive)',
              icon: Icons.refresh,
              onPressed: _resetAppState,
            ),
            _buildButton(
              label: 'Print RevenueCat Entitlements',
              icon: Icons.info_outline,
              onPressed: _printEntitlements,
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('🧭 Navigation Shortcuts'),
            _buildButton(
              label: 'Go to Paywall Screen',
              onPressed: () => context.push('/pricing'),
            ),
            _buildButton(
              label: 'Go to Home Screen',
              onPressed: () => context.push('/home'),
            ),
            const SizedBox(height: 32),
            Text('Status: $_status', style: theme.textTheme.bodyMedium),
            Text('Current Tier: $_tier', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD5C9F3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          elevation: 2,
        ),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.open_in_new),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }
}

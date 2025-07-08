import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
    if (kReleaseMode) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Dev Testing Tools')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _resetAppState,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset App State'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _printEntitlements,
              icon: const Icon(Icons.info_outline),
              label: const Text('Print RevenueCat Entitlements'),
            ),
            const SizedBox(height: 32),
            Text('Status: $_status'),
            Text('Current Tier: $_tier'),
          ],
        ),
      ),
    );
  }
}

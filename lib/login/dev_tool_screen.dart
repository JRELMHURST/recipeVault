import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

class DevToolScreen extends StatefulWidget {
  const DevToolScreen({super.key});

  @override
  State<DevToolScreen> createState() => _DevToolScreenState();
}

class _DevToolScreenState extends State<DevToolScreen> {
  String _status = 'Idle';
  String _tier = 'Unknown';
  User? _user;
  Map<String, EntitlementInfo> _entitlements = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    final info = await Purchases.getCustomerInfo();
    final tier = SubscriptionService().getCurrentTierName();

    setState(() {
      _user = user;
      _tier = tier;
      _entitlements = info.entitlements.active;
    });
  }

  Future<void> _resetAppState() async {
    setState(() => _status = 'Resetting app state...');
    await FirebaseAuth.instance.signOut();
    await SubscriptionService().refresh();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _refreshEntitlements() async {
    setState(() => _status = 'Refreshing entitlements...');
    await SubscriptionService().refresh();
    await _fetchData();
    setState(() => _status = 'Entitlements refreshed.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Dev Tools')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            _sectionTitle('🧪 User Info'),
            _infoTile('Email', _user?.email ?? '—'),
            _infoTile('UID', _user?.uid ?? '—'),
            _infoTile('Current Tier', _tier),

            const SizedBox(height: 24),
            _sectionTitle('📦 Active Entitlements'),
            ..._entitlements.entries.map((e) => _infoTile(e.key, '✅ active')),

            const SizedBox(height: 24),
            _sectionTitle('🛠 Actions'),
            _devButton('Refresh Entitlements', _refreshEntitlements),
            _devButton('Reset App State', _resetAppState),

            const SizedBox(height: 24),
            _sectionTitle('🧭 Shortcuts'),
            _devButton('Go to Paywall', () => context.push('/pricing')),
            _devButton('Go to Home', () => context.push('/home')),
            _devButton('Go to Login', () => context.go('/login')),

            const SizedBox(height: 24),
            Text('Status: $_status', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  );

  Widget _infoTile(String label, String value) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value),
  );

  Widget _devButton(String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    ),
  );
}

import 'package:flutter/material.dart';

class SubscriptionSettingsScreen extends StatelessWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionHeader('CURRENT PLAN'),
          ListTile(
            leading: Icon(Icons.card_membership_outlined),
            title: Text('Subscription Tier'),
            subtitle: Text('N/A'),
          ),
          ListTile(
            leading: Icon(Icons.verified_user_outlined),
            title: Text('Active Entitlements'),
            subtitle: Text('N/A'),
          ),
          ListTile(
            leading: Icon(Icons.cancel_outlined),
            title: Text('Cancel Anytime'),
            subtitle: Text(
              'Manage or cancel your plan anytime from your App Store account.',
            ),
          ),
          SizedBox(height: 24),
          _SectionHeader('ACTIONS'),
          ListTile(
            leading: Icon(Icons.upgrade_outlined),
            title: Text('Change Plan'),
            enabled: false,
          ),
          ListTile(
            leading: Icon(Icons.refresh),
            title: Text('Restore Purchases'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
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

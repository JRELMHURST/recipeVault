import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/login/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: Text("No user signed in")));
    }

    final email = user.email ?? '';
    final displayName = user.displayName ?? 'No name';
    final photoUrl = user.photoURL;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// Profile Section
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(email, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Account Settings'),
            onTap: () => context.push('/settings/account'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            textColor: theme.colorScheme.error,
            iconColor: theme.colorScheme.error,
            onTap: () async {
              await AuthService().signOut();
              if (context.mounted) context.go('/login');
            },
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('Preferences'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Appearance'),
            onTap: () => context.push('/settings/appearance'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            onTap: () => context.push('/settings/notifications'),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('Storage & Sync'),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Sync Status'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear Cache'),
            onTap: () {},
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('Subscription'),
          ListTile(
            leading: const Icon(Icons.card_membership_outlined),
            title: const Text('Manage Subscription'),
            onTap: () => context.push('/settings/subscription'),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About & Legal'),
            onTap: () => context.push('/settings/about'),
          ),

          if (email == 'jnriggall@gmail.com') ...[
            const SizedBox(height: 32),
            _buildSectionHeader('Developer'),
          ],
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

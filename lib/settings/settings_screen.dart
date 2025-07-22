// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:url_launcher/url_launcher.dart';

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
      body: SafeArea(
        child: ResponsiveWrapper(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // 🔮 Gradient Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 48, bottom: 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(36),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 44,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _buildSettingsCard(
                context,
                title: 'Account',
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.manage_accounts_outlined,
                    label: 'Account Settings',
                    route: '/settings/account',
                  ),
                ],
              ),
              _buildSettingsCard(
                context,
                title: 'Preferences',
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: CupertinoIcons.brightness,
                    label: 'Appearance',
                    route: '/settings/appearance',
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    route: '/settings/notifications',
                  ),
                ],
              ),
              _buildSettingsCard(
                context,
                title: 'Overview',
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.cloud_done_outlined,
                    label: 'Storage & Sync',
                    route: '/settings/storage-sync',
                  ),
                ],
              ),
              _buildSettingsCard(
                context,
                title: 'Subscription',
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.card_membership_outlined,
                    label: 'Manage Subscription',
                    route: '/settings/subscription',
                  ),
                ],
              ),
              _buildSettingsCard(
                context,
                title: 'About',
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.info_outline,
                    label: 'About & Legal',
                    route: '/settings/about',
                  ),
                ],
              ),

              // 👋 Friendly footer with links
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Cheeky Badger Creations',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Image.asset(
                          'assets/icon/cheeky_badger_round.png',
                          width: 16,
                          height: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      children: [
                        GestureDetector(
                          onTap: () => _launchUrl(
                            'https://badger-creations.co.uk/privacy',
                          ),
                          child: Text(
                            'Privacy Policy',
                            style: theme.textTheme.labelSmall?.copyWith(
                              decoration: TextDecoration.underline,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _launchUrl(
                            'https://badger-creations.co.uk/terms',
                          ),
                          child: Text(
                            'Terms of Use',
                            style: theme.textTheme.labelSmall?.copyWith(
                              decoration: TextDecoration.underline,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('⚠️ Could not launch $url');
    }
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required List<Widget> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}

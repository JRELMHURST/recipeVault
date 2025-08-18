// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    if (user == null) {
      return Scaffold(body: Center(child: Text(t.authUserNotFound)));
    }

    final tier = context.watch<SubscriptionService>().tier;
    final planLabel = switch (tier) {
      'home_chef' => '👨‍🍳 ${t.planHomeChef}',
      'master_chef' => '👑 ${t.planMasterChef}',
      _ => '🆓 ${t.planFree}',
    };

    return Scaffold(
      body: SafeArea(
        child: ResponsiveWrapper(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
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
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Center(
                  child: Text(
                    planLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Account
              _buildSettingsCard(
                context,
                title: t.settingsSectionAccount,
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.manage_accounts_outlined,
                    label: t.settingsTileAccountSettings,
                    route: '/settings/account',
                  ),
                ],
              ),

              // Preferences
              _buildSettingsCard(
                context,
                title: t.settingsSectionPreferences,
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: CupertinoIcons.brightness,
                    label: t.settingsTileAppearance,
                    route: '/settings/appearance',
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.notifications_outlined,
                    label: t.settingsTileNotifications,
                    route: '/settings/notifications',
                  ),
                ],
              ),

              // Local Storage
              _buildSettingsCard(
                context,
                title: t.settingsSectionStorage,
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.cloud_done_outlined,
                    label: t.settingsTileCacheClear,
                    route: '/settings/storage',
                  ),
                ],
              ),

              // Subscription
              _buildSettingsCard(
                context,
                title: t.settingsSectionSubscription,
                items: [
                  // Note: /paywall lives outside the shell → use context.go
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.card_membership_outlined,
                    label: t.settingsTileManageSubscription,
                    route: '/paywall',
                  ),
                ],
              ),

              // Support
              _buildSettingsCard(
                context,
                title: t.settingsSectionSupport,
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.help_outline,
                    label: t.settingsTileHelpFaqs,
                    route: '/settings/faqs',
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.info_outline,
                    label: t.settingsTileAboutLegal,
                    route: '/settings/about',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Footer
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.footerCompanyName,
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
                            t.legalPrivacy,
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
                            t.legalTerms,
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
          // Keep i18n intact; no forced uppercase.
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.6,
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
    final isPaywall = route == '/paywall';
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (isPaywall) {
          // replace shell with Paywall (outside the ShellRoute)
          context.go(route);
        } else {
          // push settings subpages on top of the current shell
          context.push(route);
        }
      },
    );
  }
}

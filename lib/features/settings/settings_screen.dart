// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/app/routes.dart';
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

    return Scaffold(
      body: SafeArea(
        child: ResponsiveWrapper(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Header (plan/app banner)
              const SizedBox(height: 8),
              _PlanHeaderBanner(),

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
                    route: AppRoutes.settingsAccount,
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
                    route: AppRoutes.settingsAppearance,
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.notifications_outlined,
                    label: t.settingsTileNotifications,
                    route: AppRoutes.settingsNotifications,
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
                    route: AppRoutes.settingsStorage,
                  ),
                ],
              ),

              // Subscription
              _buildSettingsCard(
                context,
                title: t.settingsSectionSubscription,
                items: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.card_membership_outlined,
                    label: t.settingsTileManageSubscription,
                    route: AppRoutes.paywall, // helper will add ?manage=1
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
                    route: AppRoutes.settingsFaqs,
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.info_outline,
                    label: t.settingsTileAboutLegal,
                    route: AppRoutes.settingsAbout,
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
    final isPaywall = route == AppRoutes.paywall;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (isPaywall) {
          final loc = Uri(
            path: AppRoutes.paywall,
            queryParameters: {'manage': '1'},
          ).toString();
          context.go(loc);
        } else {
          context.push(route);
        }
      },
    );
  }
}

/// Floating premium-style banner that keeps text perfectly centered.
/// If tier is free/none → shows the app title instead of "Free plan".
class _PlanHeaderBanner extends StatelessWidget {
  const _PlanHeaderBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final tier = context.watch<SubscriptionService>().tier;

    final label = switch (tier) {
      'home_chef' => t.planHomeChef,
      'master_chef' => t.planMasterChef,
      _ => t.appTitle, // ← free/default shows app name
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          // soft, premium gradient
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.90),
              theme.colorScheme.primary.withOpacity(0.72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label, // no emojis
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

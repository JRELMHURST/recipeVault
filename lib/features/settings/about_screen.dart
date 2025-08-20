// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/billing/subscription_service.dart';

class AboutSettingsScreen extends StatefulWidget {
  const AboutSettingsScreen({super.key});

  @override
  State<AboutSettingsScreen> createState() => _AboutSettingsScreenState();
}

class _AboutSettingsScreenState extends State<AboutSettingsScreen> {
  String? _appVersion; // null = loading

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = '${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 24),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        onTap: onTap,
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // 🔎 subscription plan label
    final tier = context.watch<SubscriptionService>().tier;
    final planLabel = switch (tier) {
      'home_chef' => t.planHomeChef,
      'master_chef' => t.planMasterChef,
      _ => '',
    };

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        elevation: 0,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(.96),
                theme.colorScheme.primary.withOpacity(.80),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.aboutLegalTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: .6,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    blurRadius: 2,
                    offset: Offset(0, 1),
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
            if (planLabel.isNotEmpty)
              Text(
                planLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: ListView(
          children: [
            _buildSection(t.appInfoSectionTitle, [
              _buildCard(
                icon: Icons.info_outline,
                title: t.versionLabel,
                subtitle: _appVersion ?? t.loading,
              ),
            ]),
            _buildSection(t.legalSectionTitle, [
              _buildCard(
                icon: Icons.privacy_tip_outlined,
                title: t.legalPrivacy,
                onTap: () =>
                    _launchURL('https://badger-creations.co.uk/privacy'),
              ),
              _buildCard(
                icon: Icons.description_outlined,
                title: t.legalTerms,
                onTap: () => _launchURL('https://badger-creations.co.uk/terms'),
              ),
            ]),
            _buildSection(t.supportSectionTitle, [
              _buildCard(
                icon: Icons.link,
                title: t.visitWebsite,
                onTap: () => _launchURL('https://badger-creations.co.uk'),
              ),
              _buildCard(
                icon: Icons.mail_outline,
                title: t.contactSupport,
                onTap: () =>
                    _launchURL('https://badger-creations.co.uk/support'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

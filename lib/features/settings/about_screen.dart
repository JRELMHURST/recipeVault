import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(t.aboutLegalTitle)),
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
                title: t.legalPrivacy, // already exists in your ARB
                onTap: () =>
                    _launchURL('https://badger-creations.co.uk/privacy'),
              ),
              _buildCard(
                icon: Icons.description_outlined,
                title: t.legalTerms, // already exists in your ARB
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

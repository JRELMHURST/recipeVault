import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutSettingsScreen extends StatefulWidget {
  const AboutSettingsScreen({super.key});

  @override
  State<AboutSettingsScreen> createState() => _AboutSettingsScreenState();
}

class _AboutSettingsScreenState extends State<AboutSettingsScreen> {
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${info.version} (${info.buildNumber})';
    });
  }

  void _openURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About & Legal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('App Version'),
            subtitle: Text(_appVersion),
            leading: const Icon(Icons.info_outline),
          ),
          const Divider(),
          ListTile(
            title: const Text('Privacy Policy'),
            leading: const Icon(Icons.privacy_tip_outlined),
            onTap: () => _openURL('https://yourdomain.com/privacy'),
          ),
          ListTile(
            title: const Text('Terms of Service'),
            leading: const Icon(Icons.description_outlined),
            onTap: () => _openURL('https://yourdomain.com/terms'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Website'),
            leading: const Icon(Icons.link),
            onTap: () => _openURL('https://yourdomain.com'),
          ),
          ListTile(
            title: const Text('Contact Support'),
            leading: const Icon(Icons.mail_outline),
            onTap: () => _openURL('mailto:support@yourdomain.com'),
          ),
        ],
      ),
    );
  }
}

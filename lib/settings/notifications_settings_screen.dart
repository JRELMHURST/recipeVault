import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _reminderNotifications = true;
  bool _newFeatureAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reminderNotifications = prefs.getBool('reminderNotifications') ?? true;
      _newFeatureAlerts = prefs.getBool('newFeatureAlerts') ?? true;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildSectionHeader('REMINDERS'),
            SwitchListTile(
              title: const Text('Weekly Recipe Reminders'),
              subtitle: const Text(
                'Get a reminder every week to upload recipes',
              ),
              value: _reminderNotifications,
              onChanged: (val) {
                setState(() => _reminderNotifications = val);
                _updateSetting('reminderNotifications', val);
              },
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('UPDATES'),
            SwitchListTile(
              title: const Text('New Feature Announcements'),
              subtitle: const Text('Be notified when new features go live'),
              value: _newFeatureAlerts,
              onChanged: (val) {
                setState(() => _newFeatureAlerts = val);
                _updateSetting('newFeatureAlerts', val);
              },
            ),
          ],
        ),
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

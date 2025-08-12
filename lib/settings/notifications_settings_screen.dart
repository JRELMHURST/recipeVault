import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/services/notification_service.dart';

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

    if (key == 'reminderNotifications') {
      if (value) {
        await NotificationService.scheduleWeeklyReminder();
      } else {
        await NotificationService.cancelWeeklyReminder();
      }
    }

    if (key == 'newFeatureAlerts') {
      if (value) {
        await NotificationService.enableFeatureAnnouncements();
      } else {
        await NotificationService.disableFeatureAnnouncements();
      }
    }
  }

  Widget _sectionHeader(BuildContext context, String title) {
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

  Widget _prefTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
    IconData? icon,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title),
        subtitle: Text(subtitle),
        secondary: Icon(icon ?? Icons.notifications_outlined),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.notificationsTitle)),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _sectionHeader(context, t.notificationsSectionReminders),
            _prefTile(
              title: t.notificationsWeeklyTitle,
              subtitle: t.notificationsWeeklySubtitle,
              icon: Icons.calendar_today_outlined,
              value: _reminderNotifications,
              onChanged: (val) {
                setState(() => _reminderNotifications = val);
                _updateSetting('reminderNotifications', val);
              },
            ),
            _sectionHeader(context, t.notificationsSectionUpdates),
            _prefTile(
              title: t.notificationsFeatureAlertsTitle,
              subtitle: t.notificationsFeatureAlertsSubtitle,
              icon: Icons.auto_awesome,
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
}

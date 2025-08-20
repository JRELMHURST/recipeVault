// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/data/services/notification_service.dart';
import 'package:recipe_vault/billing/subscription_service.dart';

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
    final theme = Theme.of(context);

    // 🔎 Plan label
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
              t.notificationsTitle,
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

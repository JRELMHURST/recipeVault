// ignore_for_file: deprecated_member_use

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Firebase Messaging Permissions
    await _messaging.requestPermission();
    await _messaging.getToken().then((token) {
      if (kDebugMode) print('🔔 FCM Token: \$token');
    });
  }

  static Future<void> scheduleWeeklyReminder() async {
    await _plugin.zonedSchedule(
      0,
      'Weekly Recipe Reminder',
      'Don’t forget to upload your latest recipes!',
      _nextInstanceOfSundayAtTime(10, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_reminder',
          'Weekly Reminder',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelWeeklyReminder() async {
    await _plugin.cancel(0);
  }

  static Future<void> enableFeatureAnnouncements() async {
    await _messaging.subscribeToTopic('feature_announcements');
    debugPrint('✅ Subscribed to feature_announcements');
  }

  static Future<void> disableFeatureAnnouncements() async {
    await _messaging.unsubscribeFromTopic('feature_announcements');
    debugPrint('🚫 Unsubscribed from feature_announcements');
  }

  static tz.TZDateTime _nextInstanceOfSundayAtTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != DateTime.sunday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    return scheduled;
  }
}

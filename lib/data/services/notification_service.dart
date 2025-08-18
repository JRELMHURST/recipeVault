// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Centralised local + push notification wiring.
/// - Handles iOS/Android permission prompts
/// - Creates Android channels
/// - Shows foreground FCMs using local notifications
/// - Provides simple weekly scheduler
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const _weeklyChannelId = 'weekly_reminder';
  static const _weeklyChannelName = 'Weekly Reminder';
  static const _weeklyChannelDesc = 'Reminds you to add new recipes weekly';

  static bool _initialised = false;
  static bool _tzInitialised = false;

  /// Call once at app start (after Firebase is ready).
  static Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // ---- Timezone (idempotent) ----
    if (!_tzInitialised) {
      tz.initializeTimeZones();
      _tzInitialised = true;
    }

    // ---- Local notifications init ----
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      // Show alert/badge/sound when local notif fires in foreground
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        if (kDebugMode) {
          debugPrint('🔔 Local notification tapped: ${resp.payload}');
        }
        // No navigation here—route handling stays in your GoRouter layer.
      },
    );

    // ---- Android: create channels up-front ----
    await _ensureAndroidChannels();

    // ---- Push permissions (iOS + Android 13+) ----
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (kDebugMode) {
      debugPrint('🔐 Notification permission: ${settings.authorizationStatus}');
    }

    // iOS: ensure foreground notifications show system banners
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // 🍏 Wait for APNs token on iOS (important before topic subs)
    await _waitForAPNSToken();

    // 🪪 Print FCM token for debug
    final token = await _messaging.getToken();
    if (kDebugMode) debugPrint('🔔 FCM Token: $token');

    // ---- Foreground FCM → show as local notification ----
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        debugPrint(
          '📬 FCM (foreground): ${message.notification?.title} | ${message.notification?.body}',
        );
      }
      await _showForegroundRemote(message);
    });

    // (Optional) app opened from a terminated/background state via a push
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      if (kDebugMode) debugPrint('🚪 Notification opened app: ${message.data}');
      // Keep any deep-link routing in your GoRouter layer (e.g., via a top-level handler).
    });
  }

  /// Re-requests notification permissions (useful from settings screen).
  static Future<AuthorizationStatus> requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return settings.authorizationStatus;
  }

  /// Schedules a weekly reminder for Sunday at [hour]:[minute] local time.
  static Future<void> scheduleWeeklyReminder({
    int hour = 10,
    int minute = 0,
  }) async {
    await _ensureAndroidChannels();
    await _plugin.zonedSchedule(
      1000, // unique id for this reminder
      'Weekly Recipe Reminder',
      'Don’t forget to upload your latest recipes!',
      _nextInstanceOfWeekdayAtTime(DateTime.sunday, hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _weeklyChannelId,
          _weeklyChannelName,
          channelDescription: _weeklyChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelWeeklyReminder() => _plugin.cancel(1000);

  /// Opt-in broadcast updates for feature announcements (topic).
  static Future<void> enableFeatureAnnouncements() async {
    await _waitForAPNSToken();
    await _messaging.subscribeToTopic('feature_announcements');
    debugPrint('✅ Subscribed to feature_announcements');
  }

  static Future<void> disableFeatureAnnouncements() async {
    await _waitForAPNSToken();
    await _messaging.unsubscribeFromTopic('feature_announcements');
    debugPrint('🚫 Unsubscribed from feature_announcements');
  }

  /// Expose current tokens (useful for debugging/support).
  static Future<String?> getFcmToken() => _messaging.getToken();
  static Future<String?> getApnsToken() => _messaging.getAPNSToken();

  // ----------------- Internals -----------------

  static Future<void> _ensureAndroidChannels() async {
    if (!Platform.isAndroid) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _weeklyChannelId,
        _weeklyChannelName,
        description: _weeklyChannelDesc,
        importance: Importance.high,
      ),
    );
  }

  static Future<void> _showForegroundRemote(RemoteMessage m) async {
    final notif = m.notification;

    // If the remote specifies a channel id, prefer it; otherwise use our default.
    final androidDetails = AndroidNotificationDetails(
      notif?.android?.channelId ?? _weeklyChannelId,
      notif?.android?.channelId == null ? _weeklyChannelName : 'Remote channel',
      channelDescription: _weeklyChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      // Transient id to avoid collisions
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notif?.title ?? 'RecipeVault',
      notif?.body ?? '',
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      payload: m.data.isEmpty ? null : m.data.toString(),
    );
  }

  static Future<void> _waitForAPNSToken() async {
    if (!Platform.isIOS) return;

    String? apnsToken;
    for (int i = 0; i < 10; i++) {
      apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null) break;
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (kDebugMode) {
      if (apnsToken == null) {
        debugPrint('⚠️ Failed to retrieve APNs token after retries');
      } else {
        debugPrint('🍏 APNs token acquired: $apnsToken');
      }
    }
  }

  static tz.TZDateTime _nextInstanceOfWeekdayAtTime(
    int weekday,
    int hour,
    int minute,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Move forward to requested weekday at/after now
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

// ignore_for_file: unnecessary_null_checks

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/settings/faq_screen.dart';

// Core
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';

// Auth Screens
import 'login/login_screen.dart';
import 'login/register_screen.dart';
import 'login/change_password.dart';

// Main Screens
import 'screens/home_screen/home_screen.dart';
import 'screens/results_screen.dart';

// Settings
import 'settings/settings_screen.dart';
import 'settings/account_settings_screen.dart';
import 'settings/appearance_settings_screen.dart';
import 'settings/notifications_settings_screen.dart';
import 'settings/about_screen.dart';
import 'settings/storage_sync_screen.dart';

// Subscription
import 'rev_cat/paywall_screen.dart';
import 'rev_cat/trial_ended_screen.dart';

/// Global Navigator Key (optional if needed for navigation without context)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Custom route generator
Route<dynamic> generateRoute(RouteSettings settings) {
  final user = FirebaseAuth.instance.currentUser;

  // Route map
  final routes = <String, WidgetBuilder>{
    '/': (_) => user == null ? const LoginScreen() : const HomeScreen(),
    '/login': (_) => const LoginScreen(),
    '/register': (_) => const RegisterScreen(),
    '/home': (_) => const HomeScreen(),
    '/results': (_) => const ResultsScreen(),

    // Settings
    '/settings': (_) => const SettingsScreen(),
    '/settings/account': (_) => const AccountSettingsScreen(),
    '/settings/account/change-password': (_) => const ChangePasswordScreen(),
    '/settings/appearance': (context) => AppearanceSettingsScreen(
      themeNotifier: Provider.of<ThemeNotifier>(context, listen: false),
      textScaleNotifier: Provider.of<TextScaleNotifier>(context, listen: false),
    ),
    '/settings/notifications': (_) => const NotificationsSettingsScreen(),
    '/settings/storage': (_) => const StorageSyncScreen(),
    '/settings/about': (_) => const AboutSettingsScreen(),
    '/settings/faqs': (_) => FaqsScreen(),

    // Subscription
    '/paywall': (_) => const PaywallScreen(),
    '/trial-ended': (_) => const TrialEndedScreen(),
  };

  final builder = routes[settings.name];
  return MaterialPageRoute(
    builder:
        builder ??
        (_) => const Scaffold(
          body: Center(
            child: Text(
              '404 – Page not found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
        ),
    settings: settings,
  );
}

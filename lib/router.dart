import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Screens
import 'package:recipe_vault/screens/home_screen.dart';
import 'package:recipe_vault/screens/welcome_screen/welcome_screen.dart';
import 'package:recipe_vault/screens/results_screen.dart';
import 'package:recipe_vault/login/login_screen.dart';
import 'package:recipe_vault/login/register_screen.dart';
import 'package:recipe_vault/settings/settings_screen.dart';
import 'package:recipe_vault/settings/acount_settings/account_settings_screen.dart';
import 'package:recipe_vault/settings/acount_settings/change_password.dart';
import 'package:recipe_vault/settings/appearance_settings_screen.dart';
import 'package:recipe_vault/settings/notifications_settings_screen.dart';
import 'package:recipe_vault/settings/subscription_settings_screen.dart';
import 'package:recipe_vault/settings/about_screen.dart';
import 'package:recipe_vault/settings/storage_sync_screen.dart';
import 'package:recipe_vault/revcat_paywall/screens/subscription_success_screen.dart';
import 'package:recipe_vault/revcat_paywall/screens/upgrade_blocked_screen.dart';
import 'package:recipe_vault/revcat_paywall/screens/paywall_screen.dart';

import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/z_main_widgets/auth_change_notifier.dart';
import 'package:recipe_vault/z_main_widgets/launch_gate_screen.dart'; // ✅ New import

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/launch',
    refreshListenable: AuthChangeNotifier(),
    routes: [
      GoRoute(
        path: '/launch',
        builder: (context, state) => const LaunchGateScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/upgrade-success',
        builder: (context, state) => const SubscriptionSuccessScreen(),
      ),
      GoRoute(
        path: '/upgrade-blocked',
        builder: (context, state) => const UpgradeBlockedScreen(),
      ),

      // Settings grouped
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/account/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (context, state) {
          final themeNotifier = Provider.of<ThemeNotifier>(
            context,
            listen: false,
          );
          final textScaleNotifier = Provider.of<TextScaleNotifier>(
            context,
            listen: false,
          );
          return AppearanceSettingsScreen(
            themeNotifier: themeNotifier,
            textScaleNotifier: textScaleNotifier,
          );
        },
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/subscription',
        builder: (context, state) => const SubscriptionSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AboutSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/storage-sync',
        builder: (context, state) => const StorageSyncScreen(),
      ),

      // Fallback route
      GoRoute(
        path: '/error',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text(
              'Something went wrong.\nPlease try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Page not found'))),
  );
}

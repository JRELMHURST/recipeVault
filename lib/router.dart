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
import 'package:recipe_vault/z_main_widgets/launch_gate_screen.dart'; // ✅ New import

GoRouter buildRouter() {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/launch',
    routes: [
      /// 🔐 Auth & Launch
      GoRoute(path: '/launch', builder: (_, __) => const LaunchGateScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      /// 🏡 App Flow
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/results', builder: (_, __) => const ResultsScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),

      /// 💸 Subscription
      GoRoute(path: '/paywall', builder: (_, __) => const PaywallScreen()),
      GoRoute(
        path: '/upgrade-success',
        builder: (_, __) => const SubscriptionSuccessScreen(),
      ),
      GoRoute(
        path: '/upgrade-blocked',
        builder: (_, __) => const UpgradeBlockedScreen(),
      ),

      /// ⚙️ Settings
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/settings/account',
        builder: (_, __) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/account/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (context, _) {
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
        builder: (_, __) => const NotificationsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/subscription',
        builder: (_, __) => const SubscriptionSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (_, __) => const AboutSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/storage-sync',
        builder: (_, __) => const StorageSyncScreen(),
      ),

      /// 🚫 Fallback
      GoRoute(
        path: '/error',
        builder: (_, __) => const Scaffold(
          body: Center(
            child: Text(
              'Something went wrong.\nPlease try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ],
    errorBuilder: (_, __) =>
        const Scaffold(body: Center(child: Text('Page not found'))),
  );
}

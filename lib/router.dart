import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Core services
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';

// Auth
import 'package:recipe_vault/login/login_screen.dart';

// Screens
import 'package:recipe_vault/screens/home_screen.dart';
import 'package:recipe_vault/screens/results_screen.dart';
import 'package:recipe_vault/settings/settings_screen.dart';
import 'package:recipe_vault/settings/acount_settings/account_settings_screen.dart';
import 'package:recipe_vault/settings/acount_settings/change_password.dart';
import 'package:recipe_vault/settings/appearance_settings_screen.dart';
import 'package:recipe_vault/settings/notifications_settings_screen.dart';
import 'package:recipe_vault/settings/subscription_settings_screen.dart';
import 'package:recipe_vault/settings/about_screen.dart';
import 'package:recipe_vault/settings/storage_sync_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/home',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggingIn = state.uri.toString() == '/login';

      // Redirect unauthenticated users to /login
      if (user == null && !isLoggingIn) return '/login';

      // Redirect authenticated users away from /login
      if (user != null && isLoggingIn) return '/home';

      return null; // no redirect
    },
    routes: [
      /// 🔐 Auth
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      /// 🏡 Main App Flow
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/results', builder: (_, __) => const ResultsScreen()),

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

      /// 🚫 Error fallback
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
    errorBuilder: (_, state) {
      debugPrint('❌ Route not found: ${state.uri.toString()}');
      return const Scaffold(body: Center(child: Text('Page not found')));
    },
  );
}

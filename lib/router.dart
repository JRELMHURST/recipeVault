import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/theme.dart';

// Core services
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';

// Auth
import 'package:recipe_vault/login/login_screen.dart';
import 'package:recipe_vault/login/register_screen.dart';

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

// Paywall
import 'package:recipe_vault/rev_cat/paywall_screen.dart';

Map<String, WidgetBuilder> buildRoutes(BuildContext context) {
  final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
  final textScaleNotifier = Provider.of<TextScaleNotifier>(
    context,
    listen: false,
  );

  return {
    '/': (context) {
      final user = FirebaseAuth.instance.currentUser;
      return user == null ? const LoginScreen() : const HomeScreen();
    },
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),
    '/home': (context) => const HomeScreen(),
    '/results': (context) => const ResultsScreen(),

    // Settings
    '/settings': (context) => const SettingsScreen(),
    '/settings/account': (context) => const AccountSettingsScreen(),
    '/settings/account/change-password': (context) =>
        const ChangePasswordScreen(),
    '/settings/appearance': (context) => AppearanceSettingsScreen(
      themeNotifier: themeNotifier,
      textScaleNotifier: textScaleNotifier,
    ),
    '/settings/notifications': (context) => const NotificationsSettingsScreen(),
    '/settings/subscription': (context) => const SubscriptionSettingsScreen(),
    '/settings/about': (context) => const AboutSettingsScreen(),
    '/settings/storage-sync': (context) => const StorageSyncScreen(),

    // Paywall
    '/paywall': (context) => const PaywallScreen(),
  };
}

Route<dynamic> generateRoute(RouteSettings settings) {
  return MaterialPageRoute(
    builder: (context) {
      final routes = buildRoutes(context);
      final builder = routes[settings.name];
      if (builder != null) {
        return builder(context);
      } else {
        debugPrint("❌ Route not found: ${settings.name}");
        return const Scaffold(body: Center(child: Text('Page not found')));
      }
    },
    settings: settings,
  );
}

Widget buildAppWithRouter() {
  return Builder(
    builder: (context) {
      final themeNotifier = Provider.of<ThemeNotifier>(context);
      final textScaleNotifier = Provider.of<TextScaleNotifier>(context);

      return MaterialApp(
        title: 'RecipeVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeNotifier.themeMode,
        initialRoute: '/',
        onGenerateRoute: generateRoute,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScaleNotifier.scaleFactor),
            ),
            child: child!,
          );
        },
      );
    },
  );
}

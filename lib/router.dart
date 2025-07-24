import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Core
import 'core/theme.dart';
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';

// Auth Screens
import 'login/login_screen.dart';
import 'login/register_screen.dart';
import 'login/change_password.dart';

// Main Screens
import 'screens/home_screen/home_screen.dart';
import 'screens/results_screen.dart';
import 'screens/shared/shared_recipe_screen.dart';

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

  // Handle shared recipe deep link
  if (settings.name?.startsWith('/shared/') == true) {
    final recipeId = settings.name!.split('/').last;
    return MaterialPageRoute(
      builder: (_) => SharedRecipeScreen(recipeId: recipeId),
      settings: settings,
    );
  }

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
    '/settings/about': (_) => const AboutSettingsScreen(),
    '/settings/storage': (_) => const StorageSyncScreen(),

    // Subscription
    '/paywall': (_) => const PaywallScreen(),
    '/trial-ended': (_) => const TrialEndedScreen(),

    // Fallback invalid shared link
    '/shared': (_) => const Scaffold(
      body: Center(
        child: Text(
          'Please use a valid shared recipe link.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    ),
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

/// Builds the full app with theme, localisation, and router
Widget buildAppWithRouter() {
  return Builder(
    builder: (context) {
      final themeNotifier = Provider.of<ThemeNotifier>(context);
      final textScaleNotifier = Provider.of<TextScaleNotifier>(context);

      return MaterialApp(
        navigatorKey: navigatorKey,
        title: 'RecipeVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeNotifier.themeMode,
        supportedLocales: const [Locale('en', 'GB')],
        locale: const Locale('en', 'GB'),
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

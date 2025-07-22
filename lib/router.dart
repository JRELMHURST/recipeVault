import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Core
import 'package:recipe_vault/core/theme.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/login/change_password.dart';

// Auth Screens
import 'package:recipe_vault/login/login_screen.dart';
import 'package:recipe_vault/login/register_screen.dart';

// Main Screens
import 'package:recipe_vault/screens/home_screen/home_screen.dart';
import 'package:recipe_vault/screens/home_screen/home_tutorial_overlay.dart';
import 'package:recipe_vault/screens/results_screen.dart';
import 'package:recipe_vault/screens/shared/shared_recipe_screen.dart';

// Settings
import 'package:recipe_vault/settings/settings_screen.dart';
import 'package:recipe_vault/settings/account_settings_screen.dart';
import 'package:recipe_vault/settings/appearance_settings_screen.dart';
import 'package:recipe_vault/settings/notifications_settings_screen.dart';
import 'package:recipe_vault/settings/about_screen.dart';
import 'package:recipe_vault/settings/storage_sync_screen.dart';

// Subscription
import 'package:recipe_vault/rev_cat/paywall_screen.dart';
import 'package:recipe_vault/rev_cat/trial_ended_screen.dart';

class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String results = '/results';
  static const String homeTutorial = '/home-tutorial';

  // Settings
  static const String settings = '/settings';
  static const String accountSettings = '/settings/account';
  static const String changePassword = '/settings/account/change-password';
  static const String appearanceSettings = '/settings/appearance';
  static const String notificationsSettings = '/settings/notifications';
  static const String aboutSettings = '/settings/about';
  static const String storageSync = '/settings/storage';

  // Subscription
  static const String paywall = '/paywall';
  static const String trialEnded = '/trial-ended';
  static const String sharedFallback = '/shared';
}

Map<String, WidgetBuilder> buildRoutes(BuildContext context) {
  final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
  final textScaleNotifier = Provider.of<TextScaleNotifier>(
    context,
    listen: false,
  );

  return {
    AppRoutes.root: (context) {
      final user = FirebaseAuth.instance.currentUser;
      return user == null ? const LoginScreen() : const HomeScreen();
    },
    AppRoutes.login: (context) => const LoginScreen(),
    AppRoutes.register: (context) => const RegisterScreen(),
    AppRoutes.home: (context) => const HomeScreen(),
    AppRoutes.results: (context) => const ResultsScreen(),

    AppRoutes.homeTutorial: (context) => HomeTutorialOverlay(
      targets: [
        GlobalKey(debugLabel: 'scanButtonKey'),
        GlobalKey(debugLabel: 'vaultButtonKey'),
        GlobalKey(debugLabel: 'viewModeToggleKey'),
        GlobalKey(debugLabel: 'profileButtonKey'),
      ],
    ),

    // Settings
    AppRoutes.settings: (context) => const SettingsScreen(),
    AppRoutes.accountSettings: (context) => const AccountSettingsScreen(),
    AppRoutes.changePassword: (context) => const ChangePasswordScreen(),
    AppRoutes.appearanceSettings: (context) => AppearanceSettingsScreen(
      themeNotifier: themeNotifier,
      textScaleNotifier: textScaleNotifier,
    ),
    AppRoutes.notificationsSettings: (context) =>
        const NotificationsSettingsScreen(),
    AppRoutes.aboutSettings: (context) => const AboutSettingsScreen(),
    AppRoutes.storageSync: (context) => const StorageSyncScreen(),

    // Subscription
    AppRoutes.paywall: (context) => const PaywallScreen(),
    AppRoutes.trialEnded: (context) => const TrialEndedScreen(),

    // Fallback
    AppRoutes.sharedFallback: (context) => const Scaffold(
      body: Center(
        child: Text(
          'Please use a valid shared recipe link.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    ),
  };
}

Route<dynamic> generateRoute(RouteSettings settings) {
  if (settings.name != null && settings.name!.startsWith('/shared/')) {
    final recipeId = settings.name!.split('/').last;
    return MaterialPageRoute(
      builder: (context) => SharedRecipeScreen(recipeId: recipeId),
      settings: settings,
    );
  }

  return MaterialPageRoute(
    builder: (context) {
      final routes = buildRoutes(context);
      final builder = routes[settings.name];
      return builder != null
          ? builder(context)
          : const Scaffold(
              body: Center(
                child: Text(
                  '404 – Page not found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            );
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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Core
import 'package:recipe_vault/core/theme.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';

// Auth Screens
import 'package:recipe_vault/login/login_screen.dart';
import 'package:recipe_vault/login/register_screen.dart';
import 'package:recipe_vault/login/change_password.dart';

// Main Screens
import 'package:recipe_vault/screens/home_screen/home_screen.dart';
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

// Controllers
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_controller.dart';
import 'package:recipe_vault/start_up_gate.dart';

Map<String, WidgetBuilder> buildRoutes(BuildContext context) {
  final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
  final textScaleNotifier = Provider.of<TextScaleNotifier>(
    context,
    listen: false,
  );

  return {
    '/': (context) {
      final user = FirebaseAuth.instance.currentUser;
      return user == null
          ? const LoginScreen()
          : StartupGate(
              child: ChangeNotifierProvider(
                create: (_) => RecipeVaultController()..initialise(),
                child: const HomeScreen(),
              ),
            );
    },
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),

    '/home': (context) => ChangeNotifierProvider(
      create: (_) => RecipeVaultController()..initialise(),
      child: const HomeScreen(),
    ),

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
    '/settings/about': (context) => const AboutSettingsScreen(),
    '/settings/storage': (context) => const StorageSyncScreen(),

    // Subscription
    '/paywall': (context) => const PaywallScreen(),
    '/trial-ended': (context) => const TrialEndedScreen(),

    // Invalid shared links
    '/shared': (context) => const Scaffold(
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
  if (settings.name?.startsWith('/shared/') == true) {
    final recipeId = settings.name!.split('/').last;
    return MaterialPageRoute(
      builder: (context) => SharedRecipeScreen(recipeId: recipeId),
      settings: settings,
    );
  }

  final routes = buildRoutes(navigatorKey.currentContext!);
  final builder = routes[settings.name];
  return MaterialPageRoute(
    builder: (context) => builder != null
        ? builder(context)
        : const Scaffold(
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

// Optional: Global navigator key (if needed)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

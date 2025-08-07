import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/edit_recipe_screen.dart';

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
import 'settings/faq_screen.dart';

// Subscription
import 'rev_cat/paywall_screen.dart';
import 'rev_cat/trial_ended_screen.dart';

/// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Route<dynamic> generateRoute(RouteSettings settings) {
  final user = FirebaseAuth.instance.currentUser;

  switch (settings.name) {
    case '/':
      return MaterialPageRoute(
        builder: (_) => user == null ? const LoginScreen() : const HomeScreen(),
        settings: settings,
      );
    case '/login':
      return MaterialPageRoute(
        builder: (_) => const LoginScreen(),
        settings: settings,
      );
    case '/register':
      return MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
        settings: settings,
      );
    case '/home':
      return MaterialPageRoute(
        builder: (_) => const HomeScreen(),
        settings: settings,
      );
    case '/results':
      return MaterialPageRoute(
        builder: (_) => const ResultsScreen(),
        settings: settings,
      );
    case '/edit-recipe':
      final recipe = settings.arguments as RecipeCardModel;
      return MaterialPageRoute(
        builder: (_) => EditRecipeScreen(recipe: recipe),
        settings: settings,
      );

    // Settings
    case '/settings':
      return MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
        settings: settings,
      );
    case '/settings/account':
      return MaterialPageRoute(
        builder: (_) => const AccountSettingsScreen(),
        settings: settings,
      );
    case '/settings/account/change-password':
      return MaterialPageRoute(
        builder: (_) => const ChangePasswordScreen(),
        settings: settings,
      );
    case '/settings/appearance':
      return MaterialPageRoute(
        builder: (context) => AppearanceSettingsScreen(
          themeNotifier: Provider.of<ThemeNotifier>(context, listen: false),
          textScaleNotifier: Provider.of<TextScaleNotifier>(
            context,
            listen: false,
          ),
        ),
        settings: settings,
      );
    case '/settings/notifications':
      return MaterialPageRoute(
        builder: (_) => const NotificationsSettingsScreen(),
        settings: settings,
      );
    case '/settings/storage':
      return MaterialPageRoute(
        builder: (_) => const StorageSyncScreen(),
        settings: settings,
      );
    case '/settings/about':
      return MaterialPageRoute(
        builder: (_) => const AboutSettingsScreen(),
        settings: settings,
      );
    case '/settings/faqs':
      return MaterialPageRoute(
        builder: (_) => FaqsScreen(),
        settings: settings,
      );

    // Subscription
    case '/paywall':
      return MaterialPageRoute(
        builder: (_) => const PaywallScreen(),
        settings: settings,
      );
    case '/trial-ended':
      return MaterialPageRoute(
        builder: (_) => const TrialEndedScreen(),
        settings: settings,
      );

    // Default 404
    default:
      return MaterialPageRoute(
        builder: (_) => const Scaffold(
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
}

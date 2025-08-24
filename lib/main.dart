// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:recipe_vault/app/app_bootstrap.dart';
import 'package:recipe_vault/app/recipe_vault_app.dart';

import 'package:recipe_vault/auth/auth_service.dart';
import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/core/language_provider.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/features/recipe_vault/vault_view_mode_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase first
  await Firebase.initializeApp();

  // 🔒 Initialise App Check (best practice)
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
    webProvider: ReCaptchaV3Provider('YOUR_REAL_RECAPTCHA_V3_SITE_KEY'),
  );

  // Ensure any app-specific bootstrapping is done
  await AppBootstrap.ensureReady();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        // Load saved view mode immediately (prevents UI flash)
        ChangeNotifierProvider(
          create: (_) => VaultViewModeNotifier()..loadFromPrefs(),
        ),
        // Eagerly create & init subs so router/guards have it ready
        ChangeNotifierProvider<SubscriptionService>(
          lazy: false,
          create: (_) => SubscriptionService()..init(),
        ),
        Provider(create: (_) => AuthService()),
      ],
      child: const RecipeVaultApp(),
    ),
  );
}

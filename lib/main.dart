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

// If you’ve run `flutterfire configure`, uncomment the line below
// and use `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`
// import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialise Firebase
  // If using FlutterFire CLI: await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Firebase.initializeApp();

  // 2) App Check: production providers only (no debug tokens)
  // - iOS: App Attest with DeviceCheck fallback (you registered both in Console)
  // - Android: Play Integrity
  // - Web: ReCAPTCHA v3 (site key via --dart-define)
  await FirebaseAppCheck.instance.activate(
    appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
    androidProvider: AndroidProvider.playIntegrity,
    webProvider: kIsWeb
        ? ReCaptchaV3Provider(
            String.fromEnvironment('RECAPTCHA_V3_SITE_KEY', defaultValue: ''),
          )
        : null,
  );

  // 3) App‑level bootstrap (preferences, Hive boxes, warm caches, etc.)
  await AppBootstrap.ensureReady();

  // 4) Run app with eagerly‑initialised services
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(
          create: (_) => VaultViewModeNotifier()..loadFromPrefs(),
        ),
        // Eager: subs service so navigation guards & paywall have it ready
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

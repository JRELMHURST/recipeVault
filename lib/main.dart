// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:recipe_vault/app/app_bootstrap.dart';
import 'package:recipe_vault/app/recipe_vault_app.dart';

import 'package:recipe_vault/auth/auth_service.dart';
import 'package:recipe_vault/billing/subscription/subscription_service.dart';
import 'package:recipe_vault/data/services/usage_service.dart';
import 'package:recipe_vault/core/language_provider.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/features/recipe_vault/vault_view_mode_notifier.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2) App Check
  await FirebaseAppCheck.instance.activate(
    appleProvider: kReleaseMode
        ? AppleProvider.appAttestWithDeviceCheckFallback
        : AppleProvider.debug,
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
    webProvider: kIsWeb
        ? ReCaptchaV3Provider(
            const String.fromEnvironment(
              'RECAPTCHA_V3_SITE_KEY',
              defaultValue: '',
            ),
          )
        : null,
  );

  // 3) App bootstrap (Hive, prefs, etc.)
  await AppBootstrap.ensureReady();

  // 4) Run app with eagerly-initialized services
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(
          create: (_) => VaultViewModeNotifier()..loadFromPrefs(),
        ),

        // Entitlements + limits (RC + FS override)
        ChangeNotifierProvider<SubscriptionService>(
          lazy: false,
          create: (_) => SubscriptionService()..init(),
        ),

        // ✅ Live usage counters (streams Firestore usage docs)
        ChangeNotifierProvider<UsageService>(
          lazy: false,
          create: (_) => UsageService()..init(),
        ),

        Provider(create: (_) => AuthService()),
      ],
      child: const RecipeVaultApp(),
    ),
  );
}

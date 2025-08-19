import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/core/language_provider.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/features/recipe_vault/vault_view_mode_notifier.dart';
import 'package:recipe_vault/auth/auth_service.dart';
import 'package:recipe_vault/billing/subscription_service.dart';

import 'package:recipe_vault/app/recipe_vault_app.dart';
import 'package:recipe_vault/app/app_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.ensureReady();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => VaultViewModeNotifier()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()..init()),
        Provider(create: (_) => AuthService()),
      ],
      child: const RecipeVaultApp(),
    ),
  );
}

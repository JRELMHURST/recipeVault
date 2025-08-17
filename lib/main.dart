import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/language_provider.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';

import 'package:recipe_vault/recipe_vault_app.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

import 'access_controller.dart';
import 'app_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.ensureReady();

  final access = AccessController()..start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
        ChangeNotifierProvider.value(value: access),
      ],
      child: RecipeVaultApp(access: access),
    ),
  );
}

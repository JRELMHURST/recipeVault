import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/app_bootstrap.dart';
import 'package:recipe_vault/recipe_vault_app.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.ensureReady();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
      ],
      child: const RecipeVaultApp(),
    ),
  );
}

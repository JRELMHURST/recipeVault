import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/language_provider.dart';
import 'package:recipe_vault/core/theme.dart';

import 'package:recipe_vault/app/app_router.dart';
import 'package:recipe_vault/billing/subscription_service.dart';

class RecipeVaultApp extends StatefulWidget {
  const RecipeVaultApp({super.key});

  @override
  State<RecipeVaultApp> createState() => _RecipeVaultAppState();
}

class _RecipeVaultAppState extends State<RecipeVaultApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Safe to use context.read in initState for a non-listening lookup.
    // Providers are created in main() before this widget is built.
    final subs = context.read<SubscriptionService>();
    _router = buildAppRouter(subs);
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final scaleFactor = context.watch<TextScaleNotifier>().scaleFactor;
    final langKey = context.watch<LanguageProvider>().selected;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      title: 'RecipeVault',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      // i18n
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _localeFromBcp47(langKey),
      localeResolutionCallback: (device, supported) {
        final chosen = _localeFromBcp47(langKey);
        if (supported.contains(chosen)) return chosen;
        return supported.firstWhere(
          (l) => l.languageCode == chosen.languageCode,
          orElse: () => supported.first,
        );
      },
      // global text scale
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scaleFactor)),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

Locale _localeFromBcp47(String key) {
  final norm = key.replaceAll('_', '-');
  final parts = norm.split('-');
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return Locale(parts[0], parts[1]);
  }
  return Locale(parts[0]);
}

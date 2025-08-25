// lib/app/recipe_vault_app.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← for SystemUiOverlayStyle
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

      // 🌗 Themes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,

      // 🌍 i18n
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

      // 🔤 Global text scale + system bars styling that reacts to theme
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        final wrapped = AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: theme.colorScheme.surface,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );

        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scaleFactor)),
          child: wrapped,
        );
      },
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

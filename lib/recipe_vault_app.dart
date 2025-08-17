import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';

import 'core/text_scale_notifier.dart';
import 'core/theme_notifier.dart';
import 'core/language_provider.dart';
import 'core/theme.dart';

import 'controller/access_controller.dart';
import 'routing/app_router.dart';

class RecipeVaultApp extends StatefulWidget {
  final AccessController access;
  const RecipeVaultApp({super.key, required this.access});

  @override
  State<RecipeVaultApp> createState() => _RecipeVaultAppState();
}

class _RecipeVaultAppState extends State<RecipeVaultApp> {
  late final GoRouter _router = buildAppRouter(widget.access);

  @override
  Widget build(BuildContext context) {
    // If you also provide Theme/TextScale/Language at a higher level, keep using context.watch here.
    final themeNotifier = context.watch<ThemeNotifier>();
    final scaleFactor = context.watch<TextScaleNotifier>().scaleFactor;
    final langKey = context.watch<LanguageProvider>().selected; // e.g. 'en-GB'

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      title: 'RecipeVault',

      // Themes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,

      // i18n
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      // Force chosen locale from LanguageProvider
      locale: _localeFromBcp47(langKey),
      localeResolutionCallback: (device, supported) {
        final chosen = _localeFromBcp47(langKey);
        if (supported.contains(chosen)) return chosen;
        final matchByLang = supported.firstWhere(
          (l) => l.languageCode == chosen.languageCode,
          orElse: () => supported.first,
        );
        return matchByLang;
      },

      // Global text scaling from TextScaleNotifier
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scaleFactor)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Converts BCP-47 like 'en-GB' or 'bg' to a Flutter Locale('en','GB') / Locale('bg')
Locale _localeFromBcp47(String key) {
  final norm = key.replaceAll('_', '-');
  final parts = norm.split('-');
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return Locale(parts[0], parts[1]); // language + region
  }
  return Locale(parts[0]); // language only
}

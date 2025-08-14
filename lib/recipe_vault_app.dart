import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';

import 'core/text_scale_notifier.dart';
import 'core/theme_notifier.dart';
import 'core/language_provider.dart'; // ⬅️ use the language selection
import 'router.dart';
import 'core/theme.dart';

class RecipeVaultApp extends StatelessWidget {
  const RecipeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final scaleFactor = context.watch<TextScaleNotifier>().scaleFactor;
    final langKey = context
        .watch<LanguageProvider>()
        .selected; // e.g. 'en-GB', 'bg', ...

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'RecipeVault',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,

      // ✅ i18n
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      // ✅ Force the app to the user's chosen locale (from LanguageProvider)
      locale: _localeFromBcp47(langKey),

      // (optional) sensible resolver if device locale isn't in supported list
      localeResolutionCallback: (device, supported) {
        final chosen = _localeFromBcp47(langKey);
        // If the chosen locale is supported, use it; otherwise fall back to device/supported[0]
        if (supported.contains(chosen)) return chosen;
        // Try matching only by language code if region variant isn't available
        final matchByLang = supported.firstWhere(
          (l) => l.languageCode == chosen.languageCode,
          orElse: () => supported.first,
        );
        return matchByLang;
      },

      onGenerateRoute: generateRoute,

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scaleFactor)),
          child: child!,
        );
      },
    );
  }
}

/// Converts BCP‑47 like 'en-GB' or 'bg' to a Flutter Locale('en','GB') / Locale('bg')
Locale _localeFromBcp47(String key) {
  // Normalise underscores just in case (we store with hyphens).
  final norm = key.replaceAll('_', '-');
  final parts = norm.split('-');
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return Locale(parts[0], parts[1]); // language + region
  }
  return Locale(parts[0]); // language only
}

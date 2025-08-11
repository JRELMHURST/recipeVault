import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// If/when you add ARB files via gen_l10n, uncomment this import and the delegate below.
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'core/text_scale_notifier.dart';
import 'core/theme_notifier.dart';
import 'router.dart';
import 'core/theme.dart';

/// Keep this list tidy & European-focused for now.
const List<Locale> kSupportedLocales = <Locale>[
  Locale('en', 'GB'),
  Locale('fr', 'FR'),
  Locale('de', 'DE'),
  Locale('es', 'ES'),
  Locale('it', 'IT'),
  Locale('nl', 'NL'),
  Locale('pt', 'PT'),
  Locale('sv', 'SE'),
  Locale('da', 'DK'),
  Locale('nb', 'NO'),
  Locale('fi', 'FI'),
  Locale('pl', 'PL'),
  Locale('cs', 'CZ'),
  Locale('sk', 'SK'),
  Locale('ro', 'RO'),
  Locale('hu', 'HU'),
  Locale('el', 'GR'),
  Locale('tr', 'TR'),
  // Add more as you localize strings (e.g., 'ga', 'bg', 'hr', etc.)
];

class RecipeVaultApp extends StatelessWidget {
  const RecipeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final scaleFactor = context.watch<TextScaleNotifier>().scaleFactor;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'RecipeVault',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,

      // Use system locale; we’ll fall back to en-GB if unsupported.
      supportedLocales: kSupportedLocales,
      // If you want to force en-GB, set `locale: const Locale('en', 'GB')`.
      localeResolutionCallback: (deviceLocale, supported) {
        if (deviceLocale == null) return const Locale('en', 'GB');
        // Match by full locale first, then by language code.
        for (final loc in supported) {
          if (loc.languageCode == deviceLocale.languageCode &&
              (loc.countryCode == null ||
                  loc.countryCode == deviceLocale.countryCode)) {
            return loc;
          }
        }
        for (final loc in supported) {
          if (loc.languageCode == deviceLocale.languageCode) return loc;
        }
        return const Locale('en', 'GB');
      },

      // Platform/localized widgets (Material, Widgets, Cupertino).
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        // When you generate your own strings with gen_l10n, include:
        // AppLocalizations.delegate,
      ],

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

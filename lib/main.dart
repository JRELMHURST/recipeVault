import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controller/access_controller.dart';
import 'routing/app_router.dart';

// i18n + theming + prefs
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'core/theme.dart';
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';
import 'core/language_provider.dart';

// one-stop init for Firebase, RC, Hive, notifications, prefs, etc.
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
        ChangeNotifierProvider.value(value: access), // expose AccessController
      ],
      child: RecipeVaultApp(access: access),
    ),
  );
}

class RecipeVaultApp extends StatefulWidget {
  final AccessController access;
  const RecipeVaultApp({super.key, required this.access});

  @override
  State<RecipeVaultApp> createState() => _RecipeVaultAppState();
}

class _RecipeVaultAppState extends State<RecipeVaultApp> {
  late final router = buildAppRouter(widget.access);

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final scaleFactor = context.watch<TextScaleNotifier>().scaleFactor;
    final langKey = context.watch<LanguageProvider>().selected; // e.g. 'en-GB'

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      title: 'RecipeVault',

      // Themes
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

      // Global text scaling
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

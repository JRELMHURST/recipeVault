import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/router.dart';
import 'package:recipe_vault/core/theme.dart';

class RecipeVaultApp extends StatelessWidget {
  const RecipeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()..loadTheme()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()..loadScale()),
      ],
      child: Builder(
        builder: (context) {
          final themeNotifier = context.watch<ThemeNotifier>();
          final scaleFactor = context.watch<TextScaleNotifier>().scaleFactor;

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            title: 'RecipeVault',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeNotifier.themeMode,
            supportedLocales: const [Locale('en', 'GB')],
            locale: const Locale('en', 'GB'),
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
        },
      ),
    );
  }
}

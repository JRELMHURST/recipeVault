import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/text_scale_notifier.dart';
import 'core/theme_notifier.dart';
import 'router.dart';
import 'core/theme.dart';

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
  }
}

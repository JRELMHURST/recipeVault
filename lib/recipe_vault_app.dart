import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/router.dart';
import 'package:recipe_vault/core/theme.dart';
import 'package:recipe_vault/services/user_session_service.dart';
import 'package:uni_links/uni_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecipeVaultApp extends StatefulWidget {
  const RecipeVaultApp({super.key});

  @override
  State<RecipeVaultApp> createState() => _RecipeVaultAppState();
}

class _RecipeVaultAppState extends State<RecipeVaultApp> {
  @override
  void initState() {
    super.initState();
    _handleInitialDeepLink();
    uriLinkStream.listen((uri) {
      if (uri != null) _processUri(uri);
    });
  }

  Future<void> _handleInitialDeepLink() async {
    final uri = await getInitialUri();
    if (uri != null) _processUri(uri);
  }

  Future<void> _processUri(Uri uri) async {
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shared') {
      final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      if (id == null || id.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();

      if (UserSessionService.isInitialised && UserSessionService.isSignedIn) {
        // ✅ Safely navigate using Future.microtask
        Future.microtask(() {
          navigatorKey.currentState?.pushNamed('/shared/$id');
        });
      } else {
        // ✅ Store it for post-login processing
        await prefs.setString('pendingSharedRecipeId', id);
      }
    }
  }

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

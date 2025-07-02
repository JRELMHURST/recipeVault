import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:recipe_vault/firebase_auth.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';
import 'core/theme.dart';
import 'core/accessibility.dart';

// ✅ Globally accessible Firebase Functions instance
late final FirebaseFunctions functions;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Anonymous sign-in required to satisfy Firebase Storage rules
  await FirebaseAuthService.signInAnonymously();

  // ✅ Set the region for Cloud Functions
  functions = FirebaseFunctions.instanceFor(region: 'europe-west2');

  runApp(const RecipeVaultApp());
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/results',
      builder: (context, state) {
        final ocrText = state.extra as String? ?? 'No recipe found.';
        return ResultsScreen(ocrText: ocrText);
      },
    ),
    GoRoute(
      path: '/processing',
      builder: (context, state) {
        final imageFiles = state.extra as List<File>?;

        if (imageFiles != null && imageFiles.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ProcessingOverlay.show(context, imageFiles);
          });
        } else {
          debugPrint('⚠️ No image files passed to /processing route.');
        }

        return const SizedBox.shrink(); // Dummy widget required by GoRouter
      },
    ),
  ],
);

class RecipeVaultApp extends StatelessWidget {
  const RecipeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(
              Accessibility.constrainedTextScale(context),
            ),
          ),
          child: MaterialApp.router(
            title: 'RecipeVault',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            routerConfig: _router,
          ),
        );
      },
    );
  }
}

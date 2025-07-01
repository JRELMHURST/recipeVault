import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';

void main() {
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
  ],
);

class RecipeVaultApp extends StatelessWidget {
  const RecipeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RecipeVault',
      theme: ThemeData.dark(),
      routerConfig: _router,
    );
  }
}

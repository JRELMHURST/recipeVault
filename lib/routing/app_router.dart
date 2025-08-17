import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

import 'package:recipe_vault/boot/boot_screen.dart';
import 'package:recipe_vault/controller/access_controller.dart';
import 'package:recipe_vault/rev_cat/paywall_screen.dart';

// Vault + results
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/screens/results_screen.dart';
import 'package:recipe_vault/model/processed_recipe_result.dart';
import 'package:recipe_vault/services/user_preference_service.dart';

GoRouter buildAppRouter(AccessController access) {
  return GoRouter(
    initialLocation: '/boot',
    // Re-check redirects whenever access changes
    refreshListenable: access,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // 1) While resolving access → keep on /boot
      if (!access.ready || access.status == EntitlementStatus.checking) {
        return (loc == '/boot') ? null : '/boot';
      }

      // 2) No access → force paywall (except when already on paywall/boot)
      if (!access.hasAccess) {
        if (loc == '/paywall' || loc == '/boot') return null;
        return '/paywall';
      }

      // 3) Access granted → keep out of boot/paywall
      if (loc == '/boot' || loc == '/paywall') {
        return '/vault';
      }

      // 4) No redirect
      return null;
    },
    routes: [
      GoRoute(path: '/boot', builder: (context, state) => const BootScreen()),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/vault',
        builder: (context, state) {
          // Choose a default view; adjust if you expose it via query params later
          return const RecipeVaultScreen(viewMode: ViewMode.grid);
        },
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) =>
            ResultsScreen(initialResult: state.extra as ProcessedRecipeResult?),
      ),
      // Add more routes (settings, details, etc.) as needed
    ],
    // Optional: a simple error page instead of throwing
    errorBuilder: (context, state) => const SizedBox.shrink(),
  );
}

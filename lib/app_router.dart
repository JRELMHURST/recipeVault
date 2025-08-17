// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/boot_screen.dart';
import 'package:recipe_vault/access_controller.dart';
import 'package:recipe_vault/rev_cat/paywall_screen.dart';

// Vault + results
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/screens/results_screen.dart';
import 'package:recipe_vault/model/processed_recipe_result.dart';
import 'package:recipe_vault/services/user_preference_service.dart';

GoRouter buildAppRouter(AccessController access) {
  return GoRouter(
    initialLocation: '/boot',

    // Re-check redirects whenever access changes.
    refreshListenable: access,

    // Centralized access control.
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // 1) While resolving access → keep on /boot.
      if (!access.ready || access.status == EntitlementStatus.checking) {
        return (loc == '/boot') ? null : '/boot';
      }

      // 2) No access → force paywall (except when already on paywall/boot).
      if (!access.hasAccess) {
        if (loc == '/paywall' || loc == '/boot') return null;
        return '/paywall';
      }

      // 3) Access granted → keep out of boot/paywall.
      if (loc == '/boot' || loc == '/paywall') {
        return '/vault';
      }

      // 4) No redirect.
      return null;
    },

    // Routes.
    routes: [
      GoRoute(
        path: '/boot',
        pageBuilder: (context, state) =>
            _fade(const BootScreen(), key: const ValueKey('boot')),
      ),
      GoRoute(
        path: '/paywall',
        pageBuilder: (context, state) =>
            _fade(const PaywallScreen(), key: const ValueKey('paywall')),
      ),
      GoRoute(
        path: '/vault',
        pageBuilder: (context, state) => _fade(
          // Default view; adjust if you expose via query params later.
          const RecipeVaultScreen(viewMode: ViewMode.grid),
          key: const ValueKey('vault'),
        ),
      ),
      GoRoute(
        path: '/results',
        pageBuilder: (context, state) => _fade(
          ResultsScreen(initialResult: state.extra as ProcessedRecipeResult?),
          key: const ValueKey('results'),
        ),
      ),
      // Add more routes (settings, details, etc.) as needed.
    ],

    // Friendly error page instead of a blank screen.
    errorBuilder: (context, state) => _RouterErrorPage(error: state.error),
  );
}

/// Small helper to keep transitions consistent across routes.
CustomTransitionPage _fade(Widget child, {LocalKey? key}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Gentle fade; feels native on both platforms.
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// A simple, user-friendly error page. Shown for unknown routes and router errors.
class _RouterErrorPage extends StatelessWidget {
  final Object? error;
  const _RouterErrorPage({this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = (error?.toString().isNotEmpty ?? false)
        ? error.toString()
        : 'Unknown route or navigation error.';

    return Scaffold(
      appBar: AppBar(title: const Text('Oops')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 56,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Something went wrong',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/vault'),
                  child: const Text('Go to Vault'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

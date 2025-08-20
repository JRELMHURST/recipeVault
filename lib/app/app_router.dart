// lib/app/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';

import 'package:recipe_vault/navigation/nav_keys.dart';
import 'package:recipe_vault/navigation/routes.dart';
import 'package:recipe_vault/navigation/transition_pages.dart';
import 'package:recipe_vault/navigation/nav_shell.dart';
import 'package:recipe_vault/navigation/nav_utils.dart';

import 'package:recipe_vault/app/boot_screen.dart';
import 'package:recipe_vault/billing/paywall_screen.dart';
import 'package:recipe_vault/auth/login_screen.dart';
import 'package:recipe_vault/auth/register_screen.dart';

import 'package:recipe_vault/features/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/features/results/results_screen.dart';
import 'package:recipe_vault/data/models/processed_recipe_result.dart';

// Settings
import 'package:recipe_vault/features/settings/settings_screen.dart';
import 'package:recipe_vault/features/settings/account_settings_screen.dart';
import 'package:recipe_vault/auth/change_password.dart';
import 'package:recipe_vault/features/settings/appearance_settings_screen.dart';
import 'package:recipe_vault/features/settings/notifications_settings_screen.dart';
import 'package:recipe_vault/features/settings/storage_sync_screen.dart';
import 'package:recipe_vault/features/settings/faq_screen.dart';
import 'package:recipe_vault/features/settings/about_screen.dart';

// Subscriptions
import 'package:recipe_vault/billing/subscription_service.dart';

GoRouter buildAppRouter(SubscriptionService subs) {
  // Make GoRouter re-evaluate redirects on auth changes.
  final authTick = ValueNotifier(0);
  FirebaseAuth.instance.authStateChanges().listen((_) {
    authTick.value++;
  });

  return GoRouter(
    navigatorKey: NavKeys.root,
    initialLocation: AppRoutes.boot,

    // Refresh on subscription changes (ChangeNotifier) and auth changes.
    refreshListenable: Listenable.merge([subs, authTick]),

    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loc = state.matchedLocation;
      final isManaging = state.uri.queryParameters['manage'] == '1';

      // 1) While subs resolving → keep on /boot (except explicit manage paywall)
      final isResolving = subs.status == EntitlementStatus.checking;
      if (isResolving) {
        if (loc == AppRoutes.paywall && isManaging) return null;
        return loc == AppRoutes.boot ? null : AppRoutes.boot;
      }

      // 2) Not logged in → allow only /login and /register
      if (user == null) {
        if (loc == AppRoutes.login || loc == AppRoutes.register) return null;
        return AppRoutes.login;
      }

      // 3) Logged in with access → keep out of boot/paywall/auth
      if (subs.hasAccess) {
        if (loc == AppRoutes.boot ||
            loc == AppRoutes.paywall ||
            loc == AppRoutes.login ||
            loc == AppRoutes.register) {
          return AppRoutes.vault;
        }
        return null;
      }

      // 4) Logged in without access (paid‑only app) → always show paywall
      if (loc == AppRoutes.paywall) return null; // including ?manage=1
      return AppRoutes.paywall;
    },

    routes: [
      // ----- Root-level pages -----
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.boot,
        pageBuilder: (context, state) =>
            fadePage(const BootScreen(), key: const ValueKey('boot')),
      ),
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.paywall,
        pageBuilder: (context, state) {
          final isManaging = state.uri.queryParameters['manage'] == '1';
          const key = ValueKey('paywall');
          return isManaging
              ? slideFromLeftPage(const PaywallScreen(), key: key)
              : slideFromRightPage(const PaywallScreen(), key: key);
        },
      ),
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            fadePage(const LoginScreen(), key: const ValueKey('login')),
      ),
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            fadePage(const RegisterScreen(), key: const ValueKey('register')),
      ),

      // ----- Shell with top/bottom nav -----
      ShellRoute(
        navigatorKey: NavKeys.shell,
        builder: (context, state, child) => NavShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.vault,
            pageBuilder: (context, state) => fadePage(
              const RecipeVaultScreen(),
              key: const ValueKey('vault'),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => fadePage(
              const SettingsScreen(),
              key: const ValueKey('settings'),
            ),
          ),
        ],
      ),

      // ----- Settings detail pages (root) -----
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.settingsAccount,
        pageBuilder: (context, state) => fadePage(
          const AccountSettingsScreen(),
          key: const ValueKey('settings-account'),
        ),
        routes: [
          GoRoute(
            path: 'change-password', // AppRoutes.settingsChangePassword
            pageBuilder: (context, state) => fadePage(
              const ChangePasswordScreen(),
              key: const ValueKey('settings-change-password'),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.settingsAppearance,
        pageBuilder: (context, state) => fadePage(
          AppearanceSettingsScreen(
            themeNotifier: context.read<ThemeNotifier>(),
            textScaleNotifier: context.read<TextScaleNotifier>(),
          ),
          key: const ValueKey('settings-appearance'),
        ),
      ),
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.settingsNotifications,
        pageBuilder: (context, state) => fadePage(
          const NotificationsSettingsScreen(),
          key: const ValueKey('settings-notifications'),
        ),
      ),
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.settingsStorage,
        pageBuilder: (context, state) => fadePage(
          const StorageSyncScreen(),
          key: const ValueKey('settings-storage'),
        ),
      ),
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.settingsFaqs,
        pageBuilder: (context, state) =>
            fadePage(FaqsScreen(), key: const ValueKey('settings-faqs')),
      ),
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.settingsAbout,
        pageBuilder: (context, state) => fadePage(
          const AboutSettingsScreen(),
          key: const ValueKey('settings-about'),
        ),
      ),

      // ----- Full-screen outside shell -----
      GoRoute(
        parentNavigatorKey: NavKeys.root,
        path: AppRoutes.results,
        pageBuilder: (context, state) => fadePage(
          ResultsScreen(initialResult: state.extra as ProcessedRecipeResult?),
          key: const ValueKey('results'),
        ),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Oops')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Something went wrong',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Unknown route or navigation error.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => safeGo(context, AppRoutes.vault),
                  child: const Text('Go to Vault'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

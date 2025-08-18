import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/access_controller.dart';
import 'package:recipe_vault/boot_screen.dart';
import 'package:recipe_vault/rev_cat/paywall_screen.dart';
import 'package:recipe_vault/model/processed_recipe_result.dart';
import 'package:recipe_vault/screens/results_screen.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';

// Settings root + subpages
import 'package:recipe_vault/settings/settings_screen.dart';
import 'package:recipe_vault/settings/account_settings_screen.dart';
import 'package:recipe_vault/login/change_password.dart';
import 'package:recipe_vault/settings/appearance_settings_screen.dart';
import 'package:recipe_vault/settings/notifications_settings_screen.dart';
import 'package:recipe_vault/settings/storage_sync_screen.dart';
import 'package:recipe_vault/settings/faq_screen.dart';
import 'package:recipe_vault/settings/about_screen.dart';

// ✅ Add your login screen import
import 'package:recipe_vault/login/login_screen.dart';
import 'package:recipe_vault/login/register_screen.dart';

// Notifiers required by appearance settings
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';

// Navigation helpers
import 'navigation/routes.dart';
import 'navigation/redirects.dart';
import 'navigation/transition_pages.dart';
import 'navigation/nav_shell.dart';

GoRouter buildAppRouter(AccessController access) {
  return GoRouter(
    initialLocation: AppRoutes.boot,
    refreshListenable: access,
    redirect: (context, state) => appRedirect(context, state, access),

    routes: [
      GoRoute(
        path: AppRoutes.boot,
        pageBuilder: (context, state) =>
            fadePage(const BootScreen(), key: const ValueKey('boot')),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        pageBuilder: (context, state) =>
            fadePage(const PaywallScreen(), key: const ValueKey('paywall')),
      ),

      // ✅ Login route
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            fadePage(const LoginScreen(), key: const ValueKey('login')),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            fadePage(const RegisterScreen(), key: const ValueKey('register')),
      ),

      // ----- SHELL with AppBar + Bottom nav -----
      ShellRoute(
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

      // ----- Settings detail pages OUTSIDE the ShellRoute -----
      GoRoute(
        path: AppRoutes.settingsAccount,
        pageBuilder: (context, state) => fadePage(
          const AccountSettingsScreen(),
          key: const ValueKey('settings-account'),
        ),
        routes: [
          GoRoute(
            path: 'change-password',
            pageBuilder: (context, state) => fadePage(
              const ChangePasswordScreen(),
              key: const ValueKey('settings-change-password'),
            ),
          ),
        ],
      ),
      GoRoute(
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
        path: AppRoutes.settingsNotifications,
        pageBuilder: (context, state) => fadePage(
          const NotificationsSettingsScreen(),
          key: const ValueKey('settings-notifications'),
        ),
      ),
      GoRoute(
        path: AppRoutes.settingsStorage,
        pageBuilder: (context, state) => fadePage(
          const StorageSyncScreen(),
          key: const ValueKey('settings-storage'),
        ),
      ),
      GoRoute(
        path: AppRoutes.settingsFaqs,
        pageBuilder: (context, state) =>
            fadePage(FaqsScreen(), key: const ValueKey('settings-faqs')),
      ),
      GoRoute(
        path: AppRoutes.settingsAbout,
        pageBuilder: (context, state) => fadePage(
          const AboutSettingsScreen(),
          key: const ValueKey('settings-about'),
        ),
      ),

      // Full-screen route outside shell
      GoRoute(
        path: AppRoutes.results,
        pageBuilder: (context, state) => fadePage(
          ResultsScreen(initialResult: state.extra as ProcessedRecipeResult?),
          key: const ValueKey('results'),
        ),
      ),
    ],

    errorBuilder: (context, state) => const _RouterErrorPage(),
  );
}

/// Simple friendly error page
class _RouterErrorPage extends StatelessWidget {
  const _RouterErrorPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  onPressed: () => context.go(AppRoutes.vault),
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

// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/services/user_session_service.dart';
import 'package:hive/hive.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';

// Providers
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/language_provider.dart';
import 'package:recipe_vault/billing/subscription_service.dart';

// 🚦 routes + safe nav helpers
import 'package:recipe_vault/app/routes.dart';
import 'package:recipe_vault/navigation/nav_utils.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return Scaffold(body: Center(child: Text(t.noUserSignedIn)));
    }

    final langProvider = context.watch<LanguageProvider>();
    final currentLangKey = langProvider.selected;
    final currentLangLabel =
        LanguageProvider.displayNames[currentLangKey] ?? currentLangKey;

    // 🔎 Plan label (no emojis; free/none → app title)
    final tier = context.watch<SubscriptionService>().tier;
    final planLabel = switch (tier) {
      'home_chef' => t.planHomeChef,
      'master_chef' => t.planMasterChef,
      _ => t.appTitle,
    };

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        elevation: 0,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: theme.brightness == Brightness.dark
              ? Brightness.dark
              : Brightness.light,
          statusBarIconBrightness: theme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(.96),
                theme.colorScheme.primary.withOpacity(.80),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.accountSettingsTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: .6,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    blurRadius: 2,
                    offset: Offset(0, 1),
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
            if (planLabel.isNotEmpty && planLabel != t.appTitle)
              Text(
                planLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SizedBox(height: 24),

              // ===== Security Section =====
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        t.securitySectionTitle.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.lock_outline),
                            title: Text(t.changePasswordTitle),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                            onTap: () =>
                                context.push(AppRoutes.settingsChangePassword),
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout),
                            title: Text(t.signOut),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                            onTap: () => _confirmSignOut(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete_forever),
                            title: Text(t.deleteAccount),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                            textColor: theme.colorScheme.error,
                            iconColor: theme.colorScheme.error,
                            onTap: () => _confirmDeleteAccount(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ===== Language Section =====
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        'LANGUAGE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.language),
                        title: const Text('Recipe language'),
                        subtitle: Text(currentLangLabel),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () => _showLanguagePicker(context, langProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Dialogs & actions =====

  Future<void> _confirmSignOut(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.signOutQuestion),
        content: Text(t.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.signOut),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await LoadingOverlay.show(context);
    try {
      await UserSessionService.signOut(); // 👈 single orchestrator
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.signOutFailed('$e'))));
      }
      LoadingOverlay.hide();
      return;
    } finally {
      LoadingOverlay.hide();
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.signedOut)));

    // Router guard will keep us on /login during teardown; pushing is fine too.
    safeGo(context, AppRoutes.login);
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.deleteAccountQuestion),
        content: Text(t.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.deleteAccount),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await LoadingOverlay.show(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user');

      // Call backend to delete account & server-side resources
      await FirebaseFunctions.instanceFor(
        region: 'europe-west2',
      ).httpsCallable('deleteAccount').call();

      // Local purge and subscription reset
      await UserSessionService.signOut();
      await context.read<SubscriptionService>().reset();

      // Firebase sign-out
      await UserSessionService.signOut();

      // ✅ Wait for auth to be null so router guards don't bounce
      await FirebaseAuth.instance.authStateChanges().firstWhere(
        (u) => u == null,
      );

      // Optional extra local cleanup (example: recipe box)
      final uid = user.uid;
      final boxName = 'recipes_$uid';
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box<RecipeCardModel>(boxName);
        await box.clear();
        await box.close();
      } else if (await Hive.boxExists(boxName)) {
        await Hive.deleteBoxFromDisk(boxName);
      }
    } on FirebaseFunctionsException catch (e) {
      final msg = e.code == 'permission-denied'
          ? t.deleteAccountFailed('Permission denied')
          : t.deleteAccountFailed(e.message ?? e.code);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      LoadingOverlay.hide();
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'For security, please sign in again, then retry account deletion.',
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.deleteAccountFailed(e.code))),
          );
        }
      }
      LoadingOverlay.hide();
      return;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.deleteAccountFailed('$e'))));
      }
      LoadingOverlay.hide();
      return;
    } finally {
      LoadingOverlay.hide();
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.deleteAccountSuccess)));

    // Let router redirects handle it or go directly:
    safeGo(context, AppRoutes.login);
  }

  // ===== Language picker bottom sheet =====
  void _showLanguagePicker(BuildContext context, LanguageProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final current = provider.selected;

        final items = LanguageProvider.supported.toList()
          ..sort((a, b) {
            final la = LanguageProvider.displayNames[a] ?? a;
            final lb = LanguageProvider.displayNames[b] ?? b;
            return la.toLowerCase().compareTo(lb.toLowerCase());
          });

        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final key = items[i];
              final label = LanguageProvider.displayNames[key] ?? key;
              final selected = key == current;

              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(label),
                onTap: () async {
                  await provider.setSelected(key);
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Recipe language set to $label')),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

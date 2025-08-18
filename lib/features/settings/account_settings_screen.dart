// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:recipe_vault/billing/subscription_service.dart'; // 👈 plan source

// 🚦 routes + safe nav helpers
import 'package:recipe_vault/navigation/routes.dart';
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

    final displayName = user.displayName ?? t.noName;

    final langProvider = context.watch<LanguageProvider>();
    final currentLangKey = langProvider.selected;
    final currentLangLabel =
        LanguageProvider.displayNames[currentLangKey] ?? currentLangKey;

    // 🔎 Plan label (no emojis; free/none → app title)
    final tier = context.watch<SubscriptionService>().tier;
    final planLabel = switch (tier) {
      'home_chef' => t.planHomeChef,
      'master_chef' => t.planMasterChef,
      _ => t.appTitle, // Free/none shows app name
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.accountSettingsTitle), centerTitle: true),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // ===== Header: pill with Name + subtle plan (centered) =====
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.85),
                        theme.colorScheme.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        planLabel,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

    if (confirm == true) {
      await LoadingOverlay.show(context);
      try {
        await UserSessionService.logoutReset();
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.signOutFailed('$e'))));
        }
        return;
      } finally {
        LoadingOverlay.hide();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.signedOut)));
        safeGo(context, AppRoutes.login);
      }
    }
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

    if (confirm == true) {
      await LoadingOverlay.show(context);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('No user');

        await FirebaseFunctions.instanceFor(
          region: 'europe-west2',
        ).httpsCallable('deleteAccount').call();

        await UserSessionService.logoutReset();
        await FirebaseAuth.instance.signOut();

        final uid = user.uid;
        final boxName = 'recipes_$uid';
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box<RecipeCardModel>(boxName);
          await box.clear();
          await box.close();
        } else if (await Hive.boxExists(boxName)) {
          await Hive.deleteBoxFromDisk(boxName);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.deleteAccountFailed('$e'))));
        }
        return;
      } finally {
        LoadingOverlay.hide();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.deleteAccountSuccess)));
        safeGo(context, AppRoutes.login);
      }
    }
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

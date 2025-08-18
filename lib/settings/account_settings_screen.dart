// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/services/user_session_service.dart';
import 'package:hive/hive.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

// 👇 Add these
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/language_provider.dart';

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

    final email = user.email ?? '';
    final displayName = user.displayName ?? t.noName;

    final langProvider = context.watch<LanguageProvider>();
    final currentLangKey = langProvider.selected;
    final currentLangLabel =
        LanguageProvider.displayNames[currentLangKey] ?? currentLangKey;

    return Scaffold(
      appBar: AppBar(title: Text(t.accountSettingsTitle), centerTitle: true),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 32, bottom: 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(36),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
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
                            onTap: () => context.push(
                              '/settings/account/change-password',
                            ),
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
      // Loading overlay (attached to screen context; pop with same)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await UserSessionService.logoutReset();
        await FirebaseAuth.instance.signOut();

        if (context.mounted) {
          Navigator.of(context).pop(); // dismiss loading
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.signedOut)));
          context.go('/login');
        }
      } catch (e) {
        Navigator.of(context).pop(); // dismiss loading
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.signOutFailed('$e'))));
        }
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
      // Loading overlay (attached to screen context; pop with same)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

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

        if (context.mounted) {
          Navigator.of(context).pop(); // dismiss loading
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.deleteAccountSuccess)));
          context.go('/login');
        }
      } catch (e) {
        Navigator.of(context).pop(); // dismiss loading
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.deleteAccountFailed('$e'))));
        }
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

        // 🔧 Convert the Set to a sorted List for stable UI & index access
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
                  Navigator.of(sheetContext).pop(); // ✅ close just the sheet
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

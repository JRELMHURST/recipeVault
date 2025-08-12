// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/services/user_session_service.dart';
import 'package:hive/hive.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

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
                            onTap: () => Navigator.pushNamed(
                              context,
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.signOutQuestion),
        content: Text(t.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.signOut),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await UserSessionService.logoutReset();
        await FirebaseAuth.instance.signOut();

        if (context.mounted) {
          Navigator.pop(context); // dismiss loading
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.signedOut)));
          Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
        }
      } catch (e) {
        Navigator.pop(context);
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
      builder: (_) => AlertDialog(
        title: Text(t.deleteAccountQuestion),
        content: Text(t.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.deleteAccount),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.deleteAccountSuccess)));
          Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
        }
      } catch (e) {
        Navigator.pop(context);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.deleteAccountFailed('$e'))));
        }
      }
    }
  }
}

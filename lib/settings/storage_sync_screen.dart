// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';

class StorageSyncScreen extends StatefulWidget {
  const StorageSyncScreen({super.key});

  @override
  State<StorageSyncScreen> createState() => _StorageSyncScreenState();
}

class _StorageSyncScreenState extends State<StorageSyncScreen> {
  late String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  }

  Future<Box> getSafeBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name); // already opened, assume correct type
    }
    return await Hive.openBox<dynamic>(name);
  }

  Future<void> _clearCache() async {
    final t = AppLocalizations.of(context);
    final confirm = await _showClearCacheDialog(context);
    if (confirm == true) {
      final recipeBox = await HiveRecipeService.getBox();
      final categoryBox = await getSafeBox('customCategories_$_uid');
      final prefsBox = await getSafeBox('userPrefs_$_uid');

      // Use strict open logic for String-only box
      final hiddenBox = Hive.isBoxOpen('hiddenDefaultCategories_$_uid')
          ? Hive.box<String>('hiddenDefaultCategories_$_uid')
          : await Hive.openBox<String>('hiddenDefaultCategories_$_uid');

      await recipeBox.clear();
      await categoryBox.clear();
      await hiddenBox.clear();
      await prefsBox.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.localCacheCleared)));
      }
    }
  }

  Future<bool?> _showClearCacheDialog(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                t.clearCacheDialogTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.clearCacheDialogBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(t.cancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(t.clearNow),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.localStorageTitle)),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.storage_rounded,
              size: 60,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              t.clearLocalCacheTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              t.clearLocalCacheDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(t.clearLocalCacheButton),
              onPressed: _clearCache,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/services/hive_recipe_service.dart';
import 'package:recipe_vault/billing/subscription/subscription_service.dart';

class StorageSyncScreen extends StatefulWidget {
  const StorageSyncScreen({super.key});

  @override
  State<StorageSyncScreen> createState() => _StorageSyncScreenState();
}

class _StorageSyncScreenState extends State<StorageSyncScreen> {
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  }

  Future<Box<dynamic>> _openAnyBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return Hive.openBox<dynamic>(name);
  }

  Future<Box<String>> _openStringBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<String>(name);
    return Hive.openBox<String>(name);
  }

  Future<void> _clearCache() async {
    final t = AppLocalizations.of(context);

    final confirm = await _showClearCacheDialog(context);
    if (confirm != true) return;

    try {
      await HiveRecipeService.init();
      final recipeBox = await HiveRecipeService.getBox();

      final categoriesBox = await _openAnyBox('customCategories_$_uid');
      final hiddenDefaultsBox = await _openStringBox(
        'hiddenDefaultCategories_$_uid',
      );
      final prefsBox = await _openAnyBox('userPrefs_$_uid');

      await Future.wait([
        recipeBox.clear(),
        categoriesBox.clear(),
        hiddenDefaultsBox.clear(),
        prefsBox.clear(),
      ]);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.localCacheCleared)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
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
                textAlign: TextAlign.center,
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

    // 🔎 Plan label (consistent with other settings screens)
    final tier = context.watch<SubscriptionService>().tier;
    final planLabel = switch (tier) {
      'home_chef' => t.planHomeChef,
      'master_chef' => t.planMasterChef,
      _ => '',
    };

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        elevation: 0,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: true,
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
              t.localStorageTitle,
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
            if (planLabel.isNotEmpty)
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

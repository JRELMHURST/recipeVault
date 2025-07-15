// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/model/category_model.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

class StorageSyncScreen extends StatefulWidget {
  const StorageSyncScreen({super.key});

  @override
  State<StorageSyncScreen> createState() => _StorageSyncScreenState();
}

class _StorageSyncScreenState extends State<StorageSyncScreen> {
  int localRecipeCount = 0;
  int localCategoryCount = 0;
  String lastSyncTime = 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<Box<T>> getSafeBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return await Hive.openBox<T>(name);
  }

  Future<void> _loadStats() async {
    final recipeBox = await getSafeBox<RecipeCardModel>('recipes');
    final categoryBox = await getSafeBox<CategoryModel>('categories');

    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('lastSync') ?? 'Never';

    setState(() {
      localRecipeCount = recipeBox.length;
      localCategoryCount = categoryBox.length;
      lastSyncTime = lastSync;
    });
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove all locally stored recipes and categories. Your cloud data will remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final recipeBox = await getSafeBox<RecipeCardModel>('recipes');
      final categoryBox = await getSafeBox<CategoryModel>('categories');

      await recipeBox.clear();
      await categoryBox.clear();

      setState(() {
        localRecipeCount = 0;
        localCategoryCount = 0;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Local cache cleared')));
    }
  }

  Future<void> _syncNow() async {
    try {
      await CategoryService.syncFromFirestore();

      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();
      await prefs.setString('lastSync', timestamp);

      await _loadStats();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Sync complete')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Sync failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Sync')),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Sync Status',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.cloud_done_outlined),
              title: const Text('Last Sync'),
              subtitle: Text(lastSyncTime),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Cached Recipes'),
              subtitle: Text('$localRecipeCount locally stored'),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Cached Categories'),
              subtitle: Text('$localCategoryCount locally stored'),
            ),
            const Divider(height: 32),
            Text(
              'Actions',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _syncNow,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Local Cache'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

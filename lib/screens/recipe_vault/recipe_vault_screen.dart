import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_compact_view.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_category_filter_bar.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_list_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_grid_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_dialog.dart';
import 'package:recipe_vault/screens/recipe_vault/category_speed_dial.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/rev_cat/upgrade_banner.dart';

enum ViewMode { list, grid, compact }

class RecipeVaultScreen extends StatefulWidget {
  final int viewMode;
  const RecipeVaultScreen({super.key, required this.viewMode});

  @override
  State<RecipeVaultScreen> createState() => _RecipeVaultScreenState();
}

class _RecipeVaultScreenState extends State<RecipeVaultScreen> {
  String? userId;
  late final CollectionReference<Map<String, dynamic>> recipeCollection;
  String _selectedCategory = 'All';

  static const List<String> _defaultCategories = [
    'Favourites',
    'Translated',
    'Breakfast',
    'Main',
    'Dessert',
  ];

  List<String> _allCategories = ['All', 'Favourites', 'Translated'];
  List<RecipeCardModel> _allRecipes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      userId = user?.uid;

      recipeCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recipes');

      await _initializeDefaultCategories();
      await _loadCustomCategories();
      await _loadRecipes();
    });
  }

  Future<void> _initializeDefaultCategories() async {
    final savedCategories = await CategoryService.getAllCategories();
    for (final defaultCat in _defaultCategories) {
      if (!savedCategories.contains(defaultCat)) {
        await CategoryService.saveCategory(defaultCat);
      }
    }
  }

  Future<void> _loadCustomCategories() async {
    final saved = await CategoryService.getAllCategories();
    if (!mounted) return;
    setState(() {
      _allCategories = [
        'All',
        ..._defaultCategories,
        ...saved.where((c) => !_defaultCategories.contains(c)),
      ];
    });
  }

  Future<void> _loadRecipes() async {
    try {
      // User-authenticated Firestore access
      final snapshot = await recipeCollection
          .orderBy('createdAt', descending: true)
          .get();

      final userRecipes = snapshot.docs
          .map((doc) => RecipeCardModel.fromJson(doc.data()))
          .toList();

      // Global public recipes
      final globalSnapshot = await FirebaseFirestore.instance
          .collection('global_recipes')
          .orderBy('createdAt', descending: true)
          .get();

      final globalRecipes = globalSnapshot.docs
          .map((doc) => RecipeCardModel.fromJson(doc.data()))
          .toList();

      // Merge with priority to user recipes
      final Map<String, RecipeCardModel> recipeMap = {};

      for (final recipe in globalRecipes) {
        recipeMap[recipe.id] = recipe;
      }

      for (final recipe in userRecipes) {
        recipeMap[recipe.id] = recipe; // override if also in global
      }

      // Cache in Hive and update state
      for (final recipe in recipeMap.values) {
        await HiveRecipeService.save(recipe);
      }

      if (!mounted) return;
      setState(() {
        _allRecipes = recipeMap.values.toList();
      });
    } catch (e) {
      debugPrint("⚠️ Firestore fetch failed, loading from Hive: $e");
      final fallback = HiveRecipeService.getAll();
      if (!mounted) return;
      setState(() {
        _allRecipes = fallback;
      });
    }
  }

  Future<void> _deleteRecipe(RecipeCardModel recipe) async {
    try {
      await recipeCollection.doc(recipe.id).delete();
      await HiveRecipeService.delete(recipe.id);

      if (recipe.imageUrl?.isNotEmpty ?? false) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(recipe.imageUrl!);
          await ref.delete();
        } catch (e) {
          debugPrint('❌ Failed to delete attached image: $e');
        }
      }

      for (final url in recipe.originalImageUrls) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (e) {
          debugPrint('❌ Failed to delete original image: $e');
        }
      }

      setState(() {
        _allRecipes.removeWhere((r) => r.id == recipe.id);
      });
    } catch (e) {
      debugPrint("❌ Error during recipe deletion: $e");
    }
  }

  void _toggleFavourite(RecipeCardModel recipe) async {
    final newFavourite = !recipe.isFavourite;
    final updated = recipe.copyWith(
      isFavourite: newFavourite,
      categories: recipe.categories,
    );

    try {
      await recipeCollection.doc(recipe.id).update({
        'isFavourite': newFavourite,
      });
      await HiveRecipeService.save(updated);

      setState(() {
        final index = _allRecipes.indexWhere((r) => r.id == recipe.id);
        if (index != -1) {
          _allRecipes[index] = updated;
        }
      });
    } catch (e) {
      debugPrint('Error toggling favourite: $e');
    }
  }

  void _assignCategories(
    RecipeCardModel recipe,
    List<String> selectedCategories,
  ) async {
    final updated = recipe.copyWith(
      categories: selectedCategories.toSet().toList(),
    );
    await recipeCollection.doc(recipe.id).update({
      'categories': selectedCategories,
    });
    await HiveRecipeService.save(updated);

    setState(() {
      final index = _allRecipes.indexWhere((r) => r.id == recipe.id);
      if (index != -1) {
        _allRecipes[index] = updated;
      }
    });
  }

  void _removeCategory(String category) async {
    if (_defaultCategories.contains(category) || category == 'All') return;

    await CategoryService.deleteCategory(category);
    await _loadCustomCategories();
    if (_selectedCategory == category) {
      setState(() {
        _selectedCategory = 'All';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = switch (_selectedCategory) {
      'All' => _allRecipes,
      'Favourites' => _allRecipes.where((r) => r.isFavourite).toList(),
      'Translated' => _allRecipes.where((r) => r.translationUsed).toList(),
      _ =>
        _allRecipes
            .where((r) => r.categories.contains(_selectedCategory))
            .toList(),
    };

    final ViewMode currentView = ViewMode.values[widget.viewMode];
    final textScaleFactor = Provider.of<TextScaleNotifier>(context).scaleFactor;

    return Scaffold(
      body: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
        child: Column(
          children: [
            RecipeCategoryFilterBar(
              categories: _allCategories,
              selectedCategory: _selectedCategory,
              onCategorySelected: (cat) =>
                  setState(() => _selectedCategory = cat),
              onCategoryDeleted: _removeCategory,
            ),
            ValueListenableBuilder<String?>(
              valueListenable: ImageProcessingService.upgradeBannerMessage,
              builder: (context, message, _) {
                if (message == null) return const SizedBox.shrink();
                return UpgradeBanner(message: message);
              },
            ),
            Expanded(
              child: filteredRecipes.isEmpty
                  ? const Center(child: Text("No recipes found"))
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: ResponsiveWrapper(
                        child: switch (currentView) {
                          ViewMode.list => RecipeListView(
                            recipes: filteredRecipes,
                            onDelete: _deleteRecipe,
                            onTap: (r) => showRecipeDialog(context, r),
                            onToggleFavourite: _toggleFavourite,
                            categories: _allCategories,
                            onAssignCategories: _assignCategories,
                          ),
                          ViewMode.grid => RecipeGridView(
                            recipes: filteredRecipes,
                            onTap: (r) => showRecipeDialog(context, r),
                            onToggleFavourite: _toggleFavourite,
                            categories: _allCategories,
                            onAssignCategories: _assignCategories,
                          ),
                          ViewMode.compact => RecipeCompactView(
                            recipes: filteredRecipes,
                            onTap: (r) => showRecipeDialog(context, r),
                            onToggleFavourite: _toggleFavourite,
                            onAssignCategories: _assignCategories,
                            categories: _allCategories,
                          ),
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final subService = Provider.of<SubscriptionService>(context);
          final currentCategoryCount = _allCategories
              .where((c) => !_defaultCategories.contains(c) && c != 'All')
              .length;

          final canCreateCategory =
              subService.allowCategoryCreation ||
              (subService.isHomeChef && currentCategoryCount < 3);

          return CategorySpeedDial(
            onCategoryChanged: _loadCustomCategories,
            allowCreation: canCreateCategory,
          );
        },
      ),
    );
  }
}

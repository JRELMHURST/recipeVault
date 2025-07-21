// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/rev_cat/trial_prompt_helper.dart';
import 'package:recipe_vault/rev_cat/upgrade_banner.dart';
import 'package:recipe_vault/screens/recipe_vault/category_speed_dial.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_category_filter_bar.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_compact_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_dialog.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_grid_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_list_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_search_bar.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';

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
  String _searchQuery = '';

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
      final snapshot = await recipeCollection
          .orderBy('createdAt', descending: true)
          .get();
      final userRecipes = snapshot.docs
          .map((doc) => RecipeCardModel.fromJson(doc.data()))
          .toList();

      final hiddenSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('hiddenGlobalRecipes')
          .get();
      final hiddenGlobalIds = hiddenSnapshot.docs.map((doc) => doc.id).toSet();

      final globalSnapshot = await FirebaseFirestore.instance
          .collection('global_recipes')
          .orderBy('createdAt', descending: true)
          .get();
      final globalRecipes = globalSnapshot.docs
          .where((doc) => !hiddenGlobalIds.contains(doc.id))
          .map((doc) => RecipeCardModel.fromJson(doc.data()))
          .toList();

      final Map<String, RecipeCardModel> mergedMap = {};

      for (final recipe in globalRecipes) {
        mergedMap[recipe.id] = recipe;
      }
      for (final recipe in userRecipes) {
        mergedMap[recipe.id] = recipe;
      }

      final List<RecipeCardModel> merged = [];
      for (final recipe in mergedMap.values) {
        final local = HiveRecipeService.getById(recipe.id);
        final mergedRecipe = recipe.copyWith(
          isFavourite: local?.isFavourite ?? recipe.isFavourite,
          categories: local?.categories ?? recipe.categories,
        );
        await HiveRecipeService.save(mergedRecipe);
        merged.add(mergedRecipe);
      }

      setState(() {
        _allRecipes = merged;
      });
    } catch (e) {
      debugPrint("⚠️ Firestore fetch failed, loading from Hive: $e");
      final fallback = HiveRecipeService.getAll();
      setState(() {
        _allRecipes = fallback;
      });
    }
  }

  Future<void> _deleteRecipe(RecipeCardModel recipe) async {
    try {
      final isGlobalRecipe =
          !(await recipeCollection.doc(recipe.id).get()).exists;

      if (isGlobalRecipe) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('hiddenGlobalRecipes')
            .doc(recipe.id)
            .set({'hiddenAt': FieldValue.serverTimestamp()});
      } else {
        await recipeCollection.doc(recipe.id).delete();
        if (recipe.imageUrl?.isNotEmpty ?? false) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(recipe.imageUrl!);
            await ref.delete();
          } catch (e) {
            if (!e.toString().contains('object-not-found')) {
              debugPrint('❌ Failed to delete attached image: $e');
            }
          }
        }
        for (final url in recipe.originalImageUrls) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(url);
            await ref.delete();
          } catch (e) {
            if (!e.toString().contains('object-not-found')) {
              debugPrint('❌ Failed to delete original image: $e');
            }
          }
        }
      }

      await HiveRecipeService.delete(recipe.id);
      setState(() => _allRecipes.removeWhere((r) => r.id == recipe.id));
    } catch (e) {
      debugPrint("❌ Error during recipe deletion: $e");
    }
  }

  Future<void> _toggleFavourite(RecipeCardModel recipe) async {
    final updated = recipe.copyWith(isFavourite: !recipe.isFavourite);
    await HiveRecipeService.save(updated);

    final subService = Provider.of<SubscriptionService>(context, listen: false);
    if (subService.hasAccess) {
      await recipeCollection
          .doc(updated.id)
          .set(updated.toJson(), SetOptions(merge: true));
    } else {
      await TrialPromptHelper.showIfTryingRestrictedFeature(context);
    }

    setState(() {
      final index = _allRecipes.indexWhere((r) => r.id == recipe.id);
      if (index != -1) _allRecipes[index] = updated;
    });
  }

  Future<void> _assignCategories(
    RecipeCardModel recipe,
    List<String> selected,
  ) async {
    final updated = recipe.copyWith(categories: selected.toSet().toList());
    await HiveRecipeService.save(updated);

    final subService = Provider.of<SubscriptionService>(context, listen: false);
    if (subService.hasAccess) {
      await recipeCollection
          .doc(updated.id)
          .set(updated.toJson(), SetOptions(merge: true));
    } else {
      await TrialPromptHelper.showIfTryingRestrictedFeature(context);
    }

    setState(() {
      final index = _allRecipes.indexWhere((r) => r.id == recipe.id);
      if (index != -1) _allRecipes[index] = updated;
    });
  }

  void _removeCategory(String category) async {
    if (_defaultCategories.contains(category) || category == 'All') return;

    await CategoryService.deleteCategory(category);
    await _loadCustomCategories();
    if (_selectedCategory == category) {
      setState(() => _selectedCategory = 'All');
    }
  }

  List<RecipeCardModel> get _filteredRecipes {
    List<RecipeCardModel> base = switch (_selectedCategory) {
      'All' => _allRecipes,
      'Favourites' => _allRecipes.where((r) => r.isFavourite).toList(),
      'Translated' => _allRecipes.where((r) => r.translationUsed).toList(),
      _ =>
        _allRecipes
            .where((r) => r.categories.contains(_selectedCategory))
            .toList(),
    };

    if (_searchQuery.trim().isEmpty) return base;

    return base
        .where(
          (r) => r.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final view = ViewMode.values[widget.viewMode];
    final scale = Provider.of<TextScaleNotifier>(context).scaleFactor;

    return Scaffold(
      body: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Column(
          children: [
            RecipeCategoryFilterBar(
              categories: _allCategories,
              selectedCategory: _selectedCategory,
              onCategorySelected: (cat) =>
                  setState(() => _selectedCategory = cat),
              onCategoryDeleted: _removeCategory,
            ),
            RecipeSearchBar(
              initialValue: _searchQuery,
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: ImageProcessingService.upgradeBannerMessage,
              builder: (_, message, __) => message == null
                  ? const SizedBox.shrink()
                  : UpgradeBanner(message: message),
            ),
            Expanded(
              child: _filteredRecipes.isEmpty
                  ? const Center(child: Text("No recipes found"))
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: ResponsiveWrapper(
                        child: switch (view) {
                          ViewMode.list => RecipeListView(
                            recipes: _filteredRecipes,
                            onDelete: _deleteRecipe,
                            onTap: (r) => showRecipeDialog(context, r),
                            onToggleFavourite: _toggleFavourite,
                            categories: _allCategories,
                            onAssignCategories: _assignCategories,
                          ),
                          ViewMode.grid => RecipeGridView(
                            recipes: _filteredRecipes,
                            onTap: (r) => showRecipeDialog(context, r),
                            onToggleFavourite: _toggleFavourite,
                            onAssignCategories: _assignCategories,
                            categories: _allCategories,
                            onDelete: _deleteRecipe,
                          ),
                          ViewMode.compact => RecipeCompactView(
                            recipes: _filteredRecipes,
                            onTap: (r) => showRecipeDialog(context, r),
                            onToggleFavourite: _toggleFavourite,
                            onDelete: _deleteRecipe,
                            categories: _allCategories,
                            onAssignCategories: _assignCategories,
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
          final count = _allCategories
              .where((c) => !_defaultCategories.contains(c) && c != 'All')
              .length;
          final allow =
              subService.allowCategoryCreation ||
              (subService.isHomeChef && count < 3);

          return CategorySpeedDial(
            onCategoryChanged: _loadCustomCategories,
            allowCreation: allow,
          );
        },
      ),
    );
  }
}

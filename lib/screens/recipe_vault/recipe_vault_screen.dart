import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/services/category_service.dart';

import 'package:recipe_vault/screens/recipe_vault/recipe_category_filter_bar.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_list_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_grid_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_compact_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_dialog.dart';
import 'package:recipe_vault/screens/recipe_vault/category_speed_dial.dart';

enum ViewMode { list, grid, compact }

class RecipeVaultScreen extends StatefulWidget {
  final int viewMode;
  const RecipeVaultScreen({super.key, required this.viewMode});

  @override
  State<RecipeVaultScreen> createState() => _RecipeVaultScreenState();
}

class _RecipeVaultScreenState extends State<RecipeVaultScreen> {
  late final String userId;
  late final CollectionReference<Map<String, dynamic>> recipeCollection;
  String _selectedCategory = 'All';

  static const List<String> _defaultCategories = [
    'Favourites',
    'Breakfast',
    'Main',
    'Dessert',
  ];

  List<String> _allCategories = ['All', 'Favourites']; // Start with these fixed

  List<RecipeCardModel> _allRecipes = [];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");

    userId = user.uid;
    recipeCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recipes');

    _initializeDefaultCategories().then((_) => _loadCustomCategories());
    _loadRecipes();
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
      // Always keep 'All' and 'Favourites' at front, append others from saved
      _allCategories = [
        'All',
        'Favourites',
        ...saved.where((c) => c != 'Favourites'),
      ];
    });
  }

  Future<void> _loadRecipes() async {
    try {
      final snapshot = await recipeCollection
          .orderBy('createdAt', descending: true)
          .get();
      final recipes = snapshot.docs
          .map((doc) => RecipeCardModel.fromJson(doc.data()))
          .toList();
      for (final recipe in recipes) {
        await HiveRecipeService.save(recipe);
      }
      setState(() {
        _allRecipes = recipes;
      });
    } catch (e) {
      debugPrint("⚠️ Firestore fetch failed, loading from Hive: $e");
      setState(() {
        _allRecipes = HiveRecipeService.getAll();
      });
    }
  }

  void _deleteRecipe(RecipeCardModel recipe) async {
    await recipeCollection.doc(recipe.id).delete();
    await HiveRecipeService.delete(recipe.id);

    // Delete associated uploaded images from Firebase Storage
    for (final url in recipe.originalImageUrls) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        debugPrint('❌ Failed to delete image from storage: $e');
      }
    }

    setState(() {
      _allRecipes.removeWhere((r) => r.id == recipe.id);
    });
  }

  void _toggleFavourite(RecipeCardModel recipe) async {
    final newFavourite = !recipe.isFavourite;
    final updated = recipe.copyWith(isFavourite: newFavourite);

    await recipeCollection.doc(recipe.id).update({'isFavourite': newFavourite});
    await HiveRecipeService.save(updated);

    setState(() {
      final index = _allRecipes.indexWhere((r) => r.id == recipe.id);
      if (index != -1) {
        _allRecipes[index] = updated;
      }
    });
  }

  void _removeCategory(String category) async {
    if (category == 'Favourites' || category == 'All') return;

    await CategoryService.deleteCategory(category);
    await _loadCustomCategories(); // reload after delete
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
      _ =>
        _allRecipes
            .where((r) => r.categories.contains(_selectedCategory))
            .toList(),
    };

    final ViewMode currentView = ViewMode.values[widget.viewMode];

    return Scaffold(
      body: Column(
        children: [
          RecipeCategoryFilterBar(
            categories: _allCategories,
            selectedCategory: _selectedCategory,
            onCategorySelected: (cat) =>
                setState(() => _selectedCategory = cat),
            onCategoryDeleted: _removeCategory,
          ),
          Expanded(
            child: filteredRecipes.isEmpty
                ? const Center(child: Text("No recipes found"))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: switch (currentView) {
                      ViewMode.list => RecipeListView(
                        recipes: filteredRecipes,
                        onDelete: _deleteRecipe,
                        onTap: (r) => showRecipeDialog(context, r),
                        onToggleFavourite: _toggleFavourite,
                      ),
                      ViewMode.grid => RecipeGridView(
                        recipes: filteredRecipes,
                        onTap: (r) => showRecipeDialog(context, r),
                        onToggleFavourite: _toggleFavourite,
                      ),
                      ViewMode.compact => RecipeCompactView(
                        recipes: filteredRecipes,
                        onTap: (r) => showRecipeDialog(context, r),
                      ),
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: CategorySpeedDial(
        onCategoryChanged: _loadCustomCategories,
      ),
    );
  }
}

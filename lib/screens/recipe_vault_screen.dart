// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:recipe_vault/core/hive_recipe_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';

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

  final List<String> _allCategories = [
    'All',
    'Favourites',
    'Dessert',
    'Main',
    'Vegan',
    'Quick',
    'Side',
    'Breakfast',
  ];

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
    _loadRecipes();
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

  void _showRecipeDialog(RecipeCardModel recipe) {
    final markdown = _formatRecipeMarkdown(recipe);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: RecipeCard(recipeText: markdown),
        ),
      ),
    );
  }

  String _formatRecipeMarkdown(RecipeCardModel recipe) {
    return '''
---
Title: ${recipe.title}

Ingredients:
${recipe.ingredients.map((i) => "- $i").join("\n")}

Instructions:
${recipe.instructions.asMap().entries.map((e) => "${e.key + 1}. ${e.value}").join("\n")}
---
''';
  }

  Widget _buildRecipeList(List<RecipeCardModel> recipes, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return Dismissible(
          key: Key(recipe.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _deleteRecipe(recipe),
          child: GestureDetector(
            onTap: () => _showRecipeDialog(recipe),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.25),
                  width: 2,
                ),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.deepPurple.shade50,
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: Colors.deepPurple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to view recipe',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        recipe.isFavourite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: recipe.isFavourite ? Colors.amber : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => _toggleFavourite(recipe),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeGrid(List<RecipeCardModel> recipes, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 4 / 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return GestureDetector(
          onTap: () => _showRecipeDialog(recipe),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.25),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      recipe.categories.isNotEmpty
                          ? recipe.categories.first
                          : 'Uncategorised',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        recipe.isFavourite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: recipe.isFavourite ? Colors.amber : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => _toggleFavourite(recipe),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactGalleryView(
    List<RecipeCardModel> recipes,
    ThemeData theme,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
        childAspectRatio: 7 / 7,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return GestureDetector(
          onTap: () => _showRecipeDialog(recipe),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.25),
                width: 2,
              ),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    recipe.isFavourite
                        ? Icons.star_rounded
                        : Icons.restaurant_menu,
                    size: 32,
                    color: recipe.isFavourite
                        ? Colors.amber
                        : Colors.deepPurple,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredRecipes = switch (_selectedCategory) {
      'All' => _allRecipes,
      'Favourites' => _allRecipes.where((r) => r.isFavourite).toList(),
      _ =>
        _allRecipes
            .where((r) => r.categories.contains(_selectedCategory))
            .toList(),
    };

    final ViewMode currentView = ViewMode.values[widget.viewMode];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: _allCategories.map((category) {
              final selected = category == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: filteredRecipes.isEmpty
              ? const Center(child: Text("No recipes found"))
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: currentView == ViewMode.list
                      ? _buildRecipeList(filteredRecipes, theme)
                      : currentView == ViewMode.grid
                      ? _buildRecipeGrid(filteredRecipes, theme)
                      : _buildCompactGalleryView(filteredRecipes, theme),
                ),
        ),
      ],
    );
  }
}

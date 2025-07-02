import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:recipe_vault/core/hive_recipe_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';

class RecipeVaultScreen extends StatefulWidget {
  const RecipeVaultScreen({super.key});

  @override
  State<RecipeVaultScreen> createState() => _RecipeVaultScreenState();
}

class _RecipeVaultScreenState extends State<RecipeVaultScreen> {
  late final String userId;
  late final CollectionReference<Map<String, dynamic>> recipeCollection;

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
  }

  Future<List<RecipeCardModel>> _fetchRecipes() async {
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
      return recipes;
    } catch (e) {
      debugPrint("⚠️ Firestore fetch failed, loading from Hive: $e");
      return HiveRecipeService.getAll();
    }
  }

  void _deleteRecipe(RecipeCardModel recipe) async {
    await recipeCollection.doc(recipe.id).delete();
    await HiveRecipeService.delete(recipe.id);
    setState(() {});
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

  void _toggleFavourite(RecipeCardModel recipe) {
    debugPrint("⭐ Long pressed to favourite: ${recipe.title}");
    // Add Hive or Firestore toggle logic here if needed
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: FutureBuilder<List<RecipeCardModel>>(
        future: _fetchRecipes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("Error loading recipes"));
          }

          final recipes = snapshot.data ?? [];

          if (recipes.isEmpty) {
            return const Center(child: Text("No recipes found"));
          }

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
                  onLongPress: () => _toggleFavourite(recipe),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

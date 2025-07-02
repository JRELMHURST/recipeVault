// lib/screens/recipe_vault_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/widgets/placeholder_logo.dart';
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
    final snapshot = await recipeCollection
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => RecipeCardModel.fromJson(doc.data()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: FutureBuilder<List<RecipeCardModel>>(
          future: _fetchRecipes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading recipes',
                  style: theme.textTheme.titleMedium,
                ),
              );
            }

            final recipes = snapshot.data ?? [];

            if (recipes.isEmpty) {
              return const Center(
                child: PlaceholderLogo(
                  imageAsset: 'assets/icon/round_vaultLogo.png',
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return GestureDetector(
                  onTap: () => _showRecipeDialog(context, recipe),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              recipe.ingredients.take(3).join(', ') +
                                  (recipe.ingredients.length > 3
                                      ? ', ...'
                                      : ''),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            recipe.createdAt
                                .toLocal()
                                .toString()
                                .split(' ')
                                .first,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showRecipeDialog(BuildContext context, RecipeCardModel recipe) {
    final markdown =
        """
---
Title: ${recipe.title}

Ingredients:
${recipe.ingredients.map((i) => "- $i").join("\n")}

Instructions:
${recipe.instructions.asMap().entries.map((e) => "${e.key + 1}. ${e.value}").join("\n")}
---
""";

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
}

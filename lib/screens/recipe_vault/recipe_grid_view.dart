// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class RecipeGridView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onToggleFavourite;
  final List<String> categories;
  final void Function(RecipeCardModel, List<String>) onAssignCategories;

  const RecipeGridView({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onToggleFavourite,
    required this.categories,
    required this.onAssignCategories,
  });

  void _showCategoryDialog(BuildContext context, RecipeCardModel recipe) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final selectedCategories = Set<String>.from(recipe.categories);
        return AlertDialog(
          title: const Text('Assign Categories'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              children: categories.map((category) {
                final isSelected = selectedCategories.contains(category);
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      selectedCategories.add(category);
                    } else {
                      selectedCategories.remove(category);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, selectedCategories.toList()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      onAssignCategories(recipe, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: recipes.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        final hasCategory = recipe.categories.isNotEmpty;
        final primaryCategory = hasCategory ? recipe.categories.first : null;

        return GestureDetector(
          onTap: () => onTap(recipe),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Recipe image
                  recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                      ? Image.network(
                          recipe.imageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.deepPurple.shade50,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.deepPurple.shade50,
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.chefHat,
                                size: 36,
                                color: Colors.deepPurple.shade200,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.deepPurple.shade50,
                          alignment: Alignment.center,
                          child: Icon(
                            LucideIcons.chefHat,
                            size: 36,
                            color: Colors.deepPurple.shade200,
                          ),
                        ),

                  // Gradient overlay with title
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Text(
                        recipe.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Favourite icon (top-right)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => onToggleFavourite(recipe),
                      child: Icon(
                        recipe.isFavourite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: recipe.isFavourite
                            ? Colors.redAccent
                            : Colors.white.withOpacity(0.9),
                        size: 24,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Category badge (top-left)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: () => _showCategoryDialog(context, recipe),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            hasCategory
                                ? Text(
                                    primaryCategory!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Colors.black87,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

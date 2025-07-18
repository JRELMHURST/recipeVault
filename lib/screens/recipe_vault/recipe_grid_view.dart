// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_card_menu.dart';

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

  void _showCategoryDialog(BuildContext context, RecipeCardModel recipe) {
    final selected = Set<String>.from(recipe.categories);
    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Assign Categories'),
            content: SingleChildScrollView(
              child: Column(
                children: categories
                    .where(
                      (c) =>
                          c != 'Favourites' && c != 'Translated' && c != 'All',
                    )
                    .map(
                      (cat) => CheckboxListTile(
                        value: selected.contains(cat),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selected.add(cat);
                            } else {
                              selected.remove(cat);
                            }
                          });
                        },
                        title: Text(cat),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  onAssignCategories(recipe, selected.toList());
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: recipes.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3 / 4,
      ),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        final primaryCategory = recipe.categories.isNotEmpty
            ? recipe.categories.first
            : 'Uncategorised';

        return GestureDetector(
          onTap: () => onTap(recipe),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child:
                          recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                          ? Image.network(
                              recipe.imageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 120,
                                  color: Colors.deepPurple.shade50,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 120,
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
                              height: 120,
                              color: Colors.deepPurple.shade50,
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.chefHat,
                                size: 36,
                                color: Colors.deepPurple.shade200,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: RecipeCardMenu(
                        isFavourite: recipe.isFavourite,
                        onToggleFavourite: () => onToggleFavourite(recipe),
                        onAssignCategories: () =>
                            _showCategoryDialog(context, recipe),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isCompact && recipe.hints.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '💡 ${recipe.hints.first}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.deepPurple.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          primaryCategory,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

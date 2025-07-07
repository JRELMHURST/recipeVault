// lib/screens/recipe_vault/recipe_grid_view.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class RecipeGridView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onToggleFavourite;
  final List<String> categories; // ✅ Add this
  final void Function(RecipeCardModel, List<String>)
  onAssignCategories; // ✅ Add this

  const RecipeGridView({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onToggleFavourite,
    required this.categories, // ✅ Add this
    required this.onAssignCategories, // ✅ Add this
  });

  void _showCategoryDialog(BuildContext context, RecipeCardModel recipe) {
    final selected = Set<String>.from(recipe.categories);
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Assign Categories'),
          content: SingleChildScrollView(
            child: Column(
              children: categories
                  .where(
                    (c) => c != 'Favourites' && c != 'Translated' && c != 'All',
                  )
                  .map(
                    (cat) => CheckboxListTile(
                      value: selected.contains(cat),
                      onChanged: (val) {
                        if (val == true) {
                          selected.add(cat);
                        } else {
                          selected.remove(cat);
                        }
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3 / 4,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];

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
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                      ? Image.network(
                          recipe.imageUrl!,
                          height: 120,
                          fit: BoxFit.cover,
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
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    recipe.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          recipe.categories.isNotEmpty
                              ? recipe.categories.first
                              : 'Uncategorised',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'favourite') {
                            onToggleFavourite(recipe);
                          } else if (value == 'assign') {
                            _showCategoryDialog(context, recipe);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'favourite',
                            child: Text(
                              recipe.isFavourite ? 'Unfavourite' : 'Favourite',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'assign',
                            child: Text('Assign Category'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

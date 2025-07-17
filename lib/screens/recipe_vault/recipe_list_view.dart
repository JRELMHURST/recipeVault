// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_card_menu.dart';

class RecipeListView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onDelete;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onToggleFavourite;
  final List<String> categories;
  final void Function(RecipeCardModel, List<String>) onAssignCategories;
  final void Function(RecipeCardModel)? onHide;

  const RecipeListView({
    super.key,
    required this.recipes,
    required this.onDelete,
    required this.onTap,
    required this.onToggleFavourite,
    required this.categories,
    required this.onAssignCategories,
    this.onHide,
  });

  void _showCategoryDialog(BuildContext context, RecipeCardModel recipe) {
    final selected = Set<String>.from(recipe.categories);
    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Assign Categories'),
              content: SingleChildScrollView(
                child: Column(
                  children: categories
                      .where(
                        (c) => !['Favourites', 'Translated', 'All'].contains(c),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveWrapper(
      maxWidth: 700,
      child: ListView.builder(
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
            onDismissed: (_) => onDelete(recipe),
            child: GestureDetector(
              onTap: () => onTap(recipe),
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
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipOval(
                            child:
                                recipe.imageUrl != null &&
                                    recipe.imageUrl!.isNotEmpty
                                ? Image.network(
                                    recipe.imageUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _fallbackIcon(),
                                  )
                                : _fallbackIcon(),
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
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.fade,
                                  softWrap: true,
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
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: RecipeCardMenu(
                          isFavourite: recipe.isFavourite,
                          onToggleFavourite: () => onToggleFavourite(recipe),
                          onAssignCategories: () =>
                              _showCategoryDialog(context, recipe),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.deepPurple.shade100,
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.utensilsCrossed,
        size: 20,
        color: Colors.deepPurple,
      ),
    );
  }
}

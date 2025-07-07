// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class RecipeListView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onDelete;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onToggleFavourite;
  final List<String> categories;
  final void Function(RecipeCardModel, List<String>) onAssignCategories;

  const RecipeListView({
    super.key,
    required this.recipes,
    required this.onDelete,
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipOval(
                      child:
                          recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                          ? Image.network(
                              recipe.imageUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
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
                              },
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.deepPurple.shade100,
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.utensilsCrossed,
                                size: 20,
                                color: Colors.deepPurple,
                              ),
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
                          if (recipe.hints.isNotEmpty)
                            Text(
                              '💡 ${recipe.hints.first}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.deepPurple.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            Text(
                              'Tap to view recipe',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                        ],
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
            ),
          ),
        );
      },
    );
  }
}

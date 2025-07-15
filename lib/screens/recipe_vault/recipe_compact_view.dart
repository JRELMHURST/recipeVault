// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class RecipeCompactView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onToggleFavourite;
  final void Function(RecipeCardModel, List<String>) onAssignCategories;
  final List<String> categories;

  const RecipeCompactView({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onToggleFavourite,
    required this.onAssignCategories,
    required this.categories,
  });

  void _showCategoryDialog(BuildContext context, RecipeCardModel recipe) {
    final selected = Set<String>.from(recipe.categories);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120, // Adjust to your preferred tile width
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];

        return GestureDetector(
          onTap: () => onTap(recipe),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                    ? Image.network(
                        recipe.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Container(
                        color: Colors.deepPurple.shade50,
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.chefHat,
                          size: 28,
                          color: Colors.deepPurple,
                        ),
                      ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
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
                  icon: const Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

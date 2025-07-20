import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_long_press_menu.dart';

class RecipeCompactView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onDelete;
  final void Function(RecipeCardModel) onToggleFavourite;
  final void Function(RecipeCardModel, List<String>) onAssignCategories;
  final List<String> categories;

  const RecipeCompactView({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavourite,
    required this.onAssignCategories,
    required this.categories,
  });

  void _showActionMenu(BuildContext context, RecipeCardModel recipe) {
    RecipeLongPressMenu.show(
      context: context,
      recipe: recipe,
      onDelete: () => onDelete(recipe),
      categories: categories,
      onAssignCategory: (selected) => onAssignCategories(recipe, selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];

        return GestureDetector(
          onTap: () => onTap(recipe),
          onLongPress: () => _showActionMenu(context, recipe),
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
                        errorBuilder: (context, error, stackTrace) =>
                            _fallbackIcon(),
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
                      )
                    : _fallbackIcon(),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: Icon(
                    recipe.isFavourite ? Icons.favorite : Icons.favorite_border,
                    color: recipe.isFavourite ? Colors.redAccent : Colors.white,
                    size: 26,
                  ),
                  onPressed: () => onToggleFavourite(recipe),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.deepPurple.shade50,
      alignment: Alignment.center,
      child: Icon(LucideIcons.chefHat, size: 28, color: Colors.deepPurple),
    );
  }
}

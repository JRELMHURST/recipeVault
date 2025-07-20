import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/assign_cat_dropdown.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_card_menu.dart';

class RecipeCompactView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onToggleFavourite;
  final List<String> categories;
  final void Function(RecipeCardModel, List<String>) onAssignCategories;

  const RecipeCompactView({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onToggleFavourite,
    required this.onAssignCategories,
    required this.categories,
  });

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

              // Favourite and options menu
              Positioned(
                top: 4,
                right: 4,
                child: RecipeCardMenu(
                  isFavourite: recipe.isFavourite,
                  onToggleFavourite: () => onToggleFavourite(recipe),
                ),
              ),

              // Category dropdown
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: AssignCategoryDropdown(
                  categories: categories,
                  current: recipe.categories,
                  onChanged: (selected) => onAssignCategories(recipe, selected),
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

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_long_press_menu.dart';
import 'package:recipe_vault/widgets/network_recipe_image.dart';

class RecipeListView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onDelete;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onToggleFavourite;
  final void Function(RecipeCardModel) onAddOrUpdateImage;
  final List<String> categories;
  final void Function(RecipeCardModel, List<String>) onAssignCategories;
  final void Function(RecipeCardModel)? onHide;

  const RecipeListView({
    super.key,
    required this.recipes,
    required this.onDelete,
    required this.onTap,
    required this.onToggleFavourite,
    required this.onAddOrUpdateImage,
    required this.categories,
    required this.onAssignCategories,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];

        return Dismissible(
          key: Key(recipe.id),

          // Ask BEFORE dismissing
          confirmDismiss: (direction) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.delete), // keep it short; localized
                content: Text(l.deleteConfirmation),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l.cancel),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(l.delete),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              onDelete(recipe);
              return true;
            }
            return false;
          },

          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,

          child: GestureDetector(
            onTap: () => onTap(recipe),
            onLongPress: () => RecipeLongPressMenu.show(
              context: context,
              recipe: recipe,
              onDelete: () => onDelete(recipe),
              onAssignCategory: (selected) =>
                  onAssignCategories(recipe, selected),
              onAddOrUpdateImage: () => onAddOrUpdateImage(recipe),
              categories: categories,
            ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                        ? NetworkRecipeImage(
                            imageUrl: recipe.imageUrl!,
                            width: 56,
                            height: 56,
                          )
                        : _fallbackIcon(),
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
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Add a small localized hint
                          Text(
                            l.tapToViewRecipe, // <-- add this key to ARB
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => onToggleFavourite(recipe),
                      tooltip: l.favourites, // neutral tooltip
                      icon: Icon(
                        recipe.isFavourite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: recipe.isFavourite
                            ? Colors.redAccent
                            : Colors.grey,
                        size: 20,
                      ),
                      splashRadius: 22,
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

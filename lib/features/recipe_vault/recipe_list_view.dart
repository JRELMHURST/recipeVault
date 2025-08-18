// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/features/recipe_vault/recipe_long_press_menu.dart';
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

    // Fallback text in case the ARB key hasn't landed yet
    final tapHint = l.tapToViewRecipe.isEmpty
        ? 'Tap to view'
        : l.tapToViewRecipe;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];

        return Dismissible(
          key: ValueKey(recipe.id),

          // Confirm BEFORE dismissing so we don't animate an accidental delete
          confirmDismiss: (direction) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.delete),
                content: Text(l.deleteConfirmation),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l.cancel),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
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

          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: theme.colorScheme.error,
            child: Icon(Icons.delete, color: theme.colorScheme.onError),
          ),

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
            child: Semantics(
              button: true,
              label: '${recipe.title}. $tapHint',
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.20),
                    width: 1.5,
                  ),
                ),
                color: theme.cardColor,
                elevation: 2,
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
                        child: _TitleAndHint(
                          title: recipe.title,
                          hint: tapHint,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => onToggleFavourite(recipe),
                        tooltip: recipe.isFavourite
                            ? l.menuUnfavourite
                            : l.menuFavourite,
                        icon: Icon(
                          recipe.isFavourite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: recipe.isFavourite
                              ? Colors.redAccent
                              : theme.hintColor,
                          size: 20,
                        ),
                        splashRadius: 22,
                      ),
                    ],
                  ),
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

class _TitleAndHint extends StatelessWidget {
  final String title;
  final String hint;

  const _TitleAndHint({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

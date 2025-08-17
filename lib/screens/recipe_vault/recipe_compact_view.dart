// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_long_press_menu.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeCompactView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onDelete;
  final void Function(RecipeCardModel) onToggleFavourite;
  final void Function(RecipeCardModel, List<String>) onAssignCategories;
  final void Function(RecipeCardModel) onAddOrUpdateImage;
  final List<String> categories;

  const RecipeCompactView({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavourite,
    required this.onAssignCategories,
    required this.onAddOrUpdateImage,
    required this.categories,
  });

  void _showActionMenu(BuildContext context, RecipeCardModel recipe) {
    RecipeLongPressMenu.show(
      context: context,
      recipe: recipe,
      onDelete: () => onDelete(recipe),
      categories: categories,
      onAssignCategory: (selected) => onAssignCategories(recipe, selected),
      onAddOrUpdateImage: () => onAddOrUpdateImage(recipe),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
        final hasImage = recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty;

        return Semantics(
          label: '${l10n.appTitle}: ${recipe.title}',
          button: true,
          child: GestureDetector(
            onTap: () => onTap(recipe),
            onLongPress: () => _showActionMenu(context, recipe),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: hasImage
                      ? Image.network(
                          recipe.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) =>
                              _fallbackTile(theme),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Semantics(
                              label: l10n.loading,
                              child: _loadingTile(theme),
                            );
                          },
                        )
                      : _fallbackTile(theme),
                ),

                // Favourite toggle
                Positioned(
                  top: 4,
                  right: 4,
                  child: Tooltip(
                    message: recipe.isFavourite
                        ? l10n.removeFromFavourites
                        : l10n.addToFavourites,
                    child: IconButton(
                      icon: Icon(
                        recipe.isFavourite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: recipe.isFavourite
                            ? Colors.redAccent
                            : theme.colorScheme.onPrimary,
                        size: 26,
                      ),
                      onPressed: () => onToggleFavourite(recipe),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                    ),
                  ),
                ),

                // Title overlay (helps when thumbnails are busy)
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: _titlePill(theme, recipe.title),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Small helpers ---------------------------------------------------------

  Widget _fallbackTile(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.chefHat,
        size: 28,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _loadingTile(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
      alignment: Alignment.center,
      child: const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _titlePill(ThemeData theme, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

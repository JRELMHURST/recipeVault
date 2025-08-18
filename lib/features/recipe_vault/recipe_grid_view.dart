// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/features/recipe_vault/recipe_long_press_menu.dart';

class RecipeGridView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onDelete;
  final List<String> categories;
  final void Function(RecipeCardModel) onToggleFavourite;
  final void Function(RecipeCardModel, List<String>) onAssignCategories;
  final void Function(RecipeCardModel) onAddOrUpdateImage;

  const RecipeGridView({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onDelete,
    required this.categories,
    required this.onToggleFavourite,
    required this.onAssignCategories,
    required this.onAddOrUpdateImage,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final surfaceVariant = theme.colorScheme.surfaceVariant;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: recipes.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final recipe = recipes[index];

        return Semantics(
          label: '${l.appTitle}: ${recipe.title}',
          button: true,
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Image (with loader + fallback)
                    if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
                      Image.network(
                        recipe.imageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: surfaceVariant.withOpacity(0.25),
                            alignment: Alignment.center,
                            child: Semantics(
                              label: l.loading,
                              child: const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            _fallbackIcon(theme),
                        semanticLabel: recipe.title,
                      )
                    else
                      _fallbackIcon(theme),

                    // Title overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.85),
                              Colors.black.withOpacity(0.0),
                            ],
                          ),
                        ),
                        child: Text(
                          recipe.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // Favourite icon button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IconButton(
                        onPressed: () => onToggleFavourite(recipe),
                        icon: Icon(
                          recipe.isFavourite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: recipe.isFavourite
                              ? Colors.redAccent
                              : Colors.white.withOpacity(0.95),
                          size: 24,
                          shadows: const [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                        tooltip: recipe.isFavourite
                            ? l.removeFromFavourites
                            : l.addToFavourites,
                        splashRadius: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    // Subtle border for contrast on light images
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: surface.withOpacity(0.04),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
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

  Widget _fallbackIcon(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.chefHat,
        size: 36,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class RecipeCompactView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onToggleFavourite;

  const RecipeCompactView({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onToggleFavourite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
        childAspectRatio: 7 / 7,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];

        return GestureDetector(
          onTap: () => onTap(recipe),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.25),
                width: 2,
              ),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child:
                        recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                        ? Image.network(
                            recipe.imageUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.deepPurple.shade50,
                            child: Icon(
                              LucideIcons.chefHat,
                              size: 20,
                              color: Colors.deepPurple,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          recipe.isFavourite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: recipe.isFavourite
                              ? Colors.amber
                              : Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => onToggleFavourite(recipe),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

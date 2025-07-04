// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class RecipeGridView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;
  final void Function(RecipeCardModel) onToggleFavourite;

  const RecipeGridView({
    super.key,
    required this.recipes,
    required this.onTap,
    required this.onToggleFavourite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 4 / 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return GestureDetector(
          onTap: () => onTap(recipe),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.25),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ClipOval(
                  child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                      ? Image.network(
                          recipe.imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Icon(
                            LucideIcons.chefHat,
                            size: 20,
                            color: Colors.deepPurple,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  recipe.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
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
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        recipe.isFavourite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: recipe.isFavourite ? Colors.amber : Colors.grey,
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
        );
      },
    );
  }
}

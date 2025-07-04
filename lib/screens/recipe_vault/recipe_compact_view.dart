// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class RecipeCompactView extends StatelessWidget {
  final List<RecipeCardModel> recipes;
  final void Function(RecipeCardModel) onTap;

  const RecipeCompactView({
    super.key,
    required this.recipes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1, // Square cards
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];

        return GestureDetector(
          onTap: () => onTap(recipe),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                ? Image.network(recipe.imageUrl!, fit: BoxFit.cover)
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
        );
      },
    );
  }
}

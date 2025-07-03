import 'package:flutter/material.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_utils.dart';

/// Shows a modal dialog displaying the full recipe.
void showRecipeDialog(BuildContext context, RecipeCardModel recipe) {
  final markdown = formatRecipeMarkdown(recipe);

  showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RecipeCard(recipeText: markdown),
      ),
    ),
  );
}

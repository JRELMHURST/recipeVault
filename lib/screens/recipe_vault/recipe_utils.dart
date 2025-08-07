import 'package:recipe_vault/model/recipe_card_model.dart';

/// Converts a [RecipeCardModel] into formatted markdown text.
String formatRecipeMarkdown(RecipeCardModel recipe) {
  final ingredients = recipe.ingredients.map((i) => "- $i").join("\n");

  // Strip any leading numbers or bullets from original instructions
  final instructionRegex = RegExp(r'^\s*[\d]+[.)\-]?\s*');

  final methodLines = recipe.instructions
      .where((line) => line.trim().isNotEmpty)
      .toList();

  final instructions = methodLines
      .asMap()
      .entries
      .map((e) {
        final cleaned = e.value.replaceFirst(instructionRegex, '').trim();
        return "${e.key + 1}. $cleaned";
      })
      .join("\n");

  final hintsList = recipe.hints;
  final hints = hintsList.isNotEmpty
      ? hintsList.map((h) => "- $h").join("\n")
      : "- No additional tips provided.";

  return '''
---
Title: ${recipe.title}

Ingredients:
$ingredients

Instructions:
$instructions

Hints & Tips:
$hints
---
''';
}

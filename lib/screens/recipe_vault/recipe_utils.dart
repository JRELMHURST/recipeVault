import 'package:recipe_vault/model/recipe_card_model.dart';

/// Converts a [RecipeCardModel] into formatted markdown text.
String formatRecipeMarkdown(RecipeCardModel recipe) {
  final ingredients = recipe.ingredients.map((i) => "- $i").join("\n");
  final instructions = recipe.instructions
      .asMap()
      .entries
      .map((e) => "${e.key + 1}. ${e.value}")
      .join("\n");

  return '''
---
Title: ${recipe.title}

Ingredients:
$ingredients

Instructions:
$instructions
---
''';
}

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:flutter/widgets.dart';

/// Converts a [RecipeCardModel] into formatted markdown text.
String formatRecipeMarkdown(BuildContext context, RecipeCardModel recipe) {
  final l = AppLocalizations.of(context);

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
      : "- ${l.noAdditionalTips}";

  return '''
---
${l.title}: ${recipe.title}

${l.ingredients}:
$ingredients

${l.instructions}:
$instructions

${l.hintsAndTips}:
$hints
---
''';
}

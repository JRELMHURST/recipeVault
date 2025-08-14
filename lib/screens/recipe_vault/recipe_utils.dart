import 'package:flutter/widgets.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

String formatRecipeMarkdown(BuildContext context, RecipeCardModel recipe) {
  final t = AppLocalizations.of(context);

  String mdEscape(String s) => s.replaceAllMapped(
    RegExp(r'([\\`*_{}$begin:math:display$$end:math:display$()#+\-.!|>])'),
    (m) => '\\${m[1]}',
  );

  String bulletify(Iterable<String> items) =>
      items.map((e) => "- ${mdEscape(e.trim())}").join("\n");

  final numberPrefix = RegExp(r'^\s*(?:\d+|[•\-*])[\.\)\-]?\s+');

  // Ingredients
  final ingredientsList = recipe.ingredients
      .where((e) => e.trim().isNotEmpty)
      .toList();
  final ingredients = ingredientsList.isEmpty
      ? "- ${t.noAdditionalTips}"
      : bulletify(ingredientsList);

  // Instructions
  final instructionList = recipe.instructions
      .map((e) => e.replaceFirst(numberPrefix, '').trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final instructions = instructionList.isEmpty
      ? "1. ${t.noAdditionalTips}"
      : instructionList
            .asMap()
            .entries
            .map((e) => "${e.key + 1}. ${mdEscape(e.value)}")
            .join("\n");

  // Hints
  final hintsList = recipe.hints.where((e) => e.trim().isNotEmpty).toList();
  final hints = hintsList.isEmpty
      ? "- ${t.noAdditionalTips}"
      : bulletify(hintsList);

  // Categories (optional)
  final categoriesLine = recipe.categories.isNotEmpty
      ? "\n${t.categories}: ${mdEscape(recipe.categories.join(', '))}"
      : "";

  return """
${mdEscape(t.title)}: ${mdEscape(recipe.title.trim().isEmpty ? "Untitled" : recipe.title)}

$categoriesLine

${mdEscape(t.ingredients)}:
$ingredients

${mdEscape(t.instructions)}:
$instructions

${mdEscape(t.hintsAndTips)}:
$hints
"""
      .trim();
}

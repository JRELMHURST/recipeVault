import 'package:flutter/widgets.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

String formatRecipeMarkdown(BuildContext context, RecipeCardModel recipe) {
  final t = AppLocalizations.of(context);

  // Escape all Markdown-reserved characters
  String mdEscape(String s) => s.replaceAllMapped(
    RegExp(
      r'([\\`*_{}$begin:math:display$$end:math:display$$begin:math:text$$end:math:text$#\+\-\.\!|>])',
    ),
    (m) => '\\${m[1]}',
  );

  String bulletify(Iterable<String> items) =>
      items.map((e) => "- ${mdEscape(e.trim())}").join("\n");

  // Strip "1. ", "1) ", "-", "*", "•" etc. at the start of an instruction line
  final numberPrefix = RegExp(r'^\s*(?:\d+|[•\-\*])[\.\)\-]?\s+');

  // Title
  final title = recipe.title.trim().isEmpty ? "Untitled" : recipe.title.trim();

  // Ingredients
  final ingredientsList = recipe.ingredients
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final ingredients = ingredientsList.isEmpty
      ? "- ${t.noAdditionalTips}"
      : bulletify(ingredientsList);

  // Instructions (normalize numbers/bullets to 1., 2., ...)
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
  final hintsList = recipe.hints
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final hints = hintsList.isEmpty
      ? "- ${t.noAdditionalTips}"
      : bulletify(hintsList);

  // Categories (optional)
  final categoriesLine = recipe.categories.isNotEmpty
      ? "${t.categories}: ${mdEscape(recipe.categories.join(', '))}\n\n"
      : "";

  // Build final markdown
  final buffer = StringBuffer();
  buffer.writeln("# ${mdEscape(title)}\n");
  if (categoriesLine.isNotEmpty) buffer.write(categoriesLine);

  buffer
    ..writeln("${mdEscape(t.ingredients)}:")
    ..writeln(ingredients)
    ..writeln()
    ..writeln("${mdEscape(t.instructions)}:")
    ..writeln(instructions)
    ..writeln()
    ..writeln("${mdEscape(t.hintsAndTips)}:")
    ..writeln(hints);

  return buffer.toString().trim();
}

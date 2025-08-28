import 'package:flutter/widgets.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';

String formatRecipeMarkdown(BuildContext context, RecipeCardModel recipe) {
  final t = AppLocalizations.of(context);

  // 1) Prefer a preformatted translation if present
  final locale = Localizations.localeOf(context);
  final tag = _toBcp47(locale);
  final translated = recipe.formattedForLocaleTag(tag);
  if (translated != null && translated.trim().isNotEmpty) {
    return translated.trim();
  }

  // 2) Helpers
  String mdEscape(String s) => s.replaceAllMapped(
    // Escape the usual suspects for Markdown headings/lists
    RegExp(r'([\\`*_{}()$begin:math:display$$end:math:display$#+\-!|>])'),
    (m) => '\\${m[1]}',
  );

  Iterable<String> normList(Iterable<String> items) => items
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet() // dedupe
      .toList();

  String bulletify(Iterable<String> items) =>
      items.map((e) => "- ${mdEscape(e)}").join("\n");

  // Strip "1. ", "1) ", "-", "*", "•", etc. from instruction starts
  final numberPrefix = RegExp(r'^\s*(?:\d+|[•\-\*])[\.\)]?\s+');

  String localizeCategoryLabel(String raw) {
    switch (raw) {
      case 'All':
        return t.systemAll;
      case 'Favourites':
        return t.favourites;
      case 'Translated':
        return t.systemTranslated;
      default:
        return raw;
    }
  }

  // 3) Title
  final title = recipe.title.trim().isEmpty ? t.untitled : recipe.title.trim();

  // 4) Ingredients
  final ingredientsList = normList(recipe.ingredients);
  final ingredients = ingredientsList.isEmpty
      ? "- ${mdEscape(t.noAdditionalTips)}"
      : bulletify(ingredientsList);

  // 5) Instructions (re-number cleanly)
  final instructionList = normList(
    recipe.instructions.map((e) => e.replaceFirst(numberPrefix, '').trim()),
  ).toList();
  final instructions = instructionList.isEmpty
      ? "1. ${mdEscape(t.noAdditionalTips)}"
      : instructionList
            .asMap()
            .entries
            .map((e) => "${e.key + 1}. ${mdEscape(e.value)}")
            .join("\n");

  // 6) Hints
  final rawHints = normList(
    recipe.hints,
  ).where((h) => !h.toLowerCase().contains('no additional tips')).toList();
  final hints = rawHints.isEmpty
      ? "- ${mdEscape(t.noAdditionalTips)}"
      : bulletify(rawHints);

  // 7) Categories (optional)
  final cats = recipe.categories.map(localizeCategoryLabel).toList();
  final categoriesLine = cats.isNotEmpty
      ? "${mdEscape(t.categories)}: ${mdEscape(cats.join(', '))}\n\n"
      : "";

  // 8) Build final markdown
  final buf = StringBuffer();
  buf.writeln("# ${mdEscape(title)}\n");
  if (categoriesLine.isNotEmpty) buf.write(categoriesLine);

  buf
    ..writeln("${mdEscape(t.ingredients)}:")
    ..writeln(ingredients)
    ..writeln()
    ..writeln("${mdEscape(t.instructions)}:")
    ..writeln(instructions)
    ..writeln()
    ..writeln("${mdEscape(t.hintsAndTips)}:")
    ..writeln(hints);

  return buf.toString().trim();
}

String _toBcp47(Locale locale) {
  final cc = locale.countryCode;
  if (cc == null || cc.isEmpty) return locale.languageCode;
  return "${locale.languageCode}-$cc";
}

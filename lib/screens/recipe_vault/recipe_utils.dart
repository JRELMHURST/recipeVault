import 'package:flutter/widgets.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

String formatRecipeMarkdown(BuildContext context, RecipeCardModel recipe) {
  final t = AppLocalizations.of(context);

  // Try to use a preformatted translation block if present for the current locale.
  final locale = Localizations.localeOf(context);
  final tag = _toBcp47(locale);
  final translated = recipe.formattedForLocaleTag(tag);
  if (translated != null && translated.trim().isNotEmpty) {
    return translated.trim();
  }

  // --- Helpers ---------------------------------------------------------------

  // Proper Markdown escape for common special chars.
  String mdEscape(String s) => s.replaceAllMapped(
    RegExp(r'([\\`*_{}$begin:math:display$$end:math:display$()#+\-.!|>])'),
    (m) => '\\${m[1]}',
  );

  String bulletify(Iterable<String> items) =>
      items.map((e) => "- ${mdEscape(e.trim())}").join("\n");

  // Strip "1. ", "1) ", "-", "*", "•", etc. at the start of an instruction line.
  final numberPrefix = RegExp(r'^\s*(?:\d+|[•\-\*])[\.\)]?\s+');

  // Localize built-in category labels; leave user categories as-is.
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

  // --- Title -----------------------------------------------------------------
  final title = recipe.title.trim().isEmpty ? "Untitled" : recipe.title.trim();

  // --- Ingredients -----------------------------------------------------------
  final ingredientsList = recipe.ingredients
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final ingredients = ingredientsList.isEmpty
      ? "- ${mdEscape(t.noAdditionalTips)}"
      : bulletify(ingredientsList);

  // --- Instructions (normalize numbering) ------------------------------------
  final instructionList = recipe.instructions
      .map((e) => e.replaceFirst(numberPrefix, '').trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final instructions = instructionList.isEmpty
      ? "1. ${mdEscape(t.noAdditionalTips)}"
      : instructionList
            .asMap()
            .entries
            .map((e) => "${e.key + 1}. ${mdEscape(e.value)}")
            .join("\n");

  // --- Hints -----------------------------------------------------------------
  final hintsList = recipe.hints
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final hints = hintsList.isEmpty
      ? "- ${mdEscape(t.noAdditionalTips)}"
      : bulletify(hintsList);

  // --- Categories (optional line) --------------------------------------------
  final cats = recipe.categories.map(localizeCategoryLabel).toList();
  final categoriesLine = cats.isNotEmpty
      ? "${mdEscape(t.categories)}: ${mdEscape(cats.join(', '))}\n\n"
      : "";

  // --- Build final markdown ---------------------------------------------------
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

String _toBcp47(Locale locale) {
  final country = locale.countryCode;
  if (country == null || country.isEmpty) return locale.languageCode;
  return "${locale.languageCode}-$country";
}

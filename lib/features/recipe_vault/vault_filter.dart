// lib/screens/recipe_vault/vault_filter.dart
// ignore_for_file: unintended_html_in_doc_comment

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/core/recipe_chip_filter_bar.dart';

// ✅ Category keys (All / Favourites / etc.)
import 'package:recipe_vault/features/recipe_vault/categories.dart';

// ✅ Controller (provides categories, selection, and hide action)
import 'package:recipe_vault/features/recipe_vault/recipe_vault_controller.dart';

/// Filter bar for the vault using localized labels but storing key values.
/// - You can pass a [controller], [keyToLabel], and [labelToKey] explicitly
///   (e.g., from RecipeVaultScreen), OR
/// - Omit them and this widget will read the controller from Provider and
///   use its own localization mappers.
///
/// This keeps it flexible and backwards-compatible.
class VaultFilter extends StatelessWidget {
  const VaultFilter({
    super.key,
    this.controller,
    this.keyToLabel,
    this.labelToKey,
  });

  /// Optional injected controller. If null, uses context.watch<RecipeVaultController>().
  final RecipeVaultController? controller;

  /// Optional mapping from internal key -> localized label.
  final String Function(String key)? keyToLabel;

  /// Optional mapping from localized label -> internal key.
  final String Function(String label)? labelToKey;

  // ---- Default mappers (used if no mappers are injected) ----
  String _defaultKeyToLabel(String key, AppLocalizations t) {
    switch (key) {
      case CategoryKeys.all:
        return t.systemAll;
      case CategoryKeys.fav:
        return t.favourites;
      case CategoryKeys.translated:
        return t.systemTranslated;
      case CategoryKeys.breakfast:
        return t.defaultBreakfast;
      case CategoryKeys.main:
        return t.defaultMain;
      case CategoryKeys.dessert:
        return t.defaultDessert;
      default:
        return key;
    }
  }

  String _defaultLabelToKey(String label, AppLocalizations t) {
    if (label == t.systemAll) return CategoryKeys.all;
    if (label == t.favourites) return CategoryKeys.fav;
    if (label == t.systemTranslated) return CategoryKeys.translated;
    if (label == t.defaultBreakfast) return CategoryKeys.breakfast;
    if (label == t.defaultMain) return CategoryKeys.main;
    if (label == t.defaultDessert) return CategoryKeys.dessert;
    return label; // fall back to custom category name
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    final ctrl = controller ?? context.watch<RecipeVaultController>();

    final k2l = keyToLabel ?? ((k) => _defaultKeyToLabel(k, t));
    final l2k = labelToKey ?? ((l) => _defaultLabelToKey(l, t));

    final displayedCategories = ctrl.categories.map(k2l).toList();
    final displayedSelected = k2l(ctrl.selectedCategory);

    return RecipeChipFilterBar(
      categories: displayedCategories,
      selectedCategory: displayedSelected,
      onCategorySelected: (label) => ctrl.setSelectedCategory(l2k(label)),
      onCategoryDeleted: (label) => ctrl.hideDefaultCategory(l2k(label)),
      allRecipes: ctrl.allRecipes.values.toList(),
    );
  }
}

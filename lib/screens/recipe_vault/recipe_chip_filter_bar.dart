// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeChipFilterBar extends StatelessWidget {
  final List<String> categories; // may contain localized labels
  final String selectedCategory; // may be a key or localized label
  final void Function(String category) onCategorySelected; // receives key
  final void Function(String category)? onCategoryDeleted; // receives key
  final List<RecipeCardModel> allRecipes;

  const RecipeChipFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onCategoryDeleted,
    required this.allRecipes,
  });

  /// Canonical keys for system categories
  static const _systemCategories = ['All', 'Favourites', 'Translated'];

  /// Map any incoming label (possibly localized) back to the canonical key.
  String _canonicalCategory(AppLocalizations l10n, String category) {
    if (category == 'All' || category == l10n.systemAll) return 'All';
    if (category == 'Favourites' || category == l10n.favourites) {
      return 'Favourites';
    }
    if (category == 'Translated' || category == l10n.systemTranslated) {
      return 'Translated';
    }
    return category; // user-defined category key
  }

  bool _isCategoryUsed(AppLocalizations l10n, String canonicalKey) {
    return allRecipes.any(
      (r) => r.categories
          .map((c) => _canonicalCategory(l10n, c))
          .contains(canonicalKey),
    );
  }

  bool _isProtectedCategory(String canonicalKey) =>
      _systemCategories.contains(canonicalKey);

  String _localizedCategory(AppLocalizations l10n, String canonicalKey) {
    switch (canonicalKey) {
      case 'All':
        return l10n.systemAll;
      case 'Favourites':
        return l10n.favourites;
      case 'Translated':
        return l10n.systemTranslated;
      default:
        return canonicalKey; // user-defined
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final textStyle = theme.textTheme.bodySmall;

    // Safer for older SDKs than surfaceContainerHighest:
    final chipBg = theme.colorScheme.surfaceVariant.withOpacity(0.30);

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedKey = _canonicalCategory(l10n, selectedCategory);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: categories.map((rawCategory) {
          final key = _canonicalCategory(l10n, rawCategory);

          final isSelected = key == selectedKey;
          final isProtected = _isProtectedCategory(key);
          final isDeletable = !isProtected && !_isCategoryUsed(l10n, key);
          final labelText = _localizedCategory(l10n, key);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              label: Text(
                labelText,
                style: textStyle?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? primary : theme.colorScheme.onSurface,
                ),
              ),
              selected: isSelected,
              selectedColor: primary.withOpacity(0.15),
              backgroundColor: chipBg,
              onSelected: (_) => onCategorySelected(key), // pass canonical key
              deleteIcon: isDeletable ? const Icon(Icons.close) : null,
              deleteButtonTooltipMessage: isDeletable
                  ? l10n.chipDeleteCategoryTooltip
                  : null,
              onDeleted: isDeletable
                  ? () => onCategoryDeleted?.call(key)
                  : null,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected
                      ? primary
                      : theme.colorScheme.outline.withOpacity(0.40),
                  width: 1.2,
                ),
              ),
              // keep elevation props for compatibility; harmless if ignored
              elevation: 0,
              pressElevation: 1.5,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }
}

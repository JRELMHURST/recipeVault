// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeChipFilterBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final void Function(String category) onCategorySelected;
  final void Function(String category)? onCategoryDeleted;
  final List<RecipeCardModel> allRecipes;

  const RecipeChipFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onCategoryDeleted,
    required this.allRecipes,
  });

  // These are stable internal keys; UI text is localized separately.
  static const _systemCategories = ['All', 'Favourites', 'Translated'];
  static const _protectedDefaults = ['Breakfast', 'Main', 'Dessert'];

  bool _isCategoryUsed(String category) {
    return allRecipes.any((r) => r.categories.contains(category));
  }

  bool _isProtectedCategory(String category, bool isFreeUser) {
    return _systemCategories.contains(category) ||
        (isFreeUser && _protectedDefaults.contains(category));
  }

  String _localizedCategory(AppLocalizations l10n, String category) {
    switch (category) {
      case 'All':
        return l10n.systemAll;
      case 'Favourites':
        return l10n.favourites; // already exists
      case 'Translated':
        return l10n.systemTranslated;
      case 'Breakfast':
        return l10n.defaultBreakfast;
      case 'Main':
        return l10n.defaultMain;
      case 'Dessert':
        return l10n.defaultDessert;
      default:
        return category; // user-defined categories
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final isFreeUser = subscriptionService.tier == 'free';

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final textStyle = theme.textTheme.bodySmall;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: categories.map((category) {
          final isSelected = category == selectedCategory;
          final isProtected = _isProtectedCategory(category, isFreeUser);
          final isDeletable = !isProtected && !_isCategoryUsed(category);
          final labelText = _localizedCategory(l10n, category);

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
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withOpacity(0.3),
              onSelected: (_) => onCategorySelected(category),
              deleteIcon: isDeletable ? const Icon(Icons.close) : null,
              deleteButtonTooltipMessage: isDeletable
                  ? l10n.chipDeleteCategoryTooltip
                  : null,
              onDeleted: isDeletable
                  ? () => onCategoryDeleted?.call(category)
                  : null,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected
                      ? primary
                      : theme.colorScheme.outline.withOpacity(0.4),
                  width: 1.2,
                ),
              ),
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

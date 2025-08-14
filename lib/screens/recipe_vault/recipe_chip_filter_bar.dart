// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeChipFilterBar extends StatelessWidget {
  final List<String> categories; // may contain localised labels
  final String selectedCategory; // may be a key or localised label
  final void Function(String category)
  onCategorySelected; // receives canonical key
  final void Function(String category)?
  onCategoryDeleted; // receives canonical key
  final List<RecipeCardModel> allRecipes;

  const RecipeChipFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onCategoryDeleted,
    required this.allRecipes,
  });

  /// Canonical keys for the 3 system categories
  static const _systemCategories = ['All', 'Favourites', 'Translated'];

  /// Map any incoming label (possibly localised) back to its canonical key.
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
    // Normalise each recipe’s categories before checking usage
    return allRecipes.any(
      (r) => r.categories
          .map((c) => _canonicalCategory(l10n, c))
          .contains(canonicalKey),
    );
  }

  bool _isProtectedCategory(String canonicalKey, bool isFreeUser) {
    // Always protect All, Favourites, Translated
    if (_systemCategories.contains(canonicalKey)) return true;

    // Example: could protect certain defaults for free tier only
    // if (isFreeUser && _protectedDefaults.contains(canonicalKey)) return true;

    return false;
  }

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
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final isFreeUser = subscriptionService.tier == 'free';

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final textStyle = theme.textTheme.bodySmall;

    final selectedKey = _canonicalCategory(l10n, selectedCategory);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: categories.map((rawCategory) {
          final key = _canonicalCategory(l10n, rawCategory);

          final isSelected = key == selectedKey;
          final isProtected = _isProtectedCategory(key, isFreeUser);
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
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withOpacity(0.3),
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

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

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

  static const _systemCategories = ['All', 'Favourites', 'Translated'];

  bool _isCategoryUsed(String category) {
    return allRecipes.any((r) => r.categories.contains(category));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final textStyle = theme.textTheme.bodySmall;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: categories.map((category) {
          final isSelected = category == selectedCategory;
          final isDeletable =
              !_systemCategories.contains(category) &&
              !_isCategoryUsed(category);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              label: Text(
                category,
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
              onDeleted: isDeletable
                  ? () => onCategoryDeleted?.call(category)
                  : null,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected ? primary : Colors.transparent,
                  width: 1.4,
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

import 'package:flutter/material.dart';

class RecipeCategoryFilterBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final void Function(String category) onCategorySelected;
  final void Function(String category)? onCategoryDeleted;

  const RecipeCategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.onCategoryDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: categories.map((category) {
          final selected = category == selectedCategory;
          final isDeletable = ![
            'All',
            'Favourites',
            'Translated',
          ].contains(category);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              label: Text(category),
              selected: selected,
              onSelected: (_) => onCategorySelected(category),
              deleteIcon: isDeletable ? const Icon(Icons.close) : null,
              onDeleted: isDeletable
                  ? () => onCategoryDeleted?.call(category)
                  : null,
              selectedColor: primary.withAlpha(50), // ~20% opacity replacement
            ),
          );
        }).toList(),
      ),
    );
  }
}

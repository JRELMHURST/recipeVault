import 'package:flutter/material.dart';

class RecipeCategoryFilterBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final void Function(String category) onCategorySelected;

  const RecipeCategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: categories.map((category) {
          final selected = category == selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: selected,
              onSelected: (_) => onCategorySelected(category),
            ),
          );
        }).toList(),
      ),
    );
  }
}

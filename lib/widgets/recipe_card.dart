import 'package:flutter/material.dart';

class RecipeCard extends StatelessWidget {
  final String recipeText;

  const RecipeCard({super.key, required this.recipeText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: theme.colorScheme.surface,
          child: SelectableText(
            recipeText.trim(),
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

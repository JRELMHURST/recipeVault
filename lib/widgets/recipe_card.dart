// lib/widgets/recipe_card.dart
import 'package:flutter/material.dart';

class RecipeCard extends StatelessWidget {
  final String recipeText;

  const RecipeCard({super.key, required this.recipeText});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            recipeText,
            style: textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ),
      ),
    );
  }
}

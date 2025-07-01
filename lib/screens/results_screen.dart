import 'package:flutter/material.dart';
import '../widgets/recipe_card.dart';

class ResultsScreen extends StatelessWidget {
  final String ocrText;

  const ResultsScreen({super.key, required this.ocrText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formatted Recipe')),
      body: RecipeCard(recipeText: ocrText),
    );
  }
}

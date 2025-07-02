import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/recipe_card.dart';

class ResultsScreen extends StatelessWidget {
  final String ocrText;

  const ResultsScreen({super.key, required this.ocrText});

  @override
  Widget build(BuildContext context) {
    final bool hasValidContent =
        ocrText.trim().isNotEmpty && !ocrText.contains('error');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Recipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: ocrText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recipe copied to clipboard')),
              );
            },
            tooltip: 'Copy to clipboard',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: hasValidContent
            ? SingleChildScrollView(child: RecipeCard(recipeText: ocrText))
            : Center(
                child: Text(
                  'Whoops! Looks like something went wrong with formatting.\n\nPlease try again.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}

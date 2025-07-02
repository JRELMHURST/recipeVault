import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../widgets/recipe_card.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Pull formattedRecipe from GoRouter extra
    final formattedRecipe = GoRouterState.of(context).extra as String? ?? '';

    final bool hasValidContent =
        formattedRecipe.trim().isNotEmpty &&
        !formattedRecipe.toLowerCase().contains('error');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Recipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: formattedRecipe));
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
            ? SingleChildScrollView(
                child: RecipeCard(recipeText: formattedRecipe),
              )
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

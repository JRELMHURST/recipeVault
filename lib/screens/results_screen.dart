import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../widgets/recipe_card.dart';
import '../core/theme.dart'; // Make sure this import path matches your structure

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
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: const Text(
          'Your Recipe',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (hasValidContent)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy to clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedRecipe));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recipe copied to clipboard')),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: hasValidContent
            ? SingleChildScrollView(
                child: RecipeCard(recipeText: formattedRecipe),
              )
            : Center(
                child: Card(
                  elevation: 4,
                  color: Colors.red[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.redAccent, width: 1.3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[400],
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Whoops! Looks like something went wrong with formatting.\n\nPlease try again.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/recipe_card.dart';
import '../core/theme.dart';
import '../model/recipe_card_model.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isSaving = false;

  Future<void> _saveRecipe(String formattedRecipe) async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not signed in");

      final lines = formattedRecipe.trim().split('\n');
      String title = 'Untitled';
      List<String> ingredients = [];
      List<String> instructions = [];
      bool inIngredients = false, inInstructions = false;

      for (final line in lines) {
        if (line.toLowerCase().startsWith('title:')) {
          title = line.split(':').skip(1).join(':').trim();
        } else if (line.toLowerCase().contains('ingredients:')) {
          inIngredients = true;
          inInstructions = false;
        } else if (line.toLowerCase().contains('instructions:')) {
          inIngredients = false;
          inInstructions = true;
        } else if (inIngredients && line.trim().startsWith('-')) {
          ingredients.add(line.replaceFirst('-', '').trim());
        } else if (inInstructions && RegExp(r'^\d+').hasMatch(line.trim())) {
          instructions.add(line.replaceFirst(RegExp(r'^\d+\.?'), '').trim());
        }
      }

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recipes')
          .doc();

      final recipe = RecipeCardModel(
        id: docRef.id,
        userId: user.uid,
        title: title,
        ingredients: ingredients,
        instructions: instructions,
      );

      await docRef.set(recipe.toJson());

      // ✅ Show confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Recipe saved! Taking you to your Vault...'),
          duration: Duration(seconds: 2),
        ),
      );

      // ✅ Wait before navigating (so snackbar is visible)
      await Future.delayed(const Duration(milliseconds: 1500));
      GoRouter.of(context).go('/home?tab=1');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Failed to save recipe: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const SnackBar(
                    content: Text('📋 Recipe copied to clipboard'),
                  ),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: hasValidContent
            ? SingleChildScrollView(
                child: Column(
                  children: [
                    RecipeCard(recipeText: formattedRecipe),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _saveRecipe(formattedRecipe),
                      icon: const Icon(Icons.save_alt_rounded),
                      label: _isSaving
                          ? const Text('Saving...')
                          : const Text('Save to Vault'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
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

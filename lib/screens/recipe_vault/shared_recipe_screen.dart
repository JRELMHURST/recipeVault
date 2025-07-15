import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';

class SharedRecipeScreen extends StatefulWidget {
  final String recipeId;

  const SharedRecipeScreen({super.key, required this.recipeId});

  @override
  State<SharedRecipeScreen> createState() => _SharedRecipeScreenState();
}

class _SharedRecipeScreenState extends State<SharedRecipeScreen> {
  RecipeCardModel? _recipe;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSharedRecipe();
  }

  Future<void> _loadSharedRecipe() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shared_recipes')
          .doc(widget.recipeId)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'This shared recipe could not be found.';
          _loading = false;
        });
        return;
      }

      final data = doc.data()!;
      final recipe = RecipeCardModel.fromMap(data);

      setState(() {
        _recipe = recipe;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'An error occurred while loading the recipe.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingOverlay();
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shared Recipe')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_recipe!.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RecipeCard(recipeText: _recipe!.formattedText),
      ),
    );
  }
}

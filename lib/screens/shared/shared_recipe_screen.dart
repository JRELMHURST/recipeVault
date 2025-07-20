import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

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

      final data = doc.data();
      if (!doc.exists || data == null) {
        setState(() {
          _error = 'This shared recipe could not be found.';
          _loading = false;
        });
        return;
      }

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

  void _shareLink() {
    final url = 'https://recipevault.app/shared/${widget.recipeId}';

    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero) & box.size;
      Share.share(
        'Check out this recipe on RecipeVault:\n$url',
        sharePositionOrigin: origin,
      );
    } else {
      Share.share('Check out this recipe on RecipeVault:\n$url');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingOverlay();

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shared Recipe')),
        body: Center(child: Text(_error!)),
      );
    }

    final recipe = _recipe!;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLink,
            tooltip: 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ResponsiveWrapper(
          child: RecipeCard(recipeText: recipe.formattedText),
        ),
      ),
    );
  }
}

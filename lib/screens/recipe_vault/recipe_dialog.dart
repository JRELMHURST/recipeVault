// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_utils.dart';
import 'package:recipe_vault/utils/recipe_pdf_generator.dart';

void showRecipeDialog(BuildContext context, RecipeCardModel recipe) {
  final markdown = formatRecipeMarkdown(recipe);

  showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _ShareableRecipeCard(
        markdown: markdown,
        title: recipe.title,
        imageUrl: recipe.imageUrl,
        recipeId: recipe.id,
        userId: recipe.userId,
        ingredients: recipe.ingredients,
        method: recipe.method,
      ),
    ),
  );
}

class _ShareableRecipeCard extends StatefulWidget {
  final String markdown;
  final String title;
  final String? imageUrl;
  final String recipeId;
  final String userId;
  final List<String> ingredients;
  final String method;

  const _ShareableRecipeCard({
    required this.markdown,
    required this.title,
    required this.recipeId,
    required this.userId,
    required this.ingredients,
    required this.method,
    this.imageUrl,
  });

  @override
  State<_ShareableRecipeCard> createState() => _ShareableRecipeCardState();
}

class _ShareableRecipeCardState extends State<_ShareableRecipeCard> {
  Color iconColor = Colors.black;
  bool _iconReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndUpdateIconColor();
    });
  }

  @override
  void didUpdateWidget(covariant _ShareableRecipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl && widget.imageUrl != null) {
      _loadAndUpdateIconColor();
    }
  }

  Future<void> _loadAndUpdateIconColor() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return;

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(widget.imageUrl!),
        size: const Size(100, 100),
      );

      final dominant = palette.dominantColor?.color;
      final brightness = dominant?.computeLuminance();

      setState(() {
        iconColor = (brightness != null && brightness > 0.5)
            ? Colors.black
            : Colors.white;
        _iconReady = true;
      });
    } catch (_) {
      setState(() {
        iconColor = Colors.white;
        _iconReady = true;
      });
    }
  }

  Future<void> _shareAsPdf(BuildContext context) async {
    final recipe = RecipeCardModel(
      id: widget.recipeId,
      userId: widget.userId,
      title: widget.title,
      ingredients: widget.ingredients,
      method: widget.method,
      imageUrl: widget.imageUrl,
      createdAt: DateTime.now(),
    );

    await RecipePdfGenerator.sharePdf(recipe);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    widget.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!_iconReady) _loadAndUpdateIconColor();
                        });
                        return child;
                      }
                      return Container(
                        height: 200,
                        color: Colors.deepPurple.shade50,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.deepPurple.shade50,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: RecipeCard(recipeText: widget.markdown),
              ),
            ],
          ),
        ),
        if (_iconReady)
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.share,
                      color: iconColor,
                      shadows: const [
                        Shadow(
                          blurRadius: 4,
                          offset: Offset(1, 1),
                          color: Colors.black45,
                        ),
                      ],
                    ),
                    tooltip: 'Share as PDF',
                    onPressed: () => _shareAsPdf(context),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: iconColor,
                      shadows: const [
                        Shadow(
                          blurRadius: 4,
                          offset: Offset(1, 1),
                          color: Colors.black45,
                        ),
                      ],
                    ),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

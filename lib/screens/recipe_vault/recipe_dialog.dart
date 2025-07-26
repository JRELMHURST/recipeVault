import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_utils.dart';

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
      ),
    ),
  );
}

class _ShareableRecipeCard extends StatefulWidget {
  final String markdown;
  final String title;
  final String? imageUrl;
  final String recipeId;

  const _ShareableRecipeCard({
    required this.markdown,
    required this.title,
    required this.recipeId,
    this.imageUrl,
  });

  @override
  State<_ShareableRecipeCard> createState() => _ShareableRecipeCardState();
}

class _ShareableRecipeCardState extends State<_ShareableRecipeCard> {
  Color iconColor = Colors.black;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _updateIconColor(widget.imageUrl!);
    }
  }

  Future<void> _updateIconColor(String imageUrl) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(100, 100),
      );
      final dominant = palette.dominantColor?.color;
      if (dominant != null) {
        final brightness = dominant.computeLuminance();
        setState(() {
          iconColor = brightness > 0.5 ? Colors.black : Colors.white;
        });
      }
    } catch (_) {
      setState(() {
        iconColor = Colors.black;
      });
    }
  }

  Future<void> _shareLink(BuildContext context) async {
    final recipeLink =
        'https://recipes.badger-creations.co.uk/shared/${Uri.encodeComponent(widget.recipeId)}';
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero) & box.size;
      await Share.share(
        recipeLink,
        subject: 'Check out this recipe on RecipeVault!',
        sharePositionOrigin: origin,
      );
    } else {
      await Share.share(
        recipeLink,
        subject: '📋 ${widget.title} – via RecipeVault',
      );
    }
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
                      if (loadingProgress == null) return child;
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
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.share, color: iconColor),
                tooltip: 'Share recipe',
                onPressed: () => _shareLink(context),
              ),
              IconButton(
                icon: Icon(Icons.close, color: iconColor),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

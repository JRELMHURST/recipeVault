// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';
import 'package:recipe_vault/utils/recipe_pdf_generator.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

void showRecipeDialog(BuildContext context, RecipeCardModel recipe) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _ShareableRecipeCard(recipe: recipe),
    ),
  );
}

class _ShareableRecipeCard extends StatefulWidget {
  final RecipeCardModel recipe;

  const _ShareableRecipeCard({required this.recipe});

  @override
  State<_ShareableRecipeCard> createState() => _ShareableRecipeCardState();
}

class _ShareableRecipeCardState extends State<_ShareableRecipeCard> {
  Color iconColor = Colors.white;
  bool _iconReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadAndUpdateIconColor(),
    );
  }

  @override
  void didUpdateWidget(covariant _ShareableRecipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe.imageUrl != widget.recipe.imageUrl &&
        (widget.recipe.imageUrl ?? '').isNotEmpty) {
      _loadAndUpdateIconColor();
    }
  }

  Future<void> _loadAndUpdateIconColor() async {
    final url = widget.recipe.imageUrl;
    if (url == null || url.isEmpty) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
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
    await RecipePdfGenerator.sharePdf(widget.recipe);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final imageUrl = widget.recipe.imageUrl;

    // 🔑 Get locale tag & best-match formatted text
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final formattedText = widget.recipe.formattedForLocaleTag(localeTag);
    final safeTitle = widget.recipe.title.trim().isNotEmpty
        ? widget.recipe.title.trim()
        : l10n.untitled;

    debugPrint('🌍 Requested locale: $localeTag');
    debugPrint(
      '🗂️ Available formatted locales: ${widget.recipe.formattedByLocale.keys}',
    );
    debugPrint(
      '📄 Using formatted text: ${formattedText?.substring(0, (formattedText.length > 40 ? 40 : formattedText.length)) ?? "null"}',
    );

    // 🔑 Decide what to render inside card
    final hasStructured =
        widget.recipe.ingredients.isNotEmpty ||
        widget.recipe.instructions.isNotEmpty ||
        widget.recipe.hints.isNotEmpty;

    Widget recipeBody;
    if (hasStructured) {
      recipeBody = RecipeCard.fromModel(widget.recipe);
    } else if (formattedText != null && formattedText.trim().isNotEmpty) {
      recipeBody = Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            formattedText,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
          ),
        ),
      );
    } else {
      recipeBody = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.noRecipeDataFound),
        ),
      );
    }

    final header = (imageUrl != null && imageUrl.isNotEmpty)
        ? ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_iconReady) _loadAndUpdateIconColor();
                  });
                  return child;
                }
                return Semantics(
                  label: l10n.loading,
                  child: Container(
                    height: 200,
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              semanticLabel: safeTitle,
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(label: safeTitle, child: recipeBody),
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
              _roundIconButton(
                context: context,
                icon: Icons.share,
                tooltip: l10n.shareAsPdf,
                onPressed: () => _shareAsPdf(context),
              ),
              const SizedBox(width: 4),
              _roundIconButton(
                context: context,
                icon: Icons.close,
                tooltip: l10n.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundIconButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final Color fg = _iconReady ? iconColor : Colors.white;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.4),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: fg,
          shadows: const [
            Shadow(blurRadius: 4, offset: Offset(1, 1), color: Colors.black45),
          ],
        ),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

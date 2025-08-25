// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';

class RecipeCard extends StatelessWidget {
  // Legacy path (still used by ResultsScreen)
  final String? recipeText;

  // New path (preferred for saved cards / dialog)
  final RecipeCardModel? recipe;

  const RecipeCard({super.key, required String this.recipeText})
    : recipe = null;

  const RecipeCard.fromModel(this.recipe, {super.key}) : recipeText = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = theme.colorScheme;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final maxWidth = constraints.maxWidth > 600
            ? 600.0
            : constraints.maxWidth;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colour.primary.withOpacity(0.25),
                  width: 1.1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 4, color: colour.primary),
                  Container(
                    color: theme.cardColor,
                    padding: const EdgeInsets.all(20),
                    child: recipe != null
                        ? _buildFromModel(context, recipe!, theme)
                        : _buildFromText(context, recipeText ?? "", theme),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Render from model (no parsing, no weird slashes) ----------
  Widget _buildFromModel(
    BuildContext context,
    RecipeCardModel model,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        Text(
          (model.title.isEmpty ? 'Untitled' : model.title),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          softWrap: true,
        ),
        const SizedBox(height: 12),

        // Ingredients
        if (model.ingredients.isNotEmpty) ...[
          _sectionHeader('🛒 Ingredients', theme),
          const SizedBox(height: 6),
          ...model.ingredients.map(_bullet),
          const SizedBox(height: 16),
        ],

        // Instructions
        if (model.instructions.isNotEmpty) ...[
          _sectionHeader('👨‍🍳 Instructions', theme),
          const SizedBox(height: 6),
          ...model.instructions.asMap().entries.map(
            (e) => _numbered(
              // add numbering if missing
              RegExp(r'^\d+[\).]\s').hasMatch(e.value)
                  ? e.value
                  : '${e.key + 1}. ${e.value}',
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Hints
        if (model.hints.isNotEmpty) ...[
          _sectionHeader('💡 Hints & Tips', theme),
          const SizedBox(height: 6),
          ...model.hints.map(_bullet),
        ],
      ],
    );
  }

  // ---------- Legacy path (still supports ResultsScreen text) ----------
  Widget _buildFromText(BuildContext context, String text, ThemeData theme) {
    final parsed = _parseRecipe(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          parsed.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          softWrap: true,
        ),
        const SizedBox(height: 12),

        if (parsed.ingredients.isNotEmpty) ...[
          _sectionHeader('🛒 Ingredients', theme),
          const SizedBox(height: 6),
          ...parsed.ingredients.map(_bullet),
          const SizedBox(height: 16),
        ],

        if (parsed.instructions.isNotEmpty) ...[
          _sectionHeader('👨‍🍳 Instructions', theme),
          const SizedBox(height: 6),
          ...parsed.instructions.map(_numbered),
          const SizedBox(height: 16),
        ],

        if (parsed.hints.isNotEmpty) ...[
          _sectionHeader('💡 Hints & Tips', theme),
          const SizedBox(height: 6),
          ...parsed.hints.map(_bullet),
        ],
      ],
    );
  }

  Widget _sectionHeader(String text, ThemeData theme) => Text(
    text,
    style: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 16)),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _numbered(String text) {
    final match = RegExp(r'^(\d+[\).])\s*').firstMatch(text.trim());
    final number = match?.group(1) ?? '';
    final content = text.trim().replaceFirst(RegExp(r'^\d+[\).]\s*'), '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(content)),
        ],
      ),
    );
  }

  // ------- simple parser for legacy text path -------
  _ParsedRecipe _parseRecipe(String text) {
    final lines = text.trim().split('\n');
    String title = 'Untitled';
    final Set<String> ingredients = {};
    final List<String> instructions = [];
    final List<String> hints = [];

    bool inIngredients = false, inInstructions = false, inHints = false;

    for (final raw in lines) {
      final line = raw.trim();
      final lower = line.toLowerCase();

      if (lower.startsWith('title:')) {
        title = line.split(':').skip(1).join(':').trim();
        continue;
      }
      if (lower.startsWith('ingredients:')) {
        inIngredients = true;
        inInstructions = false;
        inHints = false;
        continue;
      }
      if (lower.startsWith('instructions:')) {
        inIngredients = false;
        inInstructions = true;
        inHints = false;
        continue;
      }
      if (lower.startsWith('hints & tips:') ||
          lower.startsWith('hints and tips:')) {
        inIngredients = false;
        inInstructions = false;
        inHints = true;
        continue;
      }

      if (inIngredients && line.startsWith('-')) {
        final ing = line.substring(1).trim();
        if (ing.isNotEmpty) ingredients.add(ing);
      } else if (inInstructions && RegExp(r'^\d+[\).]').hasMatch(line)) {
        instructions.add(line);
      } else if (inHints) {
        final clean = line.replaceFirst(RegExp(r'^[-•]+\s*'), '').trim();
        if (clean.isEmpty) continue;
        if (clean.toLowerCase().contains('no additional tips')) continue;
        hints.add(clean);
      }
    }

    return _ParsedRecipe(title, ingredients.toList(), instructions, hints);
  }
}

class _ParsedRecipe {
  final String title;
  final List<String> ingredients;
  final List<String> instructions;
  final List<String> hints;
  _ParsedRecipe(this.title, this.ingredients, this.instructions, this.hints);
}

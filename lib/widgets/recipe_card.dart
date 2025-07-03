// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class RecipeCard extends StatelessWidget {
  final String recipeText;

  const RecipeCard({super.key, required this.recipeText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final recipeTitle = _extractTitle(recipeText);
    final recipeBody = _stripTitleHeader(recipeText);

    final mdStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      h1: theme.textTheme.titleLarge?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h2: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      blockSpacing: 12,
      listIndent: 24,
    );

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
                  color: colorScheme.primary.withOpacity(0.25),
                  width: 1.1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 4, color: colorScheme.primary),
                  Container(
                    color: theme.cardColor,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          recipeTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Divider(
                          thickness: 1.4,
                          color: colorScheme.outline.withOpacity(0.25),
                        ),
                        const SizedBox(height: 12),
                        MarkdownBody(
                          data: _getFormattedRecipeBody(recipeBody),
                          selectable: true,
                          styleSheet: mdStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _extractTitle(String txt) {
    final lines = txt.trim().split('\n');
    for (final line in lines) {
      final lower = line.trim().toLowerCase();
      if (lower.startsWith('title:')) {
        return line.split(':').skip(1).join(':').trim();
      } else if (lower.startsWith('#')) {
        return line.replaceFirst('#', '').trim();
      }
    }
    return 'Your Recipe';
  }

  String _stripTitleHeader(String txt) {
    final lines = txt.trim().split('\n');
    return lines
        .where((line) => !line.toLowerCase().startsWith('title:'))
        .join('\n');
  }

  String _getFormattedRecipeBody(String body) {
    final cleaned = body.trim();
    if (cleaned.isEmpty ||
        !(cleaned.contains('Ingredients') ||
            cleaned.contains('Instructions'))) {
      return '*No formatted recipe found.*';
    }
    return cleaned;
  }
}

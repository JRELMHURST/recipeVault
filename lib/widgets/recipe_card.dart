// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class RecipeCard extends StatelessWidget {
  final String recipeText;

  const RecipeCard({super.key, required this.recipeText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final bg = theme.colorScheme.surfaceContainerHighest;
    final text = theme.colorScheme.onSurface;

    final mdStyle = MarkdownStyleSheet(
      h1: theme.textTheme.titleLarge!.copyWith(
        color: primary,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h2: theme.textTheme.titleMedium!.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      p: theme.textTheme.bodyMedium!.copyWith(color: text, height: 1.5),
      listBullet: theme.textTheme.bodyMedium!.copyWith(color: text),
      blockSpacing: 12,
      listIndent: 24,
    );

    final recipeTitle = _extractTitle(recipeText);
    final recipeBody = _stripTitleHeader(recipeText);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final maxWidth = constraints.maxWidth > 600
            ? 600.0
            : constraints.maxWidth;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: primary.withOpacity(0.25), width: 1.1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(height: 4, color: primary),
                  Container(
                    color: bg,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          recipeTitle,
                          style: theme.textTheme.titleLarge!.copyWith(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Divider(color: primary, thickness: 2),
                        const SizedBox(height: 16),
                        MarkdownBody(
                          data: recipeBody.trim(),
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

  // Extracts 'Title: ...' as the title for the card
  String _extractTitle(String txt) {
    final lines = txt.trim().split('\n');
    for (final line in lines) {
      if (line.trim().toLowerCase().startsWith('title:')) {
        return line.split(':').skip(1).join(':').trim();
      }
    }
    return 'Your Recipe';
  }

  // Removes the 'Title: ...' line from the markdown body
  String _stripTitleHeader(String txt) {
    final lines = txt.trim().split('\n');
    if (lines.isNotEmpty && lines[0].toLowerCase().startsWith('title')) {
      return lines.sublist(1).join('\n');
    }
    // fallback if not at top
    final filtered = lines
        .where((line) => !line.toLowerCase().startsWith('title:'))
        .toList();
    return filtered.join('\n');
  }
}

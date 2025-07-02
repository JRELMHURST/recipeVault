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
                          _extractTitle(recipeText),
                          style: theme.textTheme.titleLarge!.copyWith(
                            color: primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Divider(color: primary, thickness: 2),
                        const SizedBox(height: 16),
                        MarkdownBody(
                          data: _stripTitleHeader(recipeText),
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
    if (lines.isNotEmpty && lines[0].toLowerCase().startsWith('title')) {
      return lines[0].split(':').last.trim();
    }
    return 'Your Recipe';
  }

  String _stripTitleHeader(String txt) {
    final lines = txt.trim().split('\n');
    if (lines.isNotEmpty && lines[0].toLowerCase().startsWith('title')) {
      return lines.sublist(1).join('\n');
    }
    return txt;
  }
}

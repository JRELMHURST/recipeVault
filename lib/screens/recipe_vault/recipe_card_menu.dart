import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeCardMenu extends StatelessWidget {
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback? onAssignCategories;

  const RecipeCardMenu({
    super.key,
    required this.isFavourite,
    required this.onToggleFavourite,
    this.onAssignCategories,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<_RecipeCardMenuAction>(
      icon: const Icon(LucideIcons.moreHorizontal),
      tooltip: l10n.menuMoreOptions, // optional but helpful
      onSelected: (action) {
        switch (action) {
          case _RecipeCardMenuAction.favourite:
            onToggleFavourite();
            break;
          case _RecipeCardMenuAction.assignCategories:
            onAssignCategories?.call();
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<_RecipeCardMenuAction>>[
          PopupMenuItem(
            value: _RecipeCardMenuAction.favourite,
            child: Text(
              isFavourite ? l10n.menuUnfavourite : l10n.menuFavourite,
            ),
          ),
        ];

        if (onAssignCategories != null) {
          items.add(
            PopupMenuItem(
              value: _RecipeCardMenuAction.assignCategories,
              child: Text(l10n.menuAssignCategories),
            ),
          );
        }

        return items;
      },
    );
  }
}

enum _RecipeCardMenuAction { favourite, assignCategories }

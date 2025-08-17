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

    return PopupMenuButton<RecipeCardMenuAction>(
      icon: const Icon(LucideIcons.moreHorizontal),
      tooltip: l10n.menuMoreOptions,
      onSelected: (action) {
        switch (action) {
          case RecipeCardMenuAction.favourite:
            onToggleFavourite();
            break;
          case RecipeCardMenuAction.assignCategories:
            onAssignCategories?.call();
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<RecipeCardMenuAction>>[
          PopupMenuItem(
            value: RecipeCardMenuAction.favourite,
            child: Text(
              isFavourite ? l10n.menuUnfavourite : l10n.menuFavourite,
            ),
          ),
        ];

        if (onAssignCategories != null) {
          items.add(
            PopupMenuItem(
              value: RecipeCardMenuAction.assignCategories,
              child: Text(l10n.menuAssignCategories),
            ),
          );
        }

        return items;
      },
    );
  }
}

/// Public so it can be referenced in parent widgets, tests, etc.
enum RecipeCardMenuAction { favourite, assignCategories }

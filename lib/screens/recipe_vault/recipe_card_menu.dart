import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RecipeCardMenu extends StatelessWidget {
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback? onAssignCategories; // Made optional

  const RecipeCardMenu({
    super.key,
    required this.isFavourite,
    required this.onToggleFavourite,
    this.onAssignCategories, // Optional in constructor
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_RecipeCardMenuAction>(
      icon: const Icon(LucideIcons.moreHorizontal),
      onSelected: (action) {
        switch (action) {
          case _RecipeCardMenuAction.favourite:
            onToggleFavourite();
            break;
          case _RecipeCardMenuAction.assignCategories:
            if (onAssignCategories != null) {
              onAssignCategories!();
            }
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<_RecipeCardMenuAction>>[
          PopupMenuItem(
            value: _RecipeCardMenuAction.favourite,
            child: Text(isFavourite ? 'Unfavourite' : 'Favourite'),
          ),
        ];

        if (onAssignCategories != null) {
          items.add(
            const PopupMenuItem(
              value: _RecipeCardMenuAction.assignCategories,
              child: Text('Assign categories'),
            ),
          );
        }

        return items;
      },
    );
  }
}

enum _RecipeCardMenuAction { favourite, assignCategories }

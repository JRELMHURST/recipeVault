import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RecipeCardMenu extends StatelessWidget {
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback onAssignCategories;

  const RecipeCardMenu({
    super.key,
    required this.isFavourite,
    required this.onToggleFavourite,
    required this.onAssignCategories,
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
            onAssignCategories();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _RecipeCardMenuAction.favourite,
          child: Text(isFavourite ? 'Unfavourite' : 'Favourite'),
        ),
        const PopupMenuItem(
          value: _RecipeCardMenuAction.assignCategories,
          child: Text('Assign categories'),
        ),
      ],
    );
  }
}

enum _RecipeCardMenuAction { favourite, assignCategories }

import 'package:flutter/material.dart';
import 'package:recipe_vault/screens/recipe_vault/dismissable_bubble.dart';

class RecipeVaultBubbles extends StatelessWidget {
  final bool showScan;
  final bool showViewToggle;
  final bool showLongPress;
  final VoidCallback onDismissScan;
  final VoidCallback onDismissViewToggle;
  final VoidCallback onDismissLongPress;

  const RecipeVaultBubbles({
    super.key,
    required this.showScan,
    required this.showViewToggle,
    required this.showLongPress,
    required this.onDismissScan,
    required this.onDismissViewToggle,
    required this.onDismissLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomInset = mediaQuery.padding.bottom;

    final scanOffset = Offset(54, screenHeight - bottomInset - 320);

    const viewToggleOffset = Offset(20, kToolbarHeight - 50);
    const longPressOffset = Offset(40, 200);

    // Show one bubble at a time based on priority
    if (showScan) {
      return Stack(
        children: [
          DismissibleBubble(
            message: '🧪 Scan Recipes\nTap here to upload your recipe images.',
            position: scanOffset,
            onDismiss: onDismissScan,
          ),
        ],
      );
    } else if (showViewToggle) {
      return Stack(
        children: [
          DismissibleBubble(
            message:
                '👁️ Switch Views\nTap to change how recipes are displayed.',
            position: viewToggleOffset,
            onDismiss: onDismissViewToggle,
          ),
        ],
      );
    } else if (showLongPress) {
      return Stack(
        children: [
          DismissibleBubble(
            message: '📌 Long-press a recipe\nFavourite or assign a category.',
            position: longPressOffset,
            onDismiss: onDismissLongPress,
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}

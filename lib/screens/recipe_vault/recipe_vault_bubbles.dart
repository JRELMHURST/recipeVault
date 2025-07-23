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

    // Push it further above FAB
    final scanOffset = Offset(
      24,
      screenHeight -
          bottomInset -
          320, // ⬅️ Increased offset to lift bubble higher
    );

    const viewToggleOffset = Offset(60, kToolbarHeight + 12);
    const longPressOffset = Offset(20, 220);

    return Stack(
      children: [
        if (showScan)
          DismissibleBubble(
            message: '🧪 Scan Recipes\nTap here to upload your recipe images.',
            position: scanOffset,
            onDismiss: onDismissScan,
          ),

        if (showViewToggle)
          DismissibleBubble(
            message:
                '👁️ Switch Views\nTap to change how recipes are displayed.',
            position: viewToggleOffset,
            onDismiss: onDismissViewToggle,
          ),

        if (showLongPress)
          DismissibleBubble(
            message: '📌 Long-press a recipe\nFavourite or assign a category.',
            position: longPressOffset,
            onDismiss: onDismissLongPress,
          ),
      ],
    );
  }
}

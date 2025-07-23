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

    final scanOffset = Offset(54, screenHeight - bottomInset - 350);
    const viewToggleOffset = Offset(20, kToolbarHeight - 50);
    const longPressOffset = Offset(40, 200);

    assert(
      [showScan, showViewToggle, showLongPress].where((x) => x).length <= 1,
      'Only one bubble should be visible at a time.',
    );

    return Stack(
      children: [
        if (showScan)
          DismissibleBubble(
            key: const ValueKey('bubble_scan'),
            message:
                '📸 Scan Recipes\nTap “Create” to upload and scan recipe images.',
            position: scanOffset,
            onDismiss: onDismissScan,
          ),
        if (showViewToggle)
          DismissibleBubble(
            key: const ValueKey('bubble_view_toggle'),
            message:
                '👁️ Switch Views\nTap to change how recipes are displayed.',
            position: viewToggleOffset,
            onDismiss: onDismissViewToggle,
          ),
        if (showLongPress)
          DismissibleBubble(
            key: const ValueKey('bubble_long_press'),
            message:
                '📌 Long-press a recipe\nTap and hold to favourite or assign a category.',
            position: longPressOffset,
            onDismiss: onDismissLongPress,
          ),
      ],
    );
  }
}

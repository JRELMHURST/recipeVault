import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
// If your file is actually named "dismissible_bubble.dart", update this import.
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
    final t = AppLocalizations.of(context);

    // Must be placed inside a Stack in the parent.
    return IgnorePointer(
      ignoring: false, // allow taps to reach Dismissible/InkWell
      child: Stack(
        children: [
          if (showViewToggle)
            DismissibleBubble(
              message: t.vaultBubbleSwitchViews,
              // near the AppBar/right side
              position: _posFrom(context, top: 56, right: 16),
              onDismiss: onDismissViewToggle,
            ),
          if (showLongPress)
            DismissibleBubble(
              message: t.vaultBubbleLongPress,
              // roughly centre; nudged up a bit
              position: _posFrom(
                context,
                topFraction: 0.40,
                leftFraction: 0.10,
              ),
              onDismiss: onDismissLongPress,
            ),
          if (showScan)
            DismissibleBubble(
              message: t.vaultBubbleScan,
              // above FAB area (bottom‑right)
              position: _posFrom(context, bottom: 96, right: 16),
              onDismiss: onDismissScan,
            ),
        ],
      ),
    );
  }

  /// Helper to place bubbles using either absolute (top/left/right/bottom)
  /// or screen‑fraction positions.
  Offset _posFrom(
    BuildContext context, {
    double? top,
    double? left,
    double? right,
    double? bottom,
    double? topFraction,
    double? leftFraction,
  }) {
    final size = MediaQuery.of(context).size;

    // If right/bottom provided, convert to left/top using screen size
    final resolvedLeft =
        left ??
        (right != null
            ? (size.width - right - 280)
            : (leftFraction != null ? size.width * leftFraction : 16));
    final resolvedTop =
        top ??
        (bottom != null
            ? (size.height - bottom - 80)
            : (topFraction != null ? size.height * topFraction : 80));

    // Clamp so it stays on‑screen
    final clampedLeft = resolvedLeft.clamp(8.0, size.width - 288.0);
    final clampedTop = resolvedTop.clamp(8.0, size.height - 120.0);

    return Offset(clampedLeft.toDouble(), clampedTop.toDouble());
  }
}

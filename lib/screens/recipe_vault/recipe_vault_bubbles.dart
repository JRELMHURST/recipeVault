import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
// Keep this import matching your actual file name.
import 'package:recipe_vault/screens/recipe_vault/dismissable_bubble.dart';

class RecipeVaultBubbles extends StatelessWidget {
  final bool showScan;
  final bool showViewToggle;
  final bool showLongPress;
  final VoidCallback onDismissScan;
  final VoidCallback onDismissViewToggle;
  final VoidCallback onDismissLongPress;

  /// Optional anchors – if provided, bubbles will position relative to these.
  final GlobalKey? keyFab; // e.g. wraps your CategorySpeedDial / FAB area
  final GlobalKey? keyViewToggle; // e.g. filter bar / toggle action
  final GlobalKey? keyFirstCard; // e.g. first list/grid item area

  const RecipeVaultBubbles({
    super.key,
    required this.showScan,
    required this.showViewToggle,
    required this.showLongPress,
    required this.onDismissScan,
    required this.onDismissViewToggle,
    required this.onDismissLongPress,
    this.keyFab,
    this.keyViewToggle,
    this.keyFirstCard,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    // Must be placed inside a Stack in the parent.
    return IgnorePointer(
      ignoring: false, // allow taps to pass through to page where appropriate
      child: Stack(
        children: [
          if (showViewToggle)
            DismissibleBubble(
              message: t.vaultBubbleSwitchViews,
              // Prefer anchor if provided; otherwise fallback to previous offsets.
              anchorKey: keyViewToggle,
              position: keyViewToggle == null
                  ? _posFrom(context, top: 56, right: 16)
                  : null,
              onDismiss: onDismissViewToggle,
            ),

          if (showLongPress)
            DismissibleBubble(
              message: t.vaultBubbleLongPress,
              anchorKey: keyFirstCard,
              position: keyFirstCard == null
                  ? _posFrom(context, topFraction: 0.40, leftFraction: 0.10)
                  : null,
              onDismiss: onDismissLongPress,
            ),

          if (showScan)
            DismissibleBubble(
              message: t.vaultBubbleScan,
              anchorKey: keyFab,
              position: keyFab == null
                  ? _posFrom(context, bottom: 96, right: 16)
                  : null,
              onDismiss: onDismissScan,
            ),
        ],
      ),
    );
  }

  /// Helper to place bubbles using either absolute (top/left/right/bottom)
  /// or screen‑fraction positions (backwards‑compatible fallback).
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

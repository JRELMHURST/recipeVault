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
              position:
                  _posFromAnchor(
                    context,
                    keyViewToggle,
                    // nudge up a bit so it sits above the chips/toggles
                    nudge: const Offset(0, -56),
                  ) ??
                  _posFrom(context, top: 56, right: 16),
              onDismiss: onDismissViewToggle,
            ),

          if (showLongPress)
            DismissibleBubble(
              message: t.vaultBubbleLongPress,
              position:
                  _posFromAnchor(
                    context,
                    keyFirstCard,
                    // nudge downward slightly to not cover the first card’s title
                    nudge: const Offset(0, 8),
                  ) ??
                  _posFrom(context, topFraction: 0.40, leftFraction: 0.10),
              onDismiss: onDismissLongPress,
            ),

          if (showScan)
            DismissibleBubble(
              message: t.vaultBubbleScan,
              position:
                  _posFromAnchor(
                    context,
                    keyFab,
                    // nudge upward/left so it points at the FAB
                    nudge: const Offset(-12, -72),
                  ) ??
                  _posFrom(context, bottom: 96, right: 16),
              onDismiss: onDismissScan,
            ),
        ],
      ),
    );
  }

  /// Compute a bubble position from an anchor GlobalKey.
  /// Converts the anchor’s global top-left to local coordinates of this widget,
  /// then applies an optional nudge so the bubble doesn’t overlap the anchor.
  Offset? _posFromAnchor(
    BuildContext context,
    GlobalKey? anchorKey, {
    Offset nudge = Offset.zero,
  }) {
    if (anchorKey == null) return null;
    final targetContext = anchorKey.currentContext;
    final selfRenderObject = context.findRenderObject();
    final targetRenderObject = targetContext?.findRenderObject();

    if (selfRenderObject is! RenderBox || targetRenderObject is! RenderBox) {
      return null;
    }

    // Global position of the anchor
    final targetGlobal = targetRenderObject.localToGlobal(Offset.zero);
    // Global position of this widget (the Stack container)
    final selfGlobal = selfRenderObject.localToGlobal(Offset.zero);
    // Convert to local coords (relative to the Stack)
    final localTopLeft = targetGlobal - selfGlobal;

    // Clamp within the current widget’s bounds with some bubble width/height margin.
    final size = selfRenderObject.size;
    final x = (localTopLeft.dx + nudge.dx).clamp(8.0, size.width - 288.0);
    final y = (localTopLeft.dy + nudge.dy).clamp(8.0, size.height - 120.0);

    return Offset(x.toDouble(), y.toDouble());
  }

  /// Helper to place bubbles using either absolute (top/left/right/bottom)
  /// or screen-fraction positions (backwards-compatible fallback).
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

    // Clamp so it stays on-screen
    final clampedLeft = resolvedLeft.clamp(8.0, size.width - 288.0);
    final clampedTop = resolvedTop.clamp(8.0, size.height - 120.0);

    return Offset(clampedLeft.toDouble(), clampedTop.toDouble());
  }
}

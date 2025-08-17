import 'package:flutter/material.dart';

/// A wrapper that constrains content to a maximum width and provides
/// consistent horizontal padding across all screen sizes.
///
/// Extras:
/// - [useSafeArea]: wrap content in SafeArea (off by default).
/// - [maxWidthLarge]: alternative cap for very wide screens (>= 1200px).
/// - [adaptToTextScale]: slightly widens cap for large text scales to prevent cramped layouts.
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  /// Max width for typical tablet/desktop layouts.
  final double maxWidth;

  /// Max width when the viewport is very wide (>= 1200px).
  /// If null, defaults to maxWidth * 1.2.
  final double? maxWidthLarge;

  /// Outer padding applied at all sizes.
  final EdgeInsetsGeometry padding;

  /// Wraps content in SafeArea when true.
  final bool useSafeArea;

  /// If true, slightly adapts the max width based on text scale.
  final bool adaptToTextScale;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.maxWidthLarge,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.useSafeArea = false,
    this.adaptToTextScale = true,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final textScale = mq.textScaler.scale(1.0);

    // Breakpoints
    const wideBp = 840.0; // tablet-ish
    const ultraBp = 1200.0; // desktop-ish

    double cap = maxWidth;

    if (width >= ultraBp) {
      cap = maxWidthLarge ?? (maxWidth * 1.2);
    } else if (width >= wideBp) {
      cap = maxWidth;
    } else {
      // phone widths → no hard cap; padding still applies
      cap = double.infinity;
    }

    // Keep line length readable when users crank text size way up.
    if (adaptToTextScale && cap.isFinite && textScale > 1.2) {
      // widen a touch but don't run away
      final factor = (textScale - 1.2).clamp(0.0, 0.6); // up to +60%
      cap = cap * (1.0 + factor * 0.5); // at most +30%
    }

    Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

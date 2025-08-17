import 'package:flutter/material.dart';

/// Global accessibility utilities and reusable widgets.
class Accessibility {
  /// True if "accessible navigation" is enabled (users prefer simpler navigation,
  /// often correlated with reduced motion / assistive tech usage).
  static bool accessibleNavigationEnabled(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Back-compat alias (was misnamed; not a true screen-reader detector).
  static bool isScreenReaderOn(BuildContext context) {
    return accessibleNavigationEnabled(context);
  }

  /// Returns a clamped TextScaler you can feed directly into MediaQuery.copyWith.
  ///
  /// Example:
  /// MediaQuery.of(context).copyWith(textScaler: Accessibility.clampedTextScaler(context))
  static TextScaler clampedTextScaler(
    BuildContext context, {
    double minScale = 1.0,
    double maxScale = 1.4,
  }) {
    final scale = MediaQuery.of(context).textScaler.scale(1.0);
    final clamped = scale.clamp(minScale, maxScale).toDouble();
    return TextScaler.linear(clamped);
  }

  /// Returns the *numeric* clamped scale if you only need the factor.
  static double constrainedTextScale(
    BuildContext context, {
    double minScale = 1.0,
    double maxScale = 1.4,
  }) {
    final scale = MediaQuery.of(context).textScaler.scale(1.0);
    return scale.clamp(minScale, maxScale).toDouble();
  }

  /// True if user prefers bold text (iOS) / enhanced legibility.
  static bool prefersBoldText(BuildContext context) {
    return MediaQuery.of(context).boldText;
  }
}

/// Wraps an [Image] with rich semantics for screen readers.
class AccessibleImage extends StatelessWidget {
  final String label;
  final String? hint;
  final String? value;
  final Image image;

  const AccessibleImage({
    super.key,
    required this.label,
    required this.image,
    this.hint,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: label,
        hint: hint,
        value: value,
        image: true,
        child: image,
      ),
    );
  }
}

/// Icon button with proper semantics and minimum tap target.
///
/// - Honors disabled state in semantics when [onPressed] is null.
/// - Keeps at least 48x48 hit area.
class AccessibleIconButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final Icon icon;
  final String? tooltip;

  const AccessibleIconButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.hint,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    // 48x48 is the recommended minimum hit area.
    final button = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        tooltip: tooltip ?? label,
      ),
    );

    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: onPressed != null,
      child: button,
    );
  }
}

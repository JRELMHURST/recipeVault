import 'package:flutter/material.dart';

/// Global accessibility utilities and reusable widgets.
class Accessibility {
  /// True if accessibility navigation is enabled (e.g., screen readers / switch control).
  static bool isScreenReaderOn(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Returns a safe text scale (linear) clamped to avoid UI breakage.
  static double constrainedTextScale(
    BuildContext context, {
    double minScale = 1.0,
    double maxScale = 1.4,
  }) {
    final s = MediaQuery.of(context).textScaler.scale(1.0);
    return s.clamp(minScale, maxScale);
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
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      image: true,
      child: image,
    );
  }
}

/// Icon button with proper semantics and minimum tap target.
class AccessibleIconButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback onPressed;
  final Icon icon;
  final String? tooltip;

  const AccessibleIconButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    this.hint,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    // 48x48 is the recommended minimum hit area.
    final button = SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        tooltip: tooltip ?? label,
      ),
    );

    return Semantics(label: label, hint: hint, button: true, child: button);
  }
}

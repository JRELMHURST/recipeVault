import 'package:flutter/material.dart';

/// Global accessibility utilities and reusable widgets.
class Accessibility {
  /// Returns true if accessibility navigation is enabled (e.g. for screen readers).
  static bool isScreenReaderOn(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Returns a safe default text scale factor (linear), clamped to avoid UI breakage.
  static double constrainedTextScale(
    BuildContext context, {
    double maxScale = 1.4,
  }) {
    final double userScale = MediaQuery.of(context).textScaler.scale(1.0);
    return userScale > maxScale ? maxScale : userScale;
  }
}

/// Wraps an [Image] widget with a semantic label for screen readers.
class AccessibleImage extends StatelessWidget {
  final String label;
  final Image image;

  const AccessibleImage({super.key, required this.label, required this.image});

  @override
  Widget build(BuildContext context) {
    return Semantics(label: label, image: true, child: image);
  }
}

/// A button with semantic label support, used for icons or gesture-based actions.
class AccessibleIconButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Icon icon;

  const AccessibleIconButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: IconButton(onPressed: onPressed, icon: icon),
    );
  }
}

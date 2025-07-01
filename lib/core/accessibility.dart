// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// Global accessibility utilities and reusable widgets.
class Accessibility {
  /// Returns true if accessibility services (e.g., TalkBack or VoiceOver) are active.
  static bool isScreenReaderOn(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Returns a safe default text scale factor.
  static double constrainedTextScale(
    BuildContext context, {
    double maxScale = 1.4,
  }) {
    final userScale = MediaQuery.of(context).textScaleFactor;
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

/// A button with semantic label support, used for icons or custom gestures.
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

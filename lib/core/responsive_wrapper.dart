import 'package:flutter/material.dart';

/// A wrapper that constrains content to a maximum width and provides
/// consistent horizontal padding across all screen sizes.
///
/// This is especially useful for tablet and desktop layouts, where
/// full-width content can look stretched or unbalanced.
///
/// Usage:
/// ```dart
/// ResponsiveWrapper(
///   maxWidth: 600, // Optional override
///   child: YourWidget(),
/// )
/// ```
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        final isWide = width > maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? maxWidth : double.infinity,
            ),
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }
}

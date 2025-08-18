// lib/navigation/transition_pages.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Simple fade transition (kept for existing routes).
CustomTransitionPage<T> fadePage<T>(
  Widget child, {
  LocalKey? key,
  Duration duration = const Duration(milliseconds: 220),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

/// Slide (with slight fade) that respects push/pop direction.
CustomTransitionPage<T> slidePage<T>(
  Widget child, {
  LocalKey? key,
  AxisDirection direction = AxisDirection.right,
  Duration duration = const Duration(milliseconds: 260),
}) {
  Offset begin;
  switch (direction) {
    case AxisDirection.right:
      begin = const Offset(1, 0); // enters from right, pops to right
      break;
    case AxisDirection.left:
      begin = const Offset(-1, 0); // enters from left, pops to left
      break;
    case AxisDirection.down:
      begin = const Offset(0, 1);
      break;
    case AxisDirection.up:
      begin = const Offset(0, -1);
      break;
  }

  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Convenience: slide from **right** (push) / slide to **right** (pop).
CustomTransitionPage<T> slideFromRightPage<T>(
  Widget child, {
  LocalKey? key,
  Duration duration = const Duration(milliseconds: 260),
}) {
  return slidePage<T>(
    child,
    key: key,
    direction: AxisDirection.right,
    duration: duration,
  );
}

/// ✅ NEW: Convenience: slide from **left** (push) / slide to **left** (pop).
CustomTransitionPage<T> slideFromLeftPage<T>(
  Widget child, {
  LocalKey? key,
  Duration duration = const Duration(milliseconds: 260),
}) {
  return slidePage<T>(
    child,
    key: key,
    direction: AxisDirection.left,
    duration: duration,
  );
}

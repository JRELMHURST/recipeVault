// lib/navigation/transition_pages.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

CustomTransitionPage fadePage(Widget child, {LocalKey? key}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

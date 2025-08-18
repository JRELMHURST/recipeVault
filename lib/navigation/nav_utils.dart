// lib/navigation/nav_utils.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void safeGo(BuildContext context, String location) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    context.go(location);
  });
}

void safeGoNamed(
  BuildContext context,
  String name, {
  Map<String, String>? pathParameters,
  Map<String, dynamic>? queryParameters,
  Object? extra,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    context.goNamed(
      name,
      pathParameters: pathParameters ?? const {},
      queryParameters: queryParameters ?? const {}, // ← fix
      extra: extra,
    );
  });
}

void safePop(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    context.pop();
  });
}

// lib/navigation/redirects.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/access_controller.dart';
import 'routes.dart';

String? appRedirect(
  BuildContext context,
  GoRouterState state,
  AccessController access,
) {
  final loc = state.matchedLocation;

  // 1) While resolving access → keep on /boot.
  if (!access.ready || access.status == EntitlementStatus.checking) {
    return (loc == AppRoutes.boot) ? null : AppRoutes.boot;
  }

  // 2) No access → force paywall.
  if (!access.hasAccess) {
    return (loc == AppRoutes.paywall) ? null : AppRoutes.paywall;
  }

  // 3) Access granted → keep out of boot/paywall.
  if (loc == AppRoutes.boot || loc == AppRoutes.paywall) {
    return AppRoutes.vault;
  }

  // 4) No redirect.
  return null;
}

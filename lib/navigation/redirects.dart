// lib/navigation/redirects.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/auth/access_controller.dart';
import 'routes.dart';

String? appRedirect(
  BuildContext context,
  GoRouterState state,
  AccessController access,
) {
  final loc = state.matchedLocation;
  final isManaging = state.uri.queryParameters['manage'] == '1';
  final isResolving =
      !access.ready || access.status == EntitlementStatus.checking;

  // 0) Not logged in → allow /login and /register only
  if (!access.isLoggedIn) {
    if (loc == AppRoutes.login || loc == AppRoutes.register) return null;
    return AppRoutes.login;
  }

  // 1) While resolving, pin to /boot (unless explicitly managing the paywall)
  if (isResolving) {
    if (loc == AppRoutes.paywall && isManaging) return null;
    return loc == AppRoutes.boot ? null : AppRoutes.boot;
  }

  // 2) If they have access (paid), keep them out of boot/paywall/auth
  if (access.hasAccess) {
    if (loc == AppRoutes.boot ||
        loc == AppRoutes.paywall ||
        loc == AppRoutes.login ||
        loc == AppRoutes.register) {
      return AppRoutes.vault;
    }
    return null; // no redirect
  }

  // 3) No access (paid-only app):
  //    Always show paywall, except allow /paywall?manage=1 as-is.
  if (loc == AppRoutes.paywall) return null;
  return AppRoutes.paywall;
}

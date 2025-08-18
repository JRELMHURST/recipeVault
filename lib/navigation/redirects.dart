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
  final resolving =
      !access.ready || access.status == EntitlementStatus.checking;

  // 0) Not logged in → force Login (but allow Login/Register themselves)
  if (!access.isLoggedIn) {
    if (loc == AppRoutes.login || loc == AppRoutes.register) return null;
    return AppRoutes.login;
  }

  // ✅ Always allow paywall when explicitly managing (even during resolving)
  if (loc == AppRoutes.paywall && isManaging) return null;

  // 1) Still resolving → keep on /boot (unless explicitly managing above)
  if (resolving) {
    return (loc == AppRoutes.boot) ? null : AppRoutes.boot;
  }

  // 2) Access active
  if (access.hasAccess) {
    // With access, only reach paywall when explicitly managing (handled above)
    if (loc == AppRoutes.boot ||
        loc == AppRoutes.paywall ||
        loc == AppRoutes.login ||
        loc == AppRoutes.register) {
      return AppRoutes.vault;
    }
    return null;
  }

  // 3) No access:
  //    Show paywall ONLY if they just registered or previously had access (lapsed).
  final shouldSeePaywall = access.isNewlyRegistered || access.everHadAccess;

  if (shouldSeePaywall) {
    return (loc == AppRoutes.paywall) ? null : AppRoutes.paywall;
  }

  // 4) Free-tier path → keep them out of boot/paywall/login/register.
  if (loc == AppRoutes.boot ||
      loc == AppRoutes.paywall ||
      loc == AppRoutes.login ||
      loc == AppRoutes.register) {
    return AppRoutes.vault;
  }

  // 5) No redirect
  return null;
}

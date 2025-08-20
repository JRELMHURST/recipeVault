import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/app/app_bootstrap.dart';
import 'package:recipe_vault/billing/subscription_service.dart';
import 'routes.dart';

String? appRedirect(
  BuildContext context,
  GoRouterState state,
  SubscriptionService subs,
) {
  final loc = state.matchedLocation;
  final isManaging = state.uri.queryParameters['manage'] == '1';
  final user = FirebaseAuth.instance.currentUser;
  final isLoggedIn =
      user != null && !user.isAnonymous; // 👈 treat anon as logged out

  // 0) App bootstrap not finished → keep on /boot
  if (!AppBootstrap.isReady) return AppRoutes.boot;

  // 1) Not logged in (or anonymous) → only /login or /register allowed
  if (!isLoggedIn) {
    if (loc == AppRoutes.login || loc == AppRoutes.register) return null;
    return AppRoutes.login;
  }

  // 2) Subscriptions still resolving? Stay on /boot unless timeout hit
  final resolving = subs.status == EntitlementStatus.checking;
  if (resolving && !AppBootstrap.timeoutReached) {
    if (loc == AppRoutes.paywall && isManaging) return null;
    return AppRoutes.boot;
  }

  // 3) Logged in with access → keep them out of boot/paywall/auth
  if (subs.hasAccess) {
    if (loc == AppRoutes.boot ||
        loc == AppRoutes.paywall ||
        loc == AppRoutes.login ||
        loc == AppRoutes.register) {
      return AppRoutes.vault;
    }
    return null;
  }

  // 4) Logged in but no access → paywall (supports ?manage=1)
  if (loc == AppRoutes.paywall) return null;
  return AppRoutes.paywall;
}

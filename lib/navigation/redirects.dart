// lib/navigation/redirects.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/billing/subscription_service.dart';
import 'routes.dart';

String? appRedirect(
  BuildContext context,
  GoRouterState state,
  SubscriptionService subs,
) {
  final loc = state.matchedLocation;
  final isManaging = state.uri.queryParameters['manage'] == '1';

  // 🔐 Auth state
  final isLoggedIn = FirebaseAuth.instance.currentUser != null;

  // ⏳ While we haven’t loaded RC state yet, pin to /boot
  final isResolving = !subs.isLoaded;

  // 0) Not logged in → allow /login and /register only
  if (!isLoggedIn) {
    if (loc == AppRoutes.login || loc == AppRoutes.register) return null;
    return AppRoutes.login;
  }

  // 1) Still resolving? Keep the user on /boot (except explicit manage flow)
  if (isResolving) {
    if (loc == AppRoutes.paywall && isManaging) return null;
    return loc == AppRoutes.boot ? null : AppRoutes.boot;
  }

  // 2) Paid user → keep them out of boot/paywall/auth
  if (subs.hasAccess) {
    if (loc == AppRoutes.boot ||
        loc == AppRoutes.paywall ||
        loc == AppRoutes.login ||
        loc == AppRoutes.register) {
      return AppRoutes.vault;
    }
    return null; // no redirect
  }

  // 3) Paid‑only app: no access → always show paywall
  if (loc == AppRoutes.paywall) return null; // allow manage and default
  return AppRoutes.paywall;
}

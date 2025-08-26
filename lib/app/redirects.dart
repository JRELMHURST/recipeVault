// lib/app/redirects.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/app/app_bootstrap.dart';
import 'package:recipe_vault/billing/subscription/subscription_service.dart';
import 'package:recipe_vault/data/services/user_session_service.dart';
import 'routes.dart';

String? appRedirect(
  BuildContext context,
  GoRouterState state,
  SubscriptionService subs,
) {
  final loc = state.matchedLocation;
  final isManaging = state.uri.queryParameters['manage'] == '1';

  // 🚦 0) Hard guard during sign-out teardown to avoid paywall/vault bounce
  if (UserSessionService.isSigningOut) {
    final onAuth = loc == AppRoutes.login || loc == AppRoutes.register;
    return onAuth ? null : AppRoutes.login;
  }

  // 🔒 1) UserSessionService can force a redirect (e.g., deleted account)
  final forced = UserSessionService.getRedirectRoute(loc);
  if (forced != null) return forced;

  final user = FirebaseAuth.instance.currentUser;
  final isLoggedIn = user != null && !user.isAnonymous;

  // 👤 2) Not logged in → only allow /login or /register
  if (!isLoggedIn) {
    final onAuth = loc == AppRoutes.login || loc == AppRoutes.register;
    return onAuth ? null : AppRoutes.login;
  }

  // 🥾 3) Bootstrap gating (while subs/status resolving)
  if (!AppBootstrap.isReady && !AppBootstrap.timeoutReached) {
    // Allow paywall if user explicitly opened manage
    if (loc == AppRoutes.paywall && isManaging) return null;
    return AppRoutes.boot;
  }

  // ✅ 4) Entitled (active sub or special access)
  if (subs.hasActiveSubscription || subs.hasSpecialAccess) {
    // Allow paywall manage deep-link
    if (loc == AppRoutes.paywall && isManaging) return null;

    // Block auth/paywall/boot when entitled
    const blocked = {
      AppRoutes.boot,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.paywall,
    };
    return blocked.contains(loc) ? AppRoutes.vault : null;
  }

  // 🚧 5) Logged in but not entitled → force paywall (manage allowed)
  return loc == AppRoutes.paywall ? null : AppRoutes.paywall;
}

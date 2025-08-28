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

  // 🚦 0) During sign-out teardown — force to login to prevent race conditions
  if (UserSessionService.isSigningOut) {
    final onAuthScreen = loc == AppRoutes.login || loc == AppRoutes.register;
    return onAuthScreen ? null : AppRoutes.login;
  }

  // 🔒 1) Forced redirect (e.g., account deletion, forced logout)
  final forcedRedirect = UserSessionService.getRedirectRoute(loc);
  if (forcedRedirect != null) return forcedRedirect;

  final user = FirebaseAuth.instance.currentUser;
  final isLoggedIn = user != null && !user.isAnonymous;

  // 👤 2) Not logged in → only allow auth screens
  if (!isLoggedIn) {
    final onAuthScreen = loc == AppRoutes.login || loc == AppRoutes.register;
    return onAuthScreen ? null : AppRoutes.login;
  }

  // 🥾 3) App not bootstrapped yet
  if (!AppBootstrap.isReady && !AppBootstrap.timeoutReached) {
    // Allow paywall if user explicitly deep-linked for management
    if (loc == AppRoutes.paywall && isManaging) return null;
    return AppRoutes.boot;
  }

  final isEntitled = subs.hasActiveSubscription || subs.hasSpecialAccess;

  // ✅ 4) Entitled user
  if (isEntitled) {
    if (loc == AppRoutes.paywall && isManaging) return null;

    const blockedRoutes = {
      AppRoutes.boot,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.paywall,
    };
    return blockedRoutes.contains(loc) ? AppRoutes.vault : null;
  }

  // 🚧 5) Not entitled → hard gate to paywall
  return loc == AppRoutes.paywall ? null : AppRoutes.paywall;
}

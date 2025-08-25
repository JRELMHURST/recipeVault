import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/app/app_bootstrap.dart';
import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/data/services/user_session_service.dart'; // ✅ add
import 'routes.dart';

String? appRedirect(
  BuildContext context,
  GoRouterState state,
  SubscriptionService subs,
) {
  final loc = state.matchedLocation;
  final isManaging = state.uri.queryParameters['manage'] == '1';

  // 🔒 0) Hard auth guard — deleted or logged-out users → login
  final authRedirect = UserSessionService.getRedirectRoute(loc);
  if (authRedirect != null) return authRedirect;

  final user = FirebaseAuth.instance.currentUser;
  final isLoggedIn = user != null && !user.isAnonymous;

  // 1) App bootstrap not finished → stay on /boot
  if (!AppBootstrap.isReady) {
    return loc == AppRoutes.boot ? null : AppRoutes.boot;
  }

  // 2) Not logged in → only allow login/register
  if (!isLoggedIn) {
    final onAuthPage = loc == AppRoutes.login || loc == AppRoutes.register;
    return onAuthPage ? null : AppRoutes.login;
  }

  // 3) Subscriptions still resolving → hold on /boot (unless managing)
  if (subs.status == EntitlementStatus.checking &&
      !AppBootstrap.timeoutReached) {
    if (loc == AppRoutes.paywall && isManaging) return null;
    return AppRoutes.boot;
  }

  // 4) Logged in with valid access → block boot/auth/paywall
  if (subs.hasActiveSubscription || subs.hasSpecialAccess) {
    if (loc == AppRoutes.paywall && isManaging) return null;

    final onBlocked = {
      AppRoutes.boot,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.paywall,
    }.contains(loc);
    return onBlocked ? AppRoutes.vault : null;
  }

  // 5) Logged in but no access → must be on /paywall
  return loc == AppRoutes.paywall ? null : AppRoutes.paywall;
}

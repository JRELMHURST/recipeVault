import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

/// Wrap UI that should be conditionally visible based on tier-based capabilities
class FeatureGate extends StatelessWidget {
  final bool Function(SubscriptionService service) featureCheck;
  final Widget child;
  final Widget? fallback;
  final String? redirectRoute;

  const FeatureGate({
    super.key,
    required this.featureCheck,
    required this.child,
    this.fallback,
    this.redirectRoute,
  });

  @override
  Widget build(BuildContext context) {
    final service = SubscriptionService();

    final allowed = featureCheck(service);

    if (allowed) return child;

    // Redirect if specified
    if (redirectRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(redirectRoute!);
      });
      return const SizedBox.shrink();
    }

    return fallback ?? const SizedBox(height: 0, width: 0);
  }
}

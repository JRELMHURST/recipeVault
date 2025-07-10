import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

/// Wrap any screen or content that requires an active plan or trial
class AccessGate extends StatefulWidget {
  final Widget child;
  final Widget? loading;
  final String redirectRoute;

  const AccessGate({
    super.key,
    required this.child,
    this.loading,
    this.redirectRoute = '/upgrade-blocked',
  });

  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    await SubscriptionService().refresh();
    final access = SubscriptionService().hasAccess;

    if (!access && mounted) {
      context.go(widget.redirectRoute);
    } else {
      setState(() {
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return widget.loading ??
          const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return widget.child;
  }
}

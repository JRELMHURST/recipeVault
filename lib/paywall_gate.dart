// lib/rev_cat/paywall_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class PaywallGate extends StatefulWidget {
  final Widget child; // usually HomeScreen
  const PaywallGate({super.key, required this.child});

  @override
  State<PaywallGate> createState() => _PaywallGateState();
}

class _PaywallGateState extends State<PaywallGate> {
  final _sub = SubscriptionService();
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      setState(() => _checked = true);
      return;
    }

    await UserPreferencesService.init();
    await _sub.init();
    await _sub.refresh();

    final isNewUser = await UserPreferencesService.get('is_new_user') == true;
    final hasActive = _sub.hasActiveSubscription;
    final inTrial = _sub.isInTrial;
    final trialEnd = _sub.trialEndDate;
    final trialEnded = trialEnd != null && DateTime.now().isAfter(trialEnd);

    if (!mounted) return;

    if (isNewUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/paywall');
      });
      return;
    }

    if ((trialEnded || !inTrial) && !hasActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/trial-ended');
      });
      return;
    }

    setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();
    return widget.child;
  }
}

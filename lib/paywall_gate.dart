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
      debugPrint('[PaywallGate] No signed-in user → allow');
      setState(() => _checked = true);
      return;
    }

    debugPrint('[PaywallGate] Running access check for ${user.uid}…');

    await UserPreferencesService.init();
    await _sub.init();
    await _sub.refresh();

    final isNewUser = (await UserPreferencesService.get('is_new_user')) == true;
    final hasActive = _sub.hasActiveSubscription;
    final inTrial = _sub.isInTrial;
    final trialEnd = _sub.trialEndDate;
    final trialEnded = trialEnd != null && DateTime.now().isAfter(trialEnd);

    debugPrint(
      '[PaywallGate] isNewUser=$isNewUser, hasActive=$hasActive, '
      'inTrial=$inTrial, trialEnd=$trialEnd, trialEnded=$trialEnded',
    );

    if (!mounted) return;

    // Navigate only after first frame to avoid initState routing issues.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Brand-new user → paywall
      if (isNewUser) {
        debugPrint('[PaywallGate] New user → /paywall');
        Navigator.of(context).pushReplacementNamed('/paywall');
        return;
      }

      // Trial ended (or not in trial) AND no active subscription → paywall
      if ((trialEnded || !inTrial) && !hasActive) {
        debugPrint('[PaywallGate] No access → /paywall');
        Navigator.of(context).pushReplacementNamed('/paywall');
        return;
      }

      debugPrint('[PaywallGate] Access OK → show child');
      if (mounted) setState(() => _checked = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      // Show a real loading UI instead of a zero-size box — avoids “black screen”
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}

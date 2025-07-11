// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

/// LaunchGateScreen is the single entry point that decides where the user
/// should be routed, based on their auth state and access level.
class LaunchGateScreen extends StatefulWidget {
  const LaunchGateScreen({super.key});

  @override
  State<LaunchGateScreen> createState() => _LaunchGateScreenState();
}

class _LaunchGateScreenState extends State<LaunchGateScreen> {
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    _handleLaunch();
  }

  Future<void> _handleLaunch() async {
    await Future.delayed(
      const Duration(milliseconds: 250),
    ); // Let Firebase settle

    if (!mounted || _hasChecked) return;
    _hasChecked = true;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('🚫 No user signed in → go to /login');
      context.replace('/login');
      return;
    }

    // User is signed in – initialise SubscriptionService
    await SubscriptionService().init();

    final subscription = SubscriptionService();

    if (subscription.hasAccess) {
      debugPrint('✅ User has access → go to /home');
      context.replace('/home');
    } else if (!subscription.hasTasterTrialBeenUsed) {
      debugPrint('🧪 Show paywall with Taster Trial → go to /paywall');
      context.replace('/paywall');
    } else {
      debugPrint('💸 No access + trial used → go to /paywall');
      context.replace('/paywall');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE6E2FF),
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

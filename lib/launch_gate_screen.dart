// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

class LaunchGateScreen extends StatefulWidget {
  const LaunchGateScreen({super.key});

  @override
  State<LaunchGateScreen> createState() => _LaunchGateScreenState();
}

class _LaunchGateScreenState extends State<LaunchGateScreen> {
  @override
  void initState() {
    super.initState();
    _checkAccessState();
  }

  Future<void> _checkAccessState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('🔒 No Firebase user found. Redirecting to login.');
      context.go('/login');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final devBypass = prefs.getBool('devBypass') ?? false;

    if (devBypass) {
      debugPrint('🛠 Dev bypassing to /home');
      context.go('/home');
      return;
    }

    try {
      debugPrint('🔄 Refreshing subscription service...');
      await SubscriptionService().refresh();

      // ✅ Show toast if super user
      if (SubscriptionService().isSuperUser && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧪 Developer Mode: Super User Enabled'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      debugPrint('🟡 Calling getUserAccessState...');
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west2');
      final result = await functions.httpsCallable('getUserAccessState').call();
      final data = result.data;
      debugPrint('🟢 Function response: $data');

      final redirectTo = data['route'] as String?;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(redirectTo ?? '/home');
      });
    } catch (e, stack) {
      debugPrint('🔴 Access state error: $e');
      debugPrint('📛 Stack trace:\n$stack');
      context.go('/error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

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

    try {
      debugPrint('🟡 Calling getUserAccessState...');
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west2');

      final result = await functions.httpsCallable('getUserAccessState').call();
      final data = result.data;
      debugPrint('🟢 Function response: $data');

      final redirectTo = data['route'] as String?;
      context.go(redirectTo ?? '/home');
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

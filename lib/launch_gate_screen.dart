// ignore_for_file: use_build_context_synchronously, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getUserAccessState')
          .call();

      final redirectTo = result.data['redirectTo'] as String?;
      // ignore: use_build_context_synchronously
      context.go(redirectTo ?? '/home');
    } catch (e) {
      debugPrint('🔴 Access state error: $e');
      context.go('/error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

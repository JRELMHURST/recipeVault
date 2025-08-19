import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/billing/subscription_service.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('🚀 BootScreen: post-frame subs.refreshAndNotify()');
      await context.read<SubscriptionService>().refreshAndNotify();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

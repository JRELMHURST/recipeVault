import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/access_controller.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger refresh only after the first frame to avoid
    // "notify during build" assertions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🚀 BootScreen: post-frame access.refresh()');
      context.read<AccessController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    // This screen just shows a spinner; your router redirects elsewhere
    // once AccessController.ready becomes true.
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

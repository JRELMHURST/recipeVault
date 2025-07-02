import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

// Toggle for dev builds only
const bool kShowDevBypass = true;

class DevBypassButton extends StatelessWidget {
  const DevBypassButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kShowDevBypass) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.fast_forward_rounded),
        label: const Text("Bypass (Dev)"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasSeenWelcome', true);
          if (!context.mounted) return;
          GoRouter.of(context).go('/home'); // <-- This goes to HomeScreen
        },
      ),
    );
  }
}

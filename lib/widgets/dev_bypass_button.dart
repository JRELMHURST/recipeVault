import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DevBypassButton extends StatelessWidget {
  final String route;
  final String label;

  const DevBypassButton({
    super.key,
    required this.route,
    this.label = 'Dev Bypass',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.redAccent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: () {
        debugPrint('🛠 Dev bypassing to $route');
        context.go(route, extra: {'devBypass': true});
      },
      child: Text(label),
    );
  }
}

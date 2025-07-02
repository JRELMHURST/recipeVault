import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: const Color(0x8A000000), // ≈ black54 = 54% opacity
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

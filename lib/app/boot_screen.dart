// lib/app/boot_screen.dart
import 'package:flutter/material.dart';

class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

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

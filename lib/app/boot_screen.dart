// lib/app/boot_screen.dart
import 'package:flutter/material.dart';
import 'package:recipe_vault/app/app_bootstrap.dart';

class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FlutterLogo(
                    size: 56,
                  ), // replace with your logo if you have one
                  const SizedBox(height: 16),
                  Text(
                    'Starting RecipeVault…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    label: 'Loading',
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tiny helper text after the boot timeout window elapses
                  ValueListenableBuilder<bool>(
                    valueListenable: AppBootstrap.timeoutListenable,
                    builder: (_, timedOut, __) => AnimatedOpacity(
                      opacity: timedOut ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: timedOut
                          ? Text(
                              'This is taking a moment…',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

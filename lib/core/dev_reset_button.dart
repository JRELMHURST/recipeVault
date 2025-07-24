// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:recipe_vault/services/user_preference_service.dart';

class DevResetButton extends StatelessWidget {
  const DevResetButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      bottom: 90,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'replay_tutorial',
            backgroundColor: Colors.blueGrey,
            icon: const Icon(Icons.replay),
            label: const Text('Replay Tutorial'),
            onPressed: () async {
              await UserPreferencesService.resetVaultTutorial(localOnly: false);
              await UserPreferencesService.resetBubbles(deleteRemote: true);
              await UserPreferencesService.set('hasShownBubblesOnce', false);
              debugPrint('🎬 Tutorial reset triggered.');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🎬 Tutorial reset triggered')),
              );
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'reset_bubbles',
            backgroundColor: Colors.redAccent,
            tooltip: 'Reset Onboarding',
            onPressed: () async {
              await UserPreferencesService.resetVaultTutorial(localOnly: false);
              await UserPreferencesService.resetBubbles(deleteRemote: true);
              await UserPreferencesService.set('hasShownBubblesOnce', false);
              debugPrint('🧪 Onboarding bubbles reset via dev button.');
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('🧪 Bubbles reset')));
            },
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

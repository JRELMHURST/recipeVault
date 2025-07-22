// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/services/user_preference_service.dart';

class HomeTutorialOverlay extends StatefulWidget {
  final List<GlobalKey> targets;

  const HomeTutorialOverlay({super.key, required this.targets});

  @override
  State<HomeTutorialOverlay> createState() => _HomeTutorialOverlayState();
}

class _HomeTutorialOverlayState extends State<HomeTutorialOverlay> {
  int _step = 0;
  OverlayEntry? _overlay;

  final List<String> titles = [
    'Scan Your Recipes',
    'Your Recipe Vault',
    'Switch View Modes',
    'Manage Your Profile',
  ];

  final List<String> descriptions = [
    'Tap here to create a recipe from your screenshots.',
    'Here is where all your saved recipes appear.',
    'Use this button to switch between grid, compact, or list view.',
    'Access settings, account, and more.',
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), _showOverlay);
  }

  void _showOverlay() {
    final targetContext = widget.targets[_step].currentContext;
    if (targetContext == null) return;

    _overlay = _buildOverlay();
    Overlay.of(context).insert(_overlay!);
  }

  OverlayEntry _buildOverlay() {
    final contextTarget = widget.targets[_step].currentContext;
    final box = contextTarget?.findRenderObject() as RenderBox?;
    if (box == null) {
      return OverlayEntry(builder: (_) => const SizedBox());
    }

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _nextStep,
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
          Positioned(
            left: offset.dx - 8,
            top: offset.dy - 8,
            width: size.width + 16,
            height: size.height + 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 12,
            left: offset.dx,
            right: 16,
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titles[_step],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descriptions[_step],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_step < titles.length - 1)
                          TextButton(
                            onPressed: _nextStep,
                            child: const Text('Next'),
                          ),
                        if (_step == titles.length - 1)
                          TextButton(
                            onPressed: _finishTutorial,
                            child: const Text('Done'),
                          ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _finishTutorial,
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    _overlay?.remove();
    if (_step < widget.targets.length - 1) {
      setState(() => _step++);
      Future.delayed(const Duration(milliseconds: 300), _showOverlay);
    } else {
      _finishTutorial();
    }
  }

  Future<void> _finishTutorial() async {
    _overlay?.remove();
    await UserPreferencesService.markHomeTutorialComplete();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

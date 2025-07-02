// ignore_for_file: deprecated_member_use, unrelated_type_equality_checks

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/services/image_processing_service.dart';

class ProcessingOverlay {
  static OverlayEntry? _currentOverlay;

  static void show(BuildContext context, List<File> imageFiles) {
    if (_currentOverlay != null) return;

    final overlay = OverlayEntry(
      builder: (_) => _ProcessingOverlayView(imageFiles: imageFiles),
    );

    _currentOverlay = overlay;
    Overlay.of(context, rootOverlay: true).insert(overlay);
  }

  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _ProcessingOverlayView extends StatefulWidget {
  final List<File> imageFiles;

  const _ProcessingOverlayView({required this.imageFiles});

  @override
  State<_ProcessingOverlayView> createState() => _ProcessingOverlayViewState();
}

class _ProcessingOverlayViewState extends State<_ProcessingOverlayView>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _hasCancelled = false;

  final List<String> _steps = [
    'Uploading Images',
    'Extracting & Formatting',
    'Finishing Up',
  ];

  late final AnimationController _iconController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  late final AnimationController _barController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _runFullFlow();
  }

  @override
  void dispose() {
    _iconController.dispose();
    _barController.dispose();
    super.dispose();
  }

  Future<void> _runFullFlow() async {
    try {
      await _setStep(0);
      final imageUrls = await ImageProcessingService.uploadFiles(
        widget.imageFiles,
      );
      if (_hasCancelled) return;

      await _setStep(1);
      final formattedRecipe =
          await ImageProcessingService.extractAndFormatRecipe(imageUrls);
      if (_hasCancelled) return;

      await _setStep(2);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      ProcessingOverlay.hide();
      GoRouter.of(context).go('/results', extra: formattedRecipe);
    } catch (e, st) {
      debugPrint('❌ Processing failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        ProcessingOverlay.hide();
      }
    }
  }

  Future<void> _setStep(int step) async {
    if (!mounted) return;
    setState(() => _currentStep = step);
    await Future.delayed(const Duration(milliseconds: 320));
  }

  void _cancel() {
    _hasCancelled = true;
    ProcessingOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Material(
      color: Colors.black.withOpacity(0.35),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 18,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Icon
                  RotationTransition(
                    turns: _iconController,
                    child: Icon(Icons.restaurant_menu, size: 40, color: accent),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 44),
                      Text(
                        'Processing',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancel,
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: accent.withOpacity(0.82),
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "We're turning your screenshots into\na delicious recipe card!",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Stepper
                  _BrandedStepper(
                    currentStep: _currentStep,
                    accent: accent,
                    steps: _steps,
                  ),
                  const SizedBox(height: 30),
                  // Animated loading bar
                  FadeTransition(
                    opacity: Tween<double>(
                      begin: 0.6,
                      end: 1.0,
                    ).animate(_barController),
                    child: Container(
                      height: 6,
                      width: 62,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
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

class _BrandedStepper extends StatelessWidget {
  final int currentStep;
  final Color accent;
  final List<String> steps;

  const _BrandedStepper({
    required this.currentStep,
    required this.accent,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          List.generate(steps.length, (i) {
              final isActive = i == currentStep;
              final isDone = i < currentStep;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isDone
                          ? accent
                          : isActive
                          ? accent.withOpacity(0.8)
                          : Colors.grey[300],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive || isDone ? accent : Colors.grey[300]!,
                        width: 2.2,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : isActive
                          ? const Icon(
                              Icons.hourglass_top,
                              color: Colors.white,
                              size: 18,
                            )
                          : Container(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive ? accent : Colors.grey[500],
                    ),
                  ),
                ],
              );
            }).expand((w) => [w, if (w != steps.last) _StepperLine()]).toList()
            ..removeLast(),
    );
  }
}

class _StepperLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      width: 2,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(vertical: 2),
    );
  }
}

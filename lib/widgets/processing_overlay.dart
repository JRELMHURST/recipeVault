import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/widgets/timeline_step.dart';

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

class _ProcessingOverlayViewState extends State<_ProcessingOverlayView> {
  int _currentStep = 0;
  bool _hasCancelled = false;

  final List<String> _steps = [
    'Uploading Images',
    'Extracting & Formatting',
    'Finishing Up',
  ];

  @override
  void initState() {
    super.initState();
    _runFullFlow();
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
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _cancel() {
    _hasCancelled = true;
    ProcessingOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0x4D000000), // Replaces .withOpacity(0.3)
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    Text(
                      'Processing',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: _cancel,
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  "We're turning your screenshots into a delicious recipe!",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                for (int i = 0; i < _steps.length; i++)
                  TimelineStep(
                    label: _steps[i],
                    isCurrent: i == _currentStep,
                    isCompleted: i < _currentStep,
                  ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

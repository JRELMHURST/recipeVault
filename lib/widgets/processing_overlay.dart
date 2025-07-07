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
  bool _isTranslating = false;

  final List<String> _baseSteps = [
    'Uploading Images',
    'Extracting & Formatting',
    'Finishing Up',
  ];

  final List<String> _translationSteps = [
    'Uploading Images',
    'Translating to UK English',
    'Extracting & Formatting',
    'Finishing Up',
  ];

  List<String> get _steps => _isTranslating ? _translationSteps : _baseSteps;

  late final AnimationController _iconSpinController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
    lowerBound: 0.95,
    upperBound: 1.05,
  )..repeat(reverse: true);

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
    _iconSpinController.dispose();
    _pulseController.dispose();
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

      // Optional translating step will appear if translation is detected
      await _setStep(1);
      final result = await ImageProcessingService.extractAndFormatRecipe(
        imageUrls,
      );
      if (_hasCancelled) return;

      if (result.translationUsed) {
        setState(() {
          _isTranslating = true;
        });
        await _setStep(2); // Translating
        await Future.delayed(const Duration(milliseconds: 600));
        await _setStep(3); // Extracting & Formatting
      } else {
        await _setStep(2); // Extracting & Formatting
      }

      if (_hasCancelled) return;
      await _setStep(_steps.length - 1);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      ProcessingOverlay.hide();
      GoRouter.of(context).go('/results', extra: result);
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

  IconData _stepIcon(int step) {
    final icons = [
      Icons.cloud_upload_rounded,
      Icons.translate,
      Icons.auto_fix_high_rounded,
      Icons.hourglass_bottom_rounded,
    ];
    return icons[step % icons.length];
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
                  RotationTransition(
                    turns: _iconSpinController,
                    child: ScaleTransition(
                      scale: _pulseController,
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: accent.withOpacity(0.15),
                        child: Icon(
                          _stepIcon(_currentStep),
                          color: accent,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Processing Your Recipe',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Hang tight while we turn your screenshots\ninto a delicious, formatted recipe card!",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 26),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Column(
                      key: ValueKey<int>(_currentStep),
                      children: [
                        Text(
                          _steps[_currentStep],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
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
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
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

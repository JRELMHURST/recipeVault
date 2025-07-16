// ignore_for_file: deprecated_member_use, unrelated_type_equality_checks, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/widgets/processing_messages.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  late List<String> _currentSteps;
  late List<String> _currentFunMessages;

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
    _currentSteps = [
      'Uploading Images',
      'Extracting & Formatting',
      'Finishing Up',
    ];
    _currentFunMessages = [
      ProcessingMessages.pickRandom(ProcessingMessages.uploading),
      ProcessingMessages.pickRandom(ProcessingMessages.formatting),
      ProcessingMessages.pickRandom(ProcessingMessages.completed),
    ];
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in.');

      await _setStep(0);
      final imageUrls = await ImageProcessingService.uploadFiles(
        widget.imageFiles,
      );
      if (_hasCancelled) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      debugPrint(
        '📄 User tier before extractAndFormatRecipe: ${userDoc.data()?['tier']}',
      );
      final result = await ImageProcessingService.extractAndFormatRecipe(
        imageUrls,
        context,
      );
      if (_hasCancelled) return;

      debugPrint(
        "🧭 RAW FUNCTION RESPONSE = ${JsonEncoder.withIndent('  ').convert(result.toMap())}",
      );

      final needsTranslation = result.translationUsed;

      // 🧩 If translation was used, expand overlay steps
      if (mounted && needsTranslation) {
        _currentSteps = [
          'Uploading Images',
          'Translating',
          'Extracting & Formatting',
          'Finishing Up',
        ];
        _currentFunMessages = [
          ProcessingMessages.pickRandom(ProcessingMessages.uploading),
          ProcessingMessages.pickRandom(ProcessingMessages.translating),
          ProcessingMessages.pickRandom(ProcessingMessages.formatting),
          ProcessingMessages.pickRandom(ProcessingMessages.completed),
        ];
        setState(() {});
      }

      if (needsTranslation) {
        await _setStep(1);
        await Future.delayed(const Duration(milliseconds: 600));
        await _setStep(2);
      } else {
        await _setStep(1);
      }

      if (_hasCancelled) return;
      await Future.delayed(const Duration(milliseconds: 600));

      await _setStep(_currentSteps.length - 1);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      ProcessingOverlay.hide();
      Navigator.pushNamed(context, '/results', arguments: result);
    } catch (e, st) {
      debugPrint('❌ Processing failed: $e\n$st');

      final message = e.toString();
      final isUpgradePrompt =
          message.contains('Translation blocked') ||
          message.contains('Usage limit reached');

      if (mounted && !isUpgradePrompt) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }

      ProcessingOverlay.hide();
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
    return icons[step.clamp(0, icons.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Material(
      color: Colors.black.withOpacity(0.1),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 18,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20),
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
                    _currentFunMessages[_currentStep],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
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
                          _currentSteps[_currentStep],
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

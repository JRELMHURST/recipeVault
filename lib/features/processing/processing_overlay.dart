// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/data/services/image_processing_service.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/app/routes.dart';
import 'package:recipe_vault/features/processing/processing_messages.dart';

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
  bool _inited = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;

    final t = AppLocalizations.of(context);
    _currentSteps = [
      t.processingStepUploading,
      t.processingStepFormatting,
      t.processingStepFinishing,
    ];
    _currentFunMessages = [
      ProcessingMessages.forStage(context, ProcessingStage.uploading),
      ProcessingMessages.forStage(context, ProcessingStage.formatting),
      ProcessingMessages.forStage(context, ProcessingStage.completed),
    ];

    _inited = true;
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

      final imageUrls = await ImageProcessingService.uploadFiles(
        context,
        widget.imageFiles,
      );
      if (_hasCancelled) return;

      final result = await ImageProcessingService.extractAndFormatRecipe(
        imageUrls,
        context,
      );
      if (_hasCancelled) return;

      debugPrint(
        "🧭 RAW FUNCTION RESPONSE = \${JsonEncoder.withIndent('  ').convert(result.toMap())}",
      );
      debugPrint("📄 User tier (from CF): \${result.tier}");

      // If translation is needed → adjust steps
      if (mounted && result.translationUsed) {
        final t = AppLocalizations.of(context);
        _currentSteps = [
          t.processingStepUploading,
          t.processingStepTranslating,
          t.processingStepFormatting,
          t.processingStepFinishing,
        ];
        _currentFunMessages = [
          ProcessingMessages.forStage(context, ProcessingStage.uploading),
          ProcessingMessages.forStage(context, ProcessingStage.translating),
          ProcessingMessages.forStage(context, ProcessingStage.formatting),
          ProcessingMessages.forStage(context, ProcessingStage.completed),
        ];
        setState(() {});
      }

      // Simulate staged progress
      for (int i = 1; i < _currentSteps.length; i++) {
        if (_hasCancelled) return;
        await _setStep(i);
        await Future.delayed(const Duration(milliseconds: 600));
      }

      if (!mounted) return;
      ProcessingOverlay.hide();
      context.push(AppRoutes.results, extra: result);
    } catch (e) {
      debugPrint('❌ Processing failed: \$e\n\$st');
      if (mounted) {
        AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('\${t.error}: \$e')));
      }
      ProcessingOverlay.hide();
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

  IconData _currentStepIcon(AppLocalizations t) {
    final label = _currentSteps[_safeIndex(_currentStep, _currentSteps.length)];
    if (label == t.processingStepUploading) return Icons.cloud_upload_rounded;
    if (label == t.processingStepTranslating) return Icons.translate;
    if (label == t.processingStepFormatting) return Icons.auto_fix_high_rounded;
    return Icons.hourglass_bottom_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    final stepIdx = _safeIndex(_currentStep, _currentSteps.length);
    final funIdx = _safeIndex(_currentStep, _currentFunMessages.length);

    final funMessage = _currentFunMessages.isNotEmpty
        ? _currentFunMessages[funIdx]
        : '';

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
                  TickerMode(
                    enabled: true,
                    child: RotationTransition(
                      turns: _iconSpinController,
                      child: ScaleTransition(
                        scale: _pulseController,
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.15),
                          child: Icon(
                            _currentStepIcon(t),
                            color: theme.colorScheme.primary,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.processingTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (funMessage.isNotEmpty)
                    Text(
                      funMessage,
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
                    child: Text(
                      _currentSteps[stepIdx],
                      key: ValueKey<int>(stepIdx),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
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
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _cancel,
                      child: Semantics(
                        button: true,
                        label: t.cancel,
                        child: Text(
                          t.cancel,
                          style: TextStyle(
                            color: theme.colorScheme.primary.withOpacity(0.82),
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            decoration: TextDecoration.underline,
                          ),
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

  int _safeIndex(int i, int len) => len == 0 ? 0 : (i.clamp(0, len - 1));
}

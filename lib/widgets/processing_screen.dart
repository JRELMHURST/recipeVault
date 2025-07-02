import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/widgets/timeline_step.dart';
import 'package:recipe_vault/services/image_upload_service.dart';
import 'package:recipe_vault/services/recipe_formatter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class ProcessingScreen extends StatefulWidget {
  final List<File> imageFiles;

  const ProcessingScreen({super.key, required this.imageFiles});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  int _currentStep = 0;
  bool _hasCancelled = false;

  final List<String> _steps = [
    'Uploading Images',
    'Reading Text',
    'Formatting Recipe',
    'Done',
  ];

  @override
  void initState() {
    super.initState();
    _runFullFlow();
  }

  Future<void> _runFullFlow() async {
    try {
      // Step 1: Upload images
      await _setStep(0);
      final imageUrls = await ImageUploadService.uploadImages(
        widget.imageFiles,
      );

      if (_hasCancelled) return;

      // Step 2: Run OCR + formatting
      await _setStep(1);
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // artificial buffer
      await _setStep(2);
      final ocrText = await RecipeFormatter.formatRecipe(imageUrls);

      if (_hasCancelled) return;

      // Step 3: Navigate to results
      await _setStep(3);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      context.go('/results', extra: ocrText);
    } catch (e, st) {
      debugPrint('Processing failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        context.pop(); // Return to home on error
      }
    }
  }

  Future<void> _setStep(int step) async {
    if (!mounted) return;
    setState(() => _currentStep = step);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _cancelProcessing() {
    _hasCancelled = true;
    context.pop(); // Go back
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _cancelProcessing,
        ),
        actions: [
          TextButton(onPressed: _cancelProcessing, child: const Text('Cancel')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Hang tight while we process your recipe...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                itemCount: _steps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, index) => TimelineStep(
                  label: _steps[index],
                  isCompleted: index < _currentStep,
                  isCurrent: index == _currentStep,
                ),
              ),
            ),
            const Center(
              child: SpinKitFadingCircle(color: Colors.grey, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}

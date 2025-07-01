// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../services/image_upload_service.dart';
import '../services/recipe_formatter.dart';
import '../widgets/loading_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _jpegQuality = 80;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _generateRecipeCard() async {
    setState(() => _isLoading = true);
    try {
      // 1. Pick multiple images
      final List<XFile> pickedXFiles = await _picker.pickMultiImage();
      if (pickedXFiles.isEmpty) {
        _showError('No images selected.');
        return;
      }

      // 2. Convert XFiles to Files
      final List<File> imageFiles = pickedXFiles
          .map((xfile) => File(xfile.path))
          .toList();

      // 3. Compress images
      final List<File> compressedFiles = await _compressFiles(imageFiles);
      if (compressedFiles.isEmpty) {
        _showError('Failed to compress images.');
        return;
      }

      // 4. Upload images
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uploading images...')));
      final List<String> imageUrls = await ImageUploadService.uploadImages(
        compressedFiles,
      );

      // 5. Format recipe
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Formatting recipe...')));
      final String ocrText = await RecipeFormatter.formatRecipe(imageUrls);

      if (!mounted) return;
      context.go('/results', extra: ocrText);
    } catch (e, st) {
      debugPrint('Error in _generateRecipeCard: $e\n$st');
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<File>> _compressFiles(List<File> files) async {
    final Directory tempDir = await getTemporaryDirectory();
    final List<File> results = [];

    for (final file in files) {
      try {
        final String originalName = file.path.split('/').last;
        final String baseName = originalName.split('.').first;
        final String targetPath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$baseName.jpg';

        final File? compressedFile =
            await FlutterImageCompress.compressAndGetFile(
              file.path,
              targetPath,
              quality: _jpegQuality,
              format: CompressFormat.jpeg,
            );

        if (compressedFile != null) {
          results.add(compressedFile);
        }
      } catch (e, st) {
        debugPrint('Compression failed for ${file.path}: $e\n$st');
      }
    }

    return results;
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.colorScheme.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  Text(
                    'RecipeVault',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Effortlessly turn screenshots into beautiful recipe cards.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _generateRecipeCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Generate Recipe Card',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading) const LoadingOverlay(),
      ],
    );
  }
}

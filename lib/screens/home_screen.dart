// ignore_for_file: use_build_context_synchronously

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
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('RecipeVault')),
          body: Center(
            child: ElevatedButton(
              onPressed: _generateRecipeCard,
              child: const Text('Generate Recipe Card'),
            ),
          ),
        ),
        if (_isLoading) const LoadingOverlay(),
      ],
    );
  }
}

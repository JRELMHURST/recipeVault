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
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _generateRecipeCard() async {
    setState(() => _isLoading = true);

    try {
      // Pick multiple images (max 10)
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();

      if (pickedFiles == null || pickedFiles.isEmpty) {
        setState(() => _isLoading = false);
        return; // User cancelled or no images selected
      }

      // Convert XFile list to File list
      final List<File> files = pickedFiles
          .map((xfile) => File(xfile.path))
          .toList();

      final List<File> compressedFiles = [];
      final tempDir = await getTemporaryDirectory();

      for (final file in files) {
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.path,
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}',
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (compressedFile != null) {
          compressedFiles.add(compressedFile);
        }
      }

      if (compressedFiles.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to compress images')),
        );
        return;
      }

      // Upload compressed images and get URLs
      final List<String> imageUrls = await ImageUploadService.uploadImages(
        compressedFiles,
      );

      // Call backend to get formatted OCR text
      final String ocrText = await RecipeFormatter.formatRecipe(imageUrls);

      if (!mounted) return;
      context.go('/results', extra: ocrText);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

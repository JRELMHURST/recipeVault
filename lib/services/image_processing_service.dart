// lib/services/image_processing_service.dart

// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';

class ImageProcessingService {
  static const int _jpegQuality = 80;
  static final ImagePicker _picker = ImagePicker();

  /// Launches image picker, compresses images, then shows the processing overlay.
  static Future<void> startProcessingFlow(BuildContext context) async {
    try {
      final List<XFile> pickedXFiles = await _picker.pickMultiImage();
      if (pickedXFiles.isEmpty) {
        _showError(context, 'No images selected.');
        return;
      }

      final List<File> imageFiles = pickedXFiles
          .map((xfile) => File(xfile.path))
          .toList();
      final List<File> compressedFiles = await _compressFiles(imageFiles);

      if (compressedFiles.isEmpty) {
        _showError(context, 'Failed to compress images.');
        return;
      }

      if (context.mounted) {
        context.go('/processing', extra: compressedFiles);
      }
    } catch (e) {
      debugPrint('Image processing failed: $e');
      _showError(context, 'Something went wrong.');
    }
  }

  static Future<List<File>> _compressFiles(List<File> files) async {
    final Directory tempDir = await getTemporaryDirectory();
    final List<File> results = [];

    for (final file in files) {
      try {
        final String targetPath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

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
      } catch (e) {
        debugPrint('Compression failed for ${file.path}: $e');
      }
    }

    return results;
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

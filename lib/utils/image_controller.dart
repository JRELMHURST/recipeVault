// lib/utils/image_controller.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recipe_vault/services/image_upload_service.dart';

class ImageController {
  static const int _jpegQuality = 80;
  final ImagePicker _picker = ImagePicker();

  /// Allows multi-selection and compresses images to JPEG format
  Future<List<File>> pickAndCompressImages() async {
    final List<XFile> pickedXFiles = await _picker.pickMultiImage();
    if (pickedXFiles.isEmpty) return [];

    final List<File> imageFiles = pickedXFiles
        .map((xfile) => File(xfile.path))
        .toList();
    return await _compressFiles(imageFiles);
  }

  Future<List<File>> _compressFiles(List<File> files) async {
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

  /// Static method to upload files and return list of URLs
  static Future<List<String>> uploadFiles(List<File> files) {
    return ImageUploadService.uploadImages(files);
  }
}

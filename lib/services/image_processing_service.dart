// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recipe_vault/services/image_upload_service.dart';
import 'package:http/http.dart' as http;

class ImageProcessingService {
  static const int _jpegQuality = 80;
  static final ImagePicker _picker = ImagePicker();

  /// Picks and compresses multiple images from the gallery.
  static Future<List<File>> pickAndCompressImages() async {
    final List<XFile> pickedXFiles = await _picker.pickMultiImage();
    if (pickedXFiles.isEmpty) return [];

    final List<File> imageFiles = pickedXFiles
        .map((xfile) => File(xfile.path))
        .toList();
    return await _compressFiles(imageFiles);
  }

  /// Compresses a list of image files and returns the compressed results.
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

  /// Uploads compressed image files to Firebase Storage and returns their download URLs.
  static Future<List<String>> uploadFiles(List<File> files) {
    return ImageUploadService.uploadImages(files);
  }

  /// Calls the Firebase backend to extract merged OCR text from image URLs.
  static Future<String> extractTextFromImages(List<String> imageUrls) async {
    final url = Uri.parse(
      'https://europe-west2-recipe-vault-ai.cloudfunctions.net/extractRecipeFromImages',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'imageUrls': imageUrls}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to extract OCR text: ${response.body}');
    }

    final data = json.decode(response.body);
    return data['recipe'] as String;
  }

  /// Shows a SnackBar error.
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

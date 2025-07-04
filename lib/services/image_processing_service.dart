// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:recipe_vault/firebase_storage.dart';

class ProcessedRecipeResult {
  final String formattedRecipe;
  final List<String> categories;
  final String language;

  ProcessedRecipeResult({
    required this.formattedRecipe,
    required this.categories,
    required this.language,
  });
}

class ImageProcessingService {
  static const int _jpegQuality = 80;
  static final ImagePicker _picker = ImagePicker();

  /// Opens gallery, picks multiple images, compresses them, and returns local files.
  static Future<List<File>> pickAndCompressImages() async {
    final pickedXFiles = await _picker.pickMultiImage();
    if (pickedXFiles.isEmpty) return [];

    final imageFiles = pickedXFiles.map((x) => File(x.path)).toList();
    return _compressFiles(imageFiles);
  }

  /// Compresses images to JPEG format with specified quality.
  static Future<List<File>> _compressFiles(List<File> files) async {
    final tempDir = await getTemporaryDirectory();
    final results = <File>[];

    for (final file in files) {
      try {
        final targetPath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
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

  /// Uploads images to Firebase Storage and returns their download URLs.
  static Future<List<String>> uploadFiles(List<File> files) {
    return FirebaseStorageService.uploadImages(files);
  }

  /// Uploads a single image to Firebase Storage for a specific recipe and user.
  static Future<String> uploadRecipeImage({
    required File imageFile,
    required String userId,
    required String recipeId,
  }) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'users/$userId/recipe_images/$recipeId.jpg',
      );

      final uploadTask = await storageRef.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('❌ Failed to upload recipe image: $e');
    }
  }

  /// Crops an image using the image_cropper package.
  static Future<File?> cropImage(File originalImage) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: originalImage.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio16x9,
      ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    if (croppedFile == null) return null;

    return File(croppedFile.path);
  }

  /// Runs OCR and GPT formatting via Firebase Callable Function.
  /// Automatically deletes uploaded images afterwards.
  static Future<ProcessedRecipeResult> extractAndFormatRecipe(
    List<String> imageUrls,
  ) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west2');
      final callable = functions.httpsCallable('extractAndFormatRecipe');

      final result = await callable.call({'imageUrls': imageUrls});
      final data = result.data as Map<String, dynamic>;

      final formatted = data['formattedRecipe'] as String?;
      final categories = List<String>.from(data['categories'] ?? []);
      final language = data['language'] as String? ?? 'unknown';

      if (formatted == null || formatted.isEmpty) {
        throw Exception('Formatted recipe is missing or empty.');
      }

      return ProcessedRecipeResult(
        formattedRecipe: formatted,
        categories: categories,
        language: language,
      );
    } catch (e) {
      throw Exception('❌ Failed to process recipe: $e');
    } finally {
      await FirebaseStorageService.deleteImages(imageUrls);
    }
  }

  /// Shows an error snackbar in the current context.
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

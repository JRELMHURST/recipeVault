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
import 'package:recipe_vault/model/processed_recipe_result.dart';

class ImageProcessingService {
  static const int _jpegQualityAndroid = 80;
  static const int _jpegQualityIOS = 85;
  static final ImagePicker _picker = ImagePicker();
  static const bool _debug = false;

  /// Pick multiple images and compress them to JPEG format.
  static Future<List<File>> pickAndCompressImages() async {
    final pickedXFiles = await _picker.pickMultiImage();
    if (pickedXFiles.isEmpty) return [];

    final imageFiles = pickedXFiles.map((x) => File(x.path)).toList();
    return _compressFiles(imageFiles);
  }

  /// Compresses files to JPEG and stores them temporarily.
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
          quality: Platform.isIOS ? _jpegQualityIOS : _jpegQualityAndroid,
          format: CompressFormat.jpeg,
        );

        if (compressedFile != null) {
          results.add(compressedFile);
          if (_debug) debugPrint('✅ Compressed: ${compressedFile.path}');
        }
      } catch (e) {
        debugPrint('⚠️ Compression failed for ${file.path}: $e');
      }
    }

    return results;
  }

  /// Uploads a list of image files and returns download URLs.
  static Future<List<String>> uploadFiles(List<File> files) async {
    if (_debug) {
      debugPrint('⏫ Uploading ${files.length} files to Firebase Storage...');
    }
    return FirebaseStorageService.uploadImages(files);
  }

  /// Uploads a single cropped recipe image to the user's storage path.
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
      final url = await uploadTask.ref.getDownloadURL();

      if (_debug) debugPrint('✅ Recipe image uploaded: $url');
      return url;
    } catch (e) {
      throw Exception('❌ Failed to upload recipe image: $e');
    }
  }

  /// Optionally crops the given image using platform-specific UI.
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

  /// Calls the backend function to extract, translate, and format a recipe.
  static Future<ProcessedRecipeResult> extractAndFormatRecipe(
    List<String> imageUrls, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west2');
      final callable = functions.httpsCallable('extractAndFormatRecipe');

      if (_debug) {
        debugPrint(
          '🤖 Calling Cloud Function with ${imageUrls.length} image(s)...',
        );
      }

      final result = await callable
          .call({'imageUrls': imageUrls})
          .timeout(timeout);

      final data = result.data as Map<String, dynamic>;
      final formatted = data['formattedRecipe'] as String?;

      if (formatted == null || formatted.isEmpty) {
        throw Exception('Formatted recipe is missing or empty.');
      }

      if (_debug) debugPrint('✅ Recipe formatted successfully.');
      return ProcessedRecipeResult.fromMap(data);
    } catch (e) {
      throw Exception('❌ Failed to process recipe: $e');
    }
  }

  /// Displays an error message using a snackbar.
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

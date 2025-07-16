// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:recipe_vault/firebase_storage.dart';
import 'package:recipe_vault/model/processed_recipe_result.dart';

class ImageProcessingService {
  static const int _jpegQualityAndroid = 80;
  static const int _jpegQualityIOS = 85;
  static const bool _debug = false;
  static final ImagePicker _picker = ImagePicker();

  /// Notifies UI to display upgrade banner (e.g. on usage limit)
  static final ValueNotifier<String?> upgradeBannerMessage = ValueNotifier(
    null,
  );

  /// Picks multiple images and compresses them for upload
  static Future<List<File>> pickAndCompressImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return [];

    final files = picked.map((x) => File(x.path)).toList();
    return _compressFiles(files);
  }

  /// Compresses a list of images and stores them temporarily
  static Future<List<File>> _compressFiles(List<File> files) async {
    final tempDir = await getTemporaryDirectory();
    final result = <File>[];

    for (final file in files) {
      try {
        final targetPath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: Platform.isIOS ? _jpegQualityIOS : _jpegQualityAndroid,
          format: CompressFormat.jpeg,
        );

        if (compressed != null) {
          result.add(compressed);
          if (_debug) debugPrint('✅ Compressed: ${compressed.path}');
        }
      } catch (e) {
        debugPrint('⚠️ Compression failed for ${file.path}: $e');
      }
    }

    return result;
  }

  /// Uploads image files to Firebase and returns their download URLs
  static Future<List<String>> uploadFiles(List<File> files) async {
    if (_debug) {
      debugPrint('⏫ Uploading ${files.length} files to Firebase Storage...');
    }

    return FirebaseStorageService.uploadImages(files);
  }

  /// Uploads a single cropped recipe image to the user's folder
  static Future<String> uploadRecipeImage({
    required File imageFile,
    required String userId,
    required String recipeId,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'users/$userId/recipe_images/$recipeId.jpg',
      );

      final uploadTask = await ref.putFile(imageFile);
      final url = await uploadTask.ref.getDownloadURL();

      if (_debug) debugPrint('✅ Recipe image uploaded: $url');
      return url;
    } catch (e) {
      throw Exception('❌ Failed to upload recipe image: $e');
    }
  }

  /// Optional crop flow using ImageCropper
  static Future<File?> cropImage(File originalImage) async {
    final cropped = await ImageCropper().cropImage(
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
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    return cropped == null ? null : File(cropped.path);
  }

  /// Calls Firebase Function to run OCR → Translate → GPT Format
  static Future<ProcessedRecipeResult> extractAndFormatRecipe(
    List<String> imageUrls,
    BuildContext context, {
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

      if ((data['formattedRecipe'] as String?)?.isEmpty ?? true) {
        throw Exception('Formatted recipe is missing or empty.');
      }

      if (_debug) {
        debugPrint('✅ Recipe formatted successfully.');
        debugPrint('📥 Raw OCR: ${data['originalText']}');
        debugPrint('🌐 Detected Language: ${data['detectedLanguage']}');
        debugPrint('🔁 Translation Used: ${data['translationUsed']}');
        debugPrint('📤 Translated From: ${data['translatedFromLanguage']}');
      }

      return ProcessedRecipeResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      if (_debug) {
        debugPrint("🛑 FirebaseFunctionsException: ${e.code} — ${e.message}");
      }

      if (e.code == 'permission-denied') {
        upgradeBannerMessage.value =
            "✨ Unlock Chef Mode with the Home Chef or Master Chef plan!";
        throw Exception("Translation blocked due to plan limit.");
      }

      if (e.code == 'resource-exhausted') {
        upgradeBannerMessage.value =
            "🚧 You’ve hit your monthly quota. Upgrade for unlimited access!";
        throw Exception("Usage limit reached.");
      }

      throw Exception('❌ Failed to process recipe: ${e.message}');
    } catch (e) {
      if (_debug) debugPrint("❌ General exception: $e");
      throw Exception('❌ Failed to process recipe: $e');
    }
  }

  /// Show a snackbar error in context
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

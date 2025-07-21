// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
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
          _logDebug('✅ Compressed: ${compressed.path}');
        }
      } catch (e) {
        debugPrint('⚠️ Compression failed for ${file.path}: $e');
      }
    }

    return result;
  }

  /// Uploads image files to Firebase and returns their download URLs
  static Future<List<String>> uploadFiles(List<File> files) async {
    _logDebug('⏫ Uploading ${files.length} files to Firebase Storage...');
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

      _logDebug('✅ Recipe image uploaded: $url');
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

  /// Uploads a single recipe image after picking and cropping
  static Future<String?> pickAndUploadRecipeImage({
    required BuildContext context,
    required String recipeId,
  }) async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return null;

      final cropped = await cropImage(File(picked.path));
      if (cropped == null) return null;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');

      return await uploadRecipeImage(
        imageFile: cropped,
        userId: user.uid,
        recipeId: recipeId,
      );
    } catch (e) {
      showError(context, 'Image upload failed: $e');
      return null;
    }
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

      _logDebug(
        '🤖 Calling Cloud Function with ${imageUrls.length} image(s)...',
      );

      final result = await callable
          .call({'imageUrls': imageUrls})
          .timeout(timeout);
      final data = result.data as Map<String, dynamic>;

      if ((data['formattedRecipe'] as String?)?.isEmpty ?? true) {
        throw Exception('Formatted recipe is missing or empty.');
      }

      _logDebug('✅ Recipe formatted successfully.');
      _logDebug('📥 Raw OCR: ${data['originalText']}');
      _logDebug('🌐 Detected Language: ${data['detectedLanguage']}');
      _logDebug('🔁 Translation Used: ${data['translationUsed']}');
      _logDebug('📤 Translated From: ${data['translatedFromLanguage']}');

      return ProcessedRecipeResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      _logDebug("🛑 FirebaseFunctionsException: ${e.code} — ${e.message}");

      switch (e.code) {
        case 'permission-denied':
          upgradeBannerMessage.value =
              "✨ Unlock Chef Mode with the Home Chef or Master Chef plan!";
          throw Exception("Translation blocked due to plan limit.");
        case 'resource-exhausted':
          upgradeBannerMessage.value =
              "🚧 You’ve hit your monthly quota. Upgrade for unlimited access!";
          throw Exception("Usage limit reached.");
        default:
          throw Exception('❌ Failed to process recipe: ${e.message}');
      }
    } catch (e) {
      _logDebug("❌ General exception: $e");
      throw Exception('❌ Failed to process recipe: $e');
    }
  }

  /// Shows a snackbar error in context
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Conditional debug logger
  static void _logDebug(String message) {
    if (_debug) debugPrint(message);
  }
}

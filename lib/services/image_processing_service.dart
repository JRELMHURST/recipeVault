// ignore_for_file: use_build_context_synchronously

import 'dart:async';
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
  // Tunables
  static const int _jpegQualityAndroid = 80;
  static const int _jpegQualityIOS = 85;
  static const int _maxDimension = 2200; // clamp long side for uploads
  static const Duration _uploadTimeout = Duration(seconds: 30);

  static const bool _debug = false;

  static final ImagePicker _picker = ImagePicker();

  /// Notifies UI to display upgrade banner (e.g. on usage limit)
  static final ValueNotifier<String?> upgradeBannerMessage =
      ValueNotifier<String?>(null);

  static void clearUpgradeBanner() => upgradeBannerMessage.value = null;

  // ───────── PICK + COMPRESS ─────────

  /// Picks multiple images and compresses them for upload (JPEG + orientation fixed).
  static Future<List<File>> pickAndCompressImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return [];

    final files = picked.map((x) => File(x.path)).toList();
    return _compressFiles(files);
  }

  /// Compresses a list of images to JPEG, clamps long side, preserves orientation.
  static Future<List<File>> _compressFiles(List<File> files) async {
    final tempDir = await getTemporaryDirectory();
    final result = <File>[];

    for (final file in files) {
      try {
        final targetPath =
            '${tempDir.path}/rv_${DateTime.now().microsecondsSinceEpoch}.jpg';

        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: Platform.isIOS ? _jpegQualityIOS : _jpegQualityAndroid,
          format: CompressFormat.jpeg,
          // Clamp long side; plugin keeps aspect ratio
          minWidth: _maxDimension,
          minHeight: _maxDimension,
        );

        if (compressed != null) {
          result.add(compressed);
          _logDebug(
            '✅ Compressed: ${compressed.path} '
            '(${await compressed.length()} bytes)',
          );
        } else {
          // Fallback gracefully
          result.add(file);
          _logDebug(
            '⚠️ Compression returned null; using original: ${file.path}',
          );
        }
      } catch (e) {
        _logDebug('⚠️ Compression failed for ${file.path}: $e');
        result.add(file); // don’t block user
      }
    }

    return result;
  }

  // ───────── UPLOADS ─────────

  /// Uploads image files to Firebase and returns their download URLs.
  static Future<List<String>> uploadFiles(List<File> files) async {
    _logDebug('⏫ Uploading ${files.length} files to Firebase Storage...');
    // Uses your helper (kept as is)
    return FirebaseStorageService.uploadImages(files);
  }

  /// Uploads a single cropped recipe image to the user's folder.
  /// Adds JPEG metadata + timeout for stability.
  static Future<String> uploadRecipeImage({
    required File imageFile,
    required String userId,
    required String recipeId,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref(
        'users/$userId/recipe_images/$recipeId.jpg',
      );

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000, immutable',
      );

      final task = await ref
          .putFile(imageFile, metadata)
          .timeout(_uploadTimeout);
      final url = await task.ref.getDownloadURL();

      _logDebug('✅ Recipe image uploaded: $url');
      return url;
    } on TimeoutException {
      throw Exception('❌ Upload timed out. Please check your connection.');
    } on FirebaseException catch (e) {
      throw Exception('❌ Storage error: ${e.code}');
    } catch (e) {
      throw Exception('❌ Failed to upload recipe image: $e');
    }
  }

  // ───────── CROP ─────────

  /// Optional crop flow using ImageCropper.
  /// Optional crop flow using ImageCropper.
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

  /// Picks a single image (gallery by default), crops, uploads, returns the URL.
  static Future<String?> pickAndUploadSingleImage({
    required BuildContext context,
    required String recipeId,
    ImageSource source = ImageSource.gallery, // camera/gallery
    bool allowCrop = true,
  }) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return null;

      // Convert to JPEG & compress before (faster crop, consistent format)
      File file = (await _compressFiles([File(picked.path)])).first;

      if (allowCrop) {
        final cropped = await cropImage(file);
        if (cropped == null) return null;
        file = cropped;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');

      return await uploadRecipeImage(
        imageFile: file,
        userId: user.uid,
        recipeId: recipeId,
      );
    } catch (e) {
      showError(context, 'Image upload failed: $e');
      return null;
    }
  }

  // ───────── CLOUD FUNCTION (OCR → TRANSLATE → FORMAT) ─────────

  static Future<ProcessedRecipeResult> extractAndFormatRecipe(
    List<String> imageUrls,
    BuildContext context, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      // Detect the user's app locale
      final locale = Localizations.localeOf(context);
      final targetLanguage = locale.languageCode; // e.g. "pl"
      final targetRegion = locale.countryCode; // e.g. "GB" for en_GB

      final functions = FirebaseFunctions.instanceFor(region: 'europe-west2');
      final callable = functions.httpsCallable('extractAndFormatRecipe');

      _logDebug(
        '🤖 Calling Cloud Function with ${imageUrls.length} image(s) '
        '→ $targetLanguage${targetRegion != null ? "_$targetRegion" : ""}',
      );

      final result = await callable
          .call({
            'imageUrls': imageUrls,
            'targetLanguage': targetLanguage,
            'targetRegion': targetRegion,
          })
          .timeout(timeout);

      final data = (result.data as Map).cast<String, dynamic>();

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
        case 'deadline-exceeded':
        case 'unavailable':
          // One light retry helps with transient hiccups
          await Future.delayed(const Duration(milliseconds: 600));
          final locale = Localizations.localeOf(context);
          final functions = FirebaseFunctions.instanceFor(
            region: 'europe-west2',
          );
          final callable = functions.httpsCallable('extractAndFormatRecipe');
          final retry = await callable
              .call({
                'imageUrls': imageUrls,
                'targetLanguage': locale.languageCode,
                'targetRegion': locale.countryCode,
              })
              .timeout(timeout);
          final data = (retry.data as Map).cast<String, dynamic>();
          return ProcessedRecipeResult.fromMap(data);
        default:
          throw Exception('❌ Failed to process recipe: ${e.message}');
      }
    } on TimeoutException {
      throw Exception('⏳ Server took too long. Please try again.');
    } catch (e) {
      _logDebug("❌ General exception: $e");
      throw Exception('❌ Failed to process recipe: $e');
    }
  }

  // ───────── UI HELPERS ─────────

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ───────── LOGGING ─────────

  static void _logDebug(String message) {
    if (_debug) debugPrint(message);
  }
}

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:recipe_vault/firebase_storage.dart'; // FirebaseStorageService
import 'package:recipe_vault/model/processed_recipe_result.dart';

class ImageProcessingService {
  // ───────────────────────────── Tunables ─────────────────────────────
  static const int _jpegQualityAndroid = 80;
  static const int _jpegQualityIOS = 85;
  static const int _maxDimension = 2200; // clamp long side for uploads
  static const Duration _uploadTimeout = Duration(seconds: 30);
  static const bool _debug = false;

  static final ImagePicker _picker = ImagePicker();

  /// Notifies UI to display an upgrade/limit banner (consumed by screens/widgets).
  static final ValueNotifier<String?> upgradeBannerMessage = ValueNotifier(
    null,
  );
  static void clearUpgradeBanner() => upgradeBannerMessage.value = null;

  // ───────────────────────── PICK + COMPRESS ─────────────────────────

  /// Picks multiple images and compresses them (JPEG + orientation fixed).
  static Future<List<File>> pickAndCompressImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return [];
    return _compressFiles(picked.map((x) => File(x.path)).toList());
  }

  /// Compresses to JPEG, clamps long side, preserves orientation.
  static Future<List<File>> _compressFiles(List<File> files) async {
    final tempDir = await getTemporaryDirectory();
    final out = <File>[];

    for (final file in files) {
      try {
        final targetPath =
            '${tempDir.path}/rv_${DateTime.now().microsecondsSinceEpoch}.jpg';

        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: Platform.isIOS ? _jpegQualityIOS : _jpegQualityAndroid,
          format: CompressFormat.jpeg,
          minWidth: _maxDimension,
          minHeight: _maxDimension,
        );

        if (compressed != null) {
          out.add(compressed);
          _logDebug(
            '✅ Compressed → ${compressed.path} (${await compressed.length()} bytes)',
          );
        } else {
          out.add(file);
          _logDebug(
            '⚠️ Compression returned null; kept original: ${file.path}',
          );
        }
      } catch (e) {
        _logDebug('⚠️ Compression failed for ${file.path}: $e');
        out.add(file); // be permissive
      }
    }
    return out;
  }

  // ────────────────────────────── UPLOADS ──────────────────────────────

  /// Uploads image files to Firebase Storage; returns download URLs.
  static Future<List<String>> uploadFiles(List<File> files) async {
    _logDebug('⏫ Uploading ${files.length} file(s) to Firebase Storage…');
    return FirebaseStorageService.uploadImages(files);
  }

  /// Upload a single recipe image to a user path with sane metadata.
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
      _logDebug('✅ Uploaded recipe image: $url');
      return url;
    } on TimeoutException {
      throw Exception('Upload timed out. Please check your connection.');
    } on FirebaseException catch (e) {
      throw Exception('Storage error: ${e.code}');
    } catch (e) {
      throw Exception('Failed to upload recipe image: $e');
    }
  }

  // ─────────────────────────────── CROP ───────────────────────────────

  /// Optional crop flow via ImageCropper.
  static Future<File?> cropImage(File originalImage) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: originalImage.path,
      aspectRatioPresets: const [
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio16x9,
      ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepPurple,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );
    return cropped == null ? null : File(cropped.path);
  }

  /// Pick → (compress) → (crop) → upload. Returns download URL or null if cancelled.
  static Future<String?> pickAndUploadSingleImage({
    required BuildContext context,
    required String recipeId,
    ImageSource source = ImageSource.gallery,
    bool allowCrop = true,
  }) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return null;

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

  // ───────── OCR → TRANSLATE → FORMAT (Cloud Function) ─────────

  static Future<ProcessedRecipeResult> extractAndFormatRecipe(
    List<String> imageUrls,
    BuildContext context, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final locale = Localizations.localeOf(context);
      final lang = locale.languageCode; // e.g. "en"
      final region = locale.countryCode; // e.g. "GB"

      final functions = FirebaseFunctions.instanceFor(region: 'europe-west2');
      final callable = functions.httpsCallable('extractAndFormatRecipe');

      _logDebug(
        '🤖 Calling CF with ${imageUrls.length} image(s) → $lang${region != null ? "_$region" : ""}',
      );

      final res = await callable
          .call({
            'imageUrls': imageUrls,
            'targetLanguage': lang,
            'targetRegion': region,
          })
          .timeout(timeout);

      final data = (res.data as Map).cast<String, dynamic>();
      final formatted = (data['formattedRecipe'] as String?)?.trim() ?? '';
      if (formatted.isEmpty) {
        throw Exception('Formatted recipe was empty.');
      }

      _logDebug(
        '✅ CF success. lang=${data['detectedLanguage']} translated=${data['translationUsed']}',
      );

      return ProcessedRecipeResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      _logDebug('🛑 CF exception: ${e.code} — ${e.message}');
      switch (e.code) {
        case 'permission-denied':
          upgradeBannerMessage.value =
              '✨ Unlock Chef Mode with the Home Chef or Master Chef plan!';
          throw Exception('Translation blocked due to plan limit.');
        case 'resource-exhausted':
          upgradeBannerMessage.value =
              '🚧 Monthly quota reached. Upgrade for more!';
          throw Exception('Usage limit reached.');
        case 'deadline-exceeded':
        case 'unavailable':
          // Small retry helps against transient errors.
          await Future.delayed(const Duration(milliseconds: 600));
          final locale = Localizations.localeOf(context);
          final retry =
              await FirebaseFunctions.instanceFor(region: 'europe-west2')
                  .httpsCallable('extractAndFormatRecipe')
                  .call({
                    'imageUrls': imageUrls,
                    'targetLanguage': locale.languageCode,
                    'targetRegion': locale.countryCode,
                  })
                  .timeout(timeout);
          final retryData = (retry.data as Map).cast<String, dynamic>();
          return ProcessedRecipeResult.fromMap(retryData);
        default:
          throw Exception('Processing failed: ${e.message}');
      }
    } on TimeoutException {
      throw Exception('Server took too long. Please try again.');
    } catch (e) {
      _logDebug('❌ General exception: $e');
      throw Exception('Failed to process recipe: $e');
    }
  }

  // ───────────────────────────── UI HELPERS ─────────────────────────────

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ────────────────────────────── LOGGING ──────────────────────────────

  static void _logDebug(String message) {
    if (_debug) debugPrint(message);
  }
}

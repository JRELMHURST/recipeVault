// lib/data/services/image_processing_service.dart
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
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'package:recipe_vault/firebase_storage.dart'; // FirebaseStorageService
import 'package:recipe_vault/features/processing/processed_recipe_result.dart';
import 'package:recipe_vault/billing/subscription/subscription_service.dart';

class ImageProcessingService {
  static const int _jpegQualityAndroid = 80;
  static const int _jpegQualityIOS = 85;
  static const int _maxDimension = 2200;
  static const Duration _uploadTimeout = Duration(seconds: 30);
  static const Duration _cfTimeout = Duration(seconds: 150);
  static const int _primaryPages = 3;
  static const int _ocrSufficientChars = 900;
  static const bool _debug = false;
  static final ImagePicker _picker = ImagePicker();

  static Future<void> _ensureUploadAllowedOrThrow(BuildContext context) async {
    final subs = context.read<SubscriptionService>();
    if (!subs.allowImageUpload) {
      _logDebug("❌ Upload entitlement denied. Tier=\${subs.tier}");
      throw SubscriptionGateException(
        '✨ Upload images with the Home Chef or Master Chef plan.',
      );
    }
  }

  static Future<List<File>> pickAndCompressImages(BuildContext context) async {
    await _ensureUploadAllowedOrThrow(context);
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return [];
    return _compressFiles(picked.map((x) => File(x.path)).toList());
  }

  static Future<List<File>> _compressFiles(List<File> files) async {
    final tempDir = await getTemporaryDirectory(); // ✅ This was missing
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
          keepExif: true,
          autoCorrectionAngle: true,
        );

        if (compressed != null && compressed.existsSync()) {
          out.add(compressed);
          _logDebug(
            '✅ Compressed → ${compressed.path} (${await compressed.length()} bytes)',
          );
        } else {
          _logDebug(
            '⚠️ Compression returned null or file missing: ${file.path}',
          );
          out.add(file);
        }
      } catch (e) {
        _logDebug('⚠️ Compression failed for ${file.path}: $e');
        out.add(file);
      }
    }
    return out;
  }

  static Future<List<String>> uploadFiles(
    BuildContext context,
    List<File> files,
  ) async {
    await _ensureUploadAllowedOrThrow(context);
    _logDebug('⏫ Uploading \${files.length} file(s) to Firebase Storage…');
    return FirebaseStorageService.uploadImages(files);
  }

  static Future<String> uploadRecipeImage({
    required BuildContext context,
    required File imageFile,
    required String userId,
    required String recipeId,
  }) async {
    await _ensureUploadAllowedOrThrow(context);
    try {
      final ref = FirebaseStorage.instance.ref(
        'users/\$userId/recipe_images/\$recipeId.jpg',
      );
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000, immutable',
      );

      final task = await ref
          .putFile(imageFile, metadata)
          .timeout(_uploadTimeout);
      final url = await task.ref.getDownloadURL();
      _logDebug('✅ Uploaded recipe image: \$url');
      return url;
    } on TimeoutException {
      throw NetworkTimeoutException(
        'Upload timed out. Please check your connection.',
      );
    } on FirebaseException {
      throw StorageException('Storage error: \${e.code}');
    } catch (e) {
      throw StorageException('Failed to upload recipe image: \$e');
    }
  }

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

  static Future<String?> pickAndUploadSingleImage({
    required BuildContext context,
    required String recipeId,
    ImageSource source = ImageSource.gallery,
    bool allowCrop = true,
  }) async {
    try {
      await _ensureUploadAllowedOrThrow(context);

      final picked = await _picker.pickImage(source: source);
      if (picked == null) return null;

      File file = (await _compressFiles([File(picked.path)])).first;

      if (allowCrop) {
        final cropped = await cropImage(file);
        if (cropped == null) return null;
        file = cropped;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw AuthException('User not signed in');

      return await uploadRecipeImage(
        context: context,
        imageFile: file,
        userId: user.uid,
        recipeId: recipeId,
      );
    } catch (e) {
      showError(context, 'Image upload failed: \$e');
      return null;
    }
  }

  static Future<ProcessedRecipeResult> extractAndFormatRecipe(
    List<String> imageUrls,
    BuildContext context, {
    Duration timeout = _cfTimeout,
  }) async {
    final primaryUrls = imageUrls.length > _primaryPages
        ? imageUrls.take(_primaryPages).toList()
        : imageUrls;

    final locale = Localizations.localeOf(context);
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west2');

    final callable = functions.httpsCallable(
      'extractAndFormatRecipe',
      options: HttpsCallableOptions(timeout: timeout),
    );

    Future<ProcessedRecipeResult> callCF(List<String> urls) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw AuthException('Not signed in.');
      await user.getIdToken(true);

      _logDebug(
        '🤖 Calling CF with \${urls.length} image(s) → \${locale.languageCode}_\${locale.countryCode}',
      );

      final res = await callable.call({
        'imageUrls': urls,
        'targetLanguage': locale.languageCode,
        'targetRegion': locale.countryCode,
      });

      final data = (res.data as Map).cast<String, dynamic>();
      final formatted = (data['formattedRecipe'] as String?)?.trim() ?? '';
      if (formatted.isEmpty) {
        throw ProcessingException('Formatted recipe was empty.');
      }
      return ProcessedRecipeResult.fromMap(data);
    }

    try {
      final fast = await callCF(primaryUrls);

      final subs = context.read<SubscriptionService>();
      if (fast.translationUsed && !subs.allowTranslation) {
        throw SubscriptionGateException(
          '✨ Unlock Chef Mode with Home Chef or Master Chef to translate recipes.',
        );
      }

      final original = fast.originalText.trim();
      if (imageUrls.length > primaryUrls.length &&
          original.length < _ocrSufficientChars) {
        _logDebug(
          '↪️ OCR looked short (\${original.length} chars). Retrying with all \${imageUrls.length} images…',
        );
        final full = await callCF(imageUrls);
        return full;
      }

      return fast;
    } on FirebaseFunctionsException catch (e) {
      _logDebug('🛑 CF exception: \${e.code} — \${e.message}');
      switch (e.code) {
        case 'permission-denied':
          throw SubscriptionGateException(
            '✨ Unlock Chef Mode with the Home Chef or Master Chef plan!',
          );
        case 'resource-exhausted':
          throw UsageLimitException(
            '🚧 Monthly quota reached. Upgrade for more!',
          );
        case 'deadline-exceeded':
        case 'unavailable':
          await Future.delayed(const Duration(milliseconds: 600));
          final retry =
              await FirebaseFunctions.instanceFor(region: 'europe-west2')
                  .httpsCallable(
                    'extractAndFormatRecipe',
                    options: HttpsCallableOptions(timeout: timeout),
                  )
                  .call({
                    'imageUrls': primaryUrls,
                    'targetLanguage': locale.languageCode,
                    'targetRegion': locale.countryCode,
                  });
          return ProcessedRecipeResult.fromMap(
            (retry.data as Map).cast<String, dynamic>(),
          );
        default:
          throw ProcessingException('Processing failed: \${e.message}');
      }
    } on TimeoutException {
      throw NetworkTimeoutException('Server took too long. Please try again.');
    } catch (e) {
      _logDebug('❌ General exception: \$e');
      throw ProcessingException('Failed to process recipe: \$e');
    }
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static void _logDebug(String message) {
    if (_debug) debugPrint(message);
  }
}

class SubscriptionGateException implements Exception {
  final String message;
  SubscriptionGateException(this.message);
  @override
  String toString() => 'SubscriptionGateException: \$message';
}

class UsageLimitException implements Exception {
  final String message;
  UsageLimitException(this.message);
  @override
  String toString() => 'UsageLimitException: \$message';
}

class NetworkTimeoutException implements Exception {
  final String message;
  NetworkTimeoutException(this.message);
  @override
  String toString() => 'NetworkTimeoutException: \$message';
}

class StorageException implements Exception {
  final String message;
  StorageException(this.message);
  @override
  String toString() => 'StorageException: \$message';
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: \$message';
}

class ProcessingException implements Exception {
  final String message;
  ProcessingException(this.message);
  @override
  String toString() => 'ProcessingException: \$message';
}

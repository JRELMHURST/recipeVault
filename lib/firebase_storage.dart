import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

typedef StorageUrl = String;

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Uuid _uuid = const Uuid();

  /// Uploads files to Firebase Storage under the user's path and returns their download URLs.
  static Future<List<String>> uploadImages(List<File> files) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final urls = <String>[];

    for (final file in files) {
      try {
        final recipeId = _uuid.v4();
        final ref = _storage.ref().child(
          'users/${user.uid}/tempUploads/$recipeId.jpg',
        );

        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask.whenComplete(() {});
        final url = await snapshot.ref.getDownloadURL();

        urls.add(url);
      } catch (e, st) {
        if (kDebugMode) {
          print('🔥 Upload failed for ${file.path}: $e\n$st');
        }
        rethrow;
      }
    }

    return urls;
  }

  /// Deletes the images at the given list of download URLs.
  static Future<void> deleteImages(List<StorageUrl> urls) async {
    for (final url in urls) {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
        debugPrint('✅ Deleted image: $url');
      } catch (e) {
        debugPrint('⚠️ Failed to delete image: $url – $e');
      }
    }
  }

  /// Deletes a single image by download URL.
  static Future<void> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      debugPrint('✅ Deleted image: $url');
    } catch (e) {
      debugPrint('⚠️ Failed to delete image: $url – $e');
    }
  }
}

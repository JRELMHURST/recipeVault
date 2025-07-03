import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Uuid _uuid = const Uuid();

  /// Uploads files to Firebase Storage under the user's path and returns their download URLs.
  static Future<List<String>> uploadImages(List<File> files) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final urls = <String>[];

    for (final file in files) {
      try {
        final recipeId = _uuid.v4(); // Unique ID per image or recipe
        final ref = _storage.ref().child(
          'users/${user.uid}/recipe_images/$recipeId.jpg',
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

  /// Deletes an image from the user's folder in Firebase Storage.
  static Future<void> deleteImage(String recipeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final ref = _storage.ref().child(
      'users/${user.uid}/recipe_images/$recipeId.jpg',
    );

    await ref.delete();
  }
}

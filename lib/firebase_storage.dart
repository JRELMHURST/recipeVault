import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class FirebaseStorageService {
  /// Uploads a list of images to the user's tempUploads folder and returns their download URLs.
  static Future<List<String>> uploadImages(List<File> files) async {
    final user = FirebaseAuth.instance.currentUser;
    final storage = FirebaseStorage.instance;
    final urls = <String>[];

    if (user == null) {
      throw Exception('❌ Not signed in — cannot upload images');
    }

    final subService = SubscriptionService();
    if (!subService.allowImageUpload) {
      throw Exception('🔒 Your plan does not allow image uploads.');
    }

    for (final file in files) {
      try {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final path = 'users/${user.uid}/tempUploads/$fileName.jpg';
        final ref = storage.ref().child(path);

        if (kDebugMode) {
          print('📤 Uploading: $path');
        }

        final uploadTask = await ref.putFile(file);
        final url = await uploadTask.ref.getDownloadURL();
        urls.add(url);

        if (kDebugMode) {
          print('✅ Uploaded to: $url');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to upload image: $e');
        }
        rethrow;
      }
    }

    return urls;
  }
}

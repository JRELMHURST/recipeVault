import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  /// Uploads a list of images to the user's tempUploads folder and returns their download URLs.
  static Future<List<String>> uploadImages(List<File> files) async {
    final storage = FirebaseStorage.instance;
    final urls = <String>[];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('❌ Not signed in — cannot upload images');
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
        // You can choose to skip this file or rethrow
        rethrow;
      }
    }

    return urls;
  }
}

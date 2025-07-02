import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Uuid _uuid = const Uuid();

  /// Uploads files to Firebase Storage and returns their public download URLs.
  static Future<List<String>> uploadImages(List<File> files) async {
    final urls = <String>[];

    for (final file in files) {
      try {
        final fileName = _uuid.v4();
        final ref = _storage.ref('uploads/$fileName.jpg');
        final uploadTask = ref.putFile(file);

        final snapshot = await uploadTask.whenComplete(() {});
        final url = await snapshot.ref.getDownloadURL();

        urls.add(url);
      } catch (e, st) {
        if (kDebugMode) {
          print('🔥 Upload failed for ${file.path}: $e\n$st');
        }
        rethrow; // bubble up to caller
      }
    }

    return urls;
  }
}

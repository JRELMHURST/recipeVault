// lib/services/image_upload_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Uuid _uuid = const Uuid();

  /// Uploads each file to Firebase Storage and returns their download URLs.
  static Future<List<String>> uploadImages(List<File> files) async {
    final List<String> urls = [];

    for (final file in files) {
      try {
        final String fileName = _uuid.v4();
        final Reference ref = _storage.ref().child('uploads/$fileName.jpg');
        final UploadTask task = ref.putFile(file);

        final TaskSnapshot snapshot = await task.whenComplete(() {});
        final String url = await snapshot.ref.getDownloadURL();

        urls.add(url);
      } catch (e) {
        rethrow; // Let the caller handle the error
      }
    }

    return urls;
  }
}

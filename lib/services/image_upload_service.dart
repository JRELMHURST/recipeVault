import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Service responsible for uploading images to Firebase Storage.
class ImageUploadService {
  /// Uploads a list of compressed image [File]s to Firebase Storage.
  ///
  /// Returns a list of publicly accessible URLs for the uploaded images.
  static Future<List<String>> uploadImages(List<File> images) async {
    final storage = FirebaseStorage.instance;
    final List<String> urls = [];

    for (final image in images) {
      try {
        // Create a reference with a unique file name in 'uploads/' folder
        final fileName = image.path.split('/').last;
        final ref = storage.ref().child('uploads/$fileName');

        // Upload the file
        for (final image in images) {
          try {
            final fileName = image.path.split('/').last;
            final ref = storage.ref().child('uploads/$fileName');

            await ref.putFile(image); // No need to assign to uploadTask

            final downloadUrl = await ref.getDownloadURL();
            urls.add(downloadUrl);
          } catch (e) {
            throw Exception('Failed to upload image: $e');
          }
        }

        // Once uploaded, get the download URL
        final downloadUrl = await ref.getDownloadURL();

        urls.add(downloadUrl);
      } catch (e) {
        // You may want to log or handle upload errors here
        throw Exception('Failed to upload image: $e');
      }
    }

    return urls;
  }
}

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  /// Uploads a list of images and returns their download URLs.
  static Future<List<String>> uploadImages(List<File> files) async {
    final storage = FirebaseStorage.instance;
    final urls = <String>[];

    for (final file in files) {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = storage.ref().child('uploads/$fileName.jpg');

      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }
}

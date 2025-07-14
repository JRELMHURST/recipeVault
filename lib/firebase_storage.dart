import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  /// Uploads a list of images to the user's tempUploads folder and returns their download URLs.
  static Future<List<String>> uploadImages(List<File> files) async {
    final storage = FirebaseStorage.instance;
    final urls = <String>[];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('❌ Not signed in');
    }

    for (final file in files) {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final path = 'users/${user.uid}/tempUploads/$fileName.jpg';

      final ref = storage.ref().child(path);
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }
}

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class FirebaseStorageService {
  /// Uploads a list of images to the user's tempUploads folder and returns their download URLs.
  ///
  /// Responsibility here is *only* storage. Entitlement/plan checks belong in
  /// the caller (UI/controller) before calling this method.
  static Future<List<String>> uploadImages(List<File> files) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('❌ Not signed in — cannot upload images.');
    }
    if (files.isEmpty) return const <String>[];

    final storage = FirebaseStorage.instance;
    final urls = <String>[];
    final uuid = const Uuid();

    for (final file in files) {
      try {
        // Try to preserve extension; default to .jpg
        final pathExt = _inferExtension(file.path);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${uuid.v4()}$pathExt';
        final path = 'users/${user.uid}/tempUploads/$fileName';
        final ref = storage.ref().child(path);

        if (kDebugMode) print('📤 Uploading image → $path');

        final metadata = SettableMetadata(
          contentType: _inferContentType(pathExt),
          cacheControl: 'public,max-age=31536000,immutable',
        );

        final task = await ref.putFile(file, metadata);
        final url = await task.ref.getDownloadURL();
        urls.add(url);

        if (kDebugMode) print('✅ Uploaded: $url');
      } catch (e) {
        if (kDebugMode) print('❌ Failed to upload image: $e');
        rethrow; // propagate so caller can show a proper error
      }
    }

    return urls;
  }

  static String _inferExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.jpeg')) return '.jpeg';
    if (lower.endsWith('.jpg')) return '.jpg';
    return '.jpg';
  }

  static String _inferContentType(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.jpeg':
      case '.jpg':
      default:
        return 'image/jpeg';
    }
  }
}

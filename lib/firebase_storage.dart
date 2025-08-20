// ignore_for_file: depend_on_referenced_packages

import 'dart:io' show File;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

typedef UploadProgress =
    void Function({
      required int index, // 0-based index of the file being uploaded
      required int total, // total files
      required double? percent, // 0..1 (if known)
    });

class FirebaseStorageService {
  /// Uploads images into `users/{uid}/tempUploads/` and returns download URLs.
  /// Throws if not signed in or any upload fails.
  static Future<List<String>> uploadImages(
    List<File> files, {
    UploadProgress? onProgress,
    int concurrency = 3, // limit parallelism
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('❌ Not signed in — cannot upload images.');
    }
    if (files.isEmpty) return const <String>[];

    // NOTE: If you target Flutter Web, implement a putData() branch here.
    if (kIsWeb) {
      throw UnsupportedError('Use putData for web uploads (XFile.bytes).');
    }

    final storage = FirebaseStorage.instance;
    final total = files.length;
    final urls = List<String?>.filled(total, null);
    final uuid = const Uuid();

    // Simple worker queue
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next;
        if (i >= total) break;
        next++;

        final file = files[i];

        final ext = _inferExtension(file.path);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${uuid.v4()}$ext';
        final path = 'users/${user.uid}/tempUploads/$fileName';
        final ref = storage.ref(path);

        // Content‑type via mime package; fallback by extension.
        final ct = mime.lookupMimeType(file.path) ?? _inferContentType(ext);

        final metadata = SettableMetadata(
          contentType: ct,
          cacheControl: 'public,max-age=31536000,immutable',
          customMetadata: {
            'originalName': p.basename(file.path),
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'source': 'recipe_vault',
          },
        );

        if (kDebugMode) print('📤 [$i/${total - 1}] Uploading → $path');

        try {
          final task = ref.putFile(file, metadata);
          // Progress callback (best effort; not all platforms report total bytes)
          task.snapshotEvents.listen((snap) {
            final p = (snap.totalBytes > 0)
                ? snap.bytesTransferred / snap.totalBytes
                : null;
            onProgress?.call(index: i, total: total, percent: p);
          });

          final completed = await task;
          final url = await completed.ref.getDownloadURL();
          urls[i] = url;

          if (kDebugMode) print('✅ Uploaded: $url');
        } catch (e) {
          if (kDebugMode) print('❌ Upload failed ($path): $e');
          rethrow; // propagate so UI can show an error
        }
      }
    }

    // Start capped number of workers
    final workers = List.generate(concurrency.clamp(1, total), (_) => worker());
    await Future.wait(workers);

    // All should be filled; if any null, treat as failure (shouldn’t happen due to rethrow)
    return urls.cast<String>();
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

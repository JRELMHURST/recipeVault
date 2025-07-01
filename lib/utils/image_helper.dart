import 'dart:io';

class ImageHelper {
  /// Returns the size of the file in kilobytes.
  static Future<double> getFileSizeInKB(File file) async {
    final bytes = await file.length();
    return bytes / 1024;
  }

  /// Suggest a compression quality based on original file size.
  /// Larger files get more compression.
  static int suggestCompressionQuality(File file) {
    // File size in KB
    final sizeKB = file.lengthSync() / 1024;

    if (sizeKB > 5000) {
      return 50; // very large file, heavy compression
    } else if (sizeKB > 2000) {
      return 65;
    } else if (sizeKB > 1000) {
      return 75;
    } else {
      return 85; // small file, light compression
    }
  }

  /// Checks if the file extension is a supported image format
  /// (jpeg, jpg, png)
  static bool isSupportedImage(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return ['jpeg', 'jpg', 'png'].contains(extension);
  }
}

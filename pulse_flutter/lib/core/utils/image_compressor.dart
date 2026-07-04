import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;
  static const int _targetQuality = 80;
  static const int _minSizeThreshold = 100 * 1024;

  static bool _isImageFile(String fileName) {
    final String lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  static Future<Uint8List?> compressImageBytes({
    required Uint8List bytes,
    required String fileName,
    int? maxWidth,
    int? maxHeight,
    int quality = _targetQuality,
  }) async {
    if (!_isImageFile(fileName)) return null;
    if (bytes.length < _minSizeThreshold) return null;

    try {
      final Uint8List result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth ?? _maxWidth,
        minHeight: maxHeight ?? _maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (result.length < bytes.length) {
        return result;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<File?> compressImageFile({
    required File file,
    required String fileName,
    int? maxWidth,
    int? maxHeight,
    int quality = _targetQuality,
  }) async {
    if (!_isImageFile(fileName)) return null;

    try {
      final int fileSize = await file.length();
      if (fileSize < _minSizeThreshold) return null;

      final Directory tempDir = await getTemporaryDirectory();
      final String outPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        minWidth: maxWidth ?? _maxWidth,
        minHeight: maxHeight ?? _maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final File compressedFile = File(result.path);
        final int newSize = await compressedFile.length();
        if (newSize < fileSize) {
          return compressedFile;
        }
        try { await compressedFile.delete(); } catch (_) {}
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

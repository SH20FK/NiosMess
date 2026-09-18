import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

class DesktopPasteboardService {
  const DesktopPasteboardService._();

  /// Returns true if running on a desktop platform (Windows, macOS, Linux).
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Checks if clipboard contains files or an image.
  /// If it does, returns a list of local file paths (creating a temp file for raw image bytes if needed).
  /// If clipboard only contains text or is empty, returns an empty list.
  static Future<List<String>> getClipboardFilesOrImage() async {
    if (!isDesktop) return const <String>[];

    try {
      // 1. Check for file paths on clipboard
      final List<String> files = await Pasteboard.files();
      if (files.isNotEmpty) {
        final List<String> valid = <String>[];
        for (final String path in files) {
          if (path.isNotEmpty && await File(path).exists()) {
            valid.add(path);
          }
        }
        if (valid.isNotEmpty) {
          return valid;
        }
      }

      // 2. Check for raw image bytes on clipboard (e.g. screenshot or copied image from browser/app)
      final Uint8List? imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName =
            'clipboard_img_${DateTime.now().millisecondsSinceEpoch}.png';
        final File file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(imageBytes);
        return <String>[file.path];
      }
    } catch (_) {
      // Ignore clipboard read errors gracefully
    }

    return const <String>[];
  }
}

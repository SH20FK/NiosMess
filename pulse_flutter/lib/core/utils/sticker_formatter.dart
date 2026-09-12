import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Sticker formatting mode for client-side processing.
enum StickerFitMode {
  /// Preserves full aspect ratio with transparent margins to fit 512x512 box.
  fit,

  /// Center-crops image to a square and scales to 512x512 without borders.
  crop,
}

/// Result of formatting an image for sticker upload.
class StickerFormatResult {
  const StickerFormatResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.extension,
    required this.mimeType,
    this.isVideo = false,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String extension;
  final String mimeType;
  final bool isVideo;
}

class StickerFormatter {
  static const int kStickerDimension = 512;

  /// Formats [inputBytes] into compliant 512x512 sticker bytes.
  /// If [inputBytes] is a video or unsupported binary, returns the original bytes.
  static Future<StickerFormatResult> formatBytes(
    Uint8List inputBytes, {
    StickerFitMode mode = StickerFitMode.fit,
  }) async {
    // Attempt decoding using package:image (supports PNG, JPG, GIF, WebP, BMP, TIFF, etc.)
    final img.Image? decoded = img.decodeImage(inputBytes);

    if (decoded == null) {
      // Non-image format (e.g. video / animated webm / mp4)
      return StickerFormatResult(
        bytes: inputBytes,
        width: kStickerDimension,
        height: kStickerDimension,
        extension: 'webm',
        mimeType: 'video/webm',
        isVideo: true,
      );
    }

    final int srcW = decoded.width;
    final int srcH = decoded.height;

    img.Image finalImage;

    if (mode == StickerFitMode.crop) {
      final int minSide = min(srcW, srcH);
      final int cropX = (srcW - minSide) ~/ 2;
      final int cropY = (srcH - minSide) ~/ 2;

      final img.Image cropped = img.copyCrop(
        decoded,
        x: cropX,
        y: cropY,
        width: minSide,
        height: minSide,
      );

      finalImage = img.copyResize(
        cropped,
        width: kStickerDimension,
        height: kStickerDimension,
        interpolation: img.Interpolation.linear,
      );
    } else {
      // Fit mode: preserve aspect ratio, fit inside 512x512 and center on transparent canvas
      final double scale = kStickerDimension / max(srcW, srcH);
      final int targetW = (srcW * scale).round().clamp(1, kStickerDimension);
      final int targetH = (srcH * scale).round().clamp(1, kStickerDimension);

      final img.Image resized = img.copyResize(
        decoded,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.linear,
      );

      // Create transparent 512x512 RGBA canvas
      final img.Image canvas = img.Image(
        width: kStickerDimension,
        height: kStickerDimension,
        numChannels: 4,
      );
      canvas.clear(img.ColorRgba8(0, 0, 0, 0));

      final int dstX = (kStickerDimension - targetW) ~/ 2;
      final int dstY = (kStickerDimension - targetH) ~/ 2;

      img.compositeImage(
        canvas,
        resized,
        dstX: dstX,
        dstY: dstY,
      );

      finalImage = canvas;
    }

    // Encode as high-quality PNG with alpha transparency
    final Uint8List pngBytes = Uint8List.fromList(img.encodePng(finalImage));

    return StickerFormatResult(
      bytes: pngBytes,
      width: kStickerDimension,
      height: kStickerDimension,
      extension: 'png',
      mimeType: 'image/png',
      isVideo: false,
    );
  }
}

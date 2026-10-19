import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulse_flutter/core/utils/sticker_formatter.dart';

void main() {
  group('StickerFormatter', () {
    late Uint8List testLandscapeImageBytes;
    late Uint8List testPortraitImageBytes;

    setUp(() {
      final img.Image landscape = img.Image(width: 200, height: 100);
      landscape.clear(img.ColorRgba8(255, 0, 0, 255));
      testLandscapeImageBytes = Uint8List.fromList(img.encodePng(landscape));

      final img.Image portrait = img.Image(width: 100, height: 300);
      portrait.clear(img.ColorRgba8(0, 255, 0, 255));
      testPortraitImageBytes = Uint8List.fromList(img.encodePng(portrait));
    });

    test(
      'formatBytes with fit mode preserves aspect ratio and outputs 512x512 PNG',
      () async {
        final StickerFormatResult result = await StickerFormatter.formatBytes(
          testLandscapeImageBytes,
          mode: StickerFitMode.fit,
        );

        expect(result.width, 512);
        expect(result.height, 512);
        expect(result.extension, 'png');
        expect(result.mimeType, 'image/png');
        expect(result.isVideo, isFalse);

        final img.Image? decoded = img.decodeImage(result.bytes);
        expect(decoded, isNotNull);
        expect(decoded!.width, 512);
        expect(decoded.height, 512);
      },
    );

    test(
      'formatBytes with crop mode produces exact 512x512 cropped PNG',
      () async {
        final StickerFormatResult result = await StickerFormatter.formatBytes(
          testPortraitImageBytes,
          mode: StickerFitMode.crop,
        );

        expect(result.width, 512);
        expect(result.height, 512);
        expect(result.extension, 'png');
        expect(result.mimeType, 'image/png');
        expect(result.isVideo, isFalse);

        final img.Image? decoded = img.decodeImage(result.bytes);
        expect(decoded, isNotNull);
        expect(decoded!.width, 512);
        expect(decoded.height, 512);
      },
    );

    test(
      'invalid bytes are rejected instead of renamed as a WebM video',
      () async {
        final Uint8List rawBinary = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
        await expectLater(
          StickerFormatter.formatBytes(rawBinary),
          throwsFormatException,
        );
      },
    );

    test(
      'video containers are preserved without decoding or fake conversion',
      () async {
        final bytes = Uint8List.fromList(
          List<int>.generate(512, (i) => i % 256),
        );
        for (final ext in ['mp4', 'mov', 'webm']) {
          final result = await StickerFormatter.formatBytes(
            bytes,
            filename: 'clip.$ext',
          );
          expect(result.bytes, same(bytes));
          expect(result.extension, ext);
          expect(result.isVideo, isTrue);
        }
      },
    );
  });
}

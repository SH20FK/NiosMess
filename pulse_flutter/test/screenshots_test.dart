import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

/// Generates screenshots for the landing page using mock app screens.
///
/// Usage:
///   flutter test test/screenshots_test.dart
///
/// Output: ../niosmess_landing/public/screens/*.png
void main() {
  const screens = [
    ('chats', 0),
    ('messages', 1),
    ('group', 2),
    ('channel', 3),
    ('niosgram', 4),
    ('voice', 5),
    ('themes', 6),
    ('profile', 7),
  ];

  for (final (name, page) in screens) {
    testWidgets('capture $name', (tester) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MockScreenshotsApp(page: page),
        ),
      );
      await tester.pumpAndSettle();

      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final dir = Directory('../niosmess_landing/public/screens');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      await File('${dir.path}/$name.png').writeAsBytes(pngBytes);
      debugPrint('Screenshot saved: $name.png');
    });
  }
}

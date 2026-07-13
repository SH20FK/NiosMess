import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

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
      await tester.pump(const Duration(milliseconds: 500));

      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Output base64 to stdout for capture by external script
      print('SCREENSHOT:$name:${base64Encode(pngBytes)}');
      debugPrint('Screenshot captured: $name.png (${pngBytes.length} bytes)');
    });
  }
}

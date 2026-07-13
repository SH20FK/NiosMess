import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  testWidgets('capture all screens one by one', (tester) async {
    const screens = [0, 1, 2, 3, 4, 5, 6, 7];
    const names = ['chats','messages','group','channel','niosgram','voice','themes','profile'];
    for (var i = 0; i < screens.length; i++) {
      debugPrint('=== START screen=${names[i]} page=${screens[i]} ===');
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MockScreenshotsApp(page: screens[i]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      debugPrint('RENDERED ${names[i]}');
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      debugPrint('TOIMAGE ${names[i]}');
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final dir = Directory('../niosmess_landing/public/screens');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      await File('${dir.path}/${names[i]}.png').writeAsBytes(pngBytes);
      debugPrint('=== DONE ${names[i]} (${pngBytes.length} bytes) ===');
    }
    debugPrint('ALL DONE');
  });
}

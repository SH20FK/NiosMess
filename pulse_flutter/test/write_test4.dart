import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  testWidgets('write messages screenshot', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: MockScreenshotsApp(page: 1)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    print('PUMPED');
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    print('TOIMAGE');
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    print('BYTES');
    File('test_messages.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    print('WROTE');
  });
}

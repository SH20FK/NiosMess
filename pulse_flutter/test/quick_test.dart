import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  for (final entry in [('chats', 0), ('messages', 1)]) {
    testWidgets('cap ${entry.$1}', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: MockScreenshotsApp(page: entry.$2)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      print('SS:${entry.$1}:${base64Encode(bytes!.buffer.asUint8List())}');
    });
  }
}

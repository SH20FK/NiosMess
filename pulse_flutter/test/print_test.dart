import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  testWidgets('print chats', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: MockScreenshotsApp(page: 0)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    print('DATA:${base64Encode(bytes!.buffer.asUint8List())}');
    print('DONE');
  });
}

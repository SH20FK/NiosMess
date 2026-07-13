import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  testWidgets('mock app write test', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: MockScreenshotsApp(page: 0)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    debugPrint('CWD: ${Directory.current.path}');
    final dir = Directory('${Directory.current.path}/../niosmess_landing/public/screens');
    debugPrint('DIR: ${dir.path}');
    debugPrint('EXISTS: ${dir.existsSync()}');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      debugPrint('CREATED');
    }
    await File('${dir.path}/test_chats.png').writeAsBytes(bytes!.buffer.asUint8List());
    debugPrint('WRITTEN');
  });
}

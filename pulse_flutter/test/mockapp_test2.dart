import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  testWidgets('mock app chats', (tester) async {
    final key = GlobalKey();
    debugPrint('PUMP');
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: MockScreenshotsApp(page: 0)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    debugPrint('TOIMAGE');
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    debugPrint('IMAGE: ${image.width}x${image.height}');
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    debugPrint('BYTES: ${bytes!.lengthInBytes}');
    final dir = Directory('../niosmess_landing/public/screens');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await File('${dir.path}/test_chats.png').writeAsBytes(bytes.buffer.asUint8List());
    debugPrint('WRITTEN');
  });
}

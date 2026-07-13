import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  const screens = [
    ('chats', 0), ('messages', 1), ('group', 2), ('channel', 3),
    ('niosgram', 4), ('voice', 5), ('themes', 6), ('profile', 7),
  ];

  final outDir = Directory('${Directory.current.path}/../niosmess_landing/public/screens');
  outDir.createSync(recursive: true);

  for (final (name, page) in screens) {
    testWidgets(name, (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: MockScreenshotsApp(page: page)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final w = image.width;
      final h = image.height;
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      // Write raw RGBA data: header line + raw pixel bytes
      final header = '$w,$h\n';
      final rawBytes = raw!.buffer.asUint8List();
      final out = List<int>.generate(header.length + rawBytes.length, (i) {
        return i < header.length ? header.codeUnitAt(i) : rawBytes[i - header.length];
      });
      await File('${outDir.path}/${name}.raw').writeAsBytes(out);
    }, timeout: const Timeout(Duration(seconds: 30)));
  }
}

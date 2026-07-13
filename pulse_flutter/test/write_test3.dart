import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  final baseDir = Directory.current.path;
  final outDir = '$baseDir/../niosmess_landing/public/screens';
  
  testWidgets('write all screenshots', (tester) async {
    Directory(outDir).createSync(recursive: true);
    
    for (final entry in [(0, 'chats'), (1, 'messages'), (2, 'group'), (3, 'channel'), (4, 'niosgram'), (5, 'voice'), (6, 'themes'), (7, 'profile')]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: MockScreenshotsApp(page: entry.$1)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/${entry.$2}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      print('WROTE ${entry.$2}.png');
    }
    print('ALL DONE');
  });
}

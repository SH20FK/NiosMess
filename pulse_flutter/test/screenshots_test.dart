import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  const screens = [
    ('chats', 0), ('messages', 1), ('group', 2), ('channel', 3),
    ('niosgram', 4), ('voice', 5), ('themes', 6), ('profile', 7),
  ];

  for (final (name, page) in screens) {
    testWidgets(name, (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: MockScreenshotsApp(page: page)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('$name.png'),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  }
}

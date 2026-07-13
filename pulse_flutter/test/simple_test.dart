import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  testWidgets('simple test', (tester) async {
    await tester.pumpWidget(MockScreenshotsApp(page: 0));
    await tester.pump(const Duration(milliseconds: 500));
    print('PUMP OK');
  });
}

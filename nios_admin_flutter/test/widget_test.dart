import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nios_admin_flutter/main.dart';

void main() {
  testWidgets('AdminApp loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: AdminApp()));

    // Verify that the MaterialApp is created.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

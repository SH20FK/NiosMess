import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/modal/app_side_sheet.dart';

void main() {
  testWidgets('a full-screen child fills the side sheet', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const Key sheetKey = ValueKey<String>('sheet-screen');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => AppSideSheet.show<void>(
                context: context,
                // Profile screens are a Scaffold with a scroll view inside.
                child: const Scaffold(
                  key: sheetKey,
                  body: CustomScrollView(
                    slivers: <Widget>[
                      SliverToBoxAdapter(child: Text('profile body')),
                    ],
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(sheetKey)), const Size(440, 900));
    expect(tester.getTopLeft(find.byKey(sheetKey)), const Offset(960, 0));
    expect(find.text('profile body').hitTestable(), findsOneWidget);
  });
}

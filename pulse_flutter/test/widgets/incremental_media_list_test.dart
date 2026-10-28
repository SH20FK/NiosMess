import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/profile/incremental_media_list.dart';

void main() {
  testWidgets('embedded media rows mount in batches as the viewport advances', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final built = <int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IncrementalMediaList(
              itemCount: 60,
              itemBuilder: (_, index) {
                built.add(index);
                return SizedBox(height: 80, child: Text('row $index'));
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(built, containsAll(List.generate(8, (i) => i)));
    expect(built, isNot(contains(8)));
    for (var i = 0; i < 12 && !built.contains(59); i++) {
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -580),
      );
      await tester.pumpAndSettle();
    }
    expect(built, contains(59));
    expect(tester.takeException(), isNull);
  });
}

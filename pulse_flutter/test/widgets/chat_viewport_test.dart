import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/chat/chat_viewport.dart';

void main() {
  testWidgets(
    'composer height change moves the inset and FAB without rebuilding the messages',
    (tester) async {
      final composerHeight = ValueNotifier<double>(72);
      addTearDown(composerHeight.dispose);
      var messagesBuilds = 0;
      var rowBuilds = 0;
      ValueListenable<double>? inset;
      const fabKey = ValueKey<String>('fab');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatViewport(
              wallpaper: const SizedBox.expand(),
              messagesBuilder: (context, bottomInset) {
                messagesBuilds++;
                inset = bottomInset;
                return Builder(
                  builder: (context) {
                    rowBuilds++;
                    return const SizedBox.expand();
                  },
                );
              },
              floatingActionButton: const SizedBox(
                key: fabKey,
                width: 40,
                height: 40,
              ),
              composer: ValueListenableBuilder<double>(
                valueListenable: composerHeight,
                builder: (context, height, _) => SizedBox(height: height),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(inset!.value, 80);
      final double fabBefore = tester.getBottomLeft(find.byKey(fabKey)).dy;
      final int messagesBefore = messagesBuilds;
      final int rowsBefore = rowBuilds;

      // Emoji panel / reply bar: the composer grows on its own.
      composerHeight.value = 320;
      await tester.pump();
      await tester.pump();

      expect(inset!.value, 328);
      expect(messagesBuilds, messagesBefore);
      expect(rowBuilds, rowsBefore);
      expect(
        tester.getBottomLeft(find.byKey(fabKey)).dy,
        closeTo(fabBefore - 248, 0.001),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

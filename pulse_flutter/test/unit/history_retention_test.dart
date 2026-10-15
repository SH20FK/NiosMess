import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/storage/chat_history_retention.dart';
import 'package:pulse_flutter/core/storage/sorted_history.dart';

void main() {
  testWidgets(
    'idle histories evict by LRU and a resumed history keeps its lease',
    (tester) async {
      final retention = ChatHistoryRetention(
        maxIdleChats: 2,
        now: tester.binding.clock.now,
      );
      final released = <String>[];
      retention.retain('a', () => released.add('a'));
      retention.retain('b', () => released.add('b'));
      retention.resume('a');
      retention.retain('c', () => released.add('c'));
      expect(released, isEmpty);
      retention.retain('d', () => released.add('d'));
      expect(released, ['b']);
      expect(retention.idleCount, 2);
      retention.dispose();
      expect(released, ['b', 'c', 'd']);
    },
  );

  testWidgets(
    'idle expiration releases exactly once and resuming cancels expiry',
    (tester) async {
      final retention = ChatHistoryRetention(
        idleTtl: const Duration(seconds: 2),
        now: tester.binding.clock.now,
      );
      var released = 0;
      retention.retain('a', () => released++);
      await tester.pump(const Duration(seconds: 1));
      retention.resume('a');
      await tester.pump(const Duration(seconds: 3));
      expect(released, 0);
      retention.retain('a', () => released++);
      await tester.pump(const Duration(seconds: 2));
      expect(released, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(released, 1);
      retention.dispose();
    },
  );

  test('ordered insertion and page merge preserve out-of-order events', () {
    final history = [2, 4, 8];
    insertSorted(history, 6, (a, b) => a.compareTo(b));
    insertSorted(history, 1, (a, b) => a.compareTo(b));
    insertSorted(history, 10, (a, b) => a.compareTo(b));
    expect(history, [1, 2, 4, 6, 8, 10]);
    expect(mergeSorted(history, [0, 3, 7, 11], (a, b) => a.compareTo(b)), [
      0,
      1,
      2,
      3,
      4,
      6,
      7,
      8,
      10,
      11,
    ]);
  });
}

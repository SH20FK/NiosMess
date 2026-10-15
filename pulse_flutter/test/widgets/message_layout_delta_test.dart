import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/storage/message_history_snapshot.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/chat/message_layout_store.dart';

ApiMessage _row(int id) => ApiMessage.fromJson({
  'id': id,
  'chat_id': 42,
  'sender_id': id.isEven ? 1 : 2,
  'content': 'Message $id',
  'msg_type': 'text',
  'sent_at': DateTime.utc(
    2026,
    10,
    15,
  ).add(Duration(seconds: id.abs())).toIso8601String(),
});

class _CountedRows extends ListBase<ApiMessage> {
  _CountedRows(this.rows);
  final List<ApiMessage> rows;
  int reads = 0;
  @override
  int get length => rows.length;
  @override
  set length(int value) => throw UnsupportedError('read only');
  @override
  ApiMessage operator [](int index) {
    reads++;
    return rows[index];
  }

  @override
  void operator []=(int index, ApiMessage value) =>
      throw UnsupportedError('read only');
}

void _expectLayout(MessageLayoutStore store, List<ApiMessage> expected) {
  final reference = MessageLayoutStore()..reset(expected);
  expect(store.byId, reference.byId);
  expect(store.idToIndex, reference.idToIndex);
  for (var i = 0; i < expected.length; i++) {
    expect(store.layout[i].showDateSep, reference.layout[i].showDateSep);
    expect(store.layout[i].isPrevSame, reference.layout[i].isPrevSame);
    expect(store.layout[i].isNextSame, reference.layout[i].isNextSame);
  }
}

void main() {
  group('Known history deltas (algorithmic, not device FPS)', () {
    for (final count in [100, 1000, 10000]) {
      test('tail append reads bounded rows for history length $count', () {
        final previous = List.generate(count, (i) => _row(i + 1));
        final store = MessageLayoutStore()..reset(previous);
        final retained = store.layout.first;
        final added = _row(count + 1);
        final rows = _CountedRows([...previous, added]);
        final next = MessageHistorySnapshot(
          previous: previous,
          rows: rows,
          appended: [added],
        );
        store.sync(next);
        expect(rows.reads, lessThanOrEqualTo(3));
        expect(identical(store.layout.first, retained), isTrue);
        expect(store.idToIndex[count + 1], 0);
        expect(store.idToIndex[1], count);
        _expectLayout(store, rows.rows);
      });

      test(
        'known middle update reads bounded rows for history length $count',
        () {
          final previous = List.generate(count, (i) => _row(i + 1));
          final store = MessageLayoutStore()..reset(previous);
          final retained = store.layout.first;
          final index = count ~/ 2;
          final edited = previous[index].copyWith(
            content: 'Edited',
            senderId: 7,
          );
          final rows = _CountedRows([...previous]..[index] = edited);
          store.sync(
            MessageHistorySnapshot(
              previous: previous,
              rows: rows,
              replacements: {index: edited},
            ),
          );
          expect(rows.reads, lessThanOrEqualTo(3));
          expect(identical(store.layout.first, retained), isTrue);
          expect(identical(store.byId[edited.id], edited), isTrue);
          _expectLayout(store, rows.rows);
        },
      );
    }

    test('direct append/update APIs preserve untouched layout and indexes', () {
      final previous = List.generate(1000, (i) => _row(i + 1));
      final store = MessageLayoutStore()..reset(previous);
      final retained = store.layout[10];
      final added = _row(1001);
      store.append(added);
      final edited = previous[500].copyWith(isDeleted: true);
      expect(store.update(edited), isTrue);
      expect(store.update(_row(90000)), isFalse);
      expect(identical(store.layout[10], retained), isTrue);
      final expected = [...previous]..[500] = edited;
      expected.add(added);
      _expectLayout(store, expected);
    });

    test(
      'pending acknowledgement replaces identity without scanning old rows',
      () {
        final previous = [_row(1), _row(2), _row(-3)];
        final store = MessageLayoutStore()..reset(previous);
        final confirmed = _row(3);
        final rows = _CountedRows([previous[0], previous[1], confirmed]);
        final next = MessageHistorySnapshot.afterAcknowledgement(
          previous: previous,
          rows: rows,
          pendingId: -3,
          confirmed: confirmed,
        );
        store.sync(next);
        expect(rows.reads, lessThanOrEqualTo(5));
        expect(store.byId.containsKey(-3), isFalse);
        expect(store.idToIndex[3], 0);
        _expectLayout(store, rows.rows);
      },
    );

    test(
      'skipped producer snapshot falls back and retains concurrent middle edit',
      () {
        final previous = List.generate(100, (i) => _row(i + 1));
        final store = MessageLayoutStore()..reset(previous);
        final skipped = [...previous, _row(101)];
        final finalRows = [...skipped, _row(102)]
          ..[50] = previous[50].copyWith(content: 'Concurrent edit');
        store.sync(
          MessageHistorySnapshot(
            previous: skipped,
            rows: finalRows,
            appended: [finalRows.last],
          ),
        );
        expect(store.byId[51]!.content, 'Concurrent edit');
        _expectLayout(store, finalRows);
      },
    );

    test(
      'invalid index hint falls back before partially applying mutations',
      () {
        final previous = [_row(1), _row(2), _row(3)];
        final edited = previous[1].copyWith(content: 'Changed');
        final rows = [previous[0], edited, previous[2]];
        final store = MessageLayoutStore()..reset(previous);
        store.sync(
          MessageHistorySnapshot(
            previous: previous,
            rows: rows,
            replacements: {999: edited},
          ),
        );
        _expectLayout(store, rows);
      },
    );

    test(
      'snapshot is read only and retains only an opaque previous identity',
      () {
        final previous = [_row(1)];
        final added = _row(2);
        final next = MessageHistorySnapshot(
          previous: previous,
          rows: [...previous, added],
          appended: [added],
        );
        expect(
          next.previousIdentity,
          same(MessageHistorySnapshot.identityOf(previous)),
        );
        expect(() => next.add(_row(3)), throwsUnsupportedError);
        expect(() => next.replacements[0] = added, throwsUnsupportedError);
        expect(() => next.appended.add(added), throwsUnsupportedError);
      },
    );
  });
}

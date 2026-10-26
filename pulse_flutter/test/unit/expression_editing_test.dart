import 'package:test/test.dart';
import 'package:pulse_flutter/core/utils/expression_editing.dart';

void main() {
  group('expression deletion at the cursor', () {
    test('keeps the suffix and removes the previous whole ZWJ emoji', () {
      const prefix = 'a👩🏽‍💻';
      expect(
        deleteExpressionBeforeCursor(
          '${prefix}b',
          prefix.length,
          prefix.length,
        ),
        (text: 'ab', cursor: 1),
      );
    });
    test('expands an inner surrogate offset to the full emoji', () {
      expect(deleteExpressionBeforeCursor('Привет😊!', 7, 7), (
        text: 'Привет!',
        cursor: 6,
      ));
    });
    test('deletes custom wire tokens atomically on plain controllers', () {
      expect(deleteExpressionBeforeCursor('a:happy:b', 8, 8), (
        text: 'ab',
        cursor: 1,
      ));
      expect(deleteExpressionBeforeCursor('a:happy:b', 3, 5), (
        text: 'ab',
        cursor: 1,
      ));
    });
    test('keeps text at start and deletes only the selected range', () {
      expect(deleteExpressionBeforeCursor('abc', 0, 0), (
        text: 'abc',
        cursor: 0,
      ));
      expect(deleteExpressionBeforeCursor('abc', 1, 2), (
        text: 'ac',
        cursor: 1,
      ));
    });
  });
}

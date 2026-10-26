import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/diagnostics/app_logger.dart';

class _UnprintableError {
  @override
  String toString() =>
      throw StateError('Exception bodies must never be formatted');
}

void main() {
  group('diagnostics privacy boundary', () {
    final logger = AppLogger.instance;
    late DebugPrintCallback original;
    late List<String> console;
    setUp(() {
      logger.clear();
      original = debugPrint;
      console = [];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) console.add(message);
      };
    });
    tearDown(() {
      logger.clear();
      debugPrint = original;
    });
    test('source JSON and credentials never reach archive or console', () {
      const marker = 'synthetic-private-content-do-not-export';
      logger.error(
        const FormatException(
          'invalid payload',
          '{"message":"$marker","token":"$marker"}',
        ),
        StackTrace.current,
        source: 'transport',
      );
      logger.flutterError(
        FlutterErrorDetails(
          exception: StateError(marker),
          stack: StackTrace.current,
        ),
      );
      expect(logger.exportLogs(), isNot(contains(marker)));
      expect(console.join('\n'), isNot(contains(marker)));
      expect(logger.exportLogs(), contains('error_type:FormatException'));
      expect(logger.exportLogs(), contains('error_type:StateError'));
      expect(
        logger.entries.first.stackTrace.toString(),
        contains('app_logger_privacy_test.dart'),
      );
    });
    test(
      'does not format arbitrary exception payload and bounds retained stacks',
      () {
        logger.error(
          _UnprintableError(),
          StackTrace.fromString(List.filled(100, 'synthetic-frame').join('\n')),
        );
        expect(logger.entries.single.message, 'error_type:_UnprintableError');
        expect(
          logger.entries.single.stackTrace.toString().split('\n'),
          hasLength(24),
        );
      },
    );
  });
}

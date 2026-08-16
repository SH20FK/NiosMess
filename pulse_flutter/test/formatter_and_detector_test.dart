import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/utils/message_formatter.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';

void main() {
  group('MessageFormatter.forwarded messages', () {
    test('extracts body from _fwd hack', () {
      expect(
        MessageFormatter.displayText('_fwd from bob: check this out'),
        'check this out',
      );
    });

    test('returns normal text untouched', () {
      expect(MessageFormatter.displayText('hello world'), 'hello world');
      expect(MessageFormatter.displayText('_forwarded from x'), '_forwarded from x');
    });

    test('forwarded without body renders empty', () {
      expect(MessageFormatter.displayText('_fwd from alice:'), '');
    });
  });

  group('FileTypeDetector', () {
    test('detects images by extension', () {
      final info = FileTypeDetector.detectFromFileName('photo.JPG');
      expect(info.category, FileTypeCategory.image);
    });

    test('detects documents', () {
      expect(
        FileTypeDetector.detectFromFileName('report.pdf').category,
        FileTypeCategory.document,
      );
      expect(
        FileTypeDetector.detectFromFileName('table.XLSX').category,
        FileTypeCategory.document,
      );
    });

    test('unknown extensions fall back gracefully', () {
      final info = FileTypeDetector.detectFromFileName('mystery.zzz');
      expect(info.category, isNot(FileTypeCategory.document));
    });

    test('formats file sizes', () {
      expect(FileTypeDetector.formatFileSize(0), contains('B'));
      expect(FileTypeDetector.formatFileSize(2048), contains('KB'));
      expect(FileTypeDetector.formatFileSize(5 * 1024 * 1024), contains('MB'));
    });
  });
}

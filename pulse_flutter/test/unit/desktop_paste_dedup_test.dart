import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/services/desktop_pasteboard_service.dart';

void main() {
  test('DesktopPasteDeduplicator rejects duplicate file paste inside cooldown', () {
    final dedup = DesktopPasteDeduplicator(
      cooldown: const Duration(milliseconds: 450),
    );
    final t0 = DateTime(2026, 11, 26, 12, 0, 0, 0);

    expect(dedup.shouldAccept(['C:/tmp/clip.png'], now: t0), isTrue);
    expect(
      dedup.shouldAccept(
        ['C:/tmp/clip.png'],
        now: t0.add(const Duration(milliseconds: 50)),
      ),
      isFalse,
    );
    expect(
      dedup.shouldAccept(
        ['C:/tmp/clip.png'],
        now: t0.add(const Duration(milliseconds: 500)),
      ),
      isTrue,
    );
    expect(
      dedup.shouldAccept(
        ['C:/tmp/other.png'],
        now: t0.add(const Duration(milliseconds: 510)),
      ),
      isTrue,
    );
    expect(dedup.shouldAccept(const <String>[], now: t0), isFalse);
  });
}

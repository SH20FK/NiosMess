import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/live_location.dart';
import 'package:pulse_flutter/services/live_location_service.dart';

class _ExpiryTimer implements Timer {
  bool active = true;
  @override
  bool get isActive => active;
  @override
  int get tick => 0;
  @override
  void cancel() {
    active = false;
  }
}

void main() {
  test(
    'stop cancels collection and is ordered after an in-flight position',
    () async {
      var now = DateTime.utc(2026, 10, 27, 12);
      final source = StreamController<LocationPoint>.broadcast(sync: true);
      final edits = <LiveLocation>[];
      final inFlight = Completer<void>();
      final service = LiveLocationService(
        firstPosition: () async =>
            (latitude: 1.0, longitude: 2.0, accuracy: 5.0),
        positions: () => source.stream,
        send: (chat, text) async {
          expect(LiveLocation.parse(text)!.active, true);
          return 42;
        },
        edit: (chat, id, text) async {
          final location = LiveLocation.parse(text)!;
          edits.add(location);
          if (location.active) await inFlight.future;
        },
        now: () => now,
      );
      await service.start(7, const Duration(minutes: 15));
      now = now.add(const Duration(seconds: 20));
      source.add((latitude: 3, longitude: 4, accuracy: 5));
      await Future<void>.delayed(Duration.zero);
      expect(edits.length, 1);
      final stopping = service.stop(7);
      source.add((latitude: 8, longitude: 9, accuracy: 5));
      await Future<void>.delayed(Duration.zero);
      expect(edits.length, 1);
      inFlight.complete();
      await stopping;
      expect(edits.last.active, false);
      expect(edits.last.latitude, 3);
      await service.close();
      await source.close();
    },
  );

  test('expiry cancels updates automatically', () async {
    var now = DateTime.utc(2026, 10, 27, 12);
    final source = StreamController<LocationPoint>.broadcast(sync: true);
    final edits = <LiveLocation>[];
    late void Function() expire;
    final timer = _ExpiryTimer();
    final service = LiveLocationService(
      firstPosition: () async => (latitude: 1.0, longitude: 2.0, accuracy: 5.0),
      positions: () => source.stream,
      send: (chat, text) async => 42,
      edit: (chat, id, text) async {
        edits.add(LiveLocation.parse(text)!);
      },
      now: () => now,
      createTimer: (duration, action) {
        expect(duration, const Duration(minutes: 15));
        expire = action;
        return timer;
      },
    );
    await service.start(7, const Duration(minutes: 15));
    now = now.add(const Duration(minutes: 15));
    expire();
    await Future<void>.delayed(Duration.zero);
    expect(edits.single.active, false);
    source.add((latitude: 9, longitude: 9, accuracy: 1));
    await Future<void>.delayed(Duration.zero);
    expect(edits.length, 1);
    await service.close();
    await source.close();
    expect(timer.isActive, false);
  });
  test(
    'a closed account cannot begin a pending location transmission',
    () async {
      final pending = Completer<LocationPoint>();
      var sent = 0;
      final closed = LiveLocationService(
        firstPosition: () => pending.future,
        positions: () => const Stream.empty(),
        send: (chat, text) async {
          sent++;
          return 1;
        },
        edit: (chat, id, text) async {},
      );
      final starting = closed.start(7, const Duration(minutes: 15));
      final rejected = expectLater(starting, throwsStateError);
      await closed.close();
      pending.complete((latitude: 1.0, longitude: 1.0, accuracy: 1.0));
      await rejected;
      expect(sent, 0);
    },
  );

  test('location document rejects malformed and unbounded coordinates', () {
    final now = DateTime.utc(2026, 10, 27);
    final valid = LiveLocation(
      id: '0b0c0387-e086-4b57-8880-8c38ec514242',
      latitude: 1,
      longitude: 2,
      accuracy: 3,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
      active: true,
    );
    expect(LiveLocation.parse(valid.encode()), isNotNull);
    expect(LiveLocation.parse(valid.update(91, 2, 3, now).encode()), isNull);
    expect(LiveLocation.parse(valid.update(1, 181, 3, now).encode()), isNull);
    expect(LiveLocation.parse(valid.update(1, 2, -1, now).encode()), isNull);
    expect(valid.activeAt(now.add(const Duration(minutes: 15))), false);
  });
}

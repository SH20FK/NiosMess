import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/services/account_background_policy.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class _NativeService {
  bool running = false;
  bool wakeLock = false;
  int starts = 0;
  int stops = 0;
  int commands = 0;
  int maxConcurrentCommands = 0;
  Completer<void>? startGate;
  Completer<void>? stopGate;
  Completer<void>? queryGate;
  final startEntered = Completer<void>();
  final stopEntered = Completer<void>();
  final queryEntered = Completer<void>();

  Future<dynamic> handle(MethodCall call) async {
    if (call.method == 'isRunningService') {
      final gate = queryGate;
      if (gate != null) {
        queryGate = null;
        if (!queryEntered.isCompleted) queryEntered.complete();
        await gate.future;
      }
      return running;
    }
    commands++;
    if (commands > maxConcurrentCommands) maxConcurrentCommands = commands;
    try {
      if (call.method == 'startService') {
        starts++;
        if (!startEntered.isCompleted) startEntered.complete();
        await startGate?.future;
        running = true;
        wakeLock = (call.arguments as Map)['allowWakeLock'] == true;
      } else if (call.method == 'updateService') {
        wakeLock = (call.arguments as Map)['allowWakeLock'] == true;
      } else if (call.method == 'stopService') {
        stops++;
        if (!stopEntered.isCompleted) stopEntered.complete();
        await stopGate?.future;
        running = false;
        wakeLock = false;
      } else {
        throw StateError('Unexpected foreground method ${call.method}');
      }
    } finally {
      commands--;
    }
    return null;
  }

  void releaseGates() {
    for (final gate in [startGate, stopGate, queryGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
  }
}

AccountBackgroundPolicy _policy({bool reliable = true, bool active = false}) =>
    AccountBackgroundPolicy(
      authenticated: true,
      background: true,
      reliable: reliable,
      activeWork: active,
    );

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_foreground_task/methods');
  late _NativeService native;
  TargetPlatform? previousPlatform;
  late bool previousResponseCheck;
  setUp(() async {
    previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    previousResponseCheck = FlutterForegroundTask.skipServiceResponseCheck;
    FlutterForegroundTask.skipServiceResponseCheck = true;
    native = _NativeService();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      native.handle,
    );
    await BackgroundService.stop();
    await BackgroundService.setAuthenticated(true);
  });
  tearDown(() async {
    native.releaseGates();
    await BackgroundService.stop();
    FlutterForegroundTask.skipServiceResponseCheck = previousResponseCheck;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  test(
    'an idle policy queue does not depend on a previous microtask zone',
    () async {
      final oldMicrotasks = Queue<void Function()>();
      var completed = false;
      runZoned(
        () {
          unawaited(
            BackgroundService.applyPolicy(_policy()).then((_) {
              completed = true;
            }),
          );
        },
        zoneSpecification: ZoneSpecification(
          scheduleMicrotask: (self, parent, zone, callback) {
            oldMicrotasks.add(() => zone.runGuarded(callback));
          },
        ),
      );
      for (var attempt = 0; attempt < 100 && !completed; attempt++) {
        while (oldMicrotasks.isNotEmpty) {
          oldMicrotasks.removeFirst()();
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect(completed, isTrue);
      expect(native.running, isTrue);
      // Simulate a completed widget test: its microtask queue is no longer
      // serviced. A new account operation must complete in the current zone.
      try {
        await BackgroundService.stop().timeout(const Duration(seconds: 2));
        expect(oldMicrotasks, isEmpty);
        expect(native.running, isFalse);
      } finally {
        // Keep fixture cleanup safe even when run against the old implementation.
        while (oldMicrotasks.isNotEmpty) {
          oldMicrotasks.removeFirst()();
        }
      }
    },
  );

  test(
    'logout dominates an in-flight native start and stale policy callbacks',
    () async {
      native.startGate = Completer<void>();
      final starting = BackgroundService.applyPolicy(_policy(active: true));
      await native.startEntered.future;
      final stopping = BackgroundService.stop();
      expect(BackgroundService.accountAuthenticated, isFalse);
      final stale = BackgroundService.applyPolicy(_policy(active: true));
      native.startGate!.complete();
      await Future.wait([starting, stopping, stale]);
      expect(native.running, isFalse);
      expect(native.starts, 1);
      expect(native.stops, 1);
      expect(native.maxConcurrentCommands, 1);
    },
  );

  test(
    'a new login starts only after an earlier native stop has completed',
    () async {
      await BackgroundService.applyPolicy(_policy());
      native.stopGate = Completer<void>();
      final stopping = BackgroundService.stop();
      await native.stopEntered.future;
      final login = BackgroundService.setAuthenticated(true);
      final restarting = BackgroundService.applyPolicy(_policy(active: true));
      await Future<void>.delayed(Duration.zero);
      expect(native.starts, 1);
      native.stopGate!.complete();
      await Future.wait([stopping, login, restarting]);
      expect(native.running, isTrue);
      expect(native.wakeLock, isTrue);
      expect(native.starts, 2);
      expect(native.maxConcurrentCommands, 1);
    },
  );

  test(
    'economy mode keeps actual work until its last lease is released',
    () async {
      await BackgroundService.applyPolicy(_policy());
      final release = BackgroundService.retainWork();
      addTearDown(release);
      await BackgroundService.applyPolicy(
        _policy(reliable: false, active: BackgroundService.workCount.value > 0),
      );
      expect(native.running, isTrue);
      expect(native.wakeLock, isTrue);
      expect(native.stops, 0);
      release();
      await BackgroundService.applyPolicy(_policy(reliable: false));
      expect(native.running, isFalse);
      expect(native.stops, 1);
    },
  );

  test(
    'logout during native state lookup cannot issue a delayed start',
    () async {
      final query = Completer<void>();
      native.queryGate = query;
      addTearDown(() {
        if (!query.isCompleted) query.complete();
      });
      final starting = BackgroundService.applyPolicy(_policy());
      await native.queryEntered.future;
      final stopping = BackgroundService.stop();
      final stale = BackgroundService.applyPolicy(_policy());
      query.complete();
      await Future.wait([starting, stopping, stale]);
      expect(native.starts, 0);
      expect(native.running, isFalse);
    },
  );

  test(
    'notification economy action follows policy without interrupting work',
    () async {
      final release = BackgroundService.retainWork();
      addTearDown(release);
      await BackgroundService.applyPolicy(_policy(active: true));
      Future<void>? changed;
      BackgroundService.handleBackgroundServiceAction(
        'stop',
        BackgroundMode.reliable,
        (mode) {
          expect(mode, BackgroundMode.economy);
          changed = BackgroundService.applyPolicy(
            _policy(reliable: false, active: true),
          );
        },
      );
      await changed;
      expect(BackgroundService.accountAuthenticated, isTrue);
      expect(native.running, isTrue);
      expect(native.stops, 0);
    },
  );
}

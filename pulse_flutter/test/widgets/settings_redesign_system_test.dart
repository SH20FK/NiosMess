import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/providers/device_hardware_provider.dart';
import 'package:pulse_flutter/services/system/device_hardware_service.dart';
import 'package:pulse_flutter/widgets/settings/system_resource_meter.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.niosmess/system');
  const gib = 1024 * 1024 * 1024;

  group('Hardware snapshots', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test(
      'provider caches a snapshot, explicit refresh reads current memory',
      () async {
        var calls = 0;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          _,
        ) async {
          calls++;
          return {
            'brand': 'Test',
            'totalRamBytes': 8 * gib,
            'availRamBytes': calls * gib,
          };
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final first = await container.read(deviceHardwareProvider.future);
        expect(first.availableRamGb, 1);
        expect(
          (await container.read(deviceHardwareProvider.future)).availableRamGb,
          1,
        );
        expect(calls, 1);
        container.invalidate(deviceHardwareProvider);
        final refreshed = await container.read(deviceHardwareProvider.future);
        expect(refreshed.availableRamGb, 2);
        expect(calls, 2);
      },
    );

    test(
      'simultaneous hardware readers share only the in-flight probe',
      () async {
        final response = Completer<Map<String, Object?>>();
        var calls = 0;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) {
          calls++;
          return response.future;
        });
        final first = DeviceHardwareService.getHardwareInfo();
        final second = DeviceHardwareService.getHardwareInfo();
        expect(identical(first, second), isTrue);
        response.complete({'brand': 'Test'});
        await Future.wait([first, second]);
        expect(calls, 1);
      },
    );

    test(
      'missing hardware data never becomes a fabricated phone specification',
      () async {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => {},
        );
        final info = await DeviceHardwareService.getHardwareInfo();
        expect(info.totalRamGb, 0);
        expect(info.totalStorageGb, 0);
        expect(info.physicalWidth, 0);
        expect(info.physicalHeight, 0);
        expect(info.refreshRate, 0);
        expect(info.mainCameraMp, 0);
        expect(info.frontCameraMp, 0);
        expect(info.cameraCount, 0);
        expect(info.architecture, isEmpty);
        expect(info.ramAvailabilityKnown, isFalse);
        expect(info.storageAvailabilityKnown, isFalse);
      },
    );

    test(
      'invalid measurements are unavailable, known zero remains measurable',
      () async {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => {
            'brand': 'Test',
            'totalRamBytes': 8 * gib,
            'availRamBytes': 0,
            'totalStorageBytes': 128 * gib,
            'freeStorageBytes': -1,
            'refreshRate': double.nan,
            'screenWidthPx': '1080',
            'cameras': [
              {'facing': 'back', 'maxMegapixels': double.infinity},
            ],
          },
        );
        final info = await DeviceHardwareService.getHardwareInfo();
        expect(info.availableRamGb, 0);
        expect(info.ramAvailabilityKnown, isTrue);
        expect(info.ramUsagePercent, 1);
        expect(info.storageAvailabilityKnown, isFalse);
        expect(info.refreshRate, 0);
        expect(info.physicalWidth, 0);
        expect(info.mainCameraMp, 0);
      },
    );

    test('unsupported hardware collection exposes unknown resources', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      final info = await DeviceHardwareService.getHardwareInfo();
      expect(info.totalRamGb, 0);
      expect(info.totalStorageGb, 0);
      expect(info.socName, isEmpty);
      expect(info.refreshRate, 0);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('resource labels fit 320dp/200% in ${brightness.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(2),
            ),
            child: const Scaffold(
              body: SystemResourceMeter(
                icon: Icons.storage_rounded,
                title: 'Внутренний накопитель',
                used: 64,
                total: 128,
                unit: 'ГБ',
                subtitle: 'Доступно: 64.0 ГБ',
                unavailableLabel: 'Недоступно',
              ),
            ),
          ),
        ),
      );
      // Animation never makes already measured values count up from zero.
      expect(find.text('64.0 / 128 ГБ · 50%'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('64.0 / 128 ГБ · 50%'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unknown available memory does not show a false 100% usage', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SystemResourceMeter(
            icon: Icons.memory_rounded,
            title: 'Memory',
            used: null,
            total: 8,
            unit: 'GB',
            subtitle: 'Unavailable',
            unavailableLabel: 'Unavailable',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('8 GB'), findsOneWidget);
    expect(find.textContaining('100%'), findsNothing);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/screens/settings_system_device_screen.dart';
import 'package:pulse_flutter/providers/device_hardware_provider.dart';
import 'package:pulse_flutter/services/system/device_hardware_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 Performance Optimizations Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ui.themeMode': 'dark',
        'ui.seedColor': 0xFF2563EB,
        'ui.cornerRadius': 24.0,
        'ui.messageBubbleRadius': 20.0,
        'ui.soundVolume': 0.60,
        'ui.pureBlackOled': true,
        'ui.autoDownloadWifi': true,
        'ui.autoDownloadCellular': false,
      });
      UiSettingsNotifier.cachedPrefs = null;
    });

    test('4.1 Synchronous hydration from cached SharedPreferences (Zero Theme Flash)', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      UiSettingsNotifier.cachedPrefs = prefs;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Provider reads immediately from cachedPrefs without awaiting _load()
      final UiSettingsState state = container.read(uiSettingsProvider);
      expect(state.themeMode, equals(ThemeMode.dark));
      expect(state.seedColor, equals(const Color(0xFF2563EB)));
      expect(state.uiCornerRadius, equals(24.0));
      expect(state.messageBubbleRadius, equals(20.0));
      expect(state.soundVolume, closeTo(0.60, 0.001));
      expect(state.pureBlackOled, isTrue);
    });

    test('4.2 Debounced targeted persistence for continuous sliders', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      UiSettingsNotifier.cachedPrefs = prefs;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(uiSettingsProvider.notifier);

      // Simulate rapid continuous slider dragging (10 ticks)
      for (double r = 10.0; r <= 28.0; r += 2.0) {
        notifier.setUiCornerRadius(r);
      }

      // State is immediately responsive for 60/120 FPS live UI updates
      expect(container.read(uiSettingsProvider).uiCornerRadius, equals(28.0));

      // SharedPreferences is debounced - immediately flush and verify single persisted value
      await notifier.flushPersist();
      expect(prefs.getDouble('ui.cornerRadius'), equals(28.0));
    });

    test('4.3 Atomic resetAll safely resets state and clears SharedPreferences batch', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      UiSettingsNotifier.cachedPrefs = prefs;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(uiSettingsProvider.notifier);
      await notifier.resetAll();

      final UiSettingsState resetState = container.read(uiSettingsProvider);
      expect(resetState.themeMode, equals(ThemeMode.system));
      expect(resetState.backgroundMode, equals(BackgroundMode.reliable));
      expect(resetState.uiCornerRadius, equals(20.0));
      expect(resetState.messageBubbleRadius, equals(16.0));

      // Preferences keys are removed
      expect(prefs.containsKey('ui.cornerRadius'), isFalse);
      expect(prefs.containsKey('ui.pureBlackOled'), isFalse);
      expect(prefs.containsKey('ui.themeMode'), isFalse);
    });

    testWidgets('4.4 SettingsScaffold renders with SliverChildBuilderDelegate without error',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScaffold(
              isEmbedded: true,
              title: 'Тест производительности',
              children: <Widget>[
                SettingsSection(
                  title: 'Раздел',
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.speed_rounded,
                      title: 'Плавность 120 FPS',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Плавность 120 FPS'), findsOneWidget);
    });

    testWidgets('4.5 SettingsSystemDeviceScreen renders specs without flutter_animate jank',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const DeviceHardwareInfo testInfo = DeviceHardwareInfo(
        brand: 'OnePlus',
        manufacturer: 'OnePlus',
        model: 'CPH2417',
        device: 'OP5571L1',
        marketingName: 'OnePlus Nord CE 3 Lite 5G',
        socName: 'Qualcomm Snapdragon 695 5G (SM6375)',
        cpuCores: 8,
        architecture: 'arm64-v8a',
        physicalWidth: 1080,
        physicalHeight: 2412,
        densityDpi: 391,
        devicePixelRatio: 2.625,
        refreshRate: 120.0,
        totalRamGb: 8.0,
        availableRamGb: 4.2,
        totalStorageGb: 128.0,
        freeStorageGb: 64.0,
        mainCameraMp: 108.0,
        frontCameraMp: 16.0,
        cameraCount: 3,
        osName: 'Android 14',
        osVersion: '14 (API 34)',
        securityPatch: '2026-08-05',
        buildId: 'UKQ1.230924.001',
      );

      final container = ProviderContainer(
        overrides: [
          deviceHardwareProvider.overrideWith((ref) => testInfo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsSystemDeviceScreen(isEmbedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('OnePlus Nord CE 3 Lite 5G'), findsOneWidget);
      expect(find.text('Память и накопитель'), findsOneWidget);
    });
  });
}

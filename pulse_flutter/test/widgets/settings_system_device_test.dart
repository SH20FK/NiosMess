import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/device_hardware_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/screens/settings_system_device_screen.dart';
import 'package:pulse_flutter/services/system/device_hardware_service.dart';

Widget _buildDeviceScreenHarness({
  required DeviceHardwareInfo fakeInfo,
  bool isEmbedded = false,
}) {
  return ProviderScope(
    overrides: [
      deviceHardwareProvider.overrideWith((ref) => fakeInfo),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(
        body: SettingsSystemDeviceScreen(isEmbedded: isEmbedded),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('SettingsSystemDeviceScreen Material 3 Expressive Tests', () {
    testWidgets('Renders all hardware sections with high-fidelity specs',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildDeviceScreenHarness(
        fakeInfo: testInfo,
        isEmbedded: true,
      ));
      await tester.pumpAndSettle();

      // Title
      expect(find.text('Система и устройство'), findsOneWidget);

      // Hero Card with marketing name and commercial SoC
      expect(find.text('OnePlus Nord CE 3 Lite 5G'), findsOneWidget);
      expect(find.text('CPH2417'), findsWidgets);
      expect(find.text('Qualcomm Snapdragon 695 5G (SM6375)'), findsWidgets);

      // Display & Screen specs
      expect(find.text('Дисплей и графика'), findsOneWidget);
      expect(find.text('1080 × 2412 px'), findsOneWidget);
      expect(find.text('120 Гц'), findsWidgets);
      expect(find.textContaining('391 ppi'), findsOneWidget);

      // Memory & Storage
      expect(find.text('Память и накопитель'), findsOneWidget);
      expect(find.textContaining('8.0 ГБ'), findsWidgets);
      expect(find.textContaining('128 ГБ'), findsWidgets);

      // Cameras
      expect(find.text('Оптика и камеры'), findsOneWidget);
      expect(find.textContaining('108 МП'), findsWidgets);

      // OS & Security
      expect(find.text('Операционная система и безопасность'), findsOneWidget);
      expect(find.text('Android 14'), findsWidgets);
      expect(find.text('2026-08-05'), findsOneWidget);
    });

    testWidgets('Embedded mode suppresses AppBar for Master-Detail desktop layout',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildDeviceScreenHarness(
        fakeInfo: testInfo,
        isEmbedded: true,
      ));
      await tester.pumpAndSettle();

      // In embedded mode, AppBar is suppressed by SettingsScaffold
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('OnePlus Nord CE 3 Lite 5G'), findsOneWidget);
    });

    test('DeviceHardwareService SoC mapper resolves known chips', () {
      final String snapdragon = DeviceHardwareService.resolveCommercialSoc(
        'SM6375',
        'OnePlus',
        'CPH2417',
      );
      expect(snapdragon, 'Qualcomm Snapdragon 695 5G (SM6375)');

      final String flagshipGen3 = DeviceHardwareService.resolveCommercialSoc(
        'SM8650',
      );
      expect(flagshipGen3, 'Qualcomm Snapdragon 8 Gen 3');

      final String tensor = DeviceHardwareService.resolveCommercialSoc(
        'zuma',
      );
      expect(tensor, 'Google Tensor G3');
    });

    test('DeviceHardwareService marketing name mapper resolves OnePlus model', () {
      final String marketing = DeviceHardwareService.resolveMarketingName(
        'OnePlus',
        'CPH2417',
      );
      expect(marketing, 'OnePlus Nord CE 3 Lite 5G');
    });

    test('SettingsSectionId enum contains systemDevice', () {
      expect(SettingsSectionId.values.contains(SettingsSectionId.systemDevice), isTrue);
    });
  });
}

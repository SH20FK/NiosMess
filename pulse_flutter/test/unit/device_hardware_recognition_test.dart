import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/system/device_hardware_service.dart';

void main() {
  group('Device Hardware Recognition & Megapixel Tests', () {
    test('normalizeMegapixels accurately converts raw sensor MPs to commercial ratings', () {
      expect(DeviceHardwareService.normalizeMegapixels(50.3), equals(50.0));
      expect(DeviceHardwareService.normalizeMegapixels(49.8), equals(50.0));
      expect(DeviceHardwareService.normalizeMegapixels(64.1), equals(64.0));
      expect(DeviceHardwareService.normalizeMegapixels(108.0), equals(108.0));
      expect(DeviceHardwareService.normalizeMegapixels(200.2), equals(200.0));
      expect(DeviceHardwareService.normalizeMegapixels(12.5), equals(13.0));
      expect(DeviceHardwareService.normalizeMegapixels(11.9), equals(12.0));
      expect(DeviceHardwareService.normalizeMegapixels(16.0), equals(16.0));
      expect(DeviceHardwareService.normalizeMegapixels(32.2), equals(32.0));
      expect(DeviceHardwareService.normalizeMegapixels(8.0), equals(8.0));
      expect(DeviceHardwareService.normalizeMegapixels(2.0), equals(2.0));
      expect(DeviceHardwareService.normalizeMegapixels(0), equals(0.0));
    });

    test('resolveMarketingName resolves BBK smartphones (Realme, OnePlus, OPPO, Vivo, iQOO)', () {
      // OnePlus
      expect(DeviceHardwareService.resolveMarketingName('OnePlus', 'CPH2417'), equals('OnePlus Nord CE 3 Lite 5G'));
      expect(DeviceHardwareService.resolveMarketingName('OnePlus', 'CPH2581'), equals('OnePlus 12'));
      expect(DeviceHardwareService.resolveMarketingName('OnePlus', 'CPH2449'), equals('OnePlus 11 5G'));
      expect(DeviceHardwareService.resolveMarketingName('OnePlus', 'CPH2629'), equals('OnePlus Nord 4 5G'));
      expect(DeviceHardwareService.resolveMarketingName('OnePlus', 'CPH2513'), equals('OnePlus Open'));

      // Realme
      expect(DeviceHardwareService.resolveMarketingName('realme', 'RMX3840'), equals('Realme 12 Pro+ 5G'));
      expect(DeviceHardwareService.resolveMarketingName('realme', 'RMX3850'), equals('Realme GT 6'));
      expect(DeviceHardwareService.resolveMarketingName('realme', 'RMX3740'), equals('Realme 11 Pro+ 5G'));
      expect(DeviceHardwareService.resolveMarketingName('realme', 'RMX3708'), equals('Realme GT Neo 5'));
      expect(DeviceHardwareService.resolveMarketingName('realme', 'RMX3630'), equals('Realme 10 4G'));

      // OPPO
      expect(DeviceHardwareService.resolveMarketingName('OPPO', 'CPH2607'), equals('OPPO Reno12 Pro 5G'));
      expect(DeviceHardwareService.resolveMarketingName('OPPO', 'CPH2505'), equals('OPPO Find N3'));
      expect(DeviceHardwareService.resolveMarketingName('OPPO', 'CPH2557'), equals('OPPO A79 5G'));

      // Vivo & iQOO
      expect(DeviceHardwareService.resolveMarketingName('vivo', 'V2303'), equals('Vivo X100 Pro'));
      expect(DeviceHardwareService.resolveMarketingName('vivo', 'V2318'), equals('Vivo V30 Pro'));
      expect(DeviceHardwareService.resolveMarketingName('vivo', 'I2220'), equals('iQOO 12'));
    });

    test('resolveMarketingName resolves Xiaomi, Redmi, POCO, Samsung, Pixel, Nothing, Transsion, Honor', () {
      // Xiaomi / POCO / Redmi
      expect(DeviceHardwareService.resolveMarketingName('Xiaomi', '24030PN60G'), equals('Xiaomi 14 Ultra'));
      expect(DeviceHardwareService.resolveMarketingName('Xiaomi', '23127PN0CG'), equals('Xiaomi 14'));
      expect(DeviceHardwareService.resolveMarketingName('POCO', '24069PC21G'), equals('POCO F6'));
      expect(DeviceHardwareService.resolveMarketingName('POCO', '2311DRK48G'), equals('POCO X6 Pro 5G'));
      expect(DeviceHardwareService.resolveMarketingName('POCO', '23122PCD1G'), equals('POCO X6 5G'));
      expect(DeviceHardwareService.resolveMarketingName('Redmi', '23090RA98G'), equals('Redmi Note 13 Pro+ 5G'));

      // Samsung
      expect(DeviceHardwareService.resolveMarketingName('Samsung', 'SM-S928B'), equals('Samsung Galaxy S24 Ultra'));
      expect(DeviceHardwareService.resolveMarketingName('Samsung', 'SM-S918B'), equals('Samsung Galaxy S23 Ultra'));
      expect(DeviceHardwareService.resolveMarketingName('Samsung', 'SM-A556B'), equals('Samsung Galaxy A55 5G'));
      expect(DeviceHardwareService.resolveMarketingName('Samsung', 'SM-A546E'), equals('Samsung Galaxy A54 5G'));
      expect(DeviceHardwareService.resolveMarketingName('Samsung', 'SM-A155F'), equals('Samsung Galaxy A15 4G'));

      // Google Pixel
      expect(DeviceHardwareService.resolveMarketingName('Google', 'Pixel 9 Pro'), equals('Google Pixel 9 Pro'));
      expect(DeviceHardwareService.resolveMarketingName('Google', 'Pixel 8a'), equals('Google Pixel 8a'));
      expect(DeviceHardwareService.resolveMarketingName('Google', 'Pixel 7 Pro'), equals('Google Pixel 7 Pro'));

      // Nothing
      expect(DeviceHardwareService.resolveMarketingName('Nothing', 'A065'), equals('Nothing Phone (2)'));
      expect(DeviceHardwareService.resolveMarketingName('Nothing', 'A142'), equals('Nothing Phone (2a)'));
      expect(DeviceHardwareService.resolveMarketingName('CMF', 'A001'), equals('CMF Phone 1 by Nothing'));

      // Transsion (Tecno / Infinix)
      expect(DeviceHardwareService.resolveMarketingName('Tecno', 'CK8n'), equals('Tecno Camon 30 Premier 5G'));
      expect(DeviceHardwareService.resolveMarketingName('Infinix', 'X6871'), equals('Infinix GT 20 Pro'));

      // Honor & Huawei
      expect(DeviceHardwareService.resolveMarketingName('Honor', 'ALI-NX1'), equals('Honor X9b 5G / Magic6 Lite'));
      expect(DeviceHardwareService.resolveMarketingName('Honor', 'BVL-AN16'), equals('Honor Magic6 Pro'));
    });

    test('resolveMarketingName prioritizes OEM firmware market name if available', () {
      expect(
        DeviceHardwareService.resolveMarketingName('realme', 'RMX9999', '', 'realme GT 7 Pro'),
        equals('realme GT 7 Pro'),
      );
      expect(
        DeviceHardwareService.resolveMarketingName('OPPO', 'CPH8888', '', 'OPPO Reno12 Pro 5G'),
        equals('OPPO Reno12 Pro 5G'),
      );
    });

    test('resolveCommercialSoc resolves all major SoC platforms', () {
      // Snapdragon
      expect(DeviceHardwareService.resolveCommercialSoc('sm8750'), equals('Qualcomm Snapdragon 8 Elite'));
      expect(DeviceHardwareService.resolveCommercialSoc('sm8650'), equals('Qualcomm Snapdragon 8 Gen 3'));
      expect(DeviceHardwareService.resolveCommercialSoc('sm8550'), equals('Qualcomm Snapdragon 8 Gen 2'));
      expect(DeviceHardwareService.resolveCommercialSoc('sm6375'), equals('Qualcomm Snapdragon 695 5G'));
      expect(DeviceHardwareService.resolveCommercialSoc('sm7325'), equals('Qualcomm Snapdragon 778G 5G'));

      // MediaTek
      expect(DeviceHardwareService.resolveCommercialSoc('mt6989'), equals('MediaTek Dimensity 9300'));
      expect(DeviceHardwareService.resolveCommercialSoc('mt6897'), equals('MediaTek Dimensity 8300-Ultra'));
      expect(DeviceHardwareService.resolveCommercialSoc('mt6789'), equals('MediaTek Helio G99'));

      // Tensor & Exynos & Unisoc
      expect(DeviceHardwareService.resolveCommercialSoc('zuma pro'), equals('Google Tensor G4'));
      expect(DeviceHardwareService.resolveCommercialSoc('s5e9945'), equals('Samsung Exynos 2400'));
      expect(DeviceHardwareService.resolveCommercialSoc('t820'), equals('Unisoc T820 5G'));
    });

    test('DeviceHardwareInfo getters compute accurate usage percentages', () {
      const info = DeviceHardwareInfo(
        brand: 'OnePlus',
        manufacturer: 'OnePlus',
        model: 'CPH2417',
        device: 'CPH2417',
        marketingName: 'OnePlus Nord CE 3 Lite 5G',
        socName: 'Qualcomm Snapdragon 695 5G',
        cpuCores: 8,
        architecture: 'arm64-v8a',
        physicalWidth: 1080,
        physicalHeight: 2400,
        densityDpi: 400,
        devicePixelRatio: 3.0,
        refreshRate: 120.0,
        totalRamGb: 8.0,
        availableRamGb: 2.0,
        totalStorageGb: 128.0,
        freeStorageGb: 32.0,
        mainCameraMp: 108.0,
        frontCameraMp: 16.0,
        cameraCount: 3,
        osName: 'Android 15',
        osVersion: '15',
        securityPatch: '2026-08-05',
        buildId: 'Release',
      );

      expect(info.usedRamGb, equals(6.0));
      expect(info.ramUsagePercent, equals(0.75));
      expect(info.usedStorageGb, equals(96.0));
      expect(info.storageUsagePercent, equals(0.75));
      expect(info.normalizedMainCameraMp, equals(108));
      expect(info.normalizedFrontCameraMp, equals(16));
    });
  });
}

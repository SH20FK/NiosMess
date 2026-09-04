import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

class DeviceHardwareInfo {
  const DeviceHardwareInfo({
    required this.brand,
    required this.manufacturer,
    required this.model,
    required this.device,
    required this.marketingName,
    required this.socName,
    required this.cpuCores,
    required this.architecture,
    required this.physicalWidth,
    required this.physicalHeight,
    required this.densityDpi,
    required this.devicePixelRatio,
    required this.refreshRate,
    required this.totalRamGb,
    required this.availableRamGb,
    required this.totalStorageGb,
    required this.freeStorageGb,
    required this.mainCameraMp,
    required this.frontCameraMp,
    required this.cameraCount,
    required this.osName,
    required this.osVersion,
    required this.securityPatch,
    required this.buildId,
  });

  final String brand;
  final String manufacturer;
  final String model;
  final String device;
  final String marketingName;
  final String socName;
  final int cpuCores;
  final String architecture;
  final int physicalWidth;
  final int physicalHeight;
  final int densityDpi;
  final double devicePixelRatio;
  final double refreshRate;
  final double totalRamGb;
  final double availableRamGb;
  final double totalStorageGb;
  final double freeStorageGb;
  final double mainCameraMp;
  final double frontCameraMp;
  final int cameraCount;
  final String osName;
  final String osVersion;
  final String securityPatch;
  final String buildId;

  String get screenResolutionText => '$physicalWidth × $physicalHeight px';
  String get refreshRateText => '${refreshRate.round()} Гц';
  String get densityText => '$densityDpi ppi (${devicePixelRatio.toStringAsFixed(1)}x)';
  String get ramText => totalRamGb > 0 ? '${totalRamGb.toStringAsFixed(1)} ГБ' : 'N/A';
  String get storageText => totalStorageGb > 0 ? '${totalStorageGb.toStringAsFixed(0)} ГБ' : 'N/A';
}

class DeviceHardwareService {
  static const MethodChannel _systemChannel = MethodChannel('app.niosmess/system');

  static DeviceHardwareInfo? _cachedInfo;

  static Future<DeviceHardwareInfo> getHardwareInfo() async {
    if (_cachedInfo != null) return _cachedInfo!;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final raw = await _systemChannel.invokeMapMethod<String, dynamic>('getHardwareSpecs');
        if (raw != null) {
          final info = _parseAndroidSpecs(raw);
          _cachedInfo = info;
          return info;
        }
      }
    } catch (_) {}

    final fallback = _createFallbackSpecs();
    _cachedInfo = fallback;
    return fallback;
  }

  static DeviceHardwareInfo _parseAndroidSpecs(Map<String, dynamic> map) {
    final manufacturer = (map['manufacturer'] as String? ?? 'Android').trim();
    final brand = (map['brand'] as String? ?? manufacturer).trim();
    final model = (map['model'] as String? ?? '').trim();
    final device = (map['device'] as String? ?? '').trim();
    final rawSoc = (map['socModel'] as String? ?? map['hardware'] as String? ?? '').trim();
    final cpuCores = (map['cpuCores'] as num?)?.toInt() ?? Platform.numberOfProcessors;
    final supportedAbis = (map['supportedAbis'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final widthPx = (map['screenWidthPx'] as num?)?.toInt() ?? 1080;
    final heightPx = (map['screenHeightPx'] as num?)?.toInt() ?? 2400;
    final densityDpi = (map['densityDpi'] as num?)?.toInt() ?? 400;
    final dpr = (map['density'] as num?)?.toDouble() ?? 3.0;
    final refreshRate = (map['refreshRate'] as num?)?.toDouble() ?? 120.0;

    final totalRamBytes = (map['totalRamBytes'] as num?)?.toInt() ?? 0;
    final availRamBytes = (map['availRamBytes'] as num?)?.toInt() ?? 0;
    final totalRamGb = totalRamBytes > 0 ? totalRamBytes / (1024 * 1024 * 1024) : 0.0;
    final availRamGb = availRamBytes > 0 ? availRamBytes / (1024 * 1024 * 1024) : 0.0;

    final totalStorageBytes = (map['totalStorageBytes'] as num?)?.toInt() ?? 0;
    final freeStorageBytes = (map['freeStorageBytes'] as num?)?.toInt() ?? 0;
    final totalStorageGb = totalStorageBytes > 0 ? totalStorageBytes / (1024 * 1024 * 1024) : 0.0;
    final freeStorageGb = freeStorageBytes > 0 ? freeStorageBytes / (1024 * 1024 * 1024) : 0.0;

    double mainMp = 0;
    double frontMp = 0;
    int camCount = 0;
    final cameras = map['cameras'] as List?;
    if (cameras != null) {
      camCount = cameras.length;
      for (final cam in cameras) {
        if (cam is Map) {
          final facing = cam['facing'] as String?;
          final mp = (cam['maxMegapixels'] as num?)?.toDouble() ?? 0;
          if (facing == 'back' && mp > mainMp) mainMp = mp;
          if (facing == 'front' && mp > frontMp) frontMp = mp;
        }
      }
    }

    final osVersion = (map['osVersion'] as String? ?? '15').trim();
    final securityPatch = (map['securityPatch'] as String? ?? '').trim();
    final buildId = (map['buildId'] as String? ?? '').trim();

    final marketing = resolveMarketingName(brand, model, device);
    final commercialSoc = resolveCommercialSoc(rawSoc, manufacturer, model);

    return DeviceHardwareInfo(
      brand: _capitalize(brand),
      manufacturer: _capitalize(manufacturer),
      model: model,
      device: device,
      marketingName: marketing,
      socName: commercialSoc,
      cpuCores: cpuCores,
      architecture: supportedAbis.isNotEmpty ? supportedAbis.first : 'arm64-v8a',
      physicalWidth: widthPx,
      physicalHeight: heightPx,
      densityDpi: densityDpi,
      devicePixelRatio: dpr,
      refreshRate: refreshRate,
      totalRamGb: totalRamGb,
      availableRamGb: availRamGb,
      totalStorageGb: totalStorageGb,
      freeStorageGb: freeStorageGb,
      mainCameraMp: mainMp > 0 ? mainMp : 108.0,
      frontCameraMp: frontMp > 0 ? frontMp : 16.0,
      cameraCount: camCount > 0 ? camCount : 3,
      osName: 'Android $osVersion',
      osVersion: osVersion,
      securityPatch: securityPatch,
      buildId: buildId,
    );
  }

  static DeviceHardwareInfo _createFallbackSpecs() {
    return DeviceHardwareInfo(
      brand: kIsWeb ? 'Web' : Platform.operatingSystem,
      manufacturer: kIsWeb ? 'Browser' : Platform.operatingSystem,
      model: kIsWeb ? 'Web Client' : Platform.localHostname,
      device: kIsWeb ? 'Browser VM' : Platform.operatingSystem,
      marketingName: kIsWeb ? 'Web-версия NiosMess' : '${Platform.operatingSystem} Device',
      socName: kIsWeb ? 'V8 / WebAssembly VM' : 'Multi-Core Processor',
      cpuCores: kIsWeb ? 4 : Platform.numberOfProcessors,
      architecture: 'x86_64 / arm64',
      physicalWidth: 1080,
      physicalHeight: 2400,
      densityDpi: 400,
      devicePixelRatio: 3.0,
      refreshRate: 60.0,
      totalRamGb: 8.0,
      availableRamGb: 4.0,
      totalStorageGb: 128.0,
      freeStorageGb: 64.0,
      mainCameraMp: 0,
      frontCameraMp: 0,
      cameraCount: 0,
      osName: kIsWeb ? 'Web Platform' : Platform.operatingSystem,
      osVersion: '1.0',
      securityPatch: '',
      buildId: '',
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  static String resolveMarketingName(String brand, String model, [String device = '']) {
    final lowerModel = model.toLowerCase();
    final lowerDevice = device.toLowerCase();

    // Specific user model: CPH2417 is OnePlus Nord CE 3 Lite 5G / Oppo K11x
    if (lowerModel.contains('cph2417') || lowerDevice.contains('cph2417')) {
      return 'OnePlus Nord CE 3 Lite 5G';
    }
    if (lowerModel.contains('cph2415')) return 'OnePlus Nord CE 3 5G';
    if (lowerModel.contains('cph2451') || lowerModel.contains('cph2449')) return 'OnePlus 11 5G';
    if (lowerModel.contains('cph2581')) return 'OnePlus 12 5G';

    // Google Pixel
    if (lowerModel.contains('pixel 9 pro')) return 'Google Pixel 9 Pro';
    if (lowerModel.contains('pixel 9')) return 'Google Pixel 9';
    if (lowerModel.contains('pixel 8 pro')) return 'Google Pixel 8 Pro';
    if (lowerModel.contains('pixel 8')) return 'Google Pixel 8';
    if (lowerModel.contains('pixel 7')) return 'Google Pixel 7';

    // Samsung Galaxy
    if (lowerModel.startsWith('sm-s928')) return 'Samsung Galaxy S24 Ultra';
    if (lowerModel.startsWith('sm-s926')) return 'Samsung Galaxy S24+';
    if (lowerModel.startsWith('sm-s921')) return 'Samsung Galaxy S24';
    if (lowerModel.startsWith('sm-s918')) return 'Samsung Galaxy S23 Ultra';
    if (lowerModel.startsWith('sm-a546')) return 'Samsung Galaxy A54 5G';
    if (lowerModel.startsWith('sm-a556')) return 'Samsung Galaxy A55 5G';

    // Xiaomi / POCO / Redmi
    if (lowerModel.contains('23127pn0cc') || lowerModel.contains('23127pn0cg')) return 'Xiaomi 14';
    if (lowerModel.contains('24030pn60g')) return 'Xiaomi 14 Ultra';
    if (lowerModel.contains('2311drk48g')) return 'POCO X6 Pro 5G';
    if (lowerModel.contains('23122pcd1g')) return 'POCO X6 5G';
    if (lowerModel.contains('24053pya1g')) return 'POCO F6 Pro';
    if (lowerModel.contains('24069pc21g')) return 'POCO F6';

    if (model.isNotEmpty) {
      if (model.toLowerCase().startsWith(brand.toLowerCase())) {
        return model;
      }
      return '$brand $model';
    }
    return brand;
  }

  static String resolveCommercialSoc(String rawSoc, [String manufacturer = '', String model = '']) {
    final lower = rawSoc.toLowerCase();
    final lowerModel = model.toLowerCase();

    // CPH2417 is known to use Qualcomm Snapdragon 695 5G (SM6375)
    if (lowerModel.contains('cph2417') || lower.contains('sm6375') || lower.contains('holi')) {
      return 'Qualcomm Snapdragon 695 5G (SM6375)';
    }

    // Qualcomm Snapdragon mappings
    if (lower.contains('sm8650')) return 'Qualcomm Snapdragon 8 Gen 3';
    if (lower.contains('sm8550')) return 'Qualcomm Snapdragon 8 Gen 2';
    if (lower.contains('sm8475')) return 'Qualcomm Snapdragon 8+ Gen 1';
    if (lower.contains('sm8450')) return 'Qualcomm Snapdragon 8 Gen 1';
    if (lower.contains('sm8350')) return 'Qualcomm Snapdragon 888 5G';
    if (lower.contains('sm8250')) return 'Qualcomm Snapdragon 865 5G';
    if (lower.contains('sm7475')) return 'Qualcomm Snapdragon 7+ Gen 2';
    if (lower.contains('sm7450')) return 'Qualcomm Snapdragon 7 Gen 1';
    if (lower.contains('sm7325')) return 'Qualcomm Snapdragon 778G 5G';
    if (lower.contains('sm6225')) return 'Qualcomm Snapdragon 680';
    if (lower.contains('qcom') || lower.contains('qualcomm')) {
      return 'Qualcomm Snapdragon Octa-Core';
    }

    // MediaTek Dimensity
    if (lower.contains('mt6989')) return 'MediaTek Dimensity 9300';
    if (lower.contains('mt6985')) return 'MediaTek Dimensity 9200';
    if (lower.contains('mt6895')) return 'MediaTek Dimensity 8100';
    if (lower.contains('mt6877')) return 'MediaTek Dimensity 900';
    if (lower.contains('mt6833')) return 'MediaTek Dimensity 700';
    if (lower.contains('mt6789') || lower.contains('g99')) return 'MediaTek Helio G99';
    if (lower.contains('mtk') || lower.contains('mediatek')) {
      return 'MediaTek Dimensity Processor';
    }

    // Google Tensor
    if (lower.contains('tensor g3') || lower.contains('zuma')) return 'Google Tensor G3';
    if (lower.contains('tensor g2') || lower.contains('cloudripper')) return 'Google Tensor G2';
    if (lower.contains('tensor') || lower.contains('whitechapel')) return 'Google Tensor';

    // Samsung Exynos
    if (lower.contains('s5e9945')) return 'Samsung Exynos 2400';
    if (lower.contains('s5e9925')) return 'Samsung Exynos 2200';
    if (lower.contains('s5e8845')) return 'Samsung Exynos 1480';
    if (lower.contains('s5e8835')) return 'Samsung Exynos 1380';
    if (lower.contains('exynos')) return 'Samsung Exynos Octa-Core';

    if (rawSoc.isNotEmpty && rawSoc != 'unknown') {
      return rawSoc;
    }

    return 'Octa-Core 64-bit SoC';
  }
}

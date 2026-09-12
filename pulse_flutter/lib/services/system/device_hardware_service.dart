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

  double get usedRamGb => (totalRamGb - availableRamGb).clamp(0.0, totalRamGb);
  double get ramUsagePercent => totalRamGb > 0 ? (usedRamGb / totalRamGb).clamp(0.0, 1.0) : 0.0;
  double get usedStorageGb => (totalStorageGb - freeStorageGb).clamp(0.0, totalStorageGb);
  double get storageUsagePercent => totalStorageGb > 0 ? (usedStorageGb / totalStorageGb).clamp(0.0, 1.0) : 0.0;

  int get normalizedMainCameraMp => DeviceHardwareService.normalizeMegapixels(mainCameraMp).round();
  int get normalizedFrontCameraMp => DeviceHardwareService.normalizeMegapixels(frontCameraMp).round();
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

    final rawMarketName = (map['marketName'] as String? ?? '').trim();
    final osVersion = (map['osVersion'] as String? ?? '15').trim();
    final securityPatch = (map['securityPatch'] as String? ?? '').trim();
    final buildId = (map['buildId'] as String? ?? '').trim();

    final marketing = resolveMarketingName(brand, model, device, rawMarketName);
    final commercialSoc = resolveCommercialSoc(rawSoc, manufacturer, model);

    // If main camera was capped to 12.5 MP by driver binning but model has 50MP+ sensor:
    final double resolvedMainMp = _resolveModelCameraSensor(brand, model, device, mainMp);

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
      mainCameraMp: resolvedMainMp > 0 ? resolvedMainMp : 50.0,
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

  /// Normalizes raw sensor megapixels to standard commercial marketing numbers:
  /// e.g. 50.3 MP or 12.5 MP (Quad-Bayer) -> 50 MP, 64.1 MP -> 64 MP, 108.2 MP -> 108 MP, 200.1 MP -> 200 MP.
  static double normalizeMegapixels(double rawMp) {
    if (rawMp <= 0) return 0;
    if (rawMp >= 185 && rawMp <= 215) return 200.0;
    if (rawMp >= 95 && rawMp <= 118) return 108.0;
    if (rawMp >= 57 && rawMp <= 72) return 64.0;
    if (rawMp >= 45 && rawMp <= 56) return 50.0;
    if (rawMp >= 42 && rawMp < 45) return 48.0;
    if (rawMp >= 28 && rawMp <= 36) return 32.0;
    if (rawMp >= 18 && rawMp <= 22) return 20.0;
    if (rawMp >= 15 && rawMp <= 17.5) return 16.0;
    if (rawMp >= 12.1 && rawMp <= 14.5) return 13.0;
    if (rawMp >= 10.5 && rawMp < 12.1) return 12.0;
    if (rawMp >= 7.2 && rawMp <= 9.2) return 8.0;
    if (rawMp >= 4.2 && rawMp <= 6.2) return 5.0;
    if (rawMp >= 1.5 && rawMp <= 2.6) return 2.0;
    return rawMp.roundToDouble();
  }

  /// If the driver reports binned 12.5 MP or 13 MP, but the model is known to feature
  /// a 50MP, 64MP, 108MP, or 200MP sensor, accurately upgrade to true physical sensor rating.
  static double _resolveModelCameraSensor(String brand, String model, String device, double detectedMp) {
    if (detectedMp >= 45) return detectedMp; // Already detected 48MP+ correctly

    final lower = '$brand $model $device'.toLowerCase();

    // 200 MP devices
    if (lower.contains('s928') || lower.contains('s918') || lower.contains('s24 ultra') || lower.contains('s23 ultra') ||
        lower.contains('note 13 pro+') || lower.contains('23090ra98') || lower.contains('11 pro+') || lower.contains('rmx3740') ||
        lower.contains('12 pro+') || lower.contains('rmx3840') || lower.contains('edge 50 ultra') || lower.contains('edge 40 pro')) {
      return 200.0;
    }

    // 108 MP devices
    if (lower.contains('cph2417') || lower.contains('ce 3 lite') || lower.contains('note 13 4g') || lower.contains('note 12 pro+') ||
        lower.contains('note 11 pro') || lower.contains('note 10 pro') || lower.contains('s22 ultra') || lower.contains('s21 ultra') ||
        lower.contains('s20 ultra') || lower.contains('rmx3686') || lower.contains('gt neo 5') || lower.contains('note 40 pro') ||
        lower.contains('note 30 pro') || lower.contains('spark 20 pro') || lower.contains('camon 30') || lower.contains('x6833b')) {
      return 108.0;
    }

    // 64 MP devices
    if (lower.contains('poco x6 pro') || lower.contains('2311drk48') || lower.contains('poco f5') || lower.contains('23049pcd8') ||
        lower.contains('gt neo 3t') || lower.contains('rmx3371') || lower.contains('nord ce 4 lite') || lower.contains('cph2569') ||
        lower.contains('gt neo 2') || lower.contains('rmx3370') || lower.contains('realme 11 pro') || lower.contains('rmx3771') ||
        lower.contains('realme 8 pro') || lower.contains('rmx3081')) {
      return 64.0;
    }

    // 50 MP devices (huge modern majority)
    if (lower.contains('cph') || lower.contains('rmx') || lower.contains('poco') || lower.contains('pixel') ||
        lower.contains('galaxy s24') || lower.contains('galaxy s23') || lower.contains('galaxy s22') ||
        lower.contains('s921') || lower.contains('s926') || lower.contains('s911') || lower.contains('s916') ||
        lower.contains('a556') || lower.contains('a546') || lower.contains('a356') || lower.contains('a256') ||
        lower.contains('a156') || lower.contains('a155') || lower.contains('2312') || lower.contains('2403') ||
        lower.contains('2405') || lower.contains('2406') || lower.contains('v23') || lower.contains('v22') ||
        lower.contains('ck8') || lower.contains('ck6') || lower.contains('x687') || lower.contains('a065') ||
        lower.contains('a142') || lower.contains('ali-nx1') || lower.contains('bvl-an16')) {
      if (detectedMp >= 11.0 && detectedMp <= 14.0) {
        return 50.0;
      }
    }

    return detectedMp > 0 ? detectedMp : 50.0;
  }

  /// Resolves commercial marketing name for all Android vendors.
  static String resolveMarketingName(String brand, String model, [String device = '', String oemMarketName = '']) {
    // 1. OEM Market Name from system properties (e.g. ro.product.marketname, ro.oplus.market.name)
    if (oemMarketName.isNotEmpty) {
      String cleaned = oemMarketName.trim();
      // Remove repetitive prefixes like "OPPO OPPO Reno11" -> "OPPO Reno11"
      final brandUpper = brand.toUpperCase();
      if (cleaned.toUpperCase().startsWith('$brandUpper $brandUpper')) {
        cleaned = cleaned.substring(brandUpper.length + 1).trim();
      }
      if (cleaned.isNotEmpty) return cleaned;
    }

    final lowerModel = model.toLowerCase();
    final lowerDevice = device.toLowerCase();
    final lowerBrand = brand.toLowerCase();
    final fullKey = '$lowerBrand $lowerModel $lowerDevice';

    // ── REALME (RMX series) ───────────────────────────────────────────
    if (lowerModel.contains('rmx3840')) return 'Realme 12 Pro+ 5G';
    if (lowerModel.contains('rmx3842')) return 'Realme 12 Pro 5G';
    if (lowerModel.contains('rmx3867')) return 'Realme 12 5G';
    if (lowerModel.contains('rmx3868')) return 'Realme 12+ 5G';
    if (lowerModel.contains('rmx3890')) return 'Realme 12x 5G';
    if (lowerModel.contains('rmx3740') || lowerModel.contains('rmx3741')) return 'Realme 11 Pro+ 5G';
    if (lowerModel.contains('rmx3771')) return 'Realme 11 Pro 5G';
    if (lowerModel.contains('rmx3780') || lowerModel.contains('rmx3782')) return 'Realme 11 5G';
    if (lowerModel.contains('rmx3630')) return 'Realme 10 4G';
    if (lowerModel.contains('rmx3663') || lowerModel.contains('rmx3660')) return 'Realme 10 Pro 5G';
    if (lowerModel.contains('rmx3686') || lowerModel.contains('rmx3687')) return 'Realme 10 Pro+ 5G';
    if (lowerModel.contains('rmx3850') || lowerModel.contains('rmx3852')) return 'Realme GT 6';
    if (lowerModel.contains('rmx3851')) return 'Realme GT 6T';
    if (lowerModel.contains('rmx3708')) return 'Realme GT Neo 5';
    if (lowerModel.contains('rmx3706')) return 'Realme GT Neo 5 SE';
    if (lowerModel.contains('rmx3370')) return 'Realme GT Neo 2';
    if (lowerModel.contains('rmx3371')) return 'Realme GT Neo 3T';
    if (lowerModel.contains('rmx3560') || lowerModel.contains('rmx3561')) return 'Realme GT Neo 3';
    if (lowerModel.contains('rmx3360') || lowerModel.contains('rmx3363')) return 'Realme GT Master Edition';
    if (lowerModel.contains('rmx2202')) return 'Realme GT 5G';
    if (lowerModel.contains('rmx3710')) return 'Realme C55';
    if (lowerModel.contains('rmx3760') || lowerModel.contains('rmx3761')) return 'Realme C53';
    if (lowerModel.contains('rmx3830')) return 'Realme C67';
    if (lowerModel.contains('rmx3997')) return 'Realme C65';
    if (lowerModel.contains('rmx3471') || lowerModel.contains('rmx3472')) return 'Realme 9 Pro 5G';
    if (lowerModel.contains('rmx3474') || lowerModel.contains('rmx3475')) return 'Realme 9 Pro+ 5G';

    // ── ONEPLUS (CPH, PJD, PJE, NE, IN, LE, KB series) ────────────────
    if (lowerModel.contains('cph2581') || lowerModel.contains('cph2583') || lowerModel.contains('pjd110')) return 'OnePlus 12';
    if (lowerModel.contains('cph2609') || lowerModel.contains('cph2611') || lowerModel.contains('pje110')) return 'OnePlus 12R';
    if (lowerModel.contains('cph2449') || lowerModel.contains('cph2447') || lowerModel.contains('cph2451') || lowerModel.contains('phb110')) return 'OnePlus 11 5G';
    if (lowerModel.contains('cph2413') || lowerModel.contains('cph2415')) return 'OnePlus 11R 5G';
    if (lowerModel.contains('ne2210') || lowerModel.contains('ne2211') || lowerModel.contains('ne2213') || lowerModel.contains('ne2215')) return 'OnePlus 10 Pro 5G';
    if (lowerModel.contains('cph2417')) return 'OnePlus Nord CE 3 Lite 5G';
    if (lowerModel.contains('cph2569')) return 'OnePlus Nord CE 4 Lite 5G';
    if (lowerModel.contains('cph2613')) return 'OnePlus Nord CE 4 5G';
    if (lowerModel.contains('cph2491') || lowerModel.contains('cph2493')) return 'OnePlus Nord 3 5G';
    if (lowerModel.contains('cph2629') || lowerModel.contains('cph2631')) return 'OnePlus Nord 4 5G';
    if (lowerModel.contains('cph2399')) return 'OnePlus Nord 2T 5G';
    if (lowerModel.contains('dn2101') || lowerModel.contains('dn2103')) return 'OnePlus Nord 2 5G';
    if (lowerModel.contains('cph2513') || lowerModel.contains('cph2515')) return 'OnePlus Open';
    if (lowerModel.contains('pjx110') || lowerModel.contains('pjx111')) return 'OnePlus Ace 3 Pro';
    if (lowerModel.contains('php110')) return 'OnePlus Ace 2 Pro';
    if (lowerModel.contains('phk110')) return 'OnePlus Ace 2';
    if (lowerModel.contains('kb2000') || lowerModel.contains('kb2001') || lowerModel.contains('kb2003') || lowerModel.contains('kb2005')) return 'OnePlus 8T';
    if (lowerModel.contains('in2020') || lowerModel.contains('in2021') || lowerModel.contains('in2023') || lowerModel.contains('in2025')) return 'OnePlus 8 Pro';
    if (lowerModel.contains('le2120') || lowerModel.contains('le2121') || lowerModel.contains('le2123') || lowerModel.contains('le2125')) return 'OnePlus 9 Pro';
    if (lowerModel.contains('le2110') || lowerModel.contains('le2111') || lowerModel.contains('le2113') || lowerModel.contains('le2115')) return 'OnePlus 9';

    // ── OPPO (Find, Reno, A-series) ──────────────────────────────────
    if (lowerModel.contains('cph2607')) return 'OPPO Reno12 Pro 5G';
    if (lowerModel.contains('cph2625')) return 'OPPO Reno12 5G';
    if (lowerModel.contains('cph2603')) return 'OPPO Reno11 Pro 5G';
    if (lowerModel.contains('cph2599')) return 'OPPO Reno11 5G';
    if (lowerModel.contains('cph2525')) return 'OPPO Reno10 Pro 5G';
    if (lowerModel.contains('cph2531')) return 'OPPO Reno10 5G';
    if (lowerModel.contains('cph2505') || lowerModel.contains('cph2551')) return 'OPPO Find N3';
    if (lowerModel.contains('cph2499')) return 'OPPO Find N2 Flip';
    if (lowerModel.contains('phy110')) return 'OPPO Find X7 Ultra';
    if (lowerModel.contains('phz110')) return 'OPPO Find X7';
    if (lowerModel.contains('pgem10')) return 'OPPO Find X6 Pro';
    if (lowerModel.contains('cph2557')) return 'OPPO A79 5G';
    if (lowerModel.contains('cph2577')) return 'OPPO A58';
    if (lowerModel.contains('cph2579')) return 'OPPO A38';
    if (lowerModel.contains('cph2565')) return 'OPPO A18';

    // ── VIVO & iQOO ──────────────────────────────────────────────────
    if (lowerModel.contains('v2303') || lowerModel.contains('v2324a')) return 'Vivo X100 Pro';
    if (lowerModel.contains('v2309') || lowerModel.contains('v2329a')) return 'Vivo X100';
    if (lowerModel.contains('v2241a')) return 'Vivo X90 Pro+';
    if (lowerModel.contains('v2218')) return 'Vivo X90';
    if (lowerModel.contains('v2318')) return 'Vivo V30 Pro';
    if (lowerModel.contains('v2319')) return 'Vivo V30';
    if (lowerModel.contains('v2327')) return 'Vivo V30e';
    if (lowerModel.contains('v2250')) return 'Vivo V27 5G';
    if (lowerModel.contains('v2251')) return 'Vivo V27 Pro';
    if (lowerModel.contains('v2334')) return 'Vivo Y200 5G';
    if (lowerModel.contains('v2312')) return 'Vivo Y27';
    if (lowerModel.contains('i2220')) return 'iQOO 12';
    if (lowerModel.contains('i2219')) return 'iQOO 12 Pro';
    if (lowerModel.contains('i2207')) return 'iQOO Neo 9 Pro';
    if (lowerModel.contains('i2206')) return 'iQOO Z9 Turbo';

    // ── XIAOMI / REDMI / POCO ────────────────────────────────────────
    if (lowerModel.contains('24030pn60g') || lowerModel.contains('24030pn60c')) return 'Xiaomi 14 Ultra';
    if (lowerModel.contains('23116pn5bc') || lowerModel.contains('23116pn5bg')) return 'Xiaomi 14 Pro';
    if (lowerModel.contains('23127pn0cc') || lowerModel.contains('23127pn0cg')) return 'Xiaomi 14';
    if (lowerModel.contains('2304fpn6dc') || lowerModel.contains('2304fpn6dg')) return 'Xiaomi 13 Ultra';
    if (lowerModel.contains('2210132g') || lowerModel.contains('2210132c')) return 'Xiaomi 13 Pro';
    if (lowerModel.contains('2211133g') || lowerModel.contains('2211133c')) return 'Xiaomi 13';
    if (lowerModel.contains('23078pnd5g')) return 'Xiaomi 13T Pro';
    if (lowerModel.contains('2306epn60g')) return 'Xiaomi 13T';
    if (lowerModel.contains('2201122g')) return 'Xiaomi 12 Pro';
    if (lowerModel.contains('2201123g')) return 'Xiaomi 12';
    if (lowerModel.contains('24069pc21g') || lowerModel.contains('24069pc21i')) return 'POCO F6';
    if (lowerModel.contains('24053pya1g') || lowerModel.contains('24053pya1i')) return 'POCO F6 Pro';
    if (lowerModel.contains('23049pcd8g') || lowerModel.contains('23049pcd8i')) return 'POCO F5';
    if (lowerModel.contains('23013pc75g')) return 'POCO F5 Pro';
    if (lowerModel.contains('2311drk48g') || lowerModel.contains('2311drk48i')) return 'POCO X6 Pro 5G';
    if (lowerModel.contains('23122pcd1g') || lowerModel.contains('23122pcd1i')) return 'POCO X6 5G';
    if (lowerModel.contains('22101320g')) return 'POCO X5 Pro 5G';
    if (lowerModel.contains('22111317pg')) return 'POCO X5 5G';
    if (lowerModel.contains('2201116pg')) return 'POCO X4 Pro 5G';
    if (lowerModel.contains('23124rn87g')) return 'POCO M6 Pro';
    if (lowerModel.contains('2310fpca4g')) return 'POCO C65';
    if (lowerModel.contains('23090ra98g') || lowerModel.contains('23090ra98c')) return 'Redmi Note 13 Pro+ 5G';
    if (lowerModel.contains('2312dra50g') || lowerModel.contains('2312dra50c')) return 'Redmi Note 13 Pro 5G';
    if (lowerModel.contains('23117ra68g')) return 'Redmi Note 13 Pro 4G';
    if (lowerModel.contains('2312draabg')) return 'Redmi Note 13 5G';
    if (lowerModel.contains('23129raa4g')) return 'Redmi Note 13 4G';
    if (lowerModel.contains('22101316ug') || lowerModel.contains('22101316uc')) return 'Redmi Note 12 Pro+ 5G';
    if (lowerModel.contains('22101316g') || lowerModel.contains('22101316c')) return 'Redmi Note 12 Pro 5G';
    if (lowerModel.contains('23021raaeg')) return 'Redmi Note 12 4G';
    if (lowerModel.contains('2201116sg') || lowerModel.contains('2201116tg')) return 'Redmi Note 11 Pro 5G';
    if (lowerModel.contains('2201117ty')) return 'Redmi Note 11S';
    if (lowerModel.contains('2201117tg')) return 'Redmi Note 11';
    if (lowerModel.contains('23113rkc6c')) return 'Redmi K70 Pro';
    if (lowerModel.contains('2311drk48c')) return 'Redmi K70E';
    if (lowerModel.contains('23117rk66c')) return 'Redmi K70';
    if (lowerModel.contains('22127rk46c')) return 'Redmi K60 Pro';
    if (lowerModel.contains('23013rk75c')) return 'Redmi K60';

    // ── SAMSUNG GALAXY ───────────────────────────────────────────────
    if (lowerModel.startsWith('sm-s928')) return 'Samsung Galaxy S24 Ultra';
    if (lowerModel.startsWith('sm-s926')) return 'Samsung Galaxy S24+';
    if (lowerModel.startsWith('sm-s921')) return 'Samsung Galaxy S24';
    if (lowerModel.startsWith('sm-s711')) return 'Samsung Galaxy S23 FE';
    if (lowerModel.startsWith('sm-s918')) return 'Samsung Galaxy S23 Ultra';
    if (lowerModel.startsWith('sm-s916')) return 'Samsung Galaxy S23+';
    if (lowerModel.startsWith('sm-s911')) return 'Samsung Galaxy S23';
    if (lowerModel.startsWith('sm-s908')) return 'Samsung Galaxy S22 Ultra';
    if (lowerModel.startsWith('sm-s906')) return 'Samsung Galaxy S22+';
    if (lowerModel.startsWith('sm-s901')) return 'Samsung Galaxy S22';
    if (lowerModel.startsWith('sm-g998')) return 'Samsung Galaxy S21 Ultra';
    if (lowerModel.startsWith('sm-g996')) return 'Samsung Galaxy S21+';
    if (lowerModel.startsWith('sm-g991')) return 'Samsung Galaxy S21';
    if (lowerModel.startsWith('sm-g990')) return 'Samsung Galaxy S21 FE';
    if (lowerModel.startsWith('sm-f956') || lowerModel.startsWith('sm-f946')) return 'Samsung Galaxy Z Fold 5 / 6';
    if (lowerModel.startsWith('sm-f741') || lowerModel.startsWith('sm-f731')) return 'Samsung Galaxy Z Flip 5 / 6';
    if (lowerModel.startsWith('sm-a556')) return 'Samsung Galaxy A55 5G';
    if (lowerModel.startsWith('sm-a546')) return 'Samsung Galaxy A54 5G';
    if (lowerModel.startsWith('sm-a536')) return 'Samsung Galaxy A53 5G';
    if (lowerModel.startsWith('sm-a528') || lowerModel.startsWith('sm-a526') || lowerModel.startsWith('sm-a525')) return 'Samsung Galaxy A52';
    if (lowerModel.startsWith('sm-a356')) return 'Samsung Galaxy A35 5G';
    if (lowerModel.startsWith('sm-a346')) return 'Samsung Galaxy A34 5G';
    if (lowerModel.startsWith('sm-a336')) return 'Samsung Galaxy A33 5G';
    if (lowerModel.startsWith('sm-a256')) return 'Samsung Galaxy A25 5G';
    if (lowerModel.startsWith('sm-a156')) return 'Samsung Galaxy A15 5G';
    if (lowerModel.startsWith('sm-a155')) return 'Samsung Galaxy A15 4G';
    if (lowerModel.startsWith('sm-a057')) return 'Samsung Galaxy A05s';
    if (lowerModel.startsWith('sm-a055')) return 'Samsung Galaxy A05';
    if (lowerModel.startsWith('sm-m546')) return 'Samsung Galaxy M54 5G';
    if (lowerModel.startsWith('sm-m346')) return 'Samsung Galaxy M34 5G';

    // ── GOOGLE PIXEL ─────────────────────────────────────────────────
    if (lowerModel.contains('pixel 9 pro fold')) return 'Google Pixel 9 Pro Fold';
    if (lowerModel.contains('pixel 9 pro xl')) return 'Google Pixel 9 Pro XL';
    if (lowerModel.contains('pixel 9 pro')) return 'Google Pixel 9 Pro';
    if (lowerModel.contains('pixel 9')) return 'Google Pixel 9';
    if (lowerModel.contains('pixel 8a')) return 'Google Pixel 8a';
    if (lowerModel.contains('pixel 8 pro')) return 'Google Pixel 8 Pro';
    if (lowerModel.contains('pixel 8')) return 'Google Pixel 8';
    if (lowerModel.contains('pixel 7a')) return 'Google Pixel 7a';
    if (lowerModel.contains('pixel 7 pro')) return 'Google Pixel 7 Pro';
    if (lowerModel.contains('pixel 7')) return 'Google Pixel 7';
    if (lowerModel.contains('pixel 6a')) return 'Google Pixel 6a';
    if (lowerModel.contains('pixel 6 pro')) return 'Google Pixel 6 Pro';
    if (lowerModel.contains('pixel 6')) return 'Google Pixel 6';

    // ── NOTHING & CMF ────────────────────────────────────────────────
    if (lowerModel.contains('a065') || fullKey.contains('phone (2)')) return 'Nothing Phone (2)';
    if (lowerModel.contains('a063') || fullKey.contains('phone (1)')) return 'Nothing Phone (1)';
    if (lowerModel.contains('a142') || fullKey.contains('phone (2a)')) return 'Nothing Phone (2a)';
    if (lowerModel.contains('a001') || fullKey.contains('cmf phone 1')) return 'CMF Phone 1 by Nothing';

    // ── TRANSSION (Tecno / Infinix) ──────────────────────────────────
    if (lowerModel.contains('ck8n') || lowerModel.contains('ck8')) return 'Tecno Camon 30 Premier 5G';
    if (lowerModel.contains('cl7')) return 'Tecno Camon 30 Pro 5G';
    if (lowerModel.contains('ck6n') || lowerModel.contains('ck6')) return 'Tecno Camon 20 Pro 5G';
    if (lowerModel.contains('ck7n')) return 'Tecno Camon 20 Premier 5G';
    if (lowerModel.contains('li7')) return 'Tecno Pova 6 Pro 5G';
    if (lowerModel.contains('li6')) return 'Tecno Pova 6';
    if (lowerModel.contains('lh7n') || lowerModel.contains('lh8n')) return 'Tecno Pova 5 Pro 5G';
    if (lowerModel.contains('kj5') || lowerModel.contains('kj6')) return 'Tecno Spark 20 Pro / Pro+';
    if (lowerModel.contains('x6871')) return 'Infinix GT 20 Pro';
    if (lowerModel.contains('x6870')) return 'Infinix Note 40 Pro+ 5G';
    if (lowerModel.contains('x6850')) return 'Infinix Note 40 Pro 5G';
    if (lowerModel.contains('x6833b')) return 'Infinix Note 30 Pro';
    if (lowerModel.contains('x6831')) return 'Infinix Note 30';
    if (lowerModel.contains('x6837')) return 'Infinix Hot 40 Pro';

    // ── HONOR & HUAWEI ───────────────────────────────────────────────
    if (lowerModel.contains('bvl-an16') || lowerModel.contains('bvl-n49')) return 'Honor Magic6 Pro';
    if (lowerModel.contains('pgt-an10') || lowerModel.contains('pgt-n19')) return 'Honor Magic5 Pro';
    if (lowerModel.contains('eli-an00') || lowerModel.contains('eli-nx9')) return 'Honor 200 Pro';
    if (lowerModel.contains('ali-nx1')) return 'Honor X9b 5G / Magic6 Lite';
    if (lowerModel.contains('rea-nx9')) return 'Honor 90 5G';
    if (lowerModel.contains('hny-an00')) return 'Huawei Pura 70 Ultra';
    if (lowerModel.contains('alh-al00')) return 'Huawei Mate 60 Pro';

    // ── MOTOROLA ─────────────────────────────────────────────────────
    if (lowerModel.contains('xt2401') || lowerModel.contains('xt2403')) return 'Motorola Edge 50 Pro / Ultra';
    if (lowerModel.contains('xt2301') || lowerModel.contains('xt2303')) return 'Motorola Edge 40 Pro / Edge 40';
    if (lowerModel.contains('xt2453')) return 'Motorola Razr 50 Ultra';

    if (model.isNotEmpty) {
      if (model.toLowerCase().startsWith(brand.toLowerCase())) {
        return model;
      }
      return '$brand $model';
    }
    return brand;
  }

  /// Resolves commercial SoC names for Qualcomm, MediaTek, Tensor, Exynos, Unisoc.
  /// When a device model is provided the raw SoC ID (e.g. SM6375) is appended in
  /// parentheses for display: "Qualcomm Snapdragon 695 5G (SM6375)".
  static String resolveCommercialSoc(String rawSoc, [String manufacturer = '', String model = '']) {
    final lower = rawSoc.toLowerCase();
    final lowerModel = model.toLowerCase();

    // Helper: append raw SoC ID in parentheses — only when a device model is known,
    // so bare resolveCommercialSoc('sm6375') returns the plain marketing name.
    String withId(String name) {
      if (model.isEmpty) return name;
      final id = rawSoc.trim();
      if (id.isEmpty || id.toLowerCase() == 'unknown') return name;
      if (name.contains('($id)') || name.toLowerCase() == id.toLowerCase()) return name;
      return '$name ($id)';
    }

    // Specific mapping for common hardware strings
    if (lowerModel.contains('cph2417') || lower.contains('sm6375') || lower.contains('holi')) {
      return withId('Qualcomm Snapdragon 695 5G');
    }

    // ── QUALCOMM SNAPDRAGON ──────────────────────────────────────────
    if (lower.contains('sm8750') || lower.contains('sun')) return 'Qualcomm Snapdragon 8 Elite';
    if (lower.contains('sm8650') || lower.contains('pineapple')) return 'Qualcomm Snapdragon 8 Gen 3';
    if (lower.contains('sm8550') || lower.contains('kalama')) return 'Qualcomm Snapdragon 8 Gen 2';
    if (lower.contains('sm8475') || lower.contains('cape')) return 'Qualcomm Snapdragon 8+ Gen 1';
    if (lower.contains('sm8450') || lower.contains('taro')) return 'Qualcomm Snapdragon 8 Gen 1';
    if (lower.contains('sm8350') || lower.contains('lahaina')) return 'Qualcomm Snapdragon 888 5G';
    if (lower.contains('sm8250') || lower.contains('kona')) return 'Qualcomm Snapdragon 865 5G / 870';
    if (lower.contains('sm7675')) return 'Qualcomm Snapdragon 7+ Gen 3';
    if (lower.contains('sm7550')) return 'Qualcomm Snapdragon 7 Gen 3';
    if (lower.contains('sm7475')) return 'Qualcomm Snapdragon 7+ Gen 2';
    if (lower.contains('sm7450')) return 'Qualcomm Snapdragon 7 Gen 1';
    if (lower.contains('sm7435')) return 'Qualcomm Snapdragon 7s Gen 2';
    if (lower.contains('sm7325')) return 'Qualcomm Snapdragon 778G 5G';
    if (lower.contains('sm7250')) return 'Qualcomm Snapdragon 765G 5G';
    if (lower.contains('sm7225')) return 'Qualcomm Snapdragon 750G 5G';
    if (lower.contains('sm7150')) return 'Qualcomm Snapdragon 730G';
    if (lower.contains('sm7125')) return 'Qualcomm Snapdragon 720G';
    if (lower.contains('sm6450')) return 'Qualcomm Snapdragon 6 Gen 1';
    if (lower.contains('sm6225')) return 'Qualcomm Snapdragon 680 4G';
    if (lower.contains('sm4450')) return 'Qualcomm Snapdragon 4 Gen 2';
    if (lower.contains('sm4375')) return 'Qualcomm Snapdragon 4 Gen 1';
    if (lower.contains('qcom') || lower.contains('qualcomm')) {
      return 'Qualcomm Snapdragon Octa-Core';
    }

    // ── MEDIATEK DIMENSITY & HELIO ───────────────────────────────────
    if (lower.contains('mt6991')) return 'MediaTek Dimensity 9400';
    if (lower.contains('mt6989')) return 'MediaTek Dimensity 9300';
    if (lower.contains('mt6985')) return 'MediaTek Dimensity 9200';
    if (lower.contains('mt6983')) return 'MediaTek Dimensity 9000';
    if (lower.contains('mt6897')) return 'MediaTek Dimensity 8300-Ultra';
    if (lower.contains('mt6896')) return 'MediaTek Dimensity 8200';
    if (lower.contains('mt6895')) return 'MediaTek Dimensity 8100';
    if (lower.contains('mt6878')) return 'MediaTek Dimensity 7300';
    if (lower.contains('mt6886')) return 'MediaTek Dimensity 7200';
    if (lower.contains('mt6877v') || lower.contains('mt6877')) return 'MediaTek Dimensity 7050 / 900';
    if (lower.contains('mt6855')) return 'MediaTek Dimensity 7020';
    if (lower.contains('mt6835')) return 'MediaTek Dimensity 6100+ / 6080';
    if (lower.contains('mt6833')) return 'MediaTek Dimensity 700 / 6020';
    if (lower.contains('mt6789') || lower.contains('g99')) return 'MediaTek Helio G99';
    if (lower.contains('mt6785') || lower.contains('mt6781') || lower.contains('g96') || lower.contains('g95')) return 'MediaTek Helio G95 / G96';
    if (lower.contains('mt6769') || lower.contains('g88') || lower.contains('g85')) return 'MediaTek Helio G85 / G88';
    if (lower.contains('mt6768') || lower.contains('g80')) return 'MediaTek Helio G80';
    if (lower.contains('mt6765') || lower.contains('g36') || lower.contains('g35')) return 'MediaTek Helio G36 / G35';
    if (lower.contains('mtk') || lower.contains('mediatek')) {
      return 'MediaTek Dimensity Processor';
    }

    // ── GOOGLE TENSOR ────────────────────────────────────────────────
    if (lower.contains('zuma pro') || lower.contains('tensor g4')) return 'Google Tensor G4';
    if (lower.contains('zuma') || lower.contains('tensor g3')) return 'Google Tensor G3';
    if (lower.contains('cloudripper') || lower.contains('tensor g2')) return 'Google Tensor G2';
    if (lower.contains('whitechapel') || lower.contains('tensor')) return 'Google Tensor';

    // ── SAMSUNG EXYNOS ───────────────────────────────────────────────
    if (lower.contains('s5e9945')) return 'Samsung Exynos 2400';
    if (lower.contains('s5e9925')) return 'Samsung Exynos 2200';
    if (lower.contains('s5e8845')) return 'Samsung Exynos 1480';
    if (lower.contains('s5e8835')) return 'Samsung Exynos 1380';
    if (lower.contains('s5e8825')) return 'Samsung Exynos 1280';
    if (lower.contains('s5e9840')) return 'Samsung Exynos 2100';
    if (lower.contains('s5e8535') || lower.contains('exynos 850')) return 'Samsung Exynos 850';
    if (lower.contains('exynos')) return 'Samsung Exynos Octa-Core';

    // ── UNISOC ───────────────────────────────────────────────────────
    if (lower.contains('ums9620') || lower.contains('t820')) return 'Unisoc T820 5G';
    if (lower.contains('t760')) return 'Unisoc T760 5G';
    if (lower.contains('ums9230') || lower.contains('t606')) return 'Unisoc T606';
    if (lower.contains('t616') || lower.contains('t612') || lower.contains('t619')) return 'Unisoc T616 / T612';
    if (lower.contains('sc9863')) return 'Unisoc SC9863A';

    if (rawSoc.isNotEmpty && rawSoc != 'unknown') {
      return rawSoc;
    }

    return 'Octa-Core 64-bit SoC';
  }
}

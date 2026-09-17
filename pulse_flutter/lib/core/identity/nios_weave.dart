import 'dart:convert';
import 'dart:typed_data';
import 'package:pulse_flutter/core/identity/nios_mark.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

/// The canonical background roles mapped to 4-bit nibbles (0..15).
const List<String> kWeaveBgRoles = <String>[
  'surface',
  'surfaceContainerLowest',
  'surfaceContainerLow',
  'surfaceContainer',
  'surfaceContainerHigh',
  'surfaceContainerHighest',
  'primaryContainer',
  'secondaryContainer',
  'tertiaryContainer',
];

/// The canonical icon color roles mapped to 4-bit nibbles (0..15).
const List<String> kWeaveIconRoles = <String>[
  'primary',
  'secondary',
  'tertiary',
  'outline',
  'outlineVariant',
  'onSurface',
  'onSurfaceVariant',
  'primaryContainer',
  'secondaryContainer',
  'tertiaryContainer',
];

/// The canonical theme packs mapped to 4-bit nibbles (0..15).
const List<String> kWeaveThemePacks = <String>[
  'all',
  'chat',
  'tech',
  'space',
  'food',
  'nature',
  'minimal',
  'custom',
];

/// Nios Weave — Procedural Identity & Wallpaper Exchange Codec (.nwv).
///
/// Encodes full procedural wallpaper configurations into an ultra-compact
/// 14-byte binary envelope (~19 base64url characters) with version prefix `nwv1:`.
/// Also implements the 2D positional hash for cross-platform determinism (NW-3).
abstract final class NiosWeave {
  static const String prefix = 'nwv1:';
  static const int currentVersion = 1;
  static const int minPayloadBytes = 14;

  /// Stable 32-bit 2D positional integer hash combining seed, cellX, and cellY.
  ///
  /// Guarantees that cell (x, y) renders identically across all devices,
  /// screen orientations, viewport sizes, and platforms without sequence shifts (NW-3).
  static int posHash(int seed, int cellX, int cellY) {
    var h = (seed ^ 0x811c9dc5) & 0x7FFFFFFF;
    h = (h ^ ((cellX * 0x1f1f1f1f) & 0x7FFFFFFF)) & 0x7FFFFFFF;
    h = (h * 0x01000193) & 0x7FFFFFFF;
    h = (h ^ ((cellY * 0x3b3b3b3b) & 0x7FFFFFFF)) & 0x7FFFFFFF;
    h = (h * 0x01000193) & 0x7FFFFFFF;
    // Avalanche mix
    h = (h ^ (h >> 13)) & 0x7FFFFFFF;
    h = (h * 0x5bd1e995) & 0x7FFFFFFF;
    h = (h ^ (h >> 15)) & 0x7FFFFFFF;
    return h;
  }

  /// Encodes a [ChatWallpaperConfig] into a compact `nwv1:<base64url>` string.
  static String encode(ChatWallpaperConfig config) {
    final List<int> bytes = <int>[];

    // Byte 0: version
    bytes.add(currentVersion);

    // Bytes 1-2: uint16 seed
    final int seed16 = config.seed.abs() & 0xFFFF;
    bytes.add((seed16 >> 8) & 0xFF);
    bytes.add(seed16 & 0xFF);

    // Byte 3: iconSource (3b) | layoutMode (3b) | filled (1b) | staggerByRow (1b)
    final int iconSrcIdx = config.iconSource.index.clamp(0, 5);
    final int layoutIdx = config.layoutMode.index.clamp(0, 4);
    final int filledBit = config.filled ? 1 : 0;
    final int staggerBit = config.staggerByRow ? 1 : 0;
    bytes.add((iconSrcIdx << 5) | (layoutIdx << 2) | (filledBit << 1) | staggerBit);

    // Byte 4: themePack (4b) | colorMode (2b) | backgroundStyle (2b)
    final int packIdx = kWeaveThemePacks.indexOf(config.themePack);
    final int safePackIdx = (packIdx >= 0 ? packIdx : 0) & 0x0F;
    final int colorModeIdx = config.colorMode.index.clamp(0, 2);
    final int bgStyleIdx = config.backgroundStyle.index.clamp(0, 2);
    bytes.add((safePackIdx << 4) | (colorModeIdx << 2) | bgStyleIdx);

    // Byte 5: cellSize (step 4 dp: 20..240 -> 0..55)
    final int cellSizeByte =
        (((config.cellSize.clamp(20.0, 240.0) - 20.0) / 4.0).round()).clamp(0, 55);
    bytes.add(cellSizeByte);

    // Byte 6: density (0..1.0 -> 0..255)
    final int densityByte = (config.density.clamp(0.0, 1.0) * 255.0).round().clamp(0, 255);
    bytes.add(densityByte);

    // Byte 7: iconAlpha (0..1.0 -> 0..255)
    final int alphaByte =
        (config.iconAlpha.clamp(0.0, 1.0) * 255.0).round().clamp(0, 255);
    bytes.add(alphaByte);

    // Byte 8: gridAngle (-45..45 -> 0..90)
    final int angleByte = (config.gridAngle.clamp(-45.0, 45.0).round() + 45).clamp(0, 90);
    bytes.add(angleByte);

    // Byte 9: backgroundRole (4b) | backgroundSecondaryRole (4b)
    final int bgRole1 = kWeaveBgRoles.indexOf(config.backgroundRole);
    final int bgRole2 = kWeaveBgRoles.indexOf(config.backgroundSecondaryRole);
    final int safeBg1 = (bgRole1 >= 0 ? bgRole1 : 2) & 0x0F;
    final int safeBg2 = (bgRole2 >= 0 ? bgRole2 : 1) & 0x0F;
    bytes.add((safeBg1 << 4) | safeBg2);

    // Byte 10: iconColorRole (4b) | symbolsStyle (2b) | useAllIcons (1b) | hasCustomGlyphs (1b)
    final int iconRoleIdx = kWeaveIconRoles.indexOf(config.iconColorRole);
    final int safeIconRole = (iconRoleIdx >= 0 ? iconRoleIdx : 0) & 0x0F;
    final int symStyleIdx = config.symbolsStyle.index.clamp(0, 2);
    final int useAllBit = config.useAllIcons ? 1 : 0;
    final bool hasCustom =
        config.themePack == 'custom' && config.selectedGlyphs.isNotEmpty;
    final int customBit = hasCustom ? 1 : 0;
    bytes.add((safeIconRole << 4) | (symStyleIdx << 2) | (useAllBit << 1) | customBit);

    // Byte 11: gradientAngle (0..360 -> 0..255)
    final int gradAngleByte =
        ((config.gradientAngle % 360.0) / 360.0 * 255.0).round().clamp(0, 255);
    bytes.add(gradAngleByte);

    // Byte 12: randomRotationDeg (0..90 -> 0..255)
    final int rotByte =
        ((config.randomRotationDeg.clamp(0.0, 90.0) / 90.0) * 255.0).round().clamp(0, 255);
    bytes.add(rotByte);

    // Byte 13: randomScaleJitter (0..1.0 -> 0..255)
    final int jitterByte =
        (config.randomScaleJitter.clamp(0.0, 1.0) * 255.0).round().clamp(0, 255);
    bytes.add(jitterByte);

    final String b64 = base64Url.encode(bytes).replaceAll('=', '');
    return '$prefix$b64';
  }

  /// Decodes a string code (or link) into a [ChatWallpaperConfig]. Returns null if invalid.
  static ChatWallpaperConfig? decode(String rawInput) {
    var clean = rawInput.trim();
    if (clean.isEmpty) return null;

    // Handle full URL ni-os.ru/w/...
    final Uri? parsedUri = Uri.tryParse(clean);
    if (parsedUri != null && parsedUri.pathSegments.contains('w')) {
      final int idx = parsedUri.pathSegments.indexOf('w');
      if (idx + 1 < parsedUri.pathSegments.length) {
        clean = parsedUri.pathSegments[idx + 1];
      }
    }

    if (clean.startsWith(prefix)) {
      clean = clean.substring(prefix.length);
    }

    try {
      final String normalized = base64Url.normalize(clean);
      final Uint8List bytes = base64Url.decode(normalized);

      if (bytes.length < minPayloadBytes) return null;

      final int version = bytes[0];
      if (version != currentVersion) return null;

      final int seed = (bytes[1] << 8) | bytes[2];

      final int b3 = bytes[3];
      final int iconSrcIdx = (b3 >> 5) & 0x07;
      final int layoutIdx = (b3 >> 2) & 0x07;
      final bool filled = ((b3 >> 1) & 0x01) == 1;
      final bool staggerByRow = (b3 & 0x01) == 1;

      final int b4 = bytes[4];
      final int packIdx = (b4 >> 4) & 0x0F;
      final int colorModeIdx = (b4 >> 2) & 0x03;
      final int bgStyleIdx = b4 & 0x03;

      final int cellSizeByte = bytes[5];
      final double cellSize = (cellSizeByte * 4.0 + 20.0).clamp(20.0, 240.0);

      final int densityByte = bytes[6];
      final double density = (densityByte / 255.0).clamp(0.0, 1.0);

      final int alphaByte = bytes[7];
      final double iconAlpha = (alphaByte / 255.0).clamp(0.0, 1.0);

      final int angleByte = bytes[8];
      final double gridAngle = (angleByte - 45).toDouble().clamp(-45.0, 45.0);

      final int b9 = bytes[9];
      final int bgRole1Idx = (b9 >> 4) & 0x0F;
      final int bgRole2Idx = b9 & 0x0F;
      final String bgRole = bgRole1Idx < kWeaveBgRoles.length
          ? kWeaveBgRoles[bgRole1Idx]
          : 'surfaceContainerLow';
      final String bgSecRole = bgRole2Idx < kWeaveBgRoles.length
          ? kWeaveBgRoles[bgRole2Idx]
          : 'surfaceContainerLowest';

      final int b10 = bytes[10];
      final int iconRoleIdx = (b10 >> 4) & 0x0F;
      final int symStyleIdx = (b10 >> 2) & 0x03;
      final bool useAllIcons = ((b10 >> 1) & 0x01) == 1;
      final String iconRole = iconRoleIdx < kWeaveIconRoles.length
          ? kWeaveIconRoles[iconRoleIdx]
          : 'primary';

      final int gradByte = bytes[11];
      final double gradientAngle = (gradByte / 255.0) * 360.0;

      final int rotByte = bytes[12];
      final double randomRotationDeg = (rotByte / 255.0) * 90.0;

      final int jitterByte = bytes[13];
      final double randomScaleJitter = jitterByte / 255.0;

      final String themePack = packIdx < kWeaveThemePacks.length
          ? kWeaveThemePacks[packIdx]
          : 'all';

      return ChatWallpaperConfig(
        seed: seed,
        iconSource: IconSource.values.elementAtOrNull(iconSrcIdx) ??
            IconSource.materialSymbols,
        layoutMode: WallpaperLayoutMode.values.elementAtOrNull(layoutIdx) ??
            WallpaperLayoutMode.stagger,
        filled: filled,
        staggerByRow: staggerByRow,
        themePack: themePack,
        colorMode: WallpaperColorMode.values.elementAtOrNull(colorModeIdx) ??
            WallpaperColorMode.singleTone,
        backgroundStyle: WallpaperBackgroundStyle.values.elementAtOrNull(bgStyleIdx) ??
            WallpaperBackgroundStyle.solid,
        cellSize: cellSize,
        density: density,
        iconAlpha: iconAlpha,
        gridAngle: gridAngle,
        backgroundRole: bgRole,
        backgroundSecondaryRole: bgSecRole,
        iconColorRole: iconRole,
        symbolsStyle: MaterialSymbolsStyle.values.elementAtOrNull(symStyleIdx) ??
            MaterialSymbolsStyle.rounded,
        useAllIcons: useAllIcons,
        gradientAngle: gradientAngle,
        randomRotationDeg: randomRotationDeg,
        randomScaleJitter: randomScaleJitter,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generates a shareable URL from an encoded string (NW-2).
  static String toShareUrl(String code) {
    final String payload = code.startsWith(prefix) ? code.substring(prefix.length) : code;
    return 'https://ni-os.ru/w/$payload';
  }

  /// Generates a shareable URL that opens the web renderer or NiosMess (NW-2).
  static String generateShareUrl(ChatWallpaperConfig config) {
    final String code = encode(config);
    return toShareUrl(code);
  }

  /// Derives a deterministic, personal Weave signature pattern for a user (NW-5).
  static ChatWallpaperConfig deriveUserSignature(String userId) {
    final int seed = NiosMark.hashString(userId);
    final int packIdx = (seed >> 4) % (kWeaveThemePacks.length - 1);
    final String pack = kWeaveThemePacks[packIdx];

    const List<WallpaperLayoutMode> modes = [
      WallpaperLayoutMode.stagger,
      WallpaperLayoutMode.hex,
      WallpaperLayoutMode.grid,
    ];
    final WallpaperLayoutMode layout = modes[(seed >> 8) % modes.length];

    final int bgIdx = (seed >> 12) % kWeaveBgRoles.length;
    final int iconColorIdx = (seed >> 16) % kWeaveIconRoles.length;

    return ChatWallpaperConfig(
      seed: seed & 0xFFFF,
      iconSource: IconSource.niosMess,
      layoutMode: layout,
      cellSize: 56.0,
      density: 0.72,
      iconAlpha: 0.14,
      themePack: pack,
      backgroundRole: kWeaveBgRoles[bgIdx],
      backgroundSecondaryRole: kWeaveBgRoles[(bgIdx + 1) % kWeaveBgRoles.length],
      iconColorRole: kWeaveIconRoles[iconColorIdx],
      backgroundStyle: ((seed >> 6) % 3 == 0)
          ? WallpaperBackgroundStyle.radialGlow
          : WallpaperBackgroundStyle.solid,
      randomRotationDeg: 12.0,
      randomScaleJitter: 0.12,
    );
  }
}

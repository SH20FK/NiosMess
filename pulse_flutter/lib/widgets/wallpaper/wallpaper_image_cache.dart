import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_painter.dart';
import 'package:pulse_flutter/widgets/wallpaper/icon_sources_catalog.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';

class _WallpaperCacheKey {
  const _WallpaperCacheKey({
    required this.config,
    required this.schemeHash,
    required this.width,
    required this.height,
  });

  final ChatWallpaperConfig config;
  final int schemeHash;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _WallpaperCacheKey &&
        other.config == config &&
        other.schemeHash == schemeHash &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(config, schemeHash, width, height);
}

class WallpaperImageCache {
  const WallpaperImageCache._();

  static const int _kMaxCacheEntries = 16;
  static final Map<_WallpaperCacheKey, ui.Image> _lruCache =
      <_WallpaperCacheKey, ui.Image>{};
  static final Map<_WallpaperCacheKey, Future<ui.Image>> _inFlightFutures =
      <_WallpaperCacheKey, Future<ui.Image>>{};

  static final Map<String, String> _rawSvgStringCache = <String, String>{};

  static int _schemeKey(ColorScheme scheme) {
    return Object.hash(
      scheme.primary.toARGB32(),
      scheme.surface.toARGB32(),
      scheme.surfaceContainerLow.toARGB32(),
      scheme.brightness,
    );
  }

  static int quantizeWidth(double width, double pixelRatio) {
    final int raw = (width * pixelRatio).round();
    return max(64, ((raw + 31) ~/ 32) * 32);
  }

  static int quantizeHeight(double height, double pixelRatio) {
    final int raw = (height * pixelRatio).round();
    return max(64, ((raw + 31) ~/ 32) * 32);
  }

  static final Map<String, ui.Picture> _uncoloredPictureCache = <String, ui.Picture>{};

  /// High-performance SVG loader with in-memory picture caching and smart fill injection.
  /// Pictures are loaded in neutral white (0xFFFFFFFF) once, then tinted at draw time
  /// via Paint.colorFilter / saveLayer to eliminate reload churn on alpha or theme changes.
  static Future<ui.Picture?> loadPatternSvg({
    required String assetPath,
    Color color = const Color(0xFFFFFFFF),
    required bool filled,
  }) async {
    final String cacheKey = '${assetPath}_$filled';
    final ui.Picture? cachedPic = _uncoloredPictureCache[cacheKey];
    if (cachedPic != null) {
      return cachedPic;
    }

    try {
      final ui.Picture pic;
      if (!filled) {
        final PictureInfo info = await vg.loadPicture(
          SvgAssetLoader(assetPath, theme: const SvgTheme(currentColor: Color(0xFFFFFFFF))),
          null,
        );
        pic = info.picture;
      } else {
        String? rawSvg = _rawSvgStringCache[assetPath];
        if (rawSvg == null) {
          rawSvg = await rootBundle.loadString(assetPath);
          if (_rawSvgStringCache.length > 300) {
            _rawSvgStringCache.clear();
          }
          _rawSvgStringCache[assetPath] = rawSvg;
        }

        // Smart fill for closed vector paths: replace fill="none" with fill="currentColor"
        final String filledSvg =
            rawSvg.replaceAll('fill="none"', 'fill="currentColor"');
        final PictureInfo info = await vg.loadPicture(
          SvgStringLoader(filledSvg, theme: const SvgTheme(currentColor: Color(0xFFFFFFFF))),
          null,
        );
        pic = info.picture;
      }

      if (_uncoloredPictureCache.length > 500) {
        _uncoloredPictureCache.clear();
      }
      _uncoloredPictureCache[cacheKey] = pic;
      return pic;
    } catch (_) {
      return null;
    }
  }

  static ui.Image? getSyncCachedImage({
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    required Size size,
    double pixelRatio = 1.0,
  }) {
    if (size.width <= 0 || size.height <= 0) return null;

    final int targetWidth = quantizeWidth(size.width, pixelRatio);
    final int targetHeight = quantizeHeight(size.height, pixelRatio);
    final _WallpaperCacheKey key = _WallpaperCacheKey(
      config: config,
      schemeHash: _schemeKey(scheme),
      width: targetWidth,
      height: targetHeight,
    );

    final ui.Image? image = _lruCache.remove(key);
    if (image != null) {
      _lruCache[key] = image;
      return image;
    }
    return null;
  }

  static Future<ui.Image?> render({
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    required Size size,
    double pixelRatio = 1.0,
    bool force = false,
  }) async {
    if (size.width <= 0 || size.height <= 0) return null;

    final int targetWidth = quantizeWidth(size.width, pixelRatio);
    final int targetHeight = quantizeHeight(size.height, pixelRatio);
    final _WallpaperCacheKey key = _WallpaperCacheKey(
      config: config,
      schemeHash: _schemeKey(scheme),
      width: targetWidth,
      height: targetHeight,
    );

    if (!force) {
      final ui.Image? cached = _lruCache.remove(key);
      if (cached != null) {
        _lruCache[key] = cached;
        return cached;
      }
    }

    final Future<ui.Image>? inFlight = _inFlightFutures[key];
    if (inFlight != null) {
      return inFlight;
    }

    final Future<ui.Image> future = _doRender(
      config: config,
      scheme: scheme,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      logicalSize: size,
    );
    _inFlightFutures[key] = future;

    try {
      final ui.Image result = await future;
      _putCache(key, result);
      return result;
    } finally {
      _inFlightFutures.remove(key);
    }
  }

  static void _putCache(_WallpaperCacheKey key, ui.Image image) {
    final ui.Image? existing = _lruCache.remove(key);
    if (existing != null && existing != image) {
      existing.dispose();
    }
    while (_lruCache.length >= _kMaxCacheEntries) {
      final _WallpaperCacheKey oldestKey = _lruCache.keys.first;
      final ui.Image? evicted = _lruCache.remove(oldestKey);
      evicted?.dispose();
    }
    _lruCache[key] = image;
  }

  static Future<ui.Image> _doRender({
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    required int targetWidth,
    required int targetHeight,
    required Size logicalSize,
  }) async {
    ui.Picture? svgPicture;
    Map<String, ui.Picture>? paletteSvgPictures;
    List<ui.Picture>? poolSvgPictures;

    final Color primaryIconColor = WallpaperColorResolver.resolveIconColor(
      scheme,
      config.iconColorRole,
      config.iconAlpha,
    );

    // Preload SVGs in parallel for Lucide and Tabler
    if (config.iconSource == IconSource.lucide ||
        config.iconSource == IconSource.tabler) {
      final String folder =
          config.iconSource == IconSource.lucide ? 'lucide' : 'tabler';
      List<String> iconsToLoad = <String>[];

      if (config.themePack != 'all' && config.themePack != 'custom') {
        iconsToLoad = IconSourcesCatalog.getThemePackIcons(
          config.themePack,
          source: config.iconSource,
        );
      } else if (config.themePack == 'custom' &&
          config.selectedGlyphs.isNotEmpty) {
        iconsToLoad = config.selectedGlyphs;
      } else if (config.useAllIcons || config.themePack == 'all') {
        final List<String> catalog = config.iconSource == IconSource.lucide
            ? IconSourcesCatalog.lucideIcons
            : IconSourcesCatalog.tablerIcons;
        final int poolSize = min(28, catalog.length);
        final Random poolRng = Random(config.seed);
        for (int i = 0; i < poolSize; i++) {
          iconsToLoad.add(catalog[poolRng.nextInt(catalog.length)]);
        }
      }

      if (iconsToLoad.isNotEmpty) {
        final List<ui.Picture?> results = await Future.wait(
          iconsToLoad.map(
            (name) => loadPatternSvg(
              assetPath: 'assets/svg/pattern_icons/$folder/$name.svg',
              color: primaryIconColor,
              filled: config.filled,
            ),
          ),
        );
        poolSvgPictures = results.whereType<ui.Picture>().toList();
      } else if (config.svgAssetPath != null &&
          config.svgAssetPath!.isNotEmpty) {
        svgPicture = await loadPatternSvg(
          assetPath: config.svgAssetPath!,
          color: primaryIconColor,
          filled: config.filled,
        );
      }
    } else if (config.iconSource == IconSource.niosMess) {
      if (!config.useAllIcons &&
          config.svgAssetPath != null &&
          config.svgAssetPath!.isNotEmpty) {
        svgPicture = await loadPatternSvg(
          assetPath: config.svgAssetPath!,
          color: primaryIconColor,
          filled: config.filled,
        );
      }
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
    );

    final double scaleX = targetWidth / logicalSize.width;
    final double scaleY = targetHeight / logicalSize.height;
    canvas.scale(scaleX, scaleY);

    ChatWallpaperPainter.paintToCanvas(
      canvas: canvas,
      size: logicalSize,
      config: config,
      scheme: scheme,
      svgPicture: svgPicture,
      paletteSvgPictures: paletteSvgPictures,
      poolSvgPictures: poolSvgPictures,
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(targetWidth, targetHeight);
    picture.dispose();
    return image;
  }

  static void clear() {
    for (final ui.Image img in _lruCache.values) {
      img.dispose();
    }
    _lruCache.clear();
    _inFlightFutures.clear();
  }
}

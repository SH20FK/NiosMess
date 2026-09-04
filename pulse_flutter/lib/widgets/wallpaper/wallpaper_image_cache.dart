import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_painter.dart';
import 'package:pulse_flutter/widgets/wallpaper/icon_sources_catalog.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';

class WallpaperImageCache {
  const WallpaperImageCache._();

  static ui.Image? _cachedImage;
  static ChatWallpaperConfig? _cachedConfig;
  static ColorScheme? _cachedScheme;
  static int? _cachedWidth;
  static int? _cachedHeight;
  static Future<ui.Image>? _inFlightFuture;

  static int quantizeWidth(double width, double pixelRatio) {
    final int raw = (width * pixelRatio).round();
    return max(64, ((raw + 31) ~/ 32) * 32);
  }

  static int quantizeHeight(double height, double pixelRatio) {
    final int raw = (height * pixelRatio).round();
    return max(64, ((raw + 31) ~/ 32) * 32);
  }

  static ui.Image? getSyncCachedImage({
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    required Size size,
    double pixelRatio = 1.0,
  }) {
    final int targetWidth = quantizeWidth(size.width, pixelRatio);
    final int targetHeight = quantizeHeight(size.height, pixelRatio);

    if (_cachedImage != null &&
        _cachedConfig == config &&
        _cachedScheme == scheme &&
        _cachedWidth == targetWidth &&
        _cachedHeight == targetHeight) {
      return _cachedImage;
    }
    return null;
  }

  static Future<ui.Image> render({
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    required Size size,
    double pixelRatio = 1.0,
    bool force = false,
  }) async {
    if (size.width <= 0 || size.height <= 0) {
      throw ArgumentError('Invalid canvas size for wallpaper rendering: $size');
    }

    final int targetWidth = quantizeWidth(size.width, pixelRatio);
    final int targetHeight = quantizeHeight(size.height, pixelRatio);

    if (!force &&
        _cachedImage != null &&
        _cachedConfig == config &&
        _cachedScheme == scheme &&
        _cachedWidth == targetWidth &&
        _cachedHeight == targetHeight) {
      return _cachedImage!;
    }

    if (_inFlightFuture != null) {
      return _inFlightFuture!;
    }

    _inFlightFuture = _doRender(
      config: config,
      scheme: scheme,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      logicalSize: size,
    );

    try {
      final ui.Image result = await _inFlightFuture!;
      _cachedImage = result;
      _cachedConfig = config;
      _cachedScheme = scheme;
      _cachedWidth = targetWidth;
      _cachedHeight = targetHeight;
      return result;
    } finally {
      _inFlightFuture = null;
    }
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

    // Preload SVG if applicable
    if (config.iconSource == IconSource.lucide ||
        config.iconSource == IconSource.tabler) {
      if (config.useAllIcons) {
        // Preload diverse pool of icons from the catalog
        final List<String> catalog = config.iconSource == IconSource.lucide
            ? IconSourcesCatalog.lucideIcons
            : IconSourcesCatalog.tablerIcons;
        final String folder = config.iconSource == IconSource.lucide ? 'lucide' : 'tabler';

        poolSvgPictures = <ui.Picture>[];
        final int poolSize = min(36, catalog.length);
        final Random poolRng = Random(config.seed);

        for (int i = 0; i < poolSize; i++) {
          final String iconName = catalog[poolRng.nextInt(catalog.length)];
          try {
            final PictureInfo info = await vg.loadPicture(
              SvgAssetLoader(
                'assets/svg/pattern_icons/$folder/$iconName.svg',
                theme: SvgTheme(currentColor: primaryIconColor),
              ),
              null,
            );
            poolSvgPictures.add(info.picture);
          } catch (_) {}
        }
      } else if (config.svgAssetPath != null && config.svgAssetPath!.isNotEmpty) {
        try {
          final PictureInfo info = await vg.loadPicture(
            SvgAssetLoader(
              config.svgAssetPath!,
              theme: SvgTheme(currentColor: primaryIconColor),
            ),
            null,
          );
          svgPicture = info.picture;
        } catch (_) {}
      }
    } else if (config.iconSource == IconSource.niosMess) {
      if (!config.useAllIcons && config.svgAssetPath != null && config.svgAssetPath!.isNotEmpty) {
        try {
          final PictureInfo info = await vg.loadPicture(
            SvgAssetLoader(
              config.svgAssetPath!,
              theme: SvgTheme(currentColor: primaryIconColor),
            ),
            null,
          );
          svgPicture = info.picture;
        } catch (_) {}
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
    return image;
  }

  static void clear() {
    _cachedImage = null;
    _cachedConfig = null;
    _cachedScheme = null;
    _cachedWidth = null;
    _cachedHeight = null;
    _inFlightFuture = null;
  }
}

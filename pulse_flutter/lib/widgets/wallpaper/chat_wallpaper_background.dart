import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/chat_wallpaper_provider.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_image_cache.dart';
import 'package:universal_io/io.dart' as io;

class ChatWallpaperBackground extends ConsumerStatefulWidget {
  const ChatWallpaperBackground({
    this.chatId,
    super.key,
  });

  final String? chatId;

  @override
  ConsumerState<ChatWallpaperBackground> createState() => _ChatWallpaperBackgroundState();
}

class _ChatWallpaperBackgroundState extends ConsumerState<ChatWallpaperBackground> {
  ui.Image? _renderedImage;
  ChatWallpaperConfig? _lastConfig;
  ColorScheme? _lastScheme;
  int? _lastWidth;
  int? _lastHeight;
  bool _isRendering = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ChatWallpaperState state = ref.watch(chatWallpaperProvider);
    final ChatWallpaperConfig config = widget.chatId != null
        ? state.forChat(widget.chatId!)
        : state.global;

    final BoxDecoration placeholderDecoration;
    if (config.backgroundStyle == WallpaperBackgroundStyle.linearGradient) {
      final Color c1 = WallpaperColorResolver.resolveBackground(scheme, config.backgroundRole);
      final Color c2 = WallpaperColorResolver.resolveBackground(scheme, config.backgroundSecondaryRole);
      final double rad = config.gradientAngle * pi / 180.0;
      placeholderDecoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(cos(rad + pi), sin(rad + pi)),
          end: Alignment(cos(rad), sin(rad)),
          colors: [c1, c2],
        ),
      );
    } else if (config.backgroundStyle == WallpaperBackgroundStyle.radialGlow) {
      final Color c1 = WallpaperColorResolver.resolveBackground(scheme, config.backgroundRole);
      final Color c2 = WallpaperColorResolver.resolveBackground(scheme, config.backgroundSecondaryRole);
      placeholderDecoration = BoxDecoration(
        gradient: RadialGradient(
          colors: [c1, c2],
          radius: 0.85,
        ),
      );
    } else {
      final Color bgColor = WallpaperColorResolver.resolveBackground(
        scheme,
        config.backgroundRole,
      );
      placeholderDecoration = BoxDecoration(color: bgColor);
    }

    Widget? photoLayer;
    if (config.imagePath != null && config.imagePath!.isNotEmpty && !kIsWeb) {
      final io.File file = io.File(config.imagePath!);
      if (file.existsSync()) {
        final Size screenSize = MediaQuery.sizeOf(context);
        final double pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
        final int targetCacheWidth = (screenSize.width * pixelRatio).round().clamp(360, 1920);
        final int targetCacheHeight = (screenSize.height * pixelRatio).round().clamp(640, 2160);
        final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

        Widget img = Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: targetCacheWidth,
          cacheHeight: targetCacheHeight,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );

        // On Windows Desktop, live full-screen ImageFilter.blur stalls the compositor.
        // Replace live blur with an elegant contrast-preserving tonal scrim.
        if (config.imageBlur > 0.01 && !isWindows) {
          img = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: config.imageBlur.clamp(0.0, 16.0),
              sigmaY: config.imageBlur.clamp(0.0, 16.0),
            ),
            child: img,
          );
        }

        final double effectiveDim = (isWindows && config.imageBlur > 0.01
            ? (config.imageDim + 0.12)
            : config.imageDim).clamp(0.0, 0.95);

        if (effectiveDim > 0.01) {
          img = Stack(
            fit: StackFit.expand,
            children: <Widget>[
              img,
              ColoredBox(
                color: scheme.scrim.withValues(alpha: effectiveDim),
              ),
            ],
          );
        }
        photoLayer = RepaintBoundary(child: img);
      }
    }

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(
            decoration: placeholderDecoration,
            width: double.infinity,
            height: double.infinity,
          ),
          ?photoLayer,
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size screenSize = MediaQuery.sizeOf(context);
              final double width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                  ? constraints.maxWidth
                  : screenSize.width;
              final double height = screenSize.height;
              final Size size = Size(width, height);
              final double pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);

              // Check if we can get a synchronous cached image
              final ui.Image? syncImage = WallpaperImageCache.getSyncCachedImage(
                config: config,
                scheme: scheme,
                size: size,
                pixelRatio: pixelRatio,
              );

              if (syncImage != null) {
                _renderedImage = syncImage;
                _lastConfig = config;
                _lastScheme = scheme;
                _lastWidth = WallpaperImageCache.quantizeWidth(width, pixelRatio);
                _lastHeight = WallpaperImageCache.quantizeHeight(height, pixelRatio);
              } else {
                _triggerRenderIfNeeded(config, scheme, size, pixelRatio);
              }

              if (_renderedImage != null) {
                return RawImage(
                  image: _renderedImage,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  width: double.infinity,
                  height: double.infinity,
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  void _triggerRenderIfNeeded(
    ChatWallpaperConfig config,
    ColorScheme scheme,
    Size size,
    double pixelRatio,
  ) {
    final int targetWidth = WallpaperImageCache.quantizeWidth(size.width, pixelRatio);
    final int targetHeight = WallpaperImageCache.quantizeHeight(size.height, pixelRatio);

    if (_renderedImage != null &&
        _lastConfig == config &&
        _lastScheme == scheme &&
        _lastWidth == targetWidth &&
        _lastHeight == targetHeight) {
      return;
    }

    if (_isRendering) return;
    _isRendering = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final ui.Image? newImage = await WallpaperImageCache.render(
          config: config,
          scheme: scheme,
          size: size,
          pixelRatio: pixelRatio,
        );
        if (mounted && newImage != null) {
          setState(() {
            _renderedImage = newImage;
            _lastConfig = config;
            _lastScheme = scheme;
            _lastWidth = targetWidth;
            _lastHeight = targetHeight;
            _isRendering = false;
          });
        } else if (mounted) {
          _isRendering = false;
        }
      } catch (_) {
        if (mounted) {
          _isRendering = false;
        }
      }
    });
  }
}

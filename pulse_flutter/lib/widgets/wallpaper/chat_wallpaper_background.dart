import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/chat_wallpaper_provider.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_image_cache.dart';

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

    final Color bgColor = WallpaperColorResolver.resolveBackground(
      scheme,
      config.backgroundRole,
    );

    return RepaintBoundary(
      child: Container(
        color: bgColor,
        width: double.infinity,
        height: double.infinity,
        child: LayoutBuilder(
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
        final ui.Image newImage = await WallpaperImageCache.render(
          config: config,
          scheme: scheme,
          size: size,
          pixelRatio: pixelRatio,
        );
        if (mounted) {
          setState(() {
            _renderedImage = newImage;
            _lastConfig = config;
            _lastScheme = scheme;
            _lastWidth = targetWidth;
            _lastHeight = targetHeight;
            _isRendering = false;
          });
        }
      } catch (_) {
        if (mounted) {
          _isRendering = false;
        }
      }
    });
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_painter.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';

class WallpaperPreviewPane extends StatelessWidget {
  const WallpaperPreviewPane({
    required this.config,
    this.height,
    this.borderRadius,
    this.showSampleMessages = true,
    super.key,
  });

  final ChatWallpaperConfig config;
  final double? height;
  final BorderRadius? borderRadius;
  final bool showSampleMessages;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(24);

    final BoxDecoration bgDecoration;
    if (config.backgroundStyle == WallpaperBackgroundStyle.linearGradient) {
      final Color c1 = WallpaperColorResolver.resolveBackground(scheme, config.backgroundRole);
      final Color c2 = WallpaperColorResolver.resolveBackground(scheme, config.backgroundSecondaryRole);
      final double rad = config.gradientAngle * pi / 180.0;
      bgDecoration = BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment(cos(rad + pi), sin(rad + pi)),
          end: Alignment(cos(rad), sin(rad)),
          colors: [c1, c2],
        ),
      );
    } else if (config.backgroundStyle == WallpaperBackgroundStyle.radialGlow) {
      final Color c1 = WallpaperColorResolver.resolveBackground(scheme, config.backgroundRole);
      final Color c2 = WallpaperColorResolver.resolveBackground(scheme, config.backgroundSecondaryRole);
      bgDecoration = BoxDecoration(
        borderRadius: radius,
        gradient: RadialGradient(
          colors: [c1, c2],
          radius: 0.85,
        ),
      );
    } else {
      final Color c = WallpaperColorResolver.resolveBackground(scheme, config.backgroundRole);
      bgDecoration = BoxDecoration(
        color: c,
        borderRadius: radius,
      );
    }

    return Container(
      height: height,
      decoration: bgDecoration,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Pattern Canvas Layer
          CustomPaint(
            painter: ChatWallpaperPainter(
              config: config,
              scheme: scheme,
            ),
          ),

          // Sample Chat Messages Overlay
          if (showSampleMessages)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Incoming bubble
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Привет! Как тебе новый фон?',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Outgoing bubble
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Выглядит хорошо',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

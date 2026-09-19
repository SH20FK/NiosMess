import 'package:flutter/material.dart';

/// Material 3 Expressive edge fade for chat message viewports.
/// Uses pure tonal LinearGradients with zero live blurs or save-layers,
/// wrapped in IgnorePointer to preserve 120 FPS fluidity and scroll responsiveness.
class ChatMessageTopFade extends StatelessWidget {
  const ChatMessageTopFade({
    this.height = 44.0,
    this.top = 0.0,
    this.color,
    super.key,
  });

  final double height;
  final double top;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor = color ?? Theme.of(context).colorScheme.surface;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const <double>[0.0, 0.4, 1.0],
              colors: <Color>[
                surfaceColor.withValues(alpha: 0.90),
                surfaceColor.withValues(alpha: 0.35),
                surfaceColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dynamic bottom edge fade under the chat input composer area.
/// Extends from above the composer all the way to screen bottom (0.0),
/// creating a seamless Telegram-style floating composer experience.
class ChatMessageBottomFade extends StatelessWidget {
  const ChatMessageBottomFade({
    this.height = 136.0,
    this.bottom = 0.0,
    this.fadeOverhang = 64.0,
    this.color,
    super.key,
  });

  final double height;
  final double bottom;
  final double fadeOverhang;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor =
        color ?? Theme.of(context).colorScheme.surfaceContainerLow;

    final double safeHeight = height <= 0 ? 1.0 : height;
    final double overhangRatio =
        (fadeOverhang / safeHeight).clamp(0.12, 0.65);

    return Positioned(
      bottom: bottom,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: <double>[
                0.0,
                overhangRatio * 0.45,
                overhangRatio,
                overhangRatio + (1.0 - overhangRatio) * 0.45,
                1.0,
              ],
              colors: <Color>[
                surfaceColor.withValues(alpha: 0.0),
                surfaceColor.withValues(alpha: 0.15),
                surfaceColor.withValues(alpha: 0.65),
                surfaceColor.withValues(alpha: 0.82),
                surfaceColor.withValues(alpha: 0.94),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

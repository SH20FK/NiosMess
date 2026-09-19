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
              colors: <Color>[
                surfaceColor,
                surfaceColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom edge fade above the chat input composer area.
class ChatMessageBottomFade extends StatelessWidget {
  const ChatMessageBottomFade({
    this.height = 84.0,
    this.bottom = 0.0,
    this.color,
    super.key,
  });

  final double height;
  final double bottom;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor =
        color ?? Theme.of(context).colorScheme.surfaceContainerLow;

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
              colors: <Color>[
                surfaceColor.withValues(alpha: 0.0),
                surfaceColor,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

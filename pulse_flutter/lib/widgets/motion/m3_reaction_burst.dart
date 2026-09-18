import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Material 3 Expressive reaction particle burst effect.
///
/// Spawns lightweight orbiting particles that burst outward and fade smoothly.
/// Designed for zero save-layer overhead and 60-120 FPS performance on all tiers.
class M3ReactionBurst extends StatefulWidget {
  const M3ReactionBurst({
    required this.child,
    super.key,
    this.particleColor,
    this.particleCount = 6,
    this.burstRadius = 24.0,
    this.duration = const Duration(milliseconds: 400),
    this.onTap,
  });

  /// The interactive child (e.g. reaction emoji or like icon).
  final Widget child;

  /// Color of burst particles (defaults to `colorScheme.primary`).
  final Color? particleColor;

  /// Number of burst particles.
  final int particleCount;

  /// Maximum burst travel radius in pixels.
  final double burstRadius;

  /// Duration of the burst animation.
  final Duration duration;

  /// Optional tap callback that triggers the burst.
  final VoidCallback? onTap;

  @override
  State<M3ReactionBurst> createState() => M3ReactionBurstState();
}

class M3ReactionBurstState extends State<M3ReactionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _distanceAnimation;
  late Animation<double> _sizeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _distanceAnimation = Tween<double>(
      begin: 0.0,
      end: widget.burstRadius,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.spatial,
    ));

    _sizeAnimation = Tween<double>(
      begin: 4.0,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.expressiveDecel,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: M3SpringCurves.expressiveDecel),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Triggers the burst animation.
  void fire() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = widget.particleColor ?? scheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        fire();
        widget.onTap?.call();
      },
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          widget.child,
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? _) {
              if (!_controller.isAnimating) {
                return const SizedBox.shrink();
              }

              final double distance = _distanceAnimation.value;
              final double size = _sizeAnimation.value;
              final double opacity = _fadeAnimation.value.clamp(0.0, 1.0);

              return CustomPaint(
                painter: _BurstPainter(
                  distance: distance,
                  particleSize: size,
                  opacity: opacity,
                  count: widget.particleCount,
                  color: color,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({
    required this.distance,
    required this.particleSize,
    required this.opacity,
    required this.count,
    required this.color,
  });

  final double distance;
  final double particleSize;
  final double opacity;
  final int count;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.0 || distance <= 0.0) return;

    final Paint paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final double step = (2 * math.pi) / count;
    for (int i = 0; i < count; i++) {
      final double angle = i * step;
      final double x = math.cos(angle) * distance;
      final double y = math.sin(angle) * distance;
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) {
    return oldDelegate.distance != distance ||
        oldDelegate.particleSize != particleSize ||
        oldDelegate.opacity != opacity ||
        oldDelegate.color != color;
  }
}

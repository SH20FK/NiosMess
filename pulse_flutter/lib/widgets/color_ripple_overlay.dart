import 'dart:math' as math;
import 'package:flutter/material.dart';

class ColorRippleOverlay extends StatefulWidget {
  const ColorRippleOverlay({
    required this.child,
    required this.onColorTap,
    super.key,
  });

  final Widget child;
  final ValueChanged<Offset> onColorTap;

  @override
  State<ColorRippleOverlay> createState() => _ColorRippleOverlayState();
}

class _ColorRippleOverlayState extends State<ColorRippleOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _rippleController;
  Offset _rippleOrigin = Offset.zero;
  double _maxRadius = 0;

  void triggerRipple(Offset localPosition) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Size size = box.size;
    _maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    _rippleOrigin = localPosition;

    _rippleController?.dispose();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    widget.onColorTap(_rippleOrigin);

    _rippleController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() => _rippleController = null);
        }
      }
    });

    setState(() {});
  }

  @override
  void dispose() {
    _rippleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        widget.child,
        if (_rippleController != null)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _rippleController!,
              builder: (context, child) {
                final double t = Curves.fastLinearToSlowEaseIn.transform(_rippleController!.value);
                final double radius = _maxRadius * t;
                final double opacity = (1 - t).clamp(0, 0.6);

                return CustomPaint(
                  painter: _RipplePainter(
                    center: _rippleOrigin,
                    radius: radius,
                    t: t,
                    color: scheme.primary.withValues(alpha: opacity * 0.25),
                    accentColor: scheme.secondary.withValues(alpha: opacity * 0.15),
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter({
    required this.center,
    required this.radius,
    required this.t,
    required this.color,
    required this.accentColor,
  });

  final Offset center;
  final double radius;
  final double t;
  final Color color;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double ringCount = 3;
    final Paint paint = Paint()
      ..style = PaintingStyle.fill;

    for (int i = 0; i < ringCount; i++) {
      final double ringT = ((t * 1.2 - i * 0.3).clamp(0, 1));
      final double ringRadius = radius * (0.4 + ringT * 0.6);
      final double ringAlpha = (1 - ringT).clamp(0, 1);

      paint.color = Color.lerp(color, accentColor, i / ringCount)!.withValues(alpha: ringAlpha * 0.5);
      canvas.drawCircle(center, ringRadius, paint);

      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = (1 - ringT) * 6;
      paint.color = Color.lerp(color, accentColor, i / ringCount)!.withValues(alpha: ringAlpha * 0.7);
      canvas.drawCircle(center, ringRadius + 8, paint);
      paint.style = PaintingStyle.fill;
    }

    paint.style = PaintingStyle.fill;
    final double fillT = (t * 2).clamp(0, 1);
    paint.color = color.withValues(alpha: fillT * 0.3);
    canvas.drawCircle(center, radius * 0.15 * fillT, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      center != old.center || radius != old.radius || t != old.t;
}

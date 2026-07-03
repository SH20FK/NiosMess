import 'dart:math' as math;
import 'package:flutter/material.dart';

class BoltSparkPainter extends CustomPainter {
  BoltSparkPainter(this.scheme, this.progress);

  final ColorScheme scheme;
  final double progress;

  // Static glow paint — reuse, no blur per frame
  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final Path boltPath = Path()
      ..moveTo(cx + 2, cy - 22)
      ..lineTo(cx - 10, cy - 4)
      ..lineTo(cx - 2, cy - 4)
      ..lineTo(cx - 8, cy + 18)
      ..lineTo(cx + 12, cy - 4)
      ..lineTo(cx + 2, cy - 4)
      ..close();

    // Subtle static glow under the bolt (no per-frame blur allocation)
    _glowPaint.color = scheme.tertiary.withValues(alpha: 0.18);
    canvas.drawPath(boltPath, _glowPaint);

    // Bolt body — shimmer via color alpha only (cheap)
    final double shimmer = (math.sin(progress * math.pi * 4) + 1) / 2;
    final Paint bolt = Paint()
      ..color = Color.lerp(
        scheme.primary,
        scheme.tertiary,
        shimmer * 0.4,
      )!
      ..style = PaintingStyle.fill;
    canvas.drawPath(boltPath, bolt);

    // Orbiting sparks
    final Paint spark = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final double angle = progress * math.pi * 2 + i * 0.785;
      final double dist = 24 + math.sin(angle * 3 + i) * 10;
      final double radius =
          (1.5 + math.sin(progress * math.pi * 2 + i * 1.3)).clamp(1.0, 3.0);
      final double alpha = (math.sin(angle * 2 + i) + 1) / 2 * 0.7;

      final double sx = cx + math.cos(angle) * dist;
      final double sy = cy + math.sin(angle) * dist;
      spark.color = scheme.tertiary.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), radius, spark);
    }
  }

  @override
  bool shouldRepaint(BoltSparkPainter old) =>
      scheme != old.scheme || progress != old.progress;
}

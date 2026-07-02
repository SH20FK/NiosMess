import 'dart:math' as math;
import 'package:flutter/material.dart';

class BoltSparkPainter extends CustomPainter {
  BoltSparkPainter(this.scheme, this.progress);

  final ColorScheme scheme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final Paint bolt = Paint()
      ..color = scheme.primary
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final Path boltPath = Path()
      ..moveTo(cx + 2, cy - 22)
      ..lineTo(cx - 10, cy - 4)
      ..lineTo(cx - 2, cy - 4)
      ..lineTo(cx - 8, cy + 18)
      ..lineTo(cx + 12, cy - 4)
      ..lineTo(cx + 2, cy - 4)
      ..close();

    canvas.drawPath(boltPath, bolt);

    final double shimmer = (math.sin(progress * math.pi * 4) + 1) / 2;
    final Paint glow = Paint()
      ..color = scheme.tertiary.withValues(alpha: shimmer * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(boltPath, glow);

    final Paint spark = Paint()
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final double angle = progress * math.pi * 2 + i * 0.785;
      final double dist = 24 + math.sin(angle * 3 + i) * 10;
      final double size = 1.5 + math.sin(progress * math.pi * 2 + i * 1.3) * 1;
      final double alpha = (math.sin(angle * 2 + i) + 1) / 2 * 0.7;

      final double sx = cx + math.cos(angle) * dist;
      final double sy = cy + math.sin(angle) * dist;
      spark.color = scheme.tertiary.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), size.clamp(1.0, 3.0), spark);
    }
  }

  @override
  bool shouldRepaint(BoltSparkPainter old) =>
      scheme != old.scheme || progress != old.progress;
}

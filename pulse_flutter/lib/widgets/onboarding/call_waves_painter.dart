import 'dart:math' as math;
import 'package:flutter/material.dart';

class CallWavesPainter extends CustomPainter {
  CallWavesPainter(this.scheme, this.progress);

  final ColorScheme scheme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final Paint phone = Paint()
      ..color = scheme.onPrimaryContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final Path phonePath = Path()
      ..moveTo(cx - 14, cy + 2)
      ..lineTo(cx - 14, cy - 12)
      ..quadraticBezierTo(cx - 14, cy - 20, cx - 4, cy - 20)
      ..lineTo(cx + 4, cy - 20)
      ..quadraticBezierTo(cx + 14, cy - 20, cx + 14, cy - 12)
      ..lineTo(cx + 14, cy + 2)
      ..quadraticBezierTo(cx + 14, cy + 10, cx + 4, cy + 10)
      ..lineTo(cx - 4, cy + 10)
      ..quadraticBezierTo(cx - 14, cy + 10, cx - 14, cy + 2)
      ..close();
    canvas.drawPath(phonePath, phone);

    final Paint wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final double phase = (progress + i * 0.33) % 1.0;
      final double radius = 18 + phase * 30;
      final double alpha = (1.0 - phase).clamp(0.0, 0.6);

      wave
        ..color = scheme.primary.withValues(alpha: alpha)
        ..strokeWidth = 2.0 - phase * 1.5;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx + 18, cy - 5), radius: radius),
        -0.5,
        math.pi * 0.8,
        false,
        wave,
      );

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx - 18, cy - 5), radius: radius),
        math.pi * 1.2,
        math.pi * 0.8,
        false,
        wave,
      );
    }
  }

  @override
  bool shouldRepaint(CallWavesPainter old) =>
      scheme != old.scheme || progress != old.progress;
}

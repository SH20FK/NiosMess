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

    // Phone body — centered slightly above middle
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

    // Waves start from edge of phone (~14px) and expand outward
    // 3 waves staggered so there's always at least one visible
    final Paint wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final double phase = (progress + i / 3.0) % 1.0;
      // radius goes from 16 (just outside phone) to 46
      final double radius = 16 + phase * 30;
      // full opacity when small, fade as it expands
      final double alpha = (1.0 - phase).clamp(0.0, 1.0);
      final double strokeWidth = 2.5 - phase * 1.8;

      wave
        ..color = scheme.primary.withValues(alpha: alpha * 0.7)
        ..strokeWidth = strokeWidth.clamp(0.3, 2.5);

      // Right arc — from phone right edge
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx + 14, cy - 5), radius: radius),
        -math.pi * 0.5,
        math.pi * 0.7,
        false,
        wave,
      );
      // Left arc — from phone left edge
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx - 14, cy - 5), radius: radius),
        math.pi * 0.8,
        math.pi * 0.7,
        false,
        wave,
      );
    }
  }

  @override
  bool shouldRepaint(CallWavesPainter old) =>
      scheme != old.scheme || progress != old.progress;
}

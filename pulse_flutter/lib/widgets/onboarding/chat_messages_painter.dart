import 'dart:math' as math;
import 'package:flutter/material.dart';

class ChatMessagesPainter extends CustomPainter {
  ChatMessagesPainter(this.scheme, this.progress);

  final ColorScheme scheme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    double bubblePhase(double offset) => ((progress + offset) % 1.0);
    double easeOutBack(double t) {
      const double c1 = 1.70158;
      const double c3 = c1 + 1;
      return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
    }

    void drawBubble(double x, double y, double w, double h, Color color) {
      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - w / 2, y - h / 2, w, h),
        const Radius.circular(12),
      );
      canvas.drawRRect(rrect, Paint()..color = color);
    }

    final double b1 = bubblePhase(0.0);
    final double b2 = bubblePhase(0.45);
    final double b3 = bubblePhase(0.75);

    if (b1 < 0.7) {
      final double s = easeOutBack((b1 / 0.7).clamp(0.0, 1.0));
      drawBubble(
        cx - 20,
        cy - 4,
        28 * s,
        16 * s,
        scheme.primaryContainer.withValues(alpha: 0.9),
      );
    }

    if (b2 < 0.7) {
      final double s = easeOutBack((b2 / 0.7).clamp(0.0, 1.0));
      drawBubble(
        cx + 16,
        cy + 8,
        24 * s,
        14 * s,
        scheme.secondaryContainer.withValues(alpha: 0.9),
      );
    }

    if (b3 < 0.7) {
      final double s = easeOutBack((b3 / 0.7).clamp(0.0, 1.0));
      drawBubble(
        cx - 8,
        cy + 16,
        34 * s,
        16 * s,
        scheme.primaryContainer.withValues(alpha: 0.9),
      );
    }

    final Paint ellipsis = Paint()
      ..color = scheme.onPrimaryContainer.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final double dotPhase = progress * 3 % 1.0;
    for (int i = 0; i < 3; i++) {
      final double da = ((dotPhase - i * 0.2) % 1.0).clamp(0.0, 1.0);
      final double alpha = da < 0.3 ? da / 0.3 : 1.0;
      ellipsis.color = scheme.onPrimaryContainer.withValues(alpha: alpha * 0.6);
      canvas.drawCircle(Offset(cx + 10 + i * 8.0, cy - 10), 2.5, ellipsis);
    }
  }

  @override
  bool shouldRepaint(ChatMessagesPainter old) =>
      scheme != old.scheme || progress != old.progress;
}

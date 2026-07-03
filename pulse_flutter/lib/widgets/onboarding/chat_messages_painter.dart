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

    // Easing with slight overshoot on pop-in
    double easeOutBack(double t) {
      const double c1 = 1.70158;
      const double c3 = c1 + 1;
      return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
    }

    // Each bubble has a full cycle: 0..0.6 = scale in, 0.6..0.85 = hold, 0.85..1.0 = fade out
    double bubbleScale(double phase) {
      if (phase < 0.6) return easeOutBack((phase / 0.6).clamp(0.0, 1.0));
      return 1.0;
    }

    double bubbleAlpha(double phase) {
      if (phase < 0.6) return 1.0;
      if (phase < 0.85) return 1.0;
      // Smooth fade out in last 15% of cycle
      return 1.0 - ((phase - 0.85) / 0.15).clamp(0.0, 1.0);
    }

    void drawBubble(
      double x,
      double y,
      double w,
      double h,
      Color color,
      double phase,
    ) {
      final double s = bubbleScale(phase);
      final double a = bubbleAlpha(phase);
      if (a <= 0 || s <= 0) return;
      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - (w * s) / 2, y - (h * s) / 2, w * s, h * s),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = color.withValues(alpha: color.a * a),
      );
    }

    // Stagger bubbles evenly across the cycle
    final double b1 = (progress + 0.00) % 1.0;
    final double b2 = (progress + 0.33) % 1.0;
    final double b3 = (progress + 0.66) % 1.0;

    drawBubble(
      cx - 20, cy - 4, 28, 16,
      scheme.primaryContainer.withValues(alpha: 0.9), b1,
    );
    drawBubble(
      cx + 16, cy + 8, 24, 14,
      scheme.secondaryContainer.withValues(alpha: 0.9), b2,
    );
    drawBubble(
      cx - 8, cy + 16, 34, 16,
      scheme.primaryContainer.withValues(alpha: 0.9), b3,
    );

    // Typing dots — always visible, sequential fade
    final double dotPhase = progress * 3 % 1.0;
    for (int i = 0; i < 3; i++) {
      final double da = ((dotPhase - i * 0.2) % 1.0).clamp(0.0, 1.0);
      final double alpha = da < 0.3 ? da / 0.3 : da > 0.7 ? 1.0 - (da - 0.7) / 0.3 : 1.0;
      canvas.drawCircle(
        Offset(cx + 10 + i * 8.0, cy - 10),
        2.5,
        Paint()..color = scheme.onPrimaryContainer.withValues(alpha: alpha * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(ChatMessagesPainter old) =>
      scheme != old.scheme || progress != old.progress;
}

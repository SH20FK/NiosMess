import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';

class CallAudioRipple extends StatelessWidget {
  const CallAudioRipple({
    super.key,
    required this.animation,
    required this.scheme,
    required this.isActive,
    required this.child,
    this.size = CallTokens.avatarLargeSize,
  });

  final Animation<double> animation;
  final ColorScheme scheme;
  final bool isActive;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2.5,
      height: size * 2.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isActive)
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _AudioRipplePainter(
                        progress: animation.value,
                        primaryColor: scheme.primary,
                        tertiaryColor: scheme.tertiary,
                      ),
                    );
                  },
                ),
              ),
            ),
          Center(
            child: SizedBox(
              width: size,
              height: size,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioRipplePainter extends CustomPainter {
  _AudioRipplePainter({
    required this.progress,
    required this.primaryColor,
    required this.tertiaryColor,
  });

  final double progress;
  final Color primaryColor;
  final Color tertiaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;
    const baseRadius = CallTokens.avatarLargeSize * 0.52;

    const ringCount = 3;
    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress + (i / ringCount)) % 1.0;
      final currentRadius = baseRadius + (maxRadius - baseRadius) * ringProgress;
      
      // Easing alpha out
      final alpha = (sin(ringProgress * pi)).clamp(0.0, 1.0) * 0.28 * (1.0 - ringProgress * 0.4);
      final ringColor = Color.lerp(primaryColor, tertiaryColor, (i / ringCount))!
          .withValues(alpha: alpha);

      final paint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1.0 - ringProgress * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      canvas.drawCircle(center, currentRadius, paint);

      // Soft glow fill inside first ring
      if (i == 0) {
        final fillPaint = Paint()
          ..color = primaryColor.withValues(alpha: alpha * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
        canvas.drawCircle(center, currentRadius * 0.85, fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_AudioRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.tertiaryColor != tertiaryColor;
  }
}

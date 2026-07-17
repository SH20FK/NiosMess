import 'dart:math' as math;
import 'package:flutter/material.dart';

class Md3SquiggleProgress extends StatefulWidget {
  const Md3SquiggleProgress({
    required this.progress,
    required this.color,
    this.strokeWidth = 3.0,
    this.isCircular = false,
    super.key,
  });

  final double progress;
  final Color color;
  final double strokeWidth;
  final bool isCircular;

  @override
  State<Md3SquiggleProgress> createState() => _Md3SquiggleProgressState();
}

class _Md3SquiggleProgressState extends State<Md3SquiggleProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phaseController;

  @override
  void initState() {
    super.initState();
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _phaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _phaseController,
      builder: (context, child) {
        return CustomPaint(
          painter: _SquigglePainter(
            progress: widget.progress,
            phase: _phaseController.value * 2 * math.pi,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            isCircular: widget.isCircular,
          ),
        );
      },
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter({
    required this.progress,
    required this.phase,
    required this.color,
    required this.strokeWidth,
    required this.isCircular,
  });

  final double progress;
  final double phase;
  final Color color;
  final double strokeWidth;
  final bool isCircular;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (isCircular) {
      _paintCircular(canvas, size, paint);
    } else {
      _paintLinear(canvas, size, paint);
    }
  }

  void _paintLinear(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final double midY = size.height / 2;
    final double length = size.width;
    
    // As progress approaches 1.0, the amplitude of the squiggle goes to 0 (flattens out)
    final double amplitude = 6.0 * (1.0 - progress); 
    const double wavelength = 32.0;

    path.moveTo(0, midY);
    for (double x = 0.0; x <= length; x += 1.0) {
      final double angle = (x / wavelength) * 2 * math.pi + phase;
      final double y = midY + math.sin(angle) * amplitude;
      path.lineTo(x, y);
    }

    // Draw background track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, trackPaint);

    // Draw active progress path
    final activePath = Path();
    final double activeLength = length * progress;
    activePath.moveTo(0, midY);
    for (double x = 0.0; x <= activeLength; x += 1.0) {
      final double angle = (x / wavelength) * 2 * math.pi + phase;
      final double y = midY + math.sin(angle) * amplitude;
      activePath.lineTo(x, y);
    }
    canvas.drawPath(activePath, paint);
  }

  void _paintCircular(Canvas canvas, Size size, Paint paint) {
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    // Amplitude is modulated by time/progress and disappears at 1.0
    final double amplitude = 4.0 * (1.0 - progress);
    const int segments = 120;

    for (int i = 0; i <= segments; i++) {
      final double angle = (i / segments) * 2 * math.pi;
      // Add squiggle offset
      final double squiggleAngle = angle * 8 + phase;
      final double currentRadius = radius + math.sin(squiggleAngle) * amplitude;

      final double x = center.dx + math.cos(angle) * currentRadius;
      final double y = center.dy + math.sin(angle) * currentRadius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, trackPaint);

    // PathMetrics to draw progress portion
    final metrics = path.computeMetrics().firstOrNull;
    if (metrics != null) {
      final extract = metrics.extractPath(0.0, metrics.length * progress);
      canvas.drawPath(extract, paint);
    }
  }

  @override
  bool shouldRepaint(_SquigglePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.phase != phase;
  }
}

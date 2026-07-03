import 'dart:math' as math;
import 'package:flutter/material.dart';

class EmptyFeedWidget extends StatefulWidget {
  const EmptyFeedWidget({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<EmptyFeedWidget> createState() => _EmptyFeedWidgetState();
}

class _EmptyFeedWidgetState extends State<EmptyFeedWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _floatController,
                  builder: (_, Widget? child) {
                    return Transform.translate(
                      offset: Offset(0, _floatController.value * -8),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CustomPaint(
                        size: const Size(140, 140),
                        painter: _EmptyFeedPainter(scheme: scheme),
                      ),
                      _Sparkles(scheme: scheme),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                widget.description,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: widget.onAction,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(widget.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFeedPainter extends CustomPainter {
  _EmptyFeedPainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final Paint outerCircle = Paint()
      ..color = scheme.primaryContainer.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 52, outerCircle);

    final Paint innerCircle = Paint()
      ..color = scheme.primaryContainer.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 36, innerCircle);

    final Paint pen = Paint()
      ..color = scheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final Path penPath = Path()
      ..moveTo(cx - 14, cy - 2)
      ..quadraticBezierTo(cx - 2, cy - 10, cx + 10, cy - 8)
      ..moveTo(cx - 6, cy + 4)
      ..quadraticBezierTo(cx, cy + 14, cx + 12, cy + 6);

    canvas.drawPath(penPath, pen);

    final Paint dot = Paint()
      ..color = scheme.primary
      ..style = PaintingStyle.fill;
    for (final Offset p in <Offset>[
      Offset(cx - 13, cy - 10),
      Offset(cx + 6, cy - 14),
      Offset(cx + 16, cy - 6),
      Offset(cx - 16, cy + 4),
      Offset(cx, cy + 14),
    ]) {
      canvas.drawCircle(p, 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(_EmptyFeedPainter old) => scheme != old.scheme;
}

class _Sparkles extends StatefulWidget {
  const _Sparkles({required this.scheme});

  final ColorScheme scheme;

  @override
  State<_Sparkles> createState() => _SparklesState();
}

class _SparklesState extends State<_Sparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _sparkleController,
        builder: (_, __) {
          return CustomPaint(
            painter: _SparklePainter(
              t: _sparkleController.value,
              scheme: widget.scheme,
            ),
          );
        },
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.t, required this.scheme});

  final double t;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final Paint sparkle = Paint()
      ..color = scheme.tertiary.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final double angle = t * 2 * math.pi;
    for (int i = 0; i < 5; i++) {
      final double a = angle + i * 1.256;
      final double r = 62 + math.sin(a * 2) * 8;
      final double sx = cx + math.cos(a) * r;
      final double sy = cy + math.sin(a) * r;
      final double s = 1.5 + math.sin(a * 3) * 1.0;
      canvas.drawCircle(Offset(sx, sy), s.clamp(1.0, 3.0), sparkle);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => t != old.t || scheme != old.scheme;
}

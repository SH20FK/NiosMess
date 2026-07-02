import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
              AnimatedBuilder(
                animation: _floatController,
                builder: (_, Widget? child) {
                  return Transform.translate(
                    offset: Offset(0, _floatController.value * -8),
                    child: child,
                  );
                },
                child: CustomPaint(
                  size: const Size(140, 140),
                  painter: _EmptyFeedPainter(scheme: scheme),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 10),
              Text(
                widget.description,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: widget.onAction,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(widget.actionLabel!),
                )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 200.ms)
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
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

    final Paint sparkle = Paint()
      ..color = scheme.tertiary.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final double t = DateTime.now().millisecondsSinceEpoch / 1000;
    for (int i = 0; i < 5; i++) {
      final double angle = t + i * 1.256;
      final double r = 62 + math.sin(angle * 2) * 8;
      final double sx = cx + math.cos(angle) * r;
      final double sy = cy + math.sin(angle) * r;
      final double s = 1.5 + math.sin(angle * 3) * 1.0;
      canvas.drawCircle(Offset(sx, sy), s.clamp(1.0, 3.0), sparkle);
    }
  }

  @override
  bool shouldRepaint(_EmptyFeedPainter old) => scheme != old.scheme;
}

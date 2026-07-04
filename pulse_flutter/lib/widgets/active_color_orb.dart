import 'dart:math' as math;
import 'package:flutter/material.dart';

class ActiveColorOrb extends StatefulWidget {
  const ActiveColorOrb({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<ActiveColorOrb> createState() => _ActiveColorOrbState();
}

class _ActiveColorOrbState extends State<ActiveColorOrb>
    with TickerProviderStateMixin {
  late final AnimationController _lavaController;
  late final AnimationController _pulseController;
  late Color _seedPrimary;
  bool _isActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool active = TickerMode.of(context);
    if (active != _isActive) {
      _isActive = active;
      if (active) {
        _lavaController.repeat();
      } else {
        _lavaController.stop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _lavaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    final Brightness brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _seedPrimary = ColorScheme.fromSeed(
      seedColor: widget.color,
      brightness: brightness,
    ).primary;
  }

  @override
  void didUpdateWidget(ActiveColorOrb old) {
    super.didUpdateWidget(old);
    if (widget.color != old.color) {
      final Brightness brightness = Theme.of(context).colorScheme.brightness;
      _seedPrimary = ColorScheme.fromSeed(
        seedColor: widget.color,
        brightness: brightness,
      ).primary;
    }
    if (widget.selected && !old.selected) {
      _pulseController.forward(from: 0);
    } else if (!widget.selected && old.selected) {
      _pulseController.reverse();
    }
  }

  @override
  void dispose() {
    _lavaController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color seedSchemePrimary = _seedPrimary;

    return GestureDetector(
      onTap: widget.onTap,
      child: RepaintBoundary(
        child: AnimatedBuilder(
        animation: Listenable.merge([_lavaController, _pulseController]),
        builder: (BuildContext context, Widget? child) {
          final double pulse = _pulseController.value;
          final double lava = _lavaController.value * 2 * math.pi;

          final double orbSize = 44 + (widget.selected ? pulse * 4 : 0);

          return Container(
            width: orbSize,
            height: orbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: widget.selected
                  ? Border.all(
                      color: scheme.primary,
                      width: 2.5 * (1 + pulse * 0.3),
                    )
                  : null,
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3 + pulse * 0.2),
                        blurRadius: 8 + pulse * 6,
                        spreadRadius: 1 + pulse * 2,
                      ),
                    ]
                  : null,
            ),
            padding: EdgeInsets.all(3.5),
            child: CustomPaint(
              painter: _LavaLampPainter(
                color1: seedSchemePrimary,
                color2: widget.color,
                t: lava,
                selected: widget.selected,
              ),
              child: const SizedBox.expand(),
            ),
            );
          },
        ),
      ),
    );
  }
}

class _LavaLampPainter extends CustomPainter {
  const _LavaLampPainter({
    required this.color1,
    required this.color2,
    required this.t,
    required this.selected,
  });

  final Color color1;
  final Color color2;
  final double t;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double radius = size.width / 2;
    final Offset center = rect.center;

    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    final Paint leftPaint = Paint()..color = color1;
    final Paint rightPaint = Paint()..color = color2;

    final double wave = math.sin(t) * 0.12;

    final Path leftPath = Path();
    final Path rightPath = Path();

    leftPath.moveTo(center.dx * (1 + wave), 0);
    leftPath.lineTo(0, 0);
    leftPath.lineTo(0, size.height);
    leftPath.lineTo(center.dx * (1 + wave), size.height);

    rightPath.moveTo(center.dx * (1 + wave), 0);
    rightPath.lineTo(size.width, 0);
    rightPath.lineTo(size.width, size.height);
    rightPath.lineTo(center.dx * (1 + wave), size.height);

    for (double y = 0; y <= size.height; y += 4) {
      final double localWave = math.sin(t * 1.3 + y * 0.05) * 4;
      final double x = center.dx * (1 + wave) + localWave;
      leftPath.lineTo(x.clamp(0, center.dx * 2), y);
      rightPath.lineTo(x.clamp(0, center.dx * 2), y);
    }

    canvas.drawPath(leftPath, leftPaint);
    canvas.drawPath(rightPath, rightPaint);

    if (selected) {
      final Paint borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (int i = 0; i < 8; i++) {
        final double phase = t + i * 0.8;
        final double alpha = (math.sin(phase) * 0.5 + 0.5) * 0.5;
        borderPaint.color = color1.withValues(alpha: alpha);
        canvas.drawCircle(
          center,
          radius - 2 - i * 0.5,
          borderPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LavaLampPainter old) =>
      t != old.t || color1 != old.color1 || color2 != old.color2 || selected != old.selected;
}

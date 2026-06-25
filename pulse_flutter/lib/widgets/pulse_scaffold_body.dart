import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class PulseScaffoldBody extends StatelessWidget {
  const PulseScaffoldBody({
    required this.child,
    this.maxWidth = 1280,
    this.topSafe = false,
    this.bottomSafe = true,
    this.bottomPadding = 0,
    this.animatedBackdrop = true,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final bool topSafe;
  final bool bottomSafe;
  final double bottomPadding;
  final bool animatedBackdrop;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.macOS ||
           defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _PulseBackdrop(animated: _isDesktop ? false : animatedBackdrop)),
        SafeArea(
          top: topSafe,
          bottom: bottomSafe,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth < maxWidth
                  ? constraints.maxWidth
                  : maxWidth;
              final double height = constraints.maxHeight - bottomPadding;

              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  height: height > 0 ? height : 0,
                  child: child,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PulseBackdrop extends ConsumerStatefulWidget {
  const _PulseBackdrop({required this.animated});

  final bool animated;

  @override
  ConsumerState<_PulseBackdrop> createState() => _PulseBackdropState();
}

class _PulseBackdropState extends ConsumerState<_PulseBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 80),
    );
    if (widget.animated) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Brightness brightness = Theme.of(context).brightness;
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool optimize = settings.optimizeForWeakDevices;

    final bool shouldAnimate = widget.animated && !optimize;

    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
        _controller.value = 0.5;
      }
    }

    if (!shouldAnimate) {
      return RepaintBoundary(
        child: CustomPaint(
          painter: _BackdropPainter(
            t: 0.5,
            scheme: scheme,
            brightness: brightness,
          ),
          size: Size.infinite,
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: _BackdropPainter(
              t: _controller.value,
              scheme: scheme,
              brightness: brightness,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.t,
    required this.scheme,
    required this.brightness,
  });

  final double t;
  final ColorScheme scheme;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final Rect rect = Offset.zero & size;
    final Gradient gradient = AppTheme.heroGradient(scheme);
    final Paint gradientPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, gradientPaint);

    final double tw = t * math.pi * 2;

    final Color primaryShape = scheme.primary.withValues(alpha: 0.15);
    final Color secondaryShape = scheme.secondary.withValues(alpha: 0.15);
    final Color tertiaryShape = scheme.tertiary.withValues(alpha: 0.15);

    _drawPolygon(
      canvas,
      size,
      alignmentX: -1.02 + (math.sin(tw) * 0.06),
      alignmentY: -0.84 + (math.cos(tw * 0.7) * 0.04),
      angle: -0.18 + (math.sin(tw * 0.45) * 0.05),
      polygonSize: 280,
      sides: 6,
      cornerRadius: 28,
      color: primaryShape,
    );

    _drawPolygon(
      canvas,
      size,
      alignmentX: 1.08 + (math.cos(tw * 0.8) * 0.05),
      alignmentY: -0.10 + (math.sin(tw * 0.6) * 0.05),
      angle: 0.24 + (math.cos(tw * 0.5) * 0.04),
      polygonSize: 220,
      sides: 5,
      cornerRadius: 24,
      color: secondaryShape,
    );

    _drawPolygon(
      canvas,
      size,
      alignmentX: 0.72 + (math.sin(tw * 0.5) * 0.04),
      alignmentY: 0.95 + (math.cos(tw * 0.9) * 0.03),
      angle: -0.12 + (math.sin(tw * 0.55) * 0.03),
      polygonSize: 180,
      sides: 7,
      cornerRadius: 22,
      color: tertiaryShape,
    );
  }

  void _drawPolygon(
    Canvas canvas,
    Size canvasSize, {
    required double alignmentX,
    required double alignmentY,
    required double angle,
    required double polygonSize,
    required int sides,
    required double cornerRadius,
    required Color color,
  }) {
    final double cx = (alignmentX + 1) / 2 * canvasSize.width;
    final double cy = (alignmentY + 1) / 2 * canvasSize.height;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    final Path path = _roundedPolygonPath(polygonSize, sides, cornerRadius);

    final Rect pathBounds = Rect.fromCenter(
      center: Offset.zero,
      width: polygonSize,
      height: polygonSize,
    );
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          color,
          color.withValues(alpha: color.a * 0.68),
        ],
      ).createShader(pathBounds);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  Path _roundedPolygonPath(double size, int sides, double radius) {
    final int safeSides = sides < 3 ? 3 : sides;
    final double polygonRadius = size / 2;
    final List<Offset> vertices = List<Offset>.generate(safeSides, (int index) {
      final double angle = (-math.pi / 2) + ((2 * math.pi * index) / safeSides);
      return Offset(
        polygonRadius * math.cos(angle),
        polygonRadius * math.sin(angle),
      );
    });

    final Path path = Path();
    for (int index = 0; index < vertices.length; index++) {
      final Offset previous =
          vertices[(index - 1 + vertices.length) % vertices.length];
      final Offset current = vertices[index];
      final Offset next = vertices[(index + 1) % vertices.length];

      final Offset toPrevious = previous - current;
      final Offset toNext = next - current;
      final double effectiveRadius = math.min(
        radius,
        math.min(toPrevious.distance, toNext.distance) / 2,
      );

      final Offset start = current + (_normalize(toPrevious) * effectiveRadius);
      final Offset end = current + (_normalize(toNext) * effectiveRadius);

      if (index == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }

      path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
    }

    path.close();
    return path;
  }

  Offset _normalize(Offset offset) {
    if (offset.distance == 0) return Offset.zero;
    return Offset(offset.dx / offset.distance, offset.dy / offset.distance);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) {
    return t != oldDelegate.t ||
        scheme != oldDelegate.scheme ||
        brightness != oldDelegate.brightness;
  }
}

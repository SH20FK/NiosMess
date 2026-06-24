import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nios_admin_flutter/core/theme/admin_theme.dart';

class AdminScaffoldBody extends StatelessWidget {
  const AdminScaffoldBody({
    required this.child,
    this.maxWidth = 1480,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _AdminBackdrop()),
        SafeArea(
          child: Padding(
            padding: padding,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth < maxWidth
                    ? constraints.maxWidth
                    : maxWidth;
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: width, child: child),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminBackdrop extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _AdminBackdropPainter(scheme),
      size: Size.infinite,
    );
  }
}

class _AdminBackdropPainter extends CustomPainter {
  _AdminBackdropPainter(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = AdminTheme.backdropGradient(
          scheme,
        ).createShader(Offset.zero & size),
    );

    final Paint primary = Paint()
      ..color = scheme.primary.withValues(alpha: 0.10);
    final Paint tertiary = Paint()
      ..color = scheme.tertiary.withValues(alpha: 0.08);
    final Paint secondary = Paint()
      ..color = scheme.secondary.withValues(alpha: 0.08);

    canvas.drawPath(
      _roundedPolygon(
        center: Offset(size.width * 0.08, size.height * 0.08),
        radius: 180,
        sides: 6,
      ),
      primary,
    );
    canvas.drawPath(
      _roundedPolygon(
        center: Offset(size.width * 0.92, size.height * 0.86),
        radius: 150,
        sides: 5,
      ),
      tertiary,
    );
    canvas.drawPath(
      _roundedPolygon(
        center: Offset(size.width * 0.78, size.height * 0.22),
        radius: 110,
        sides: 7,
      ),
      secondary,
    );
  }

  Path _roundedPolygon({
    required Offset center,
    required double radius,
    required int sides,
  }) {
    final List<Offset> vertices = List<Offset>.generate(sides, (int index) {
      final double angle = (-math.pi / 2) + ((2 * math.pi * index) / sides);
      return Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
    });

    final Path path = Path();
    const double cornerRadius = 22;
    for (int i = 0; i < vertices.length; i++) {
      final Offset prev = vertices[(i - 1 + vertices.length) % vertices.length];
      final Offset current = vertices[i];
      final Offset next = vertices[(i + 1) % vertices.length];

      final Offset toPrev = prev - current;
      final Offset toNext = next - current;
      final Offset start = current + _normalize(toPrev) * cornerRadius;
      final Offset end = current + _normalize(toNext) * cornerRadius;

      if (i == 0) {
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
    final double distance = offset.distance;
    if (distance == 0) return Offset.zero;
    return Offset(offset.dx / distance, offset.dy / distance);
  }

  @override
  bool shouldRepaint(covariant _AdminBackdropPainter oldDelegate) {
    return oldDelegate.scheme != scheme;
  }
}

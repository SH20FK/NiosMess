import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

const int _kSamples = 180;

final List<Offset> _kUnit = List<Offset>.generate(
  _kSamples,
  (int i) {
    final double a = (i / _kSamples) * 2 * math.pi;
    return Offset(math.cos(a), math.sin(a));
  },
  growable: false,
);

List<double> _scallop({required int lobes, required double depth}) =>
    List<double>.generate(
      _kSamples,
      (int i) => 1.0 - depth * math.cos(lobes * (i / _kSamples) * 2 * math.pi),
      growable: false,
    );

List<double> _polygon(int sides) {
  final double half = math.pi / sides;
  return List<double>.generate(
    _kSamples,
    (int i) {
      final double a = (i / _kSamples) * 2 * math.pi;
      return math.cos(half) / math.cos((a % (2 * half)) - half);
    },
    growable: false,
  );
}

/// Profile representation of an expressive brand shape.
class BrandShape {
  const BrandShape(this.radii, this.spin);

  /// 180 precomputed radial distance samples.
  final List<double> radii;

  /// Rotational spin in radians.
  final double spin;
}

/// The 5 official brand shape profiles.
final List<BrandShape> kBrandShapes = <BrandShape>[
  BrandShape(_scallop(lobes: 9, depth: 0.075), 0.00), // cookie
  BrandShape(_polygon(6), 0.26), // gem
  BrandShape(_scallop(lobes: 6, depth: 0.170), 0.52), // flower
  BrandShape(_scallop(lobes: 12, depth: 0.110), 0.78), // sunny
  BrandShape(_scallop(lobes: 16, depth: 0.150), 1.04), // burst
];

class _MorphPainter extends CustomPainter {
  _MorphPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.color,
  });

  final BrandShape from;
  final BrandShape to;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.shortestSide / 2;
    final Path path = Path();
    for (int i = 0; i < _kSamples; i++) {
      final double k =
          (from.radii[i] + (to.radii[i] - from.radii[i]) * t) * r;
      final Offset p = _kUnit[i] * k;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(from.spin + (to.spin - from.spin) * t);
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MorphPainter old) =>
      old.t != t || old.from != from || old.to != to || old.color != color;
}

/// Interactive M3 Expressive morphing brand mark with bouncy spring dynamics.
class MorphingBrandMark extends StatefulWidget {
  const MorphingBrandMark({
    super.key,
    this.size = 84,
    this.onEasterEgg,
  });

  final double size;
  final VoidCallback? onEasterEgg;

  @override
  State<MorphingBrandMark> createState() => _MorphingBrandMarkState();
}

class _MorphingBrandMarkState extends State<MorphingBrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: M3Durations.long2,
  );
  late final Animation<double> _shape = CurvedAnimation(
    parent: _ctrl,
    curve: M3SpringCurves.bouncy,
  );

  int _prev = 0;
  int _curr = 0;
  int _taps = 0;

  void _next() {
    if (_ctrl.isAnimating) return;
    HapticService.selection();
    setState(() {
      _prev = _curr;
      _curr = (_curr + 1) % kBrandShapes.length;
    });
    _ctrl.forward(from: 0);
    _taps++;
    if (_taps >= 5) {
      _taps = 0;
      widget.onEasterEgg?.call();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: context.l10n.appName,
      child: GestureDetector(
        onTap: _next,
        behavior: HitTestBehavior.opaque,
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: _shape,
              child: Center(
                child: SvgPicture.asset(
                  'assets/svg/niosmess_logo_tintable.svg',
                  width: widget.size * 0.52,
                  height: widget.size * 0.52,
                  colorFilter: ColorFilter.mode(
                    scheme.onPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              builder: (BuildContext context, Widget? child) => CustomPaint(
                painter: _MorphPainter(
                  from: kBrandShapes[_prev],
                  to: kBrandShapes[_curr],
                  t: _shape.value.clamp(0.0, 1.0),
                  color: scheme.primary,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Static container rendering a brand shape without animation.
class StaticBrandShapeContainer extends StatelessWidget {
  const StaticBrandShapeContainer({
    super.key,
    required this.shape,
    required this.color,
    required this.size,
    required this.child,
  });

  final BrandShape shape;
  final Color color;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MorphPainter(
          from: shape,
          to: shape,
          t: 0.0,
          color: color,
        ),
        child: Center(child: child),
      ),
    );
  }
}

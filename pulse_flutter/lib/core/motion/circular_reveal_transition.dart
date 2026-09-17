import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Clipper that reveals content via an expanding circle originating from [center].
class CircularRevealClipper extends CustomClipper<Path> {
  const CircularRevealClipper({
    required this.fraction,
    required this.center,
  });

  final double fraction;
  final Offset center;

  @override
  Path getClip(Size size) {
    final double clampedFraction = fraction.clamp(0.0, 1.0);
    if (clampedFraction <= 0.0) {
      return Path();
    }

    final double maxRadius = calcMaxRadius(center, size);
    final double radius = maxRadius * clampedFraction;

    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  /// Calculates the maximum distance from [center] to the furthest screen corner.
  static double calcMaxRadius(Offset center, Size size) {
    final double dx = math.max(center.dx, size.width - center.dx);
    final double dy = math.max(center.dy, size.height - center.dy);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool shouldReclip(CircularRevealClipper oldClipper) =>
      oldClipper.fraction != fraction || oldClipper.center != center;
}

/// Circular Reveal Transition Widget.
///
/// Used exclusively for circular theme morphs.
class CircularRevealTransition extends StatelessWidget {
  const CircularRevealTransition({
    super.key,
    required this.animation,
    required this.child,
    required this.center,
  });

  final Animation<double> animation;
  final Widget child;
  final Offset center;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? cachedChild) {
        final double t = animation.value.clamp(0.0, 1.0);
        final double curvedProgress = M3SpringCurves.gentle.transform(t);

        return ClipPath(
          clipper: CircularRevealClipper(
            fraction: curvedProgress,
            center: center,
          ),
          child: RepaintBoundary(
            child: cachedChild,
          ),
        );
      },
      child: child,
    );
  }
}

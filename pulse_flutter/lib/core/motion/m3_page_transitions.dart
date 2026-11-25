import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Shared axis X page transition on M3 Expressive tokens.
///
/// The entering page slides in from the trailing side while the page under it
/// slides away to the leading side; a pop mirrors the motion. Position follows
/// the default spatial spring, opacity the effects springs. With reduced
/// motion only the cross-fade remains.
class M3SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const M3SharedAxisPageTransitionsBuilder();

  /// [transitionDuration] in milliseconds; equals [M3Durations.spatialDefault].
  static const int kTransitionMilliseconds = 500;

  static const Curve _fadeIn = Interval(
    0.0,
    0.4,
    curve: M3SpringCurves.effectsDefault,
  );
  static const Curve _fadeOut = Interval(
    0.0,
    0.3,
    curve: M3SpringCurves.effectsFast,
  );

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: kTransitionMilliseconds);

  /// Going back is quicker than arriving: the page leaves in the time of the
  /// fast spatial spring.
  @override
  Duration get reverseTransitionDuration => M3Durations.spatialFast;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          underTransition(context, secondaryAnimation, child);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final double travel = _travel(context);
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder:
          (BuildContext context, Animation<double> animation, Widget? child) =>
              _layer(
                animation: animation,
                from: travel,
                to: 0.0,
                appearing: true,
                child: child,
              ),
      reverseBuilder:
          (BuildContext context, Animation<double> animation, Widget? child) =>
              IgnorePointer(
                ignoring: animation.status == AnimationStatus.forward,
                child: _layer(
                  animation: animation,
                  from: 0.0,
                  to: travel,
                  appearing: false,
                  child: child,
                ),
              ),
      child: underTransition(context, secondaryAnimation, child),
    );
  }

  /// Motion of a page while another page is pushed on top of it or popped
  /// off it.
  static Widget underTransition(
    BuildContext context,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    final double travel = _travel(context);
    final Widget transition = DualTransitionBuilder(
      animation: ReverseAnimation(secondaryAnimation),
      forwardBuilder:
          (BuildContext context, Animation<double> animation, Widget? child) =>
              _layer(
                animation: animation,
                from: -travel,
                to: 0.0,
                appearing: true,
                child: child,
              ),
      reverseBuilder:
          (BuildContext context, Animation<double> animation, Widget? child) =>
              _layer(
                animation: animation,
                from: 0.0,
                to: -travel,
                appearing: false,
                child: child,
              ),
      child: child,
    );
    if (!(ModalRoute.opaqueOf(context) ?? true)) return transition;
    // Both pages are translucent mid-flight: keep the surface tone behind them.
    return ColoredBox(
      color: secondaryAnimation.isAnimating
          ? ColorScheme.of(context).surface
          : Colors.transparent,
      child: transition,
    );
  }

  /// Signed travel distance in logical pixels, zero with reduced motion.
  static double _travel(BuildContext context) {
    if (context.reduceMotion) return 0.0;
    final double distance = math.min(
      MediaQuery.sizeOf(context).width * 0.25,
      96.0,
    );
    return Directionality.of(context) == TextDirection.rtl
        ? -distance
        : distance;
  }

  /// [animation] runs from 0.0 to 1.0 while the layer moves [from] -> [to].
  static Widget _layer({
    required Animation<double> animation,
    required double from,
    required double to,
    required bool appearing,
    required Widget? child,
  }) {
    final Animation<double> dx = animation.drive(
      Tween<double>(
        begin: from,
        end: to,
      ).chain(CurveTween(curve: M3SpringCurves.spatialDefault)),
    );
    final Animation<double> opacity = animation.drive(
      Tween<double>(
        begin: appearing ? 0.0 : 1.0,
        end: appearing ? 1.0 : 0.0,
      ).chain(CurveTween(curve: appearing ? _fadeIn : _fadeOut)),
    );
    return FadeTransition(
      opacity: opacity,
      child: AnimatedBuilder(
        animation: dx,
        builder: (BuildContext context, Widget? child) =>
            Transform.translate(offset: Offset(dx.value, 0.0), child: child),
        child: child,
      ),
    );
  }
}

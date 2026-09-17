import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// NiosMotion: Universal physics engine for NiosMess motion system.
///
/// Implements NF-1...NF-5 from the Motion Protocol:
/// - Uninterrupted velocity handoff: gesture velocity is preserved into spring simulations.
/// - 5 canonical springs: [spatial], [emphasized], [snappy], [bouncy], [gentle].
/// - Normalized coordinates with mathematical guarantee of settling at destination.
abstract final class NiosMotion {
  /// Spatial spring: for container movement, expands, morphs, and dismissals.
  /// (mass: 1.0, stiffness: 220.0, damping: 26.0, damping ratio: ~0.75)
  static const SpringDescription spatial = M3Spring.spatial;

  /// Emphasized spring: for prominent hero transitions and dialog reveals.
  /// (mass: 1.0, stiffness: 200.0, damping: 22.0, damping ratio: ~0.70)
  static const SpringDescription emphasized = M3Spring.emphasized;

  /// Snappy spring: high-frequency fast settling for tabs, switches, toggles.
  /// (mass: 1.0, stiffness: 340.0, damping: 32.0, damping ratio: ~0.85)
  static const SpringDescription snappy = M3Spring.snappy;

  /// Bouncy spring: visible playful overshoot for reactions, celebrations, badges.
  /// NOTE: Strictly prohibited for opacity or color transitions (use [gentle]).
  /// (mass: 1.0, stiffness: 260.0, damping: 18.0, damping ratio: ~0.55)
  static const SpringDescription bouncy = M3Spring.bouncy;

  /// Gentle spring: relaxed, sub-critically damped for background shifts, colors.
  /// (mass: 1.0, stiffness: 150.0, damping: 22.0, damping ratio: ~0.90)
  static const SpringDescription gentle = M3Spring.gentle;

  /// Creates a [SpringSimulation] with uninterrupted gesture velocity transfer.
  ///
  /// [from] and [to] are typically in normalized [0.0, 1.0] controller units.
  /// [velocity] is in units/second (see [normalizeVelocity]).
  static SpringSimulation simulate({
    required SpringDescription spring,
    required double from,
    required double to,
    double velocity = 0.0,
    double toleranceDistance = 0.001,
  }) {
    final SpringSimulation sim = SpringSimulation(spring, from, to, velocity);
    sim.tolerance = Tolerance(
      distance: toleranceDistance,
      velocity: toleranceDistance * 2.0,
    );
    return sim;
  }

  /// Normalizes a gesture velocity in logical pixels/sec into fractional units/sec.
  ///
  /// Example: for a sheet of height 600px with a swipe velocity of 1200px/s,
  /// returns `1200 / 600 = 2.0` units/sec.
  static double normalizeVelocity(double pixelVelocity, double dimension) {
    if (dimension <= 0.0) return 0.0;
    return pixelVelocity / dimension;
  }
}

/// Extension on [AnimationController] to animate with [NiosMotion] springs.
extension NiosMotionControllerExtension on AnimationController {
  /// Drives the controller toward [target] using [NiosMotion.simulate].
  ///
  /// Preserves the initial [velocity] (in units/second) to ensure seamless
  /// handoff from user touch gestures without artificial deceleration to zero.
  TickerFuture animateWithSpring({
    required SpringDescription spring,
    required double target,
    double velocity = 0.0,
  }) {
    assert(
      lowerBound == double.negativeInfinity && upperBound == double.infinity,
      'animateWithSpring requires an unbounded AnimationController '
      '(AnimationController.unbounded(vsync: this)) to allow natural spring '
      'overshoot and settling without artificial clipping to [0.0, 1.0].',
    );
    final SpringSimulation simulation = NiosMotion.simulate(
      spring: spring,
      from: value,
      to: target,
      velocity: velocity,
    );
    return animateWith(simulation);
  }
}

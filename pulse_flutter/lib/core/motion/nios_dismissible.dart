import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/nios_motion.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';

/// Dismiss direction for [NiosDismissible].
enum NiosDismissDirection {
  /// Dismiss by swiping downwards (e.g. media viewer, bottom sheets).
  down,

  /// Dismiss by swiping upwards or downwards.
  vertical,
}

/// A physics-based dismissible container with uninterrupted gesture velocity transfer.
///
/// Implements NF-1 (Velocity Handoff) and NF-4 (Interruptibility):
/// - Tracks vertical drag gestures with rubber-band resistance.
/// - At gesture release, feeds [DragEndDetails.primaryVelocity] directly into
///   a [NiosMotion.spatial] spring simulation, preventing the "dead stop" stutter
///   common in standard Flutter dismissibles.
/// - Drives backdrop fade, content translation, and scale through [builder].
class NiosDismissible extends StatefulWidget {
  const NiosDismissible({
    required this.child,
    required this.onDismissed,
    this.direction = NiosDismissDirection.down,
    this.dismissThreshold = 0.20,
    this.velocityThreshold = 1.8,
    this.builder,
    this.onProgress,
    this.ref,
    super.key,
  });

  /// The child widget being dismissed.
  final Widget child;

  /// Callback executed when the dismissal spring settles at target 1.0.
  final VoidCallback onDismissed;

  /// Dismiss direction (defaults to [NiosDismissDirection.down]).
  final NiosDismissDirection direction;

  /// Fraction of viewport height required to trigger dismiss on slow release.
  final double dismissThreshold;

  /// Minimum normalized velocity (units/sec) to trigger fling dismissal.
  final double velocityThreshold;

  /// Optional custom builder allowing surrounding elements (e.g. black scrim)
  /// to react to [progress] (0.0 = resting, 1.0 = dismissed).
  final Widget Function(BuildContext context, Widget child, double progress)?
      builder;

  /// Optional progress listener callback.
  final ValueChanged<double>? onProgress;

  /// Optional WidgetRef for TriSync multi-channel feedback.
  final WidgetRef? ref;

  @override
  State<NiosDismissible> createState() => _NiosDismissibleState();
}

class _NiosDismissibleState extends State<NiosDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragOffset = 0.0;
  bool _thresholdCrossed = false;
  int _dragGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    )..addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    widget.onProgress?.call(_controller.value.clamp(-1.0, 1.0));
  }

  // ND-3: Dimension-normalized rubber-band resistance
  double _rubberBand(double offset, double dimension) {
    if (dimension <= 0.0) return offset;
    if (widget.direction == NiosDismissDirection.down && offset < 0) {
      final double fraction = (-offset / dimension).clamp(0.0, 1.0);
      return -math.pow(fraction, 0.70).toDouble() * dimension * 0.25;
    }
    return offset;
  }

  void _onDragStart(DragStartDetails details) {
    // ND-1: Increment generation to invalidate any in-flight settlement callback
    _dragGeneration++;
    _controller.stop();

    // ND-2: Use MediaQuery height instead of nullable context.size
    final double height = MediaQuery.sizeOf(context).height;
    _dragOffset = _controller.value * height;
    _thresholdCrossed = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double height = MediaQuery.sizeOf(context).height;
    _dragOffset += details.primaryDelta ?? 0.0;

    final double effectiveOffset = _rubberBand(_dragOffset, height);
    final double minProgress = widget.direction == NiosDismissDirection.down ? -0.2 : -1.5;
    final double rawProgress = (effectiveOffset / height).clamp(minProgress, 1.5);

    _controller.value = rawProgress;

    // ND-5: Hysteresis (0.05) to prevent rapid oscillating haptic clicks
    final double absProgress = rawProgress.abs();
    if (absProgress >= widget.dismissThreshold && !_thresholdCrossed) {
      _thresholdCrossed = true;
      TriSync.pop(ref: widget.ref, context: context);
    } else if (absProgress < (widget.dismissThreshold - 0.05) && _thresholdCrossed) {
      _thresholdCrossed = false;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final int currentGeneration = _dragGeneration;
    final double height = MediaQuery.sizeOf(context).height;
    final double pixelVelocity = details.primaryVelocity ?? 0.0;
    final double normalizedVelocity =
        NiosMotion.normalizeVelocity(pixelVelocity, height);

    final double currentProgress = _controller.value;
    final bool isDown = currentProgress >= 0;

    // ND-6: Support vertical (up and down) dismiss direction
    final bool shouldDismiss;
    if (widget.direction == NiosDismissDirection.down) {
      shouldDismiss = (currentProgress >= widget.dismissThreshold &&
              normalizedVelocity >= -0.2) ||
          normalizedVelocity >= widget.velocityThreshold;
    } else {
      final double absProgress = currentProgress.abs();
      shouldDismiss = (absProgress >= widget.dismissThreshold &&
              (isDown ? normalizedVelocity >= -0.2 : normalizedVelocity <= 0.2)) ||
          normalizedVelocity.abs() >= widget.velocityThreshold;
    }

    final double target = shouldDismiss ? (isDown ? 1.0 : -1.0) : 0.0;

    if (shouldDismiss) {
      TriSync.dismiss(ref: widget.ref, context: context);
    }

    // NF-1: Hand off user velocity directly into the spatial spring simulation
    _controller
        .animateWith(
      NiosMotion.simulate(
        spring: NiosMotion.spatial,
        from: currentProgress,
        to: target,
        velocity: normalizedVelocity,
      ),
    )
        .whenCompleteOrCancel(() {
      // ND-1: Only dismiss if generation hasn't changed (not interrupted by user catch)
      if (mounted &&
          _dragGeneration == currentGeneration &&
          shouldDismiss &&
          _controller.value.abs() >= 0.95) {
        widget.onDismissed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext ctx, Widget? child) {
          final double progress = _controller.value;
          final double height = MediaQuery.sizeOf(context).height;
          final double offsetY = progress * height;

          // ND-4: Normalized, reachable scale down
          final double scale = (1.0 - progress.abs() * 0.15).clamp(0.70, 1.0);

          final Widget transformedChild = Transform.translate(
            offset: Offset(0, offsetY),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );

          if (widget.builder != null) {
            return widget.builder!(ctx, transformedChild, progress);
          }
          return transformedChild;
        },
        child: widget.child,
      ),
    );
  }
}

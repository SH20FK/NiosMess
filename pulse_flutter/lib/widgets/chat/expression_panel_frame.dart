import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:motor/motor.dart' show SingleMotionController;
import 'package:pulse_flutter/core/motion/m3_motion.dart';

/// Panel under the composer whose height springs between closed, compact and
/// expanded.
///
/// A [height] change that arrives together with a [keyboardInset] change is
/// applied at once, so the panel and the keyboard trade places 1:1. Any other
/// change springs. [ExpressionPanelFrameState.dragBy] moves the panel with
/// the finger and [ExpressionPanelFrameState.release] hands the finger's
/// velocity to the spring.
class ExpressionPanelFrame extends StatefulWidget {
  const ExpressionPanelFrame({
    required this.height,
    required this.keyboardInset,
    required this.layoutHeight,
    required this.maxHeight,
    required this.child,
    super.key,
  });

  /// Resting height for the current state, zero when the panel is closed.
  final double height;
  final double keyboardInset;

  /// Smallest height the content is laid out at. A shorter panel clips it,
  /// a taller one stretches it.
  final double layoutHeight;

  /// Upper bound for a drag.
  final double maxHeight;
  final Widget child;

  @override
  State<ExpressionPanelFrame> createState() => ExpressionPanelFrameState();
}

class ExpressionPanelFrameState extends State<ExpressionPanelFrame>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _height;
  bool _dragging = false;

  /// Height velocity of the last release, kept for one frame so a state
  /// change decided by that release starts with it.
  double? _releaseVelocity;

  @override
  void initState() {
    super.initState();
    _height = SingleMotionController(
      motion: M3Motion.spatialDefault,
      vsync: this,
    );
    _height.value = widget.height;
  }

  @override
  void didUpdateWidget(ExpressionPanelFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The finger owns the height until release.
    if (_dragging || widget.height == oldWidget.height) return;
    if (widget.keyboardInset != oldWidget.keyboardInset) {
      _height.stop(canceled: true);
      _height.value = widget.height;
    } else {
      _height.springTo(
        widget.height,
        velocity: _releaseVelocity,
        reduceMotion: context.reduceMotion,
      );
    }
  }

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  /// Moves the panel by a finger [delta]; positive is down.
  void dragBy(double delta) {
    if (!_dragging) {
      _dragging = true;
      _height.stop(canceled: true);
    }
    final double upper = math.max(widget.maxHeight, widget.height);
    _height.value = (_height.value - delta).clamp(0.0, upper);
  }

  /// Ends a drag. [velocity] is the finger's, positive is down.
  void release(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    final double heightVelocity = -velocity;
    _releaseVelocity = heightVelocity;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _releaseVelocity = null,
    );
    _height.springTo(
      widget.height,
      velocity: heightVelocity,
      reduceMotion: context.reduceMotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _height,
      builder: (BuildContext context, Widget? child) {
        // The closing spring dips below zero before it settles.
        final double height = math.max(0.0, _height.value);
        final double layoutHeight = math.max(widget.layoutHeight, height);
        return Container(
          height: height,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: height > 0
                ? Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: layoutHeight,
            maxHeight: layoutHeight,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

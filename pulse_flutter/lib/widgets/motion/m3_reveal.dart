import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Presentation styles for [M3Reveal].
enum M3RevealType {
  /// Expands height with normalized fade and spring scale.
  expandY,

  /// Scale in place with normalized fade.
  fadeScale,

  /// Pure normalized fade.
  fade,
}

/// Material 3 Expressive reveal animation widget.
///
/// Smoothly reveals or hides content using normalized spring physics ([M3SpringCurves.spatial])
/// and expressive alpha easing ([M3SpringCurves.expressiveDecel]).
class M3Reveal extends StatefulWidget {
  const M3Reveal({
    required this.revealed,
    required this.child,
    super.key,
    this.type = M3RevealType.expandY,
    this.duration = const Duration(milliseconds: 280),
    this.curve = M3SpringCurves.spatial,
    this.alignment = Alignment.center,
  });

  /// Whether the child is revealed.
  final bool revealed;

  /// Child widget to reveal.
  final Widget child;

  /// Reveal transition style.
  final M3RevealType type;

  /// Animation duration.
  final Duration duration;

  /// Spring curve for spatial expansion or scale.
  final Curve curve;

  /// Alignment for scale/expand operations.
  final Alignment alignment;

  @override
  State<M3Reveal> createState() => _M3RevealState();
}

class _M3RevealState extends State<M3Reveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _spatialAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.revealed ? 1.0 : 0.0,
    );
    _buildAnimations();
  }

  void _buildAnimations() {
    _spatialAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
      reverseCurve: M3SpringCurves.expressiveAccel,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.expressiveDecel,
      reverseCurve: M3SpringCurves.expressiveAccel,
    );
  }

  @override
  void didUpdateWidget(covariant M3Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.revealed != widget.revealed) {
      if (widget.revealed) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return widget.revealed ? widget.child : const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        if (_controller.isDismissed) {
          return const SizedBox.shrink();
        }

        switch (widget.type) {
          case M3RevealType.expandY:
            return SizeTransition(
              sizeFactor: _spatialAnimation,
              axis: Axis.vertical,
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: child,
              ),
            );

          case M3RevealType.fadeScale:
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(_spatialAnimation),
                alignment: widget.alignment,
                child: child,
              ),
            );

          case M3RevealType.fade:
            return FadeTransition(
              opacity: _fadeAnimation,
              child: child,
            );
        }
      },
      child: widget.child,
    );
  }
}

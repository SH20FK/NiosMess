import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// One-shot entrance of a widget that has just appeared.
///
/// Opacity rides an effects curve and never overshoots; the optional scale
/// and vertical offset ride the default spatial spring. The entrance plays
/// once, after [delay]. With reduced motion the child is shown at rest.
class M3Entrance extends StatefulWidget {
  const M3Entrance({
    required this.child,
    this.delay = Duration.zero,
    this.scaleFrom = 1.0,
    this.offsetY = 0.0,
    super.key,
  });

  final Widget child;

  /// Time the child stays hidden before the entrance starts.
  final Duration delay;

  /// Scale at the start of the entrance; 1.0 disables the scale.
  final double scaleFrom;

  /// Vertical offset in logical pixels at the start of the entrance.
  final double offsetY;

  @override
  State<M3Entrance> createState() => _M3EntranceState();
}

class _M3EntranceState extends State<M3Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _spatial;

  @override
  void initState() {
    super.initState();
    // The delay is part of the timeline, so no timer outlives the widget.
    final Duration total = widget.delay + M3Durations.spatialDefault;
    final double start = widget.delay.inMicroseconds / total.inMicroseconds;
    _controller = AnimationController(vsync: this, duration: total);
    _opacity = _controller.drive(
      CurveTween(
        curve: Interval(
          start,
          start + (1.0 - start) * 0.4,
          curve: M3SpringCurves.effectsDefault,
        ),
      ),
    );
    _spatial = _controller.drive(
      CurveTween(
        curve: Interval(start, 1.0, curve: M3SpringCurves.spatialDefault),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.value = 1.0;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.scaleFrom != 1.0 || widget.offsetY != 0.0) {
      child = AnimatedBuilder(
        animation: _spatial,
        builder: (BuildContext context, Widget? child) {
          final double t = _spatial.value;
          return Transform.translate(
            offset: Offset(0.0, widget.offsetY * (1.0 - t)),
            child: Transform.scale(
              scale: widget.scaleFrom + (1.0 - widget.scaleFrom) * t,
              child: child,
            ),
          );
        },
        child: child,
      );
    }
    return FadeTransition(opacity: _opacity, child: child);
  }
}

/// Postfix form of [M3Entrance] for long widget expressions.
extension M3EntranceExtension on Widget {
  Widget entrance({
    Duration delay = Duration.zero,
    double scaleFrom = 1.0,
    double offsetY = 0.0,
  }) => M3Entrance(
    delay: delay,
    scaleFrom: scaleFrom,
    offsetY: offsetY,
    child: this,
  );
}

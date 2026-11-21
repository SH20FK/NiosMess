import 'package:flutter/material.dart';
import 'package:motor/motor.dart' show SingleMotionController;
import 'package:pulse_flutter/core/motion/m3_motion.dart';

/// Row that is pulled towards the end edge to trigger [onTriggered] and then
/// springs back to rest.
///
/// The row follows the finger 1:1 and the return spring starts with the
/// finger's velocity. [background] is revealed only under the travelled part,
/// so a transparent row never shows it at rest.
class SwipeActionRow extends StatefulWidget {
  const SwipeActionRow({
    required this.child,
    required this.background,
    required this.onTriggered,
    this.enabled = true,
    this.threshold = 0.35,
    super.key,
  });

  final Widget child;
  final Widget background;
  final VoidCallback onTriggered;
  final bool enabled;

  /// Share of the row width that has to be revealed to trigger the action.
  final double threshold;

  @override
  State<SwipeActionRow> createState() => _SwipeActionRowState();
}

class _SwipeActionRowState extends State<SwipeActionRow>
    with SingleTickerProviderStateMixin {
  static const double _minFlingVelocity = 700.0;

  /// Travel along the swipe direction in logical pixels.
  late final SingleMotionController _controller;
  double _width = 0.0;

  double get _sign =>
      Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

  @override
  void initState() {
    super.initState();
    _controller = SingleMotionController(
      motion: M3Motion.spatialDefault,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _controller.stop(canceled: true);
    _width = context.size?.width ?? 0.0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double next =
        _controller.value + (details.primaryDelta ?? 0.0) * _sign;
    _controller.value = next.clamp(0.0, _width);
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = (details.primaryVelocity ?? 0.0) * _sign;
    final double extent = _controller.value;
    final bool reached = _width > 0.0 && extent / _width >= widget.threshold;
    final bool flung = velocity >= _minFlingVelocity && extent > 0.0;
    // A fling back towards rest cancels the action.
    if ((reached && velocity > -_minFlingVelocity) || flung) {
      widget.onTriggered();
    }
    _settle(velocity: velocity);
  }

  void _settle({double? velocity}) {
    _controller.springTo(
      0.0,
      velocity: velocity,
      reduceMotion: context.reduceMotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: enabled ? _onDragStart : null,
      onHorizontalDragUpdate: enabled ? _onDragUpdate : null,
      onHorizontalDragEnd: enabled ? _onDragEnd : null,
      onHorizontalDragCancel: enabled ? _settle : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double extent = _controller.value;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // The first slot always exists, so the row keeps its place in
              // the Stack and its state while the background comes and goes.
              if (extent > 0.5 && _width > 0.0)
                PositionedDirectional(
                  start: 0.0,
                  top: 0.0,
                  bottom: 0.0,
                  width: extent.clamp(0.0, _width),
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: AlignmentDirectional.centerStart,
                      minWidth: _width,
                      maxWidth: _width,
                      child: widget.background,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              Transform.translate(
                offset: Offset(extent * _sign, 0.0),
                child: child,
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart' show SingleMotionController;
import 'package:pulse_flutter/core/motion/m3_motion.dart';

/// Row that is pulled sideways to trigger an action and then springs back to
/// rest.
///
/// Pulling towards the end edge reveals [background] at the start and fires
/// [onTriggered]; pulling towards the start edge reveals [endBackground] at
/// the end and fires [onEndTriggered]. A direction without a callback does
/// not move.
///
/// The row follows the finger 1:1 and the return spring starts with the
/// finger's velocity. A background is revealed only under the travelled part,
/// so a transparent row never shows it at rest.
class SwipeActionRow extends StatefulWidget {
  const SwipeActionRow({
    required this.child,
    this.background,
    this.onTriggered,
    this.endBackground,
    this.onEndTriggered,
    this.onArmed,
    this.enabled = true,
    this.threshold = 0.35,
    super.key,
  });

  final Widget child;
  final Widget? background;
  final VoidCallback? onTriggered;
  final Widget? endBackground;
  final VoidCallback? onEndTriggered;

  /// Called each time the pull crosses [threshold] outwards: releasing now
  /// would trigger the action.
  final VoidCallback? onArmed;
  final bool enabled;

  /// Share of the row width that has to be revealed to trigger an action.
  final double threshold;

  /// Whether the pull that reveals the enclosing background is past the
  /// threshold. A background reads it to answer the moment its action arms.
  static bool armedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SwipeArmed>()?.armed ?? false;

  @override
  State<SwipeActionRow> createState() => _SwipeActionRowState();
}

class _SwipeArmed extends InheritedWidget {
  const _SwipeArmed({required this.armed, required super.child});

  final bool armed;

  @override
  bool updateShouldNotify(_SwipeArmed oldWidget) => oldWidget.armed != armed;
}

class _SwipeActionRowState extends State<SwipeActionRow>
    with SingleTickerProviderStateMixin {
  static const double _minFlingVelocity = 700.0;

  /// Signed travel in logical pixels: positive towards the end edge.
  late final SingleMotionController _controller;
  double _width = 0.0;

  /// Side of the current pull: 1 towards the end edge, -1 towards the start.
  /// The return spring may cross rest by a pixel or two; this keeps the
  /// opposite background from flashing there.
  int _side = 0;
  bool _armed = false;

  double get _sign =>
      Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

  bool get _canPullToEnd => widget.enabled && widget.onTriggered != null;
  bool get _canPullToStart => widget.enabled && widget.onEndTriggered != null;

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

  bool _reached(double extent) =>
      _width > 0.0 && extent.abs() / _width >= widget.threshold;

  void _onDragStart(DragStartDetails details) {
    _controller.stop(canceled: true);
    _width = context.size?.width ?? 0.0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double next =
        (_controller.value + (details.primaryDelta ?? 0.0) * _sign).clamp(
          _canPullToStart ? -_width : 0.0,
          _canPullToEnd ? _width : 0.0,
        );
    _controller.value = next;
    if (next != 0.0) _side = next > 0.0 ? 1 : -1;
    final bool armed = _reached(next);
    if (armed != _armed) {
      _armed = armed;
      if (armed) widget.onArmed?.call();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = (details.primaryVelocity ?? 0.0) * _sign;
    final double extent = _controller.value;
    if (extent != 0.0) {
      // Velocity along the pull: a fling back towards rest cancels the action.
      final double outward = velocity * extent.sign;
      if ((_reached(extent) && outward > -_minFlingVelocity) ||
          outward >= _minFlingVelocity) {
        (extent > 0.0 ? widget.onTriggered : widget.onEndTriggered)?.call();
      }
    }
    _armed = false;
    _settle(velocity: velocity);
  }

  void _settle({double? velocity}) {
    _armed = false;
    _controller.springTo(
      0.0,
      velocity: velocity,
      reduceMotion: context.reduceMotion,
    );
  }

  Widget _reveal({
    required Widget background,
    required double width,
    required bool atStart,
    required bool armed,
  }) {
    return PositionedDirectional(
      start: atStart ? 0.0 : null,
      end: atStart ? null : 0.0,
      top: 0.0,
      bottom: 0.0,
      width: width,
      child: ClipRect(
        child: OverflowBox(
          alignment: atStart
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          minWidth: _width,
          maxWidth: _width,
          child: _SwipeArmed(armed: armed, child: background),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = _canPullToEnd || _canPullToStart;
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
          final double reveal = extent.abs().clamp(0.0, _width);
          final bool towardsEnd = extent > 0.0;
          final Widget? background = reveal <= 0.5 || _width <= 0.0
              ? null
              : towardsEnd && _side > 0
              ? widget.background
              : !towardsEnd && _side < 0
              ? widget.endBackground
              : null;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // The first slot always exists, so the row keeps its place in
              // the Stack and its state while a background comes and goes.
              if (background != null)
                _reveal(
                  background: background,
                  width: reveal,
                  atStart: towardsEnd,
                  armed: _reached(extent),
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

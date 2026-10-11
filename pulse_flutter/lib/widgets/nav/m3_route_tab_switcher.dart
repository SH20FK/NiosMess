import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Compatibility hook and warm-up gate. No raster snapshots are retained.
class TabTransitionController {
  bool isTransitioning = false;
  void captureOutgoing() {}
}

enum _Phase { idle, outgoing, incoming }

/// Persistent tab subtrees with directional Material shared-axis motion.
/// Rapid selections change the destination, never restart opacity at a boundary.
class M3RouteTabSwitcher extends StatefulWidget {
  const M3RouteTabSwitcher({
    required this.index,
    required this.children,
    this.controller,
    this.animate = true,
    this.slideDistance,
    this.duration,
    this.onTransitionStateChanged,
    super.key,
  }) : assert(index >= 0 && index < children.length);
  final int index;
  final List<Widget> children;
  final TabTransitionController? controller;
  final bool animate;

  /// Maximum horizontal movement in logical pixels; defaults to 32.
  final double? slideDistance;
  final Duration? duration;
  final ValueChanged<bool>? onTransitionStateChanged;
  @override
  State<M3RouteTabSwitcher> createState() => _M3RouteTabSwitcherState();
}

class _M3RouteTabSwitcherState extends State<M3RouteTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _opacity;
  late int _visible;
  late int _target;
  _Phase _phase = _Phase.idle;
  int _generation = 0;
  bool _busy = false;
  double _heldScale = 1;
  double _scaleStart = 1;
  double _heldOffset = 0;
  double _slideStart = 0;
  double _direction = 1;
  double _exitStartOpacity = 1;
  double get _exitProgress => _exitStartOpacity == 0
      ? 1
      : 1 - _opacity.value / _exitStartOpacity;
  double get _distance => widget.slideDistance ?? 32;
  double get _offset => _phase == _Phase.incoming
      ? _slideStart * (1 - M3SpringCurves.gentle.transform(_opacity.value))
      : _phase == _Phase.outgoing
      ? _heldOffset +
            (-_direction * _distance - _heldOffset) * _exitProgress
      : 0;
  bool get _reduced =>
      !widget.animate || MediaQuery.maybeDisableAnimationsOf(context) == true;
  Duration get _duration =>
      widget.duration ?? const Duration(milliseconds: 320);
  double get _scale => _phase == _Phase.incoming
      ? _scaleStart +
            (1 - _scaleStart) * M3SpringCurves.gentle.transform(_opacity.value)
      : _phase == _Phase.outgoing
      ? _heldScale + (.985 - _heldScale) * _exitProgress
      : _heldScale;

  @override
  void initState() {
    super.initState();
    _visible = _target = widget.index;
    _opacity = AnimationController(vsync: this, value: 1);
  }

  void _notify(bool busy) {
    widget.controller?.isTransitioning = busy;
    if (_busy == busy) return;
    _busy = busy;
    widget.onTransitionStateChanged?.call(busy);
  }

  void _jump() {
    _generation++;
    _opacity.stop();
    _visible = _target = widget.index;
    _phase = _Phase.idle;
    _heldScale = _scaleStart = 1;
    _heldOffset = _slideStart = 0;
    _opacity.value = 1;
    _notify(false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced && _busy) _jump();
  }

  @override
  void didUpdateWidget(covariant M3RouteTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.isTransitioning = false;
      widget.controller?.isTransitioning = _busy;
    }
    if (_reduced || _duration == Duration.zero) {
      _jump();
      return;
    }
    if (oldWidget.index == widget.index) return;
    _target = widget.index;
    if (_phase == _Phase.outgoing && _target != _visible) return;
    if (_target == _visible) {
      if (_phase == _Phase.outgoing) {
        // Return to the page still on screen, retaining its current scale.
        final currentScale = _scale;
        final currentOffset = _offset;
        final progress = M3SpringCurves.gentle.transform(_opacity.value);
        _scaleStart = progress == 1
            ? 1
            : (currentScale - progress) / (1 - progress);
        _slideStart = progress == 1 ? 0 : currentOffset / (1 - progress);
        _phase = _Phase.incoming;
        unawaited(_drive(false));
      }
      return;
    }
    _heldScale = _scale;
    _heldOffset = _offset;
    _exitStartOpacity = _opacity.value;
    _direction = _target > _visible ? 1 : -1;
    if (Directionality.of(context) == TextDirection.rtl) _direction *= -1;
    _phase = _Phase.outgoing;
    _notify(true);
    unawaited(_drive(true));
  }

  Future<void> _drive(bool outgoing) async {
    final generation = ++_generation;
    _opacity.stop();
    final remaining = outgoing ? _opacity.value : 1 - _opacity.value;
    final micros =
        (_duration.inMicroseconds * (outgoing ? .35 : .65) * remaining).round();
    try {
      await _opacity
          .animateTo(
            outgoing ? 0 : 1,
            duration: Duration(microseconds: micros),
            curve: outgoing
                ? M3SpringCurves.expressiveAccel
                : M3SpringCurves.expressiveDecel,
          )
          .orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || generation != _generation) return;
    if (outgoing) {
      setState(() {
        _direction = _target > _visible ? 1 : -1;
        if (Directionality.of(context) == TextDirection.rtl) _direction *= -1;
        _visible = _target;
        _phase = _Phase.incoming;
        _scaleStart = .96;
        _slideStart = _direction * _distance;
      });
      unawaited(_drive(false));
    } else {
      setState(() {
        _phase = _Phase.idle;
        _heldScale = 1;
        _heldOffset = _slideStart = 0;
      });
      _notify(false);
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.controller?.isTransitioning = false;
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _opacity,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Offstage(
            key: ValueKey(i),
            offstage: i != _visible,
            child: TickerMode(
              enabled: i == widget.index && _phase == _Phase.idle,
              child: ExcludeFocus(
                excluding: i != widget.index || _phase != _Phase.idle,
                child: ExcludeSemantics(
                  excluding: i != widget.index || _phase != _Phase.idle,
                  child: IgnorePointer(
                    ignoring: i != widget.index || _phase != _Phase.idle,
                    child: RepaintBoundary(
                      child: Opacity(
                        opacity: i == _visible ? _opacity.value : 1,
                        child: Transform.translate(
                          offset: Offset(i == _visible ? _offset : 0, 0),
                          child: Transform.scale(
                            scale: i == _visible ? _scale : 1,
                            child: widget.children[i],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

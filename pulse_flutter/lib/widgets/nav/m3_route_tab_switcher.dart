import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Compatibility hook and warm-up gate. No raster snapshots are retained.
class TabTransitionController {
  bool isTransitioning = false;
  void captureOutgoing() {}
}

enum _Phase { idle, outgoing, incoming }

/// Persistent tab subtrees with a two-phase Material fade-through transition.
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

  /// Retained for source compatibility; fade through has no lateral movement.
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
  bool get _reduced =>
      !widget.animate || MediaQuery.maybeDisableAnimationsOf(context) == true;
  Duration get _duration =>
      widget.duration ?? const Duration(milliseconds: 250);
  double get _scale => _phase == _Phase.incoming
      ? _scaleStart +
            (1 - _scaleStart) * M3SpringCurves.gentle.transform(_opacity.value)
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
        final progress = M3SpringCurves.gentle.transform(_opacity.value);
        _scaleStart = progress == 1
            ? 1
            : (_heldScale - progress) / (1 - progress);
        _phase = _Phase.incoming;
        unawaited(_drive(false));
      }
      return;
    }
    _heldScale = _scale;
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
        _visible = _target;
        _phase = _Phase.incoming;
        _scaleStart = .985;
      });
      unawaited(_drive(false));
    } else {
      setState(() {
        _phase = _Phase.idle;
        _heldScale = 1;
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
      ],
    ),
  );
}

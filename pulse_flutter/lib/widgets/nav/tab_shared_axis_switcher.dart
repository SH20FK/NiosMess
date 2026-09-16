import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Imperative hook: the shell rasterizes the outgoing tab at the exact moment
/// of the tap, while its layer is still freshly painted.
class TabTransitionController {
  _TabSharedAxisSwitcherState? _state;

  /// Call immediately BEFORE `context.go('/main/<tab>')`.
  void captureOutgoing() => _state?._captureOutgoing();
}

/// Direction-aware M3 Expressive shared-axis transition between shell tabs.
///
/// The outgoing tab is captured once as a GPU texture and animated as a
/// [RawImage], so it costs a single texture blit instead of a build, layout
/// and paint pass. The incoming tab is animated with transforms only, so the
/// whole transition allocates zero save layers.
class TabSharedAxisSwitcher extends StatefulWidget {
  const TabSharedAxisSwitcher({
    required this.index,
    required this.children,
    required this.controller,
    this.animate = true,
    this.shift = 0.14,
    this.duration = M3Durations.medium2,
    super.key,
  });

  final int index;
  final List<Widget> children;
  final TabTransitionController controller;

  /// False on tier C, on reduced-motion, or on weak-device mode: instant swap.
  final bool animate;

  /// Horizontal travel as a fraction of page width.
  final double shift;

  final Duration duration;

  @override
  State<TabSharedAxisSwitcher> createState() => _TabSharedAxisSwitcherState();
}

class _TabSharedAxisSwitcherState extends State<TabSharedAxisSwitcher>
    with SingleTickerProviderStateMixin {
  static const double _outScale = 0.94;
  static const double _inScale = 0.96;

  /// Load-bearing twice: it lets us find the boundary to rasterize, and it
  /// keeps the live subtree alive when the tree shape changes between the
  /// steady state and the animating Stack.
  final GlobalKey _boundaryKey = GlobalKey();

  late final AnimationController _controller;
  late final Animation<double> _spatial;
  late final Animation<double> _outAlpha;

  ui.Image? _snapshot;
  double _snapshotScale = 1.0;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1.0
      ..addStatusListener(_onStatus);
    _spatial = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.spatial,
    );
    // Leaf-level alpha on the texture only: no Opacity widget, no save layer.
    // Monotonic curve, never an overshoot curve (motion protocol rule 5).
    _outAlpha = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: M3SpringCurves.expressiveDecel,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant TabSharedAxisSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.index == widget.index) return;

    _direction = widget.index > oldWidget.index ? 1 : -1;

    if (!widget.animate) {
      _controller.value = 1.0;
      _disposeSnapshot();
      return;
    }

    // Fallback capture for programmatic switches (deep link, back button).
    if (_snapshot == null) {
      _captureOutgoing();
    }
    _controller.forward(from: 0.0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }
    if (_snapshot != null) {
      setState(_disposeSnapshot);
    }
  }

  void _disposeSnapshot() {
    _snapshot?.dispose();
    _snapshot = null;
  }

  void _captureOutgoing() {
    if (!widget.animate || !mounted) return;
    final RenderObject? object = _boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return;
    _disposeSnapshot();
    try {
      bool isDirty = false;
      assert(() {
        isDirty = object.debugNeedsPaint;
        return true;
      }());
      if (isDirty) return;
      // Cap at 2.0: a 3x full-screen texture costs bandwidth for nothing.
      final double scale =
          MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
      _snapshot = object.toImageSync(pixelRatio: scale);
      _snapshotScale = scale;
    } catch (_) {
      _disposeSnapshot();
    }
  }

  @override
  void dispose() {
    widget.controller._state = null;
    _controller.dispose();
    _disposeSnapshot();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget live = RepaintBoundary(
      key: _boundaryKey,
      child: IndexedStack(index: widget.index, children: widget.children),
    );

    // Steady state: exactly the tree we have today, zero animation overhead.
    if (_snapshot == null && _controller.value == 1.0) return live;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AnimatedBuilder(
          animation: _spatial,
          child: live,
          builder: (BuildContext context, Widget? child) {
            final double t = _spatial.value;
            return FractionalTranslation(
              translation: Offset(_direction * widget.shift * (1.0 - t), 0.0),
              child: Transform.scale(
                scale: ui.lerpDouble(_inScale, 1.0, t)!,
                child: child,
              ),
            );
          },
        ),
        if (_snapshot != null)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _spatial,
              builder: (BuildContext context, Widget? child) {
                final double t = _spatial.value;
                return FractionalTranslation(
                  translation: Offset(-_direction * widget.shift * t, 0.0),
                  child: Transform.scale(
                    scale: ui.lerpDouble(1.0, _outScale, t)!,
                    child: RawImage(
                      image: _snapshot,
                      scale: _snapshotScale,
                      opacity: _outAlpha,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

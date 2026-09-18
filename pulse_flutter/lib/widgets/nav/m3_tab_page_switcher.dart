import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Controller hook retained for backward compatibility with existing callers.
class TabTransitionController {
  /// No-op in modern M3TabPageSwitcher (raster capture eliminated for 120 FPS performance).
  void captureOutgoing() {}
}

/// Lightweight Material 3 Expressive Tab Page Switcher.
///
/// Eliminates all `toImageSync` GPU raster overhead, eliminating render thread
/// stalls during tab switching. Uses a directional fade-through with subtle
/// sub-12dp spatial glide and strictly monotonic easing curves (anti-jank protocol).
class M3TabPageSwitcher extends StatefulWidget {
  const M3TabPageSwitcher({
    required this.index,
    required this.children,
    this.controller,
    this.animate = true,
    this.slideDistance = 12.0,
    this.duration = M3Durations.medium1,
    super.key,
  });

  final int index;
  final List<Widget> children;
  final TabTransitionController? controller;

  /// Whether transitions should animate. When false, switches instantly.
  final bool animate;

  /// Micro-translation travel distance in logical pixels (default 12dp).
  final double slideDistance;

  final Duration duration;

  @override
  State<M3TabPageSwitcher> createState() => _M3TabPageSwitcherState();
}

class _M3TabPageSwitcherState extends State<M3TabPageSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  int _currentIndex = 0;
  int? _outgoingIndex;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addStatusListener(_onStatus);

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.expressiveDecel,
    );
  }

  @override
  void didUpdateWidget(covariant M3TabPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (oldWidget.index != widget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;

      if (!widget.animate) {
        setState(() {
          _currentIndex = widget.index;
          _outgoingIndex = null;
        });
        _controller.value = 1.0;
        return;
      }

      setState(() {
        _outgoingIndex = _currentIndex;
        _currentIndex = widget.index;
      });
      _controller.forward(from: 0.0);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted && _outgoingIndex != null) {
        setState(() {
          _outgoingIndex = null;
        });
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
    // Steady state: single IndexedStack, zero animation overhead.
    if (_outgoingIndex == null || !widget.animate) {
      return IndexedStack(
        index: _currentIndex,
        children: widget.children,
      );
    }

    // Animating state: incoming page slides and fades in; outgoing page fades out
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double t = _fadeAnimation.value;
        final double slideT = _slideAnimation.value;
        final double currentSlide = _direction * widget.slideDistance * (1.0 - slideT);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Outgoing page: fading out, ignore touches
            if (_outgoingIndex != null &&
                _outgoingIndex! < widget.children.length)
              IgnorePointer(
                child: Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0),
                  child: widget.children[_outgoingIndex!],
                ),
              ),

            // Incoming page: fading and gliding in
            Transform.translate(
              offset: Offset(currentSlide, 0.0),
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: widget.children[_currentIndex],
              ),
            ),
          ],
        );
      },
    );
  }
}

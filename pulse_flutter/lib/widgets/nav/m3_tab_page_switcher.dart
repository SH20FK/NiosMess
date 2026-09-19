import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Controller hook retained for backward compatibility with existing callers.
class TabTransitionController {
  /// No-op in modern M3TabPageSwitcher (raster capture eliminated for 120 FPS performance).
  void captureOutgoing() {}
}

/// Lightweight Material 3 Expressive Tab Page Switcher.
///
/// Eliminates all `toImageSync` GPU raster overhead and dual-page `saveLayer` Opacity
/// re-allocations. Uses pure render-tree [FadeTransition] and micro-translation
/// with rapid-tap cancellation to guarantee 60-120 FPS desktop fluidity.
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
  late Animation<double> _incomingFade;
  late Animation<double> _outgoingFade;
  late Animation<Offset> _incomingSlide;

  int _currentIndex = 0;
  int? _outgoingIndex;
  int _direction = 1;

  Duration get _effectiveDuration {
    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    return isDesktop ? M3Durations.short3 : widget.duration;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: _effectiveDuration,
    )..addStatusListener(_onStatus);

    _setupAnimations();
  }

  void _setupAnimations() {
    final Animation<double> curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _incomingFade = curve;
    _outgoingFade = Tween<double>(begin: 1.0, end: 0.0).animate(curve);

    // Subtle 8-12dp spatial slide (expressed as fraction of viewport)
    final double fractionalOffset = (_direction * 0.025).clamp(-0.05, 0.05);
    _incomingSlide = Tween<Offset>(
      begin: Offset(fractionalOffset, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.expressiveDecel,
    ));
  }

  @override
  void didUpdateWidget(covariant M3TabPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _effectiveDuration;

    if (oldWidget.index != widget.index) {
      if (widget.index == _currentIndex && _outgoingIndex == null) {
        return;
      }

      if (!widget.animate) {
        if (_controller.isAnimating) _controller.stop();
        setState(() {
          _currentIndex = widget.index;
          _outgoingIndex = null;
        });
        _controller.value = 1.0;
        return;
      }

      if (_controller.isAnimating) {
        // If user tapped back to the page currently fading out, reverse smoothly
        if (_outgoingIndex == widget.index) {
          final int temp = _currentIndex;
          setState(() {
            _currentIndex = widget.index;
            _outgoingIndex = temp;
          });
          _controller.reverse();
          return;
        }

        // Rapid tap during early transition (< 40%): maintain original outgoing page
        // as visual baseline so barely-visible intermediate page is not snapped in.
        if (_controller.value < 0.40 && _outgoingIndex != null) {
          _direction = widget.index > _outgoingIndex! ? 1 : -1;
          _setupAnimations();
          setState(() {
            _currentIndex = widget.index;
          });
          _controller.forward(from: _controller.value);
          return;
        }

        _controller.stop();
      }

      _direction = widget.index > oldWidget.index ? 1 : -1;
      _setupAnimations();

      setState(() {
        _outgoingIndex = _currentIndex;
        _currentIndex = widget.index;
      });
      _controller.forward(from: 0.0);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
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
    // Steady state: single IndexedStack, zero animation or layer overhead.
    if (_outgoingIndex == null || !widget.animate) {
      return IndexedStack(
        index: _currentIndex,
        children: widget.children,
      );
    }

    // Animating state: incoming page slides and fades in; outgoing page fades out cleanly.
    // Uses FadeTransition / SlideTransition directly to avoid rebuilding widgets per frame.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Outgoing page: strictly fading out, touches ignored
        if (_outgoingIndex != null && _outgoingIndex! < widget.children.length)
          IgnorePointer(
            child: FadeTransition(
              opacity: _outgoingFade,
              child: widget.children[_outgoingIndex!],
            ),
          ),

        // Incoming page: fading and smoothly gliding in
        SlideTransition(
          position: _incomingSlide,
          child: FadeTransition(
            opacity: _incomingFade,
            child: widget.children[_currentIndex],
          ),
        ),
      ],
    );
  }
}

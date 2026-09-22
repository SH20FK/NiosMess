import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Backward-compatibility hook for legacy callers expecting [TabTransitionController].
class TabTransitionController {
  /// No-op in modern M3RouteTabSwitcher (raster captures are eliminated).
  void captureOutgoing() {}
}

/// Material 3 Expressive & Metrolist-inspired tab route switcher.
///
/// Key design characteristics:
/// 1. Strict logical pixel-to-fraction spatial slide calculated dynamically via
///    [LayoutBuilder] (`slideDistance / constraints.maxWidth`).
/// 2. Asymmetric transition: incoming tab fades and slides into position,
///    while outgoing tab strictly fades out in place (zero slide, 0 dp).
/// 3. Monotonic rapid-tap retargeting without phase jumps, reverse glitches,
///    or intermediate frame snapping.
/// 4. Synchronous transition notifications via [onTransitionStateChanged] to allow
///    pausing background tickers and list rebuilds during flight.
/// 5. Zero raster image snapshots ([toImageSync]), eliminating GPU offscreen allocations.
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
  });

  final int index;
  final List<Widget> children;
  final TabTransitionController? controller;

  /// Whether transitions should animate. When false, switches instantly.
  final bool animate;

  /// Spatial travel distance for the incoming page in logical pixels.
  /// Defaults to 20.0 dp on mobile and 14.0 dp on desktop.
  final double? slideDistance;

  /// Duration of the transition.
  /// Defaults to 220 ms on mobile and 180 ms on desktop.
  final Duration? duration;

  /// Called when a page transition starts (`true`) or completes (`false`).
  final ValueChanged<bool>? onTransitionStateChanged;

  @override
  State<M3RouteTabSwitcher> createState() => _M3RouteTabSwitcherState();
}

class _M3RouteTabSwitcherState extends State<M3RouteTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  int _currentIndex = 0;
  int? _outgoingIndex;
  int _direction = 1; // 1 = forward (moving right), -1 = backward (moving left)

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  Duration get _effectiveDuration {
    if (widget.duration != null) return widget.duration!;
    return _isDesktop
        ? const Duration(milliseconds: 180)
        : const Duration(milliseconds: 220);
  }

  double get _effectiveSlideDistance {
    if (widget.slideDistance != null) return widget.slideDistance!;
    return _isDesktop ? 14.0 : 20.0;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: _effectiveDuration,
    )..addStatusListener(_onStatus);


  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted && _outgoingIndex != null) {
        setState(() {
          _outgoingIndex = null;
        });
        widget.onTransitionStateChanged?.call(false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant M3RouteTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _effectiveDuration;

    if (oldWidget.index != widget.index) {
      if (widget.index == _currentIndex && _outgoingIndex == null) {
        return;
      }

      final bool reducedMotion =
          !widget.animate || MediaQuery.maybeDisableAnimationsOf(context) == true;

      if (reducedMotion) {
        if (_controller.isAnimating) _controller.stop();
        setState(() {
          _currentIndex = widget.index;
          _outgoingIndex = null;
        });
        _controller.value = 1.0;
        widget.onTransitionStateChanged?.call(false);
        return;
      }

      // Metrolist Rapid-Tap Handling:
      // If user taps while transition is in-flight, smoothly retarget from current page.
      setState(() {
        if (_controller.isAnimating) {
          _direction = widget.index > _currentIndex ? 1 : -1;
          _outgoingIndex = _currentIndex;
          _currentIndex = widget.index;
        } else {
          _direction = widget.index > oldWidget.index ? 1 : -1;
          _outgoingIndex = _currentIndex;
          _currentIndex = widget.index;
        }
      });

      widget.onTransitionStateChanged?.call(true);
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion =
        !widget.animate || MediaQuery.maybeDisableAnimationsOf(context) == true;

    // Steady state: single IndexedStack, zero animation, layer, or ticker overhead.
    if (_outgoingIndex == null || reducedMotion) {
      return IndexedStack(
        index: _currentIndex,
        children: widget.children,
      );
    }

    // Animating state: M3 Expressive "fade through". The outgoing page fades
    // out fast; the incoming page fades and scales in only after the old page
    // is mostly gone. The two pages are never half-transparent at the same
    // time - that overlap was what made the switch look like a mushy crossfade.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double effectiveDistance = _effectiveSlideDistance;
        final double dxFraction = width > 0 ? (effectiveDistance / width) : 0.0;

        final Animation<double> outgoingFade = Tween<double>(begin: 1.0, end: 0.0)
            .animate(CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.40, curve: Curves.easeInCubic),
        ));

        final Animation<double> incomingFade = Tween<double>(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.35, 1.0, curve: M3SpringCurves.expressiveDecel),
        ));

        final Animation<double> incomingScale = Tween<double>(begin: 0.965, end: 1.0)
            .animate(CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.35, 1.0, curve: M3SpringCurves.expressiveDecel),
        ));

        final Animation<Offset> incomingSlide = Tween<Offset>(
          begin: Offset(_direction * dxFraction, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.35, 1.0, curve: M3SpringCurves.expressiveDecel),
        ));

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Outgoing page: fades out in place, touches ignored.
            if (_outgoingIndex != null &&
                _outgoingIndex! >= 0 &&
                _outgoingIndex! < widget.children.length)
              IgnorePointer(
                child: FadeTransition(
                  opacity: outgoingFade,
                  child: widget.children[_outgoingIndex!],
                ),
              ),

            // Incoming page: delayed fade + subtle scale-up + directional slide.
            FadeTransition(
              opacity: incomingFade,
              child: ScaleTransition(
                scale: incomingScale,
                child: SlideTransition(
                  position: incomingSlide,
                  child: widget.children[_currentIndex],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

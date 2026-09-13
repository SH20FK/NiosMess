import 'dart:ui' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The phases of a predictive back gesture.
enum PulsePredictiveBackPhase {
  /// There is no active predictive back gesture in progress.
  idle,

  /// The user pointer has contacted the screen.
  start,

  /// The user pointer has moved.
  update,

  /// The user pointer has released and the back gesture is confirmed.
  commit,

  /// The user pointer has released and the back gesture is canceled.
  cancel,
}

typedef PulsePredictiveBackGestureDetectorWidgetBuilder = Widget Function(
  BuildContext context,
  PulsePredictiveBackPhase phase,
  PredictiveBackEvent? startBackEvent,
  PredictiveBackEvent? currentBackEvent,
);

/// A customizable Material 3 Predictive Back page transitions builder that
/// adapts its scale depth, corner radius, and translation by [strength].
///
/// Supported on Android U (14+) and falls back to standard Material 3
/// forward-fade or upwards fade transitions when predictive back is not active.
class PulsePredictiveBackPageTransitionsBuilder extends PageTransitionsBuilder {
  const PulsePredictiveBackPageTransitionsBuilder({
    this.strength = 1.0,
    this.fallbackColor,
  });

  /// Scale, corner radius, and spatial translation multiplier (0.5 to 1.5).
  final double strength;

  /// Background scrim color when falling back to default page transitions.
  final Color? fallbackColor;

  @override
  Duration get transitionDuration => const Duration(
        milliseconds: FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
      );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _PulsePredictiveBackGestureDetector(
      route: route,
      builder: (
        BuildContext context,
        PulsePredictiveBackPhase phase,
        PredictiveBackEvent? startBackEvent,
        PredictiveBackEvent? currentBackEvent,
      ) {
        if (route.popGestureInProgress) {
          return _PulsePredictiveBackSharedElementPageTransition(
            strength: strength,
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            phase: phase,
            startBackEvent: startBackEvent,
            currentBackEvent: currentBackEvent,
            child: child,
          );
        }

        return FadeForwardsPageTransitionsBuilder(
          backgroundColor: fallbackColor,
        ).buildTransitions(route, context, animation, secondaryAnimation, child);
      },
    );
  }
}

class _PulsePredictiveBackGestureDetector extends StatefulWidget {
  const _PulsePredictiveBackGestureDetector({
    required this.route,
    required this.builder,
  });

  final PulsePredictiveBackGestureDetectorWidgetBuilder builder;
  final PageRoute<dynamic> route;

  @override
  State<_PulsePredictiveBackGestureDetector> createState() =>
      _PulsePredictiveBackGestureDetectorState();
}

class _PulsePredictiveBackGestureDetectorState
    extends State<_PulsePredictiveBackGestureDetector>
    with WidgetsBindingObserver {
  bool get _isEnabled => widget.route.isCurrent && widget.route.popGestureEnabled;

  PulsePredictiveBackPhase _phase = PulsePredictiveBackPhase.idle;
  PredictiveBackEvent? _startBackEvent;
  PredictiveBackEvent? _currentBackEvent;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    _phase = PulsePredictiveBackPhase.start;
    final bool gestureInProgress = !backEvent.isButtonEvent && _isEnabled;
    if (!gestureInProgress) {
      return false;
    }

    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    _startBackEvent = _currentBackEvent = backEvent;
    if (mounted) setState(() {});
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    _phase = PulsePredictiveBackPhase.update;
    widget.route.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);
    _currentBackEvent = backEvent;
    if (mounted) setState(() {});
  }

  @override
  void handleCancelBackGesture() {
    _phase = PulsePredictiveBackPhase.cancel;
    widget.route.handleCancelBackGesture();
    _startBackEvent = _currentBackEvent = null;
    if (mounted) setState(() {});
  }

  @override
  void handleCommitBackGesture() {
    _phase = PulsePredictiveBackPhase.commit;
    widget.route.handleCommitBackGesture();
    _startBackEvent = _currentBackEvent = null;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PulsePredictiveBackPhase effectivePhase =
        widget.route.popGestureInProgress ? _phase : PulsePredictiveBackPhase.idle;
    return widget.builder(
      context,
      effectivePhase,
      _startBackEvent,
      _currentBackEvent,
    );
  }
}

class _PulsePredictiveBackSharedElementPageTransition extends StatefulWidget {
  const _PulsePredictiveBackSharedElementPageTransition({
    required this.strength,
    required this.animation,
    required this.secondaryAnimation,
    required this.phase,
    required this.startBackEvent,
    required this.currentBackEvent,
    required this.child,
  });

  final double strength;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final PulsePredictiveBackPhase phase;
  final PredictiveBackEvent? startBackEvent;
  final PredictiveBackEvent? currentBackEvent;
  final Widget child;

  @override
  State<_PulsePredictiveBackSharedElementPageTransition> createState() =>
      _PulsePredictiveBackSharedElementPageTransitionState();
}

class _PulsePredictiveBackSharedElementPageTransitionState
    extends State<_PulsePredictiveBackSharedElementPageTransition>
    with SingleTickerProviderStateMixin {
  static const int _kCommitMilliseconds = 400;
  static const Curve _kCurve = Curves.easeInOutCubicEmphasized;
  static const Interval _kCommitInterval = Interval(
    0.0,
    _kCommitMilliseconds /
        FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
    curve: _kCurve,
  );

  late double _effectiveStrength;
  late double _minScale;
  late double _divisionFactor;
  late double _margin;
  late double _yPositionFactor;
  late double _deviceBorderRadius;

  late Tween<double> _borderRadiusTween;
  final Tween<double> _opacityTween = Tween<double>(begin: 1.0, end: 0.0);
  late Tween<double> _scaleTween;

  final ProxyAnimation _commitAnimation = ProxyAnimation();
  final ProxyAnimation _bounceAnimation = ProxyAnimation();
  double _lastBounceAnimationValue = 0.0;

  final ProxyAnimation _animation = ProxyAnimation();
  CurvedAnimation? _curvedAnimation;
  CurvedAnimation? _curvedAnimationReversed;

  late Animation<Offset> _positionAnimation;
  Offset _lastDrag = Offset.zero;

  void _recalculateConstants() {
    _effectiveStrength = widget.strength.clamp(0.4, 2.0);
    _minScale = clampDouble(1.0 - (0.10 * _effectiveStrength), 0.70, 0.98);
    _divisionFactor = clampDouble(20.0 / _effectiveStrength, 10.0, 45.0);
    _margin = 8.0 * _effectiveStrength;
    _yPositionFactor = 0.10 * _effectiveStrength;
    _deviceBorderRadius = clampDouble(32.0 * _effectiveStrength, 12.0, 56.0);

    _borderRadiusTween = Tween<double>(begin: 0.0, end: _deviceBorderRadius);
    _scaleTween = Tween<double>(begin: 1.0, end: _minScale);
  }

  double _getYShiftPosition(double screenHeight) {
    final double startTouchY = widget.startBackEvent?.touchOffset?.dy ?? 0;
    final double currentTouchY = widget.currentBackEvent?.touchOffset?.dy ?? 0;

    final double yShiftMax = (screenHeight / _divisionFactor) - _margin;
    final double rawYShift = currentTouchY - startTouchY;
    final double easedYShift = Curves.easeOut.transform(
          clampDouble(rawYShift.abs() / screenHeight, 0.0, 1.0),
        ) *
        rawYShift.sign *
        yShiftMax;

    return clampDouble(easedYShift, -yShiftMax, yShiftMax);
  }

  void _updateAnimations(Size screenSize) {
    _animation.parent = switch (widget.phase) {
      PulsePredictiveBackPhase.commit => _curvedAnimationReversed,
      _ => widget.animation,
    };

    _bounceAnimation.parent = switch (widget.phase) {
      PulsePredictiveBackPhase.commit => Tween<double>(
          begin: 0.0,
          end: _lastBounceAnimationValue,
        ).animate(_curvedAnimation!),
      _ => ReverseAnimation(widget.animation),
    };

    _commitAnimation.parent = switch (widget.phase) {
      PulsePredictiveBackPhase.commit => _animation,
      _ => kAlwaysDismissedAnimation,
    };

    final double xShift = (screenSize.width / _divisionFactor) - _margin;
    _positionAnimation = _animation.drive(switch (widget.phase) {
      PulsePredictiveBackPhase.commit => Tween<Offset>(
          begin: _lastDrag,
          end: Offset(screenSize.height * _yPositionFactor, 0.0),
        ),
      _ => Tween<Offset>(
          begin: switch (widget.currentBackEvent?.swipeEdge) {
            SwipeEdge.left =>
              Offset(xShift, _getYShiftPosition(screenSize.height)),
            SwipeEdge.right =>
              Offset(-xShift, _getYShiftPosition(screenSize.height)),
            null => Offset(xShift, _getYShiftPosition(screenSize.height)),
          },
          end: Offset.zero,
        ),
    });
  }

  void _updateCurvedAnimations() {
    _curvedAnimation?.dispose();
    _curvedAnimationReversed?.dispose();
    _curvedAnimation =
        CurvedAnimation(parent: widget.animation, curve: _kCommitInterval);
    _curvedAnimationReversed = CurvedAnimation(
      parent: ReverseAnimation(widget.animation),
      curve: _kCommitInterval,
    );
  }

  @override
  void initState() {
    super.initState();
    _recalculateConstants();
  }

  @override
  void didUpdateWidget(
      _PulsePredictiveBackSharedElementPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.strength != oldWidget.strength) {
      _recalculateConstants();
    }
    if (widget.animation != oldWidget.animation) {
      _updateCurvedAnimations();
    }
    if (widget.phase != oldWidget.phase &&
        widget.phase == PulsePredictiveBackPhase.commit) {
      _updateAnimations(MediaQuery.sizeOf(context));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurvedAnimations();
    _updateAnimations(MediaQuery.sizeOf(context));
  }

  @override
  void dispose() {
    _curvedAnimation?.dispose();
    _curvedAnimationReversed?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (BuildContext context, Widget? child) {
        _lastBounceAnimationValue = _bounceAnimation.value;
        return Transform.scale(
          scale: _scaleTween.evaluate(_bounceAnimation),
          child: Transform.translate(
            offset: switch (widget.phase) {
              PulsePredictiveBackPhase.commit => _positionAnimation.value,
              _ => _lastDrag = Offset(
                  _positionAnimation.value.dx,
                  _getYShiftPosition(MediaQuery.heightOf(context)),
                ),
            },
            child: Opacity(
              opacity: _opacityTween.evaluate(_commitAnimation),
              child: ClipRRect(
                borderRadius: MediaQuery.displayCornerRadiiOf(context) ??
                    BorderRadius.circular(
                      _borderRadiusTween.evaluate(_bounceAnimation),
                    ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

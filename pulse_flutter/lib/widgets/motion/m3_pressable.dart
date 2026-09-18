import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

/// Material 3 Expressive tactile pressable widget.
///
/// Provides fluid, physical press feedback with scale and translation using
/// [M3SpringCurves.snappy]. Designed with zero save-layer overhead ([Clip.none]),
/// full accessibility compliance (respects `disableAnimations`), and seamless
/// haptics integration.
class M3Pressable extends StatefulWidget {
  const M3Pressable({
    required this.child,
    super.key,
    this.onPressed,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.pressedTranslationY = 0.0,
    this.duration = const Duration(milliseconds: 140),
    this.curve = M3SpringCurves.snappy,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
    this.borderRadius,
  });

  /// The child widget to apply tactile feedback to.
  final Widget child;

  /// Called when the user taps the widget.
  final VoidCallback? onPressed;

  /// Called when the user long presses the widget.
  final VoidCallback? onLongPress;

  /// Scale factor applied when pressed down (typically between 0.94 and 0.98).
  final double pressedScale;

  /// Vertical translation applied when pressed down (tactile dip).
  final double pressedTranslationY;

  /// Duration of the spring scale transition.
  final Duration duration;

  /// Spring curve for the release and press motions.
  final Curve curve;

  /// Whether to fire subtle haptic feedback on tap down.
  final bool enableHaptic;

  /// Hit test behavior for gesture detection.
  final HitTestBehavior behavior;

  /// Optional border radius for ink ripple / focus highlights.
  final BorderRadius? borderRadius;

  @override
  State<M3Pressable> createState() => _M3PressableState();
}

class _M3PressableState extends State<M3Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _translateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _buildAnimations();
  }

  void _buildAnimations() {
    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
      reverseCurve: widget.curve,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(curved);

    _translateAnimation = Tween<double>(
      begin: 0.0,
      end: widget.pressedTranslationY,
    ).animate(curved);
  }

  @override
  void didUpdateWidget(covariant M3Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressedScale != widget.pressedScale ||
        oldWidget.pressedTranslationY != widget.pressedTranslationY ||
        oldWidget.curve != widget.curve ||
        oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      _buildAnimations();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null && widget.onLongPress == null) return;
    if (widget.enableHaptic) {
      HapticService.tap();
    }
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInteractive =
        widget.onPressed != null || widget.onLongPress != null;
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (!isInteractive || disableAnimations) {
      return GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          Widget current = child!;
          if (_translateAnimation.value != 0.0) {
            current = Transform.translate(
              offset: Offset(0, _translateAnimation.value),
              child: current,
            );
          }
          if (_scaleAnimation.value != 1.0) {
            current = Transform.scale(
              scale: _scaleAnimation.value,
              child: current,
            );
          }
          return current;
        },
        child: widget.child,
      ),
    );
  }
}

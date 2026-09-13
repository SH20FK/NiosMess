import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

/// An expressive container with tactile micro-scale press feedback and haptics.
///
/// Implements Material 3 Expressive spring physics and uses a short press delay
/// ([AppMotion.pressTimeout], ~90ms) to ensure scrolling gestures in [ListView] or
/// [CustomScrollView] do not trigger false/accidental card compression.
class TouchContainer extends StatefulWidget {
  const TouchContainer({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.borderRadius,
    this.color,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
    this.enabled = true,
    this.enableHaptics = true,
    this.scaleDown = AppMotion.scalePressed,
    this.boxShadow,
  });

  /// The child widget.
  final Widget child;

  /// Called when the user taps on the container.
  final VoidCallback? onTap;

  /// Called on long press.
  final VoidCallback? onLongPress;

  /// Called on double tap.
  final VoidCallback? onDoubleTap;

  /// The corner radius for the container and clipping (defaults to [AppRadii.mdRadius]).
  final BorderRadius? borderRadius;

  /// Background color of the container.
  final Color? color;

  /// Optional border around the container.
  final BoxBorder? border;

  /// Inner padding.
  final EdgeInsetsGeometry? padding;

  /// Outer margin.
  final EdgeInsetsGeometry? margin;

  /// Optional fixed width.
  final double? width;

  /// Optional fixed height.
  final double? height;

  /// Clipping behavior (defaults to [Clip.antiAlias]).
  final Clip clipBehavior;

  /// Whether user interaction is enabled.
  final bool enabled;

  /// Whether to trigger haptic feedback on tap up.
  final bool enableHaptics;

  /// The scale factor applied when pressed (defaults to 0.975x).
  final double scaleDown;

  /// Optional box shadows.
  final List<BoxShadow>? boxShadow;

  @override
  State<TouchContainer> createState() => _TouchContainerState();
}

class _TouchContainerState extends State<TouchContainer> {
  Timer? _pressTimer;
  bool _isPressed = false;

  bool get _isInteractive =>
      widget.enabled &&
      (widget.onTap != null ||
          widget.onLongPress != null ||
          widget.onDoubleTap != null);

  void _handleTapDown(TapDownDetails details) {
    if (!_isInteractive) return;
    _pressTimer?.cancel();
    _pressTimer = Timer(AppMotion.pressTimeout, () {
      if (mounted) {
        setState(() => _isPressed = true);
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isInteractive) return;
    _cancelPressTimer();
    if (_isPressed) {
      if (mounted) {
        setState(() => _isPressed = false);
      }
    }
    if (widget.enableHaptics) {
      HapticService.tap();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _cancelPressTimer();
    if (_isPressed) {
      if (mounted) {
        setState(() => _isPressed = false);
      }
    }
  }

  void _cancelPressTimer() {
    _pressTimer?.cancel();
    _pressTimer = null;
  }

  @override
  void dispose() {
    _cancelPressTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius effectiveRadius =
        widget.borderRadius ?? AppRadii.mdRadius;

    final Widget container = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: effectiveRadius,
        border: widget.border,
        boxShadow: widget.boxShadow,
      ),
      clipBehavior: widget.clipBehavior,
      child: widget.child,
    );

    if (!_isInteractive) {
      return container;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress != null
          ? () {
              _cancelPressTimer();
              if (_isPressed && mounted) {
                setState(() => _isPressed = false);
              }
              if (widget.enableHaptics) {
                HapticService.confirm();
              }
              widget.onLongPress?.call();
            }
          : null,
      onDoubleTap: widget.onDoubleTap,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: _isPressed
            ? AppMotion.durationPress
            : AppMotion.durationRelease,
        curve: _isPressed ? Curves.easeOutCubic : AppMotion.spring,
        child: container,
      ),
    );
  }
}

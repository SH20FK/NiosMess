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
    this.onSecondaryTapDown,
    this.borderRadius,
    this.color,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.clipBehavior = Clip.none,
    this.enabled = true,
    this.enableHaptics = true,
    this.scaleDown = AppMotion.scalePressed,
    this.releaseCurve,
    this.boxShadow,
    this.stateLayer = true,
    this.stateLayerColor,
  });

  /// The child widget.
  final Widget child;

  /// Called when the user taps on the container.
  final VoidCallback? onTap;

  /// Called on long press.
  final VoidCallback? onLongPress;

  /// Called on double tap.
  final VoidCallback? onDoubleTap;

  /// Called with the global pointer position when a secondary (right) click
  /// starts. When provided, it replaces the legacy
  /// `onSecondaryTap -> onLongPress` bridge so callers can open a single
  /// cursor-anchored menu instead of a duplicate context menu.
  final ValueChanged<Offset>? onSecondaryTapDown;

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

  /// Custom curve used when releasing the touch press.
  final Curve? releaseCurve;

  /// Optional box shadows.
  final List<BoxShadow>? boxShadow;

  /// Material 3 pressed state layer. Painted above the child (never a blur) so
  /// every [TouchContainer] gets the standard 8% `onSurface` press feedback on
  /// top of the scale animation.
  final bool stateLayer;

  /// Override for the state-layer fill (defaults to `onSurface @ 8%`).
  final Color? stateLayerColor;

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
          widget.onDoubleTap != null ||
          widget.onSecondaryTapDown != null);

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
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Color stateLayerColor =
        widget.stateLayerColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);

    final Widget container = AnimatedContainer(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      margin: widget.margin,
      duration: reduceMotion
          ? Duration.zero
          : _isPressed
          ? AppMotion.durationPress
          : AppMotion.durationRelease,
      curve: _isPressed
          ? Curves.easeOutCubic
          : (widget.releaseCurve ?? AppMotion.spring),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: effectiveRadius,
        border: widget.border,
        boxShadow: widget.boxShadow,
      ),
      // Foreground (not background) so the 8% press layer reads on top of the
      // tile/button fill exactly like an M3 InkWell highlight — without blur.
      foregroundDecoration: widget.stateLayer && _isPressed
          ? BoxDecoration(color: stateLayerColor, borderRadius: effectiveRadius)
          : null,
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
      onSecondaryTapDown: widget.onSecondaryTapDown == null
          ? null
          : (TapDownDetails details) =>
                widget.onSecondaryTapDown!(details.globalPosition),
      // Legacy bridge kept for every other call site: without a cursor-aware
      // handler a right click behaves as a long press.
      onSecondaryTap: widget.onSecondaryTapDown != null
          ? null
          : widget.onLongPress,
      onDoubleTap: widget.onDoubleTap,
      child: AnimatedScale(
        scale: _isPressed && !MediaQuery.disableAnimationsOf(context)
            ? widget.scaleDown
            : 1.0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _isPressed
            ? AppMotion.durationPress
            : AppMotion.durationRelease,
        curve: _isPressed
            ? Curves.easeOutCubic
            : (widget.releaseCurve ?? AppMotion.spring),
        child: container,
      ),
    );
  }
}

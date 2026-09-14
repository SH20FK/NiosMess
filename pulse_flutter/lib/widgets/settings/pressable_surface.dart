import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Unified tactile pressable container conforming to Material 3 Expressive standards.
/// Uses [M3SpringCurves.spatial] and [AppRadii] without anti-alias saveLayers.
class PressableSurface extends ConsumerStatefulWidget {
  const PressableSurface({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.color,
    this.padding,
    this.margin,
    this.enabled = true,
    this.playFeedback = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enabled;
  final bool playFeedback;

  @override
  ConsumerState<PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends ConsumerState<PressableSurface> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled || widget.onTap == null) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enabled || widget.onTap == null) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!widget.enabled || widget.onTap == null) return;
    setState(() => _isPressed = false);
  }

  void _handleTap() {
    if (!widget.enabled || widget.onTap == null) return;
    if (widget.playFeedback) {
      ref.read(appSoundProvider).playUiTick();
      if (ref.read(uiSettingsProvider).haptics) {
        HapticService.tap();
      }
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius effectiveRadius =
        widget.borderRadius ?? AppRadii.mdRadius;

    final Widget body = Container(
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? Colors.transparent,
        borderRadius: effectiveRadius,
      ),
      child: widget.child,
    );

    if (!widget.enabled || (widget.onTap == null && widget.onLongPress == null)) {
      return body;
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: Duration(
          milliseconds: _isPressed
              ? AppMotion.durationPress.inMilliseconds
              : AppMotion.durationRelease.inMilliseconds,
        ),
        curve: _isPressed ? M3SpringCurves.snappy : M3SpringCurves.spatial,
        child: body,
      ),
    );
  }
}

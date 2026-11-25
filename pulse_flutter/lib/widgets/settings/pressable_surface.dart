import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/motion/m3_press_scale.dart';

/// Unified tactile pressable container conforming to Material 3 Expressive standards.
/// Uses [M3SpringCurves.spatialDefault] and [AppRadii] without anti-alias saveLayers.
class PressableSurface extends ConsumerStatefulWidget {
  const PressableSurface({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.border,
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
  final BoxBorder? border;
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
  bool _focused = false;
  bool _hovered = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  void didUpdateWidget(PressableSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.onTap == null) _isPressed = false;
    // The detector is gone while the surface is inert, so nothing would ever
    // clear a ring or a hover tone left from before.
    if (!_interactive) {
      _focused = false;
      _hovered = false;
    }
  }

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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color restingColor = widget.color ?? Colors.transparent;
    // M3 hover state layer: 8% of the content colour over the resting fill.
    final Color surfaceColor = _hovered
        ? Color.alphaBlend(
            scheme.onSurface.withValues(alpha: 0.08),
            restingColor,
          )
        : restingColor;

    final Widget body = AnimatedContainer(
      duration: context.reduceMotion
          ? Duration.zero
          : M3Durations.short4,
      curve: M3SpringCurves.expressiveStandard,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: effectiveRadius,
        border: widget.border,
      ),
      foregroundDecoration: _focused
          ? BoxDecoration(
              borderRadius: effectiveRadius,
              border: Border.all(color: scheme.primary, width: 2),
            )
          : null,
      child: widget.child,
    );

    if (!_interactive) return body;

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (bool focused) {
        if (mounted && focused != _focused) setState(() => _focused = focused);
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        behavior: HitTestBehavior.opaque,
        // Its own region: the detector above reports hover only in the
        // traditional highlight mode, which a phone that gets a mouse after
        // the row was built never enters.
        child: MouseRegion(
          onEnter: (_) {
            if (mounted && !_hovered) setState(() => _hovered = true);
          },
          onExit: (_) {
            if (mounted && _hovered) setState(() => _hovered = false);
          },
          child: M3PressScale(pressed: _isPressed, scale: 0.98, child: body),
        ),
      ),
    );
  }
}

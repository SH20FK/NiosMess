import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Expressive Material 3 action button with horizontal layout, tactile haptics,
/// synchronized InkWell state-layer, and fluid spatial spring press animation.
class PulseButton extends StatefulWidget {
  const PulseButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton> {
  late final WidgetStatesController _statesController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _statesController = WidgetStatesController();
    _statesController.addListener(_onStatesChanged);
  }

  void _onStatesChanged() {
    final pressed = _statesController.value.contains(WidgetState.pressed);
    if (pressed != _isPressed && mounted) {
      setState(() => _isPressed = pressed);
    }
  }

  @override
  void dispose() {
    _statesController.removeListener(_onStatesChanged);
    _statesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      button: true,
      enabled: !widget.isLoading && widget.onPressed != null,
      child: AnimatedScale(
        scale: _isPressed ? AppMotion.scalePressed : 1.0,
        duration: _isPressed ? AppMotion.durationPress : AppMotion.durationRelease,
        curve: M3SpringCurves.spatial,
        child: FilledButton(
          statesController: _statesController,
          onPressed: widget.isLoading
              ? null
              : () {
                  HapticService.tap();
                  widget.onPressed?.call();
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (widget.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: AppLoadingIndicator(size: 18),
                )
              else if (widget.icon != null)
                Icon(widget.icon, size: 20),
              if (widget.isLoading || widget.icon != null)
                const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

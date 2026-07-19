import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      button: true,
      enabled: !widget.isLoading,
      child: Listener(
        onPointerDown: (_) {
          if (widget.onPressed != null && !widget.isLoading) {
            setState(() => _pressed = true);
          }
        },
        onPointerUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: FilledButton(
            onPressed: widget.isLoading
                ? null
                : () {
                    HapticService.tap();
                    widget.onPressed?.call();
                  },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (widget.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: AppLoadingIndicator(size: 16),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, size: 20),
                if (widget.icon != null || widget.isLoading)
                  const SizedBox(height: 4),
                Text(widget.label, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

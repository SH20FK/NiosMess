import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

class PulseButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: !isLoading,
      child: FilledButton(
        onPressed: isLoading
            ? null
            : () {
                HapticService.tap();
                onPressed?.call();
              },
        child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon, size: 18),
          if (isLoading || icon != null) const SizedBox(width: 8),
          Text(label),
          ],
        ),
      ),
    );
  }
}

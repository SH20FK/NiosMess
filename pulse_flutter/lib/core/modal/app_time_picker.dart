import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

/// Centralized Material 3 Expressive time picker helper.
/// Guarantees consistent tonal surfaces, rounded shapes, and accessibility across platforms.
class AppTimePicker {
  AppTimePicker._();

  static Future<TimeOfDay?> show({
    required BuildContext context,
    required TimeOfDay initialTime,
    String? helpText,
    String? confirmText,
    String? cancelText,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
      confirmText: confirmText,
      cancelText: cancelText,
      builder: (BuildContext ctx, Widget? child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: scheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.xlRadius,
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.20),
                ),
              ),
              elevation: 0,
              dayPeriodBorderSide: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.20),
              ),
              dialBackgroundColor: scheme.surfaceContainerLow,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

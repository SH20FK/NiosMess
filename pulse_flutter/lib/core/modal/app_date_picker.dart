import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

/// Centralized Material 3 Expressive date picker helper.
/// Guarantees consistent tonal surfaces, rounded shapes, and accessibility across platforms.
class AppDatePicker {
  AppDatePicker._();

  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    String? helpText,
    String? confirmText,
    String? cancelText,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      confirmText: confirmText,
      cancelText: cancelText,
      builder: (BuildContext ctx, Widget? child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: scheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.xlRadius,
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.20),
                ),
              ),
              elevation: 0,
              headerBackgroundColor: scheme.surfaceContainerHigh,
              headerForegroundColor: scheme.onSurface,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

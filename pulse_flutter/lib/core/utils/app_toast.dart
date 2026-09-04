import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/utils/app_error_formatter.dart';

class AppToast {
  AppToast._();

  static void showError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    Duration? duration,
  }) {
    final AppFormattedError formatted = error is AppFormattedError
        ? error
        : AppErrorFormatter.format(error);

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ScaffoldMessengerState? scaffoldMessenger =
        ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: scheme.onErrorContainer,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatted.title,
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  if (formatted.description != null &&
                      formatted.description!.isNotEmpty &&
                      formatted.description != formatted.title) ...[
                    const SizedBox(height: 2),
                    Text(
                      formatted.description!,
                      style: TextStyle(
                        color: scheme.onErrorContainer.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (formatted.technicalDetails != null)
              IconButton(
                tooltip: 'Технические подробности',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  Icons.help_outline_rounded,
                  color: scheme.onErrorContainer.withValues(alpha: 0.75),
                  size: 18,
                ),
                onPressed: () {
                  _showTechnicalDetailsDialog(context, formatted);
                },
              ),
          ],
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Повторить',
                textColor: scheme.error,
                backgroundColor: scheme.surface,
                onPressed: onRetry,
              )
            : null,
        backgroundColor: scheme.errorContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 3,
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      textColor: Theme.of(context).colorScheme.onPrimaryContainer,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
      icon: Icons.info_outline_rounded,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
  }) {
    final ScaffoldMessengerState? scaffoldMessenger =
        ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 2,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showTechnicalDetailsDialog(
    BuildContext context,
    AppFormattedError formatted,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bug_report_outlined, color: scheme.error, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Технические подробности',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatted.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    formatted.technicalDetails ?? 'Нет дополнительных данных',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: formatted.technicalDetails ?? formatted.title,
                  ),
                );
                Navigator.of(dialogContext).pop();
                showInfo(context, 'Скопировано в буфер обмена');
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Копировать'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }
}

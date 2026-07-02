import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

enum AppErrorBannerVariant { inline, centered, snackbar }

class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({
    required this.message,
    this.onRetry,
    this.variant = AppErrorBannerVariant.inline,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final AppErrorBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    switch (variant) {
      case AppErrorBannerVariant.centered:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: textTheme.bodyLarge?.copyWith(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.l10n.commonRetry),
                  ),
                ],
              ],
            ),
          ),
        );
      case AppErrorBannerVariant.snackbar:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                action: onRetry != null
                    ? SnackBarAction(
                        label: context.l10n.commonRetry,
                        onPressed: onRetry!,
                      )
                    : null,
              ),
            );
          }
        });
        return const SizedBox.shrink();
      case AppErrorBannerVariant.inline:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.error_outline_rounded, size: 20, color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: Icon(Icons.refresh_rounded, size: 16, color: scheme.onErrorContainer),
                    label: Text(
                      context.l10n.commonRetry,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
    }
  }
}

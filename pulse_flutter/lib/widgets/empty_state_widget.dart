import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isBusy = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                icon,
                size: 40,
                color: scheme.primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: isBusy ? null : onAction,
                child: isBusy
                    ? const AppLoadingIndicator(size: 20)
                    : Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

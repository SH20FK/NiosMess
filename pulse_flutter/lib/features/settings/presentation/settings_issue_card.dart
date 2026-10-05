import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/features/settings/application/settings_anchor_controller.dart';
import 'package:pulse_flutter/features/settings/domain/settings_issue.dart';

class SettingsIssueCard extends ConsumerWidget {
  const SettingsIssueCard({
    required this.issue,
    this.onDismiss,
    super.key,
  });

  final SettingsHealthIssue issue;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final Color cardBg;
    final Color iconColor;
    final IconData icon;

    switch (issue.severity) {
      case SettingsHealthSeverity.critical:
        cardBg = scheme.errorContainer.withValues(alpha: 0.35);
        iconColor = scheme.error;
        icon = Icons.warning_rounded;
      case SettingsHealthSeverity.warning:
        cardBg = scheme.tertiaryContainer.withValues(alpha: 0.35);
        iconColor = scheme.tertiary;
        icon = Icons.info_rounded;
      case SettingsHealthSeverity.advisory:
        cardBg = scheme.surfaceContainerHigh;
        iconColor = scheme.primary;
        icon = Icons.tips_and_updates_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      issue.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issue.description,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (issue.canDismiss && onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onDismiss,
                  tooltip: 'Скрыть',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () {
                context.push(issue.route);
                ref.read(settingsAnchorControllerProvider.notifier).request(
                  route: issue.route,
                  anchor: issue.anchor,
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(100, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                issue.actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

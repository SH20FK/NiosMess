import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/features/account_deletion/presentation/account_deletion_texts.dart';
import 'package:pulse_flutter/features/settings/domain/settings_issue.dart';

/// What is wrong, in one line: the heading of the card, and what a marked
/// section row tells a screen reader.
String settingsIssueTitle(AppLocalizations l10n, SettingsHealthIssue issue) =>
    switch (issue.kind) {
      SettingsHealthIssueKind.deletionPending => accountDeletionPendingTitle(
        l10n,
        issue.scheduledAt,
      ),
      SettingsHealthIssueKind.pushDenied => l10n.settingsIssuePushTitle,
      SettingsHealthIssueKind.cacheLarge => l10n.settingsIssueCacheTitle(
        FileTypeDetector.formatFileSize(issue.bytes),
      ),
      SettingsHealthIssueKind.updateFailed => l10n.settingsIssueUpdateTitle,
    };

class SettingsIssueCard extends StatelessWidget {
  const SettingsIssueCard({
    required this.issue,
    required this.onOpen,
    super.key,
  });

  final SettingsHealthIssue issue;

  /// The hub decides how to open the target: a pushed screen on a phone, the
  /// detail pane in two panes.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final l10n = context.l10n;

    final String title = settingsIssueTitle(l10n, issue);
    final (String body, String action) = switch (issue.kind) {
      SettingsHealthIssueKind.deletionPending => (
        l10n.accountDeletePendingBody,
        l10n.settingsIssueDeletionAction,
      ),
      SettingsHealthIssueKind.pushDenied => (
        l10n.settingsIssuePushBody,
        l10n.settingsIssuePushAction,
      ),
      SettingsHealthIssueKind.cacheLarge => (
        l10n.settingsIssueCacheBody,
        l10n.settingsIssueCacheAction,
      ),
      SettingsHealthIssueKind.updateFailed => (
        l10n.settingsIssueUpdateBody,
        l10n.settingsIssueUpdateAction,
      ),
    };
    final (Color background, Color accent, IconData icon) =
        switch (issue.severity) {
          SettingsHealthSeverity.critical => (
            scheme.errorContainer.withValues(alpha: 0.35),
            scheme.error,
            Icons.warning_rounded,
          ),
          SettingsHealthSeverity.warning => (
            scheme.tertiaryContainer.withValues(alpha: 0.35),
            scheme.tertiary,
            Icons.info_rounded,
          ),
          SettingsHealthSeverity.advisory => (
            scheme.surfaceContainerHigh,
            scheme.primary,
            Icons.tips_and_updates_rounded,
          ),
        };

    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppShape.card),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(100, 48),
                ),
                child: Text(action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';

enum SettingsHealthSeverity { critical, warning, advisory }

enum SettingsHealthIssueKind {
  deletionPending,
  pushDenied,
  cacheLarge,
  updateFailed,
}

/// A problem the settings hub shows above the section list. The issue says
/// what is wrong and where to fix it; the card owns the localized texts.
@immutable
class SettingsHealthIssue {
  const SettingsHealthIssue._({
    required this.kind,
    required this.severity,
    required this.route,
    required this.sectionId,
    required this.anchor,
    this.bytes = 0,
    this.scheduledAt,
  });

  /// The account is scheduled for deletion. Signing in does not cancel it,
  /// so the hub keeps saying so until the user cancels.
  const SettingsHealthIssue.deletionPending(DateTime? scheduledAt)
    : this._(
        kind: SettingsHealthIssueKind.deletionPending,
        severity: SettingsHealthSeverity.critical,
        route: '/settings/account',
        sectionId: SettingsSectionId.account,
        anchor: 'account.delete',
        scheduledAt: scheduledAt,
      );

  const SettingsHealthIssue.pushDenied()
    : this._(
        kind: SettingsHealthIssueKind.pushDenied,
        severity: SettingsHealthSeverity.warning,
        route: '/settings/preferences',
        sectionId: SettingsSectionId.preferences,
        anchor: 'push_notifications',
      );

  const SettingsHealthIssue.cacheLarge(int bytes)
    : this._(
        kind: SettingsHealthIssueKind.cacheLarge,
        severity: SettingsHealthSeverity.advisory,
        route: '/settings/storage',
        sectionId: SettingsSectionId.storage,
        anchor: 'cache_cleaning',
        bytes: bytes,
      );

  const SettingsHealthIssue.updateFailed()
    : this._(
        kind: SettingsHealthIssueKind.updateFailed,
        severity: SettingsHealthSeverity.warning,
        route: '/settings/about',
        sectionId: SettingsSectionId.about,
        anchor: 'about.update',
      );

  final SettingsHealthIssueKind kind;
  final SettingsHealthSeverity severity;
  final String route;
  final SettingsSectionId sectionId;
  final String anchor;

  /// Size the card reports; only [SettingsHealthIssueKind.cacheLarge] sets it.
  final int bytes;

  /// Day of the final erase; only [SettingsHealthIssueKind.deletionPending]
  /// sets it, and the server may leave it out.
  final DateTime? scheduledAt;

  String get id => kind.name;
}

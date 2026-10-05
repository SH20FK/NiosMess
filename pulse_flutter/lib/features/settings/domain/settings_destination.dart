import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';

@immutable
class SettingsDestination {
  const SettingsDestination({
    required this.id,
    required this.sectionId,
    required this.route,
    required this.anchor,
    required this.title,
    required this.keywords,
    this.subtitle,
  });

  final SettingId id;
  final String sectionId;
  final String route;
  final String anchor;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations)? subtitle;
  final List<String> Function(AppLocalizations) keywords;
}

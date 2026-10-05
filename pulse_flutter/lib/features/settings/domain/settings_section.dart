import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/features/settings/domain/settings_destination.dart';

@immutable
class SettingsSection {
  const SettingsSection({
    required this.id,
    required this.title,
    required this.destinations,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final List<SettingsDestination> destinations;
}

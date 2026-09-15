import 'package:flutter/material.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/screens/profile_screen.dart';

/// Central Material 3 Expressive hub for all application settings.
/// Delegates to the unified [ProfileScreen], providing full backwards-compatibility
/// for existing routes, deep links, and test harnesses.
class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({this.initialSection, super.key});

  final SettingsSectionId? initialSection;

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(initialSection: initialSection);
  }
}

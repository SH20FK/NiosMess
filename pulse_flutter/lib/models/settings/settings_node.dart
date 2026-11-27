import 'package:pulse_flutter/core/localization/secret_chat_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';

/// Semantic grouping for settings items according to Part F of the audit.
enum SettingsGroup {
  account,
  appearance,
  chats,
  notifications,
  privacy,
  storage,
  language,
  plus,
  about;

  String localizedTitle(AppLocalizations l10n) {
    switch (this) {
      case SettingsGroup.account:
        return l10n.settingsAccountTitle;
      case SettingsGroup.appearance:
        return l10n.settingsV2Appearance;
      case SettingsGroup.chats:
        return l10n.settingsV2Chats;
      case SettingsGroup.notifications:
        return l10n.settingsV2Notifications;
      case SettingsGroup.privacy:
        return l10n.settingsV2Privacy;
      case SettingsGroup.storage:
        return l10n.settingsV2Storage;
      case SettingsGroup.language:
        return l10n.settingsV2Language;
      case SettingsGroup.plus:
        return 'Nios+';
      case SettingsGroup.about:
        return l10n.settingsV2About;
    }
  }
}

/// Abstract base node in the settings tree.
sealed class SettingsNode {
  const SettingsNode({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.group,
    this.keywords = const <String>[],
    this.availability,
    this.parentNavId,
  });

  final String id;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations)? subtitle;
  final IconData icon;
  final SettingsGroup group;
  final List<String> keywords;
  final bool Function()? availability;
  final String? parentNavId;

  bool isAvailable() => availability?.call() ?? true;
}

/// A node that navigates to a sub-screen or deep link.
final class SettingsNavNode extends SettingsNode {
  const SettingsNavNode({
    required super.id,
    required super.title,
    super.subtitle,
    required super.icon,
    required super.group,
    required this.route,
    this.sectionId,
    this.anchorless = false,
    super.keywords,
    super.availability,
    super.parentNavId,
  });

  final String route;
  final SettingsSectionId? sectionId;

  /// The screen this route opens has no row whose id could be highlighted:
  /// search must navigate to the page itself instead of pointing at a row.
  final bool anchorless;
}

/// A row on the screen of its parent section. Search opens that screen and
/// highlights the row whose anchor is this node's [id]; the screen owns the
/// control itself.
final class SettingsItemNode extends SettingsNode {
  const SettingsItemNode({
    required super.id,
    required super.title,
    super.subtitle,
    required super.icon,
    required super.group,
    super.keywords,
    super.availability,
    super.parentNavId,
  });
}

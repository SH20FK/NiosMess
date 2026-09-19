import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Semantic grouping for settings items according to Part F of the audit.
enum SettingsGroup {
  account,
  appearance,
  chats,
  notifications,
  privacy,
  storage,
  motion,
  language,
  plus,
  about;

  String localizedTitle(AppLocalizations l10n) {
    switch (this) {
      case SettingsGroup.account:
        return l10n.settingsAccountTitle;
      case SettingsGroup.appearance:
        return l10n.profileAppearance;
      case SettingsGroup.chats:
        return l10n.settingsChatsTitle;
      case SettingsGroup.notifications:
        return l10n.settingsPreferencesTitle;
      case SettingsGroup.privacy:
        return l10n.settingsPrivacyTitle;
      case SettingsGroup.storage:
        return l10n.settingsStorageTitle;
      case SettingsGroup.motion:
        return 'Движение и энергосбережение';
      case SettingsGroup.language:
        return l10n.profileLanguage;
      case SettingsGroup.plus:
        return 'Nios Plus & AI';
      case SettingsGroup.about:
        return l10n.settingsSupportAboutTitle;
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
    super.keywords,
    super.availability,
    super.parentNavId,
    this.badgeValue,
  });

  final String route;
  final SettingsSectionId? sectionId;
  final String? Function(AppLocalizations, UiSettingsState)? badgeValue;
}

/// A node that represents a toggle switch.
final class SettingsToggleNode extends SettingsNode {
  const SettingsToggleNode({
    required super.id,
    required super.title,
    super.subtitle,
    required super.icon,
    required super.group,
    required this.valueSelector,
    required this.onChanged,
    super.keywords,
    super.availability,
    super.parentNavId,
  });

  final bool Function(UiSettingsState) valueSelector;
  final void Function(WidgetRef, bool) onChanged;
}

/// A node that represents a multi-choice option (SegmentedButton or radio).
final class SettingsChoiceNode<T> extends SettingsNode {
  const SettingsChoiceNode({
    required super.id,
    required super.title,
    super.subtitle,
    required super.icon,
    required super.group,
    required this.options,
    required this.optionLabel,
    required this.valueSelector,
    required this.onChanged,
    super.keywords,
    super.availability,
    super.parentNavId,
  });

  final List<T> options;
  final String Function(T, AppLocalizations) optionLabel;
  final T Function(UiSettingsState) valueSelector;
  final void Function(WidgetRef, T) onChanged;
}

/// A node that represents a continuous or stepped slider.
final class SettingsSliderNode extends SettingsNode {
  const SettingsSliderNode({
    required super.id,
    required super.title,
    super.subtitle,
    required super.icon,
    required super.group,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.valueSelector,
    required this.onChanged,
    super.keywords,
    super.availability,
    super.parentNavId,
  });

  final double min;
  final double max;
  final int divisions;
  final String unit;
  final double Function(UiSettingsState) valueSelector;
  final void Function(WidgetRef, double) onChanged;
}

/// A node that triggers an action or dialog (e.g. destructive clear cache).
final class SettingsActionNode extends SettingsNode {
  const SettingsActionNode({
    required super.id,
    required super.title,
    super.subtitle,
    required super.icon,
    required super.group,
    required this.onPerform,
    this.isDestructive = false,
    super.keywords,
    super.availability,
    super.parentNavId,
  });

  final bool isDestructive;
  final void Function(BuildContext, WidgetRef) onPerform;
}

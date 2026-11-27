import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identifiers for each settings section in Master-Detail.
enum SettingsSectionId {
  account,
  sessions,
  notifications,
  privacy,
  chats,
  appearance,
  storage,
  languageRegion,
  plus,
  about,
  systemDevice,
  e2ee;

  /// Names of sections that were renamed or dissolved: a saved link with
  /// `?section=` in it still opens the screen that took the content over.
  static const Map<String, SettingsSectionId> _legacyNames =
      <String, SettingsSectionId>{
        'preferences': SettingsSectionId.notifications,
        // The delivery rules that did the saving live on Notifications now.
        'energySaving': SettingsSectionId.notifications,
      };

  static SettingsSectionId fromString(String? raw) {
    if (raw == null) return SettingsSectionId.account;
    for (final SettingsSectionId v in SettingsSectionId.values) {
      if (v.name == raw) return v;
    }
    return _legacyNames[raw] ?? SettingsSectionId.account;
  }
}

class DesktopSettingsSectionNotifier extends Notifier<SettingsSectionId> {
  /// Where the section open beside the list is kept between launches.
  static const String storageKey = 'ui.settingsSection';

  static SettingsSectionId _available(SettingsSectionId section) =>
      kIsWeb && section == SettingsSectionId.systemDevice
      ? SettingsSectionId.about
      : section;

  // Read from the preferences loaded at start-up, so the pane opens on the
  // section it was left on instead of showing Account first and jumping.
  @override
  SettingsSectionId build() => _available(
    SettingsSectionId.fromString(
      UiSettingsNotifier.cachedPrefs?.getString(storageKey),
    ),
  );

  void setSelectedSection(SettingsSectionId section) {
    final SettingsSectionId next = _available(section);
    state = next;
    final SharedPreferences? prefs = UiSettingsNotifier.cachedPrefs;
    if (prefs == null) return;
    // Losing this write costs one extra click after a restart, no more.
    unawaited(
      prefs.setString(storageKey, next.name).catchError((Object _) => false),
    );
  }
}

final NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>
    desktopSelectedSettingsSectionProvider =
        NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>(
  DesktopSettingsSectionNotifier.new,
);

/// Keys the shell catches while the settings tab is open. A tab opened with
/// the mouse leaves the keyboard focus on the shell, above the hub, so the
/// shell hears the key and the hub decides what it means.
enum SettingsKeyCommand { search, back }

class SettingsKeyCommandNotifier
    extends Notifier<({int serial, SettingsKeyCommand command})?> {
  @override
  ({int serial, SettingsKeyCommand command})? build() => null;

  void send(SettingsKeyCommand command) =>
      state = (serial: (state?.serial ?? 0) + 1, command: command);
}

final settingsKeyCommandProvider =
    NotifierProvider<
      SettingsKeyCommandNotifier,
      ({int serial, SettingsKeyCommand command})?
    >(SettingsKeyCommandNotifier.new);

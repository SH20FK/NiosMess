import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        'energySaving': SettingsSectionId.chats,
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
  @override
  SettingsSectionId build() => SettingsSectionId.account;

  void setSelectedSection(SettingsSectionId section) {
    if (kIsWeb && section == SettingsSectionId.systemDevice) {
      state = SettingsSectionId.about;
      return;
    }
    state = section;
  }
}

final NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>
    desktopSelectedSettingsSectionProvider =
        NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>(
  DesktopSettingsSectionNotifier.new,
);

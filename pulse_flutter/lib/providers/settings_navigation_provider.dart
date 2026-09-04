import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifiers for each settings section in Master-Detail.
enum SettingsSectionId {
  account,
  appearance,
  chats,
  privacy,
  storage,
  languageRegion,
  preferences,
  systemDevice,
  about,
  e2ee,
  sessions,
}

class DesktopSettingsSectionNotifier extends Notifier<SettingsSectionId> {
  @override
  SettingsSectionId build() => SettingsSectionId.account;

  void setSelectedSection(SettingsSectionId section) {
    state = section;
  }
}

final NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>
    desktopSelectedSettingsSectionProvider =
        NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>(
  DesktopSettingsSectionNotifier.new,
);

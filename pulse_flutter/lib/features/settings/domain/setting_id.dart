import 'package:flutter/foundation.dart';

@immutable
class SettingId {
  const SettingId(this.value);
  final String value;

  // Account
  static const accountDisplayName = SettingId('account.displayName');
  static const accountUsername = SettingId('account.username');
  static const accountNiosId = SettingId('account.niosId');

  // Appearance
  static const appearanceColorSource = SettingId('appearance.color.source');
  static const appearanceThemeMode = SettingId('appearance.theme.mode');
  static const appearanceDynamicColor = SettingId('appearance.dynamic.color');
  static const appearanceFontScale = SettingId('appearance.font.scale');

  // Privacy & Messaging
  static const privacyReadReceipts = SettingId('privacy.messaging.readReceipts');
  static const privacyTypingIndicators = SettingId('privacy.messaging.typingIndicators');
  static const privacyDefaultExpiry = SettingId('privacy.messaging.defaultExpiry');
  static const privacyHideOnline = SettingId('privacy.messaging.hideOnline');
  static const privacyBlockedUsers = SettingId('privacy.blockedUsers');
  static const privacyCalls = SettingId('privacy.calls');
  static const privacyMessages = SettingId('privacy.messages');
  static const privacyVoiceMessages = SettingId('privacy.voiceMessages');
  static const privacyPhone = SettingId('privacy.phone');
  static const privacyAvatar = SettingId('privacy.avatar');
  static const privacyBio = SettingId('privacy.bio');
  static const privacyBirthday = SettingId('privacy.birthday');
  static const privacyGifts = SettingId('privacy.gifts');
  static const privacyMusic = SettingId('privacy.music');
  static const privacyInvites = SettingId('privacy.invites');
  static const privacyForwards = SettingId('privacy.forwards');
  static const privacyLastSeen = SettingId('privacy.lastSeen');
  static const privacyLinkPreviewsSecret = SettingId('privacy.messaging.linkPreviewsSecret');
  static const privacyScreenshotsSecret = SettingId('privacy.messaging.screenshotsSecret');
  static const privacyAccountSelfDestruct = SettingId('privacy.account.selfDestruct');
  static const privacyBackgroundMode = SettingId('privacy.backgroundMode');

  // Security & App Lock
  static const securityAppLock = SettingId('security.appLock.enabled');
  static const securityAppLockTimeout = SettingId('security.appLock.timeout');
  static const securityAppLockHideInRecents = SettingId('security.appLock.hideInRecents');
  static const securityTwoFactor = SettingId('security.twoFactor');
  static const securitySessionsActive = SettingId('security.sessions.active');

  // Storage
  static const storageAutoDownloadWifi = SettingId('storage.autoDownload.wifi');
  static const storageAutoDownloadMobile = SettingId('storage.autoDownload.mobile');
  static const storageClearCache = SettingId('storage.clearCache');

  // Notifications
  static const notificationsEnabled = SettingId('notifications.enabled');
  static const notificationsSound = SettingId('notifications.sound');
  static const notificationsVibration = SettingId('notifications.vibration');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SettingId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SettingId($value)';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NiosMess';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabCalls => 'Calls';

  @override
  String get tabContacts => 'Contacts';

  @override
  String get tabProfile => 'Profile';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonPreview => 'Preview';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSystem => 'System';

  @override
  String get commonLight => 'Light';

  @override
  String get commonDark => 'Dark';

  @override
  String get commonAutomatic => 'Automatic';

  @override
  String get commonManual => 'Manual';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonNoDescription => 'No public description yet.';

  @override
  String commonFailed(Object error) {
    return 'Failed: $error';
  }

  @override
  String get commonPasteFromClipboard => 'Paste from clipboard';

  @override
  String get splashTagline => 'Fluid connection, clear communication';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in with email or username.';

  @override
  String get loginIdentifierLabel => 'Email or username';

  @override
  String get loginIdentifierError => 'Enter email or username';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordError => 'Minimum 4 characters';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginSubmitting => 'Signing in...';

  @override
  String get loginCreateAccount => 'Create account';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get twoFaTitle => 'Security check';

  @override
  String get twoFaHeroTitle => 'Enter your 2FA code';

  @override
  String get twoFaHeroSubtitle =>
      'We sent a 6-digit code to your email. This keeps your NiosMess session protected.';

  @override
  String get twoFaCodeLabel => 'Verification code';

  @override
  String get twoFaCodeError => 'Enter 6 digits';

  @override
  String get twoFaVerify => 'Verify code';

  @override
  String get twoFaVerifying => 'Verifying...';

  @override
  String get twoFaProtected => 'Protected sign-in';

  @override
  String get twoFaExpires => 'Short-lived code';

  @override
  String get twoFaHint => 'Tip: paste the code directly; spaces are ignored.';

  @override
  String get twoFaFailed => '2FA verification failed';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerEmailError => 'Enter valid email';

  @override
  String get registerUsernameLabel => 'Username';

  @override
  String get registerUsernameError => 'At least 3 characters';

  @override
  String get registerDisplayNameLabel => 'Display name';

  @override
  String get registerDisplayNameError => 'At least 2 characters';

  @override
  String get registerPasswordLabel => 'Password';

  @override
  String get registerPasswordError => 'Minimum 8 characters';

  @override
  String get registerSubmit => 'Create account';

  @override
  String get registerSubmitting => 'Creating...';

  @override
  String get registerFailed => 'Registration failed';

  @override
  String get verifyEmailTitle => 'Verify email';

  @override
  String get verifyEmailCodeLabel => '6-digit code';

  @override
  String get verifyEmailCodeError => 'Enter 6 digits';

  @override
  String get verifyEmailSubmit => 'Verify';

  @override
  String get verifyEmailSubmitting => 'Verifying...';

  @override
  String get verifyEmailDone => 'Done';

  @override
  String get setupWelcomeTitle => 'Nice to meet you!';

  @override
  String get setupWelcomeBody =>
      'Let\'s quickly set up NiosMess for you.\nThis takes about 30 seconds.';

  @override
  String get setupLanguageTitle => 'Choose your language';

  @override
  String get setupTimezoneTitle => 'Your time zone';

  @override
  String get setupTimezoneUseDevice => 'Uses your device\'s current time zone';

  @override
  String get setupTimezoneChooseManual => 'Choose manually';

  @override
  String get setupStartMessaging => 'Start messaging';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageRussianNative => 'Русский';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profilePublicView => 'Your public view';

  @override
  String get profilePublicProfile => 'Public profile';

  @override
  String get profileMessage => 'Message';

  @override
  String get profileCall => 'Call';

  @override
  String get profileVideo => 'Video';

  @override
  String get profileAbout => 'About';

  @override
  String get profileDisplayName => 'Display name';

  @override
  String get profileUsername => 'Username';

  @override
  String get profileDescription => 'Description';

  @override
  String get profilePreferences => 'Preferences';

  @override
  String get profileMyProfile => 'My profile';

  @override
  String get profileQuickSettings => 'Quick settings';

  @override
  String get profileDoNotDisturb => 'Do not disturb';

  @override
  String get profileDoNotDisturbSubtitle =>
      'Pause push notifications on this device';

  @override
  String get profileHideOnline => 'Hide online';

  @override
  String get profileHideOnlineSubtitle => 'Keep presence quieter in the app UI';

  @override
  String get profileStorage => 'Storage';

  @override
  String profileStorageUsed(Object used, Object total) {
    return '$used of $total used';
  }

  @override
  String get profileAccountSection => 'Account';

  @override
  String get profileDangerZone => 'Danger zone';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profileAppearanceSubtitle => 'Theme mode, colors, density';

  @override
  String get profileHaptics => 'Haptics';

  @override
  String get profileHapticsSubtitle => 'Feedback on taps and controls';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileAccountSubtitle => 'Profile, password, sessions';

  @override
  String get profilePrivacy => 'Privacy';

  @override
  String get profilePrivacySubtitle => 'Visibility and permissions';

  @override
  String get profileHelp => 'Help';

  @override
  String get profileHelpSubtitle => 'FAQ, support, contacts';

  @override
  String get profileSession => 'Session';

  @override
  String get profileLogoutSubtitle => 'Log out from this device only.';

  @override
  String get profileLogout => 'Log out';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileThemeStudio => 'Theme studio';

  @override
  String get profileGuestName => 'Guest';

  @override
  String get profileGuestUsername => 'guest';

  @override
  String get profileDefaultBio => 'NiosMess user';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceStudioTitle => 'Theme studio';

  @override
  String get appearanceStudioSubtitle =>
      'Tune palette, mode, density, and feedback with a live preview.';

  @override
  String get appearancePreviewTitle => 'Live preview';

  @override
  String get appearancePreviewSubtitle =>
      'A compact look at your current UI style.';

  @override
  String get appearancePreviewChat => 'Preview chat';

  @override
  String get appearanceIncomingPreview => 'Incoming message preview';

  @override
  String get appearanceAccentPreview => 'Accent color preview';

  @override
  String get appearanceThemeMode => 'Theme mode';

  @override
  String get appearanceModeSystemSubtitle => 'Follow device';

  @override
  String get appearanceModeLightSubtitle => 'Clean daylight UI';

  @override
  String get appearanceModeDarkSubtitle => 'Low-glare night UI';

  @override
  String get appearanceAccentPalette => 'Accent palette';

  @override
  String get appearanceAccentPaletteSubtitle =>
      'Material 3 generates the whole color system from this seed.';

  @override
  String get appearanceMaterialVariant => 'Material variant';

  @override
  String get appearanceInteraction => 'Interaction';

  @override
  String get appearanceInteractionSubtitle =>
      'Behavior, region and motion preferences.';

  @override
  String get appearanceCompactMode => 'Compact mode';

  @override
  String get appearanceCompactModeSubtitle =>
      'Tighter spacing in chat and list screens';

  @override
  String get appearanceDarkCallBackdrop => 'Dark call backdrop';

  @override
  String get appearanceDarkCallBackdropSubtitle =>
      'Darker style on active call screen';

  @override
  String get appearanceHapticsSubtitle =>
      'Tap feedback for chips, buttons, and rows';

  @override
  String get appearanceSoundEffects => 'Sound effects';

  @override
  String get appearanceSoundEffectsSubtitle =>
      'Message tones, call sounds, and navigation clicks';

  @override
  String get appearanceSoundVolume => 'Sound volume';

  @override
  String get appearanceSoundVolumeSubtitle =>
      'Controls interface clicks, messages and call tones';

  @override
  String appearanceSoundVolumeValue(int percent) {
    return '$percent%';
  }

  @override
  String get appearanceLanguageRegion => 'Language & region';

  @override
  String get appearanceLanguageRegionSubtitle =>
      'App language, time zone, and regional format';

  @override
  String get appearancePersonalizationTitle => 'Appearance & themes';

  @override
  String get appearancePersonalizationSubtitle =>
      'Material 3 palettes, soft accent color haze, and manual visual rhythm tuning.';

  @override
  String get appearancePaletteTitle => 'Palette';

  @override
  String get appearancePaletteSubtitle =>
      'Choose accent colors for the interface, text, and buttons';

  @override
  String get appearanceDensityTitle => 'Interface density';

  @override
  String get appearanceDensitySubtitle =>
      'Affects preview size, palette, and visual rhythm of the screen';

  @override
  String get appearanceDensitySoft => 'Soft';

  @override
  String get appearanceDensityRich => 'Rich';

  @override
  String get appearanceDensityExpressive => 'Expressive';

  @override
  String get appearanceThemeParamsTitle => 'Theme parameters';

  @override
  String get appearanceThemeParamsSubtitle => 'Material 3 system toggles';

  @override
  String get appearanceDynamicColors => 'Dynamic colors';

  @override
  String get appearanceDynamicColorsSubtitle =>
      'Use a more expressive tonal scheme';

  @override
  String get appearanceDarkTheme => 'Dark theme';

  @override
  String get appearanceDarkThemeSubtitle =>
      'Manually switch between light and dark Material 3 theme';

  @override
  String get appearanceLabelLight => 'Light';

  @override
  String get appearanceLabelDark => 'Dark';

  @override
  String get appearanceLabelAmethyst => 'Amethyst';

  @override
  String get appearanceLabelLagoon => 'Lagoon';

  @override
  String get appearanceLabelMeadow => 'Meadow';

  @override
  String get appearanceLabelEmber => 'Ember';

  @override
  String get appearanceLabelOrchid => 'Orchid';

  @override
  String get appearanceLabelSlate => 'Slate';

  @override
  String get appearanceLabelSky => 'Sky';

  @override
  String get appearanceLabelRose => 'Rose';

  @override
  String get languageRegionTitle => 'Language & region';

  @override
  String get languageRegionSubtitle =>
      'Choose app language and how time is shown.';

  @override
  String get languageRegionAppLanguage => 'App language';

  @override
  String get languageRegionUseSystemLanguage => 'Use system language';

  @override
  String get languageRegionTimeZone => 'Time zone';

  @override
  String get languageRegionTimeZoneMode => 'Time zone mode';

  @override
  String get languageRegionCurrentTime => 'Current time in app';

  @override
  String get languageRegionSelectTimeZone => 'Select time zone';

  @override
  String get languageRegionSearchTimeZones => 'Search time zones';

  @override
  String get settingsAccountTitle => 'Account';

  @override
  String get settingsCenterTitle => 'Settings center';

  @override
  String get settingsCenterSubtitle =>
      'Account, appearance, privacy and support in one place.';

  @override
  String get settingsQuickControls => 'Quick controls';

  @override
  String get settingsPersonalizationTitle => 'Personalization';

  @override
  String get settingsPersonalizationSubtitle =>
      'Theme, language, density and interaction style';

  @override
  String get settingsAccountSecurityTitle => 'Account & security';

  @override
  String get settingsAccountSecuritySubtitle =>
      'Identity, recovery, sessions and 2FA';

  @override
  String get settingsPrivacyNotificationsTitle => 'Privacy & notifications';

  @override
  String get settingsPrivacyNotificationsSubtitle =>
      'Visibility, alerts, receipts and server limits';

  @override
  String get settingsSupportAboutTitle => 'Support & about';

  @override
  String get settingsSupportAboutSubtitle =>
      'Help, build info, legal pages and project links';

  @override
  String get settingsAccountSubtitle =>
      'Profile identity, security, sessions, and account recovery.';

  @override
  String get settingsAccountAccessTitle => 'Account access';

  @override
  String get settingsAccountAccessSubtitle =>
      'Verification and recovery tools for your account.';

  @override
  String get settingsProtectionTitle => 'Protection';

  @override
  String get settingsProtectionSubtitle => 'Keep account access under control.';

  @override
  String get settingsSecurityTitle => 'Security';

  @override
  String get settingsSecuritySubtitle =>
      'Manage app access, trusted devices, alerts, and protection levels.';

  @override
  String get settingsSecurityCheckupTitle => 'Security checkup';

  @override
  String get settingsSecurityCheckupEnabled =>
      'Your account already has a stronger sign-in layer.';

  @override
  String get settingsSecurityCheckupDisabled =>
      'Enable extra protection for sign-in and recovery.';

  @override
  String get settingsPrivacyTitle => 'Privacy';

  @override
  String get settingsPrivacySubtitle =>
      'Notifications, message visibility, and delivery-related account limits.';

  @override
  String get settingsPrivacyVisibilityTitle => 'Visibility';

  @override
  String get settingsPrivacyVisibilitySubtitle =>
      'What the app surfaces on this device and to other people.';

  @override
  String get settingsHelpTitle => 'Help';

  @override
  String get settingsHelpSubtitle =>
      'Support options, common questions, and quick issue reporting.';

  @override
  String get settingsHelpSupportTitle => 'Support';

  @override
  String get settingsHelpSupportSubtitle =>
      'Get answers, contact support, or send a bug report.';

  @override
  String get settingsAboutTitle => 'About NiosMess';

  @override
  String get settingsAboutSubtitle =>
      'Build information, diagnostics, legal links, and runtime environment.';

  @override
  String get settingsBuildSnapshotTitle => 'Build snapshot';

  @override
  String get settingsBuildSnapshotSubtitle =>
      'Structured communication with a clean Material 3 interface.';

  @override
  String get settingsRuntimeTitle => 'Runtime environment';

  @override
  String get settingsRuntimeSubtitle =>
      'Current app target, storage model and backend state.';

  @override
  String get settingsLinksCreditsTitle => 'Project links';

  @override
  String get settingsLinksCreditsSubtitle => 'Public pages for NiosMess.';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsApi => 'API';

  @override
  String get settingsApiEnvironment => 'API environment';

  @override
  String get settingsReleaseChannel => 'Release channel';

  @override
  String get settingsLocalStorage => 'Local storage';

  @override
  String get settingsProduction => 'Production';

  @override
  String get settingsClientCache => 'Client cache';

  @override
  String get settingsReleaseLiveHint =>
      'This build connects to the live NiosMess API.';

  @override
  String get settingsLocalStorageHint =>
      'Messages, drafts, and session data are stored locally.';

  @override
  String get settingsDevelopers => 'Developers';

  @override
  String get settingsDevelopersSubtitle => 'Meet the people behind NiosMess';

  @override
  String get settingsOpenWebsite => 'Open website';

  @override
  String settingsOpenWebsiteSubtitle(Object url) {
    return 'Open $url in your browser';
  }

  @override
  String get settingsCopyApiUrl => 'Copy API base URL';

  @override
  String get settingsApiUrlCopied => 'API base URL copied';

  @override
  String get settingsLicenses => 'Open source licenses';

  @override
  String get settingsLicensesSubtitle =>
      'Review Flutter and package licenses used by the app';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTermsOfService => 'Terms of Service';

  @override
  String get settingsLegalTitle => 'Legal';

  @override
  String get settingsLegalSubtitle => 'Policies and licenses';

  @override
  String get settingsCouldNotOpenLink => 'Could not open link in browser';

  @override
  String get settingsPushNotifications => 'Push notifications';

  @override
  String get settingsPushNotificationsSubtitle =>
      'Message and call updates on this device';

  @override
  String get settingsReadReceipts => 'Read receipts';

  @override
  String get settingsReadReceiptsSubtitle =>
      'Let others know you\'ve seen their messages';

  @override
  String get settingsTypingIndicator => 'Typing indicator';

  @override
  String get settingsTypingIndicatorSubtitle =>
      'Show when you are typing a message';

  @override
  String get settingsSpamBlockTitle => 'Spam block active';

  @override
  String get settingsSpamBlockSubtitle =>
      'You cannot start new DMs, join groups, or be invited. Contact support if this is a mistake.';

  @override
  String get settingsServerLimitsTitle => 'Server-side limits';

  @override
  String get settingsServerLimitsSubtitle =>
      'Typing indicator and read receipts are currently enforced by the backend and will become configurable later.';

  @override
  String get settingsTwoFactorStatus => 'Two-factor status';

  @override
  String get settingsTwoFactor => 'Two-factor authentication';

  @override
  String get settingsTwoFactorEnabledShort => 'Enabled on your account';

  @override
  String get settingsTwoFactorDisabledShort => 'Disabled on your account';

  @override
  String get settingsTwoFactorOpenAccount =>
      'Open account settings to enable or disable 2FA';

  @override
  String get settingsTrustedDevices => 'Trusted devices';

  @override
  String get settingsTrustedDevicesSubtitle =>
      'Review current sessions and revoke old devices';

  @override
  String get settingsResetPassword => 'Reset password';

  @override
  String get settingsResetPasswordSubtitle =>
      'Request a password reset email code';

  @override
  String get settingsVerifyEmail => 'Verify email';

  @override
  String get settingsVerifyEmailSubtitle =>
      'Confirm your email for recovery and safer sign-in flows';

  @override
  String get settingsActiveSessions => 'Active sessions';

  @override
  String get settingsActiveSessionsSubtitle => 'Manage logged-in devices';

  @override
  String get settingsNoUsername => 'No username';

  @override
  String get settingsUserFallback => 'User';

  @override
  String get settingsAvatarUpdated => 'Avatar updated';

  @override
  String get settingsDisable2faTitle => 'Disable 2FA?';

  @override
  String get settingsDisable2faBody => 'Your account will be less secure.';

  @override
  String get settingsDisable => 'Disable';

  @override
  String get settingsConfirm => 'Confirm';

  @override
  String get settingsConfirmPassword => 'Confirm password';

  @override
  String get settingsDisable2fa => 'Disable 2FA';

  @override
  String get settingsEnable2fa => 'Enable 2FA';

  @override
  String get settings2faEnabled => '2FA enabled';

  @override
  String get settings2faDisabled => '2FA disabled';

  @override
  String get settingsContactSupport => 'Contact support';

  @override
  String get settingsReportIssue => 'Report issue';

  @override
  String get settingsReportIssueSubtitle =>
      'Describe the problem you encountered';

  @override
  String get settingsReportIssueHint => 'Describe the issue...';

  @override
  String get settingsSubmit => 'Submit';

  @override
  String get settingsSupportCopied => 'Support email copied to clipboard';

  @override
  String get settingsSupportRequestSubject => 'NiosMess Support Request';

  @override
  String get settingsSupportRequestBody => 'Describe your issue here.';

  @override
  String get settingsBugReportSubject => 'NiosMess Bug Report';

  @override
  String get settingsBugReportEmpty => 'Issue description was not provided.';

  @override
  String get settingsFaq => 'FAQ';

  @override
  String get settingsFaqResetQ => 'How do I reset my password?';

  @override
  String get settingsFaqResetA =>
      'Go to Account > Reset password. Enter your email and follow the link.';

  @override
  String get settingsFaq2faQ => 'How do I enable 2FA?';

  @override
  String get settingsFaq2faA =>
      'Go to Account > Two-factor authentication and confirm with your password.';

  @override
  String get settingsFaqJoinQ => 'How do I join a group?';

  @override
  String get settingsFaqJoinA =>
      'Use an invite link or tap the link icon on the Chats screen to join by slug.';

  @override
  String get settingsFaqSpamQ => 'Why can\'t I start new chats?';

  @override
  String get settingsFaqSpamA =>
      'Your account may have a spam block. Contact support.';

  @override
  String get developersTeamTitle => 'NiosMess Team';

  @override
  String get developersHeroSubtitle =>
      'Backend, client architecture and sound design in one focused crew.';

  @override
  String get developersSanlsanRole => 'Founder & Backend Architect';

  @override
  String get developersSanlsanDescription =>
      'Server core, API, auth and messaging foundation.';

  @override
  String get developersSh20fkRole => 'App Lead & Client Architect';

  @override
  String get developersSh20fkDescription =>
      'Mobile app, client architecture, product flow and UI.';

  @override
  String get developersKarlovPrimeRole => 'Sound Designer';

  @override
  String get developersKarlovPrimeDescription =>
      'Call, message and interface sound identity.';

  @override
  String get developersTagBackend => 'Backend';

  @override
  String get developersTagApi => 'API';

  @override
  String get developersTagAuth => 'Auth';

  @override
  String get developersTagFlutter => 'Flutter';

  @override
  String get developersTagUx => 'UX';

  @override
  String get developersTagClient => 'Client';

  @override
  String get developersTagSound => 'Sound';

  @override
  String get developersTagCalls => 'Calls';

  @override
  String get developersTagIdentity => 'Identity';

  @override
  String get chatListFilterAll => 'All';

  @override
  String get chatListFilterUnread => 'Unread';

  @override
  String get chatListFilterGroups => 'Groups';

  @override
  String get chatListFilterChannels => 'Channels';

  @override
  String get chatListFilterDirect => 'Direct';

  @override
  String get chatListFilterBots => 'Bots';

  @override
  String get chatListSearch => 'Search chats';

  @override
  String get chatListSearchMessagesHint => 'Search chats and messages';

  @override
  String get chatListMessageMatches => 'Message matches';

  @override
  String get chatListNoChats => 'No chats found.';

  @override
  String get chatListNotAuthenticated => 'You are not authenticated yet.';

  @override
  String get chatListMarkRead => 'Mark as read';

  @override
  String get chatListMarkReadSubtitle => 'Clear unread state for this chat';

  @override
  String get chatListMute => 'Mute';

  @override
  String get chatListPin => 'Pin';

  @override
  String get chatListArchive => 'Archive';

  @override
  String get chatListMuteSubtitle => 'Mute is not available from API yet';

  @override
  String get chatListLeave => 'Leave chat';

  @override
  String get chatListLeaveSubtitle =>
      'Remove this conversation from your account';

  @override
  String chatListFailedLoad(Object error) {
    return 'Failed to load chats: $error';
  }

  @override
  String get chatListMuteUnsupported => 'Mute is not supported by API yet';

  @override
  String get chatListPinUnsupported => 'Pin is not supported by API yet';

  @override
  String get chatListArchiveUnsupported =>
      'Archive is not supported by API yet';

  @override
  String get chatListLeft => 'Left chat';

  @override
  String chatListChannelPreview(Object preview) {
    return 'Channel • $preview';
  }

  @override
  String chatListGroupPreview(Object preview) {
    return 'Group • $preview';
  }

  @override
  String chatListUnreadCount(int count) {
    return '$count unread';
  }

  @override
  String chatPreviewForwardedFrom(Object name) {
    return 'Forwarded from $name';
  }

  @override
  String get chatPreviewPhoto => 'Photo';

  @override
  String get chatPreviewVideo => 'Video';

  @override
  String get chatPreviewAudio => 'Audio';

  @override
  String get chatPreviewFile => 'File';

  @override
  String chatTitleFallback(int id) {
    return 'Chat #$id';
  }

  @override
  String get chatInvalidId => 'Invalid chat ID';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String chatMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String get chatNoMessages => 'No messages yet';

  @override
  String get chatSendFirst => 'Send the first message';

  @override
  String get chatLoadEarlier => 'Load earlier messages';

  @override
  String get chatNoMoreMessages => 'No more messages';

  @override
  String get chatVoiceCall => 'Voice call';

  @override
  String get chatVideoCall => 'Video call';

  @override
  String get chatMembers => 'Members';

  @override
  String get chatManage => 'Manage chat';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatResendTo => 'Resend to...';

  @override
  String get chatResendSubtitle => 'Copies message text to another chat';

  @override
  String get chatComments => 'Comments';

  @override
  String chatCommentsCount(int count) {
    return '$count comments';
  }

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatEditMessageTitle => 'Edit message';

  @override
  String get chatEditMessageHint => 'Message text';

  @override
  String get chatDeleteMessageTitle => 'Delete message?';

  @override
  String get chatDeleteMessageBody => 'This action cannot be undone.';

  @override
  String get chatMessageDeleted => 'Message deleted';

  @override
  String get chatMessageForwarded => 'Message forwarded';

  @override
  String get chatMediaSent => 'Media sent successfully';

  @override
  String get chatForwardTo => 'Forward to...';

  @override
  String get chatAttachment => 'Attachment';

  @override
  String get chatOpenAttachment => 'Open attachment';

  @override
  String get chatTapToPreview => 'Tap to preview';

  @override
  String chatReplyToId(int id) {
    return 'Reply to #$id';
  }

  @override
  String get chatForwardedTitle => 'Forwarded message';

  @override
  String chatForwardedFrom(Object name) {
    return 'From $name';
  }

  @override
  String get chatEdited => 'edited';

  @override
  String chatFailedLoadMessages(Object error) {
    return 'Failed to load messages: $error';
  }

  @override
  String get chatCancelReply => 'Cancel reply';

  @override
  String get chatAttachMedia => 'Attach media';

  @override
  String get chatMessageHint => 'Type a message';

  @override
  String get chatOnlyAdminsCanPost => 'Only admins can post in this channel';

  @override
  String chatMembersTitle(Object name) {
    return '$name members';
  }

  @override
  String get chatMembersInviteUser => 'Invite user';

  @override
  String get chatMembersSearchHint => 'Search by username or name';

  @override
  String get chatMembersSearchPrompt => 'Type a name to search';

  @override
  String chatMembersInvited(Object username) {
    return 'Invited @$username';
  }

  @override
  String get chatMembersEmpty => 'No members';

  @override
  String get chatMembersRoleOwner => 'owner';

  @override
  String get chatMembersRoleAdmin => 'admin';

  @override
  String get chatMembersRoleMember => 'member';

  @override
  String get chatMembersMuted => 'muted';

  @override
  String get chatMembersBanned => 'banned';

  @override
  String get chatMembersBan => 'Ban';

  @override
  String get chatMembersUnban => 'Unban';

  @override
  String get chatMembersMute => 'Mute';

  @override
  String get chatMembersUnmute => 'Unmute';

  @override
  String get chatMembersPromoteAdmin => 'Promote to admin';

  @override
  String get chatMembersDemoteMember => 'Demote to member';

  @override
  String get commentsTitle => 'Post comments';

  @override
  String get commentsEmpty => 'No comments yet';

  @override
  String get commentsDeleted => 'Comment deleted';

  @override
  String get commentsHint => 'Write a comment';

  @override
  String commentsFailedLoad(Object error) {
    return 'Failed to load comments: $error';
  }

  @override
  String commentsFailedSend(Object error) {
    return 'Failed to send comment: $error';
  }

  @override
  String get callsSubtitle =>
      'Recent voice and video activity with quick callback actions.';

  @override
  String get callsNoHistory =>
      'No call history yet. Start a call from any chat.';

  @override
  String callsFailedToStart(Object error) {
    return 'Failed to start call: $error';
  }

  @override
  String callsFailedLoadChats(Object error) {
    return 'Failed to load chats: $error';
  }

  @override
  String callsMissed(Object time) {
    return 'Missed • $time';
  }

  @override
  String callsDeclined(Object time) {
    return 'Declined • $time';
  }

  @override
  String get callsDeclinedShort => 'Declined';

  @override
  String callsOutgoing(Object time) {
    return 'Outgoing • $time';
  }

  @override
  String get callsOutgoingShort => 'Outgoing';

  @override
  String callsIncoming(Object time) {
    return 'Incoming • $time';
  }

  @override
  String get callsIncomingShort => 'Incoming';

  @override
  String get callsInProgress => 'In progress';

  @override
  String callsTotalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calls',
      one: '1 call',
      zero: 'No calls',
    );
    return '$_temp0';
  }

  @override
  String callsMissedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missed',
      one: '1 missed',
      zero: 'No missed',
    );
    return '$_temp0';
  }

  @override
  String callsVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video',
      one: '1 video',
      zero: 'No video',
    );
    return '$_temp0';
  }

  @override
  String get callsSearchHint => 'Search calls';

  @override
  String get callsFilterAll => 'All';

  @override
  String get callsFilterMissed => 'Missed';

  @override
  String get callsFilterVideo => 'Video';

  @override
  String get callsQuickTitle => 'Call hub';

  @override
  String callsLatestCall(Object name) {
    return 'Latest call with $name';
  }

  @override
  String get callsQuickPeople => 'Quick call';

  @override
  String get callsQuickAdd => 'Add';

  @override
  String callsResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matching calls',
      one: '1 matching call',
      zero: 'No matching calls',
    );
    return '$_temp0';
  }

  @override
  String get activeCallTitle => 'Call';

  @override
  String get activeCallInvalidChat => 'Invalid chat id';

  @override
  String get activeCallRefresh => 'Refresh call status';

  @override
  String activeCallResponseFailed(Object error) {
    return 'Call response failed: $error';
  }

  @override
  String activeCallEndFailed(Object error) {
    return 'Failed to end call: $error';
  }

  @override
  String get activeCallVoice => 'Voice';

  @override
  String get activeCallVideo => 'Video';

  @override
  String get activeCallRinging => 'Ringing';

  @override
  String get activeCallActive => 'Active';

  @override
  String get activeCallEnded => 'Ended';

  @override
  String get activeCallMissed => 'Missed';

  @override
  String get activeCallDeclined => 'Declined';

  @override
  String get activeCallVideoPreview => 'Video preview is ready';

  @override
  String get activeCallCameraOn => 'Camera on';

  @override
  String get activeCallCameraOff => 'Camera off';

  @override
  String get activeCallAnswer => 'Answer';

  @override
  String get activeCallDecline => 'Decline';

  @override
  String get activeCallEnd => 'End call';

  @override
  String get activeCallMute => 'Mute';

  @override
  String get activeCallUnmute => 'Unmute';

  @override
  String get activeCallSpeaker => 'Speaker';

  @override
  String get groupTypeGroup => 'Group';

  @override
  String get groupTypeChannel => 'Channel';

  @override
  String get groupTypeStep => 'Type';

  @override
  String get groupDetailsStep => 'Details';

  @override
  String get groupPrivacyStep => 'Privacy';

  @override
  String get groupReviewStep => 'Review';

  @override
  String get groupWizardTypeSubtitle => 'Choose what you want to create.';

  @override
  String get groupWizardDetailsSubtitle =>
      'Set the name and short description.';

  @override
  String get groupWizardPrivacySubtitle =>
      'Decide if the chat should be public or private.';

  @override
  String get groupWizardReviewSubtitle =>
      'Check your settings before creating.';

  @override
  String get groupNewGroup => 'New group';

  @override
  String get groupNewChannel => 'New channel';

  @override
  String get groupCreateOrJoin => 'Create or join';

  @override
  String get groupCreateSharedSubtitle =>
      'Create a shared chat for members and discussion';

  @override
  String get groupCreateBroadcastSubtitle =>
      'Create a broadcast space for posts and updates';

  @override
  String get groupJoinByInvite => 'Join by invite';

  @override
  String get groupJoinByInviteSubtitle =>
      'Paste an invite link or slug to enter a chat';

  @override
  String get groupTypeGroupSubtitle =>
      'Members can all talk together. Best for teams and friends.';

  @override
  String get groupTypeChannelSubtitle =>
      'Broadcast updates, posts, and announcements to subscribers.';

  @override
  String get groupYourNewChannel => 'Your new channel';

  @override
  String get groupYourNewGroup => 'Your new group';

  @override
  String get groupEditLater => 'You can edit avatar, members, and links later.';

  @override
  String get groupNameLabel => 'Name';

  @override
  String get groupNameHint => 'My team chat';

  @override
  String get groupDescriptionChannelLabel => 'Channel description (optional)';

  @override
  String get groupDescriptionGroupLabel => 'Group description (optional)';

  @override
  String get groupDescriptionChannelHint => 'What this channel is about';

  @override
  String get groupDescriptionGroupHint => 'What this group is for';

  @override
  String get groupPrivate => 'Private';

  @override
  String get groupPrivateSubtitle =>
      'People can join only through an invite link.';

  @override
  String get groupPublic => 'Public';

  @override
  String get groupPublicSubtitle =>
      'People can find it via public username or slug.';

  @override
  String get groupPublicUsername => 'Public username';

  @override
  String get groupEnableComments => 'Enable comments';

  @override
  String get groupEnableCommentsSubtitle =>
      'Members can comment on channel posts in a linked discussion chat.';

  @override
  String get groupBack => 'Back';

  @override
  String get groupContinue => 'Continue';

  @override
  String get groupCreate => 'Create';

  @override
  String get groupCreating => 'Creating...';

  @override
  String get groupAlreadyHaveInvite => 'Already have an invite? Join by link';

  @override
  String get groupVisibility => 'Visibility';

  @override
  String get groupUsernameLabel => 'Username';

  @override
  String get groupCreatedChannel => 'Channel created successfully';

  @override
  String get groupCreatedGroup => 'Group created successfully';

  @override
  String groupCreateFailed(Object error) {
    return 'Failed to create chat: $error';
  }

  @override
  String get groupNameTooShort => 'Name must be at least 3 characters';

  @override
  String get groupUsernameRules =>
      'Use 3-32 chars: letters, digits, dot, underscore';

  @override
  String get groupJoinTitle => 'Join by invite';

  @override
  String get groupJoinHeadline => 'Join with invite link or slug';

  @override
  String get groupJoinSubtitle =>
      'Paste a private invite link or a public slug to preview the chat before joining.';

  @override
  String get groupInviteLinkOrSlug => 'Invite link or slug';

  @override
  String get groupPreviewInvite => 'Preview invite';

  @override
  String get groupInvitePreviewNotFound => 'Invite preview not found.';

  @override
  String get groupJoinChat => 'Join chat';

  @override
  String get groupJoining => 'Joining...';

  @override
  String groupInviteFailedLoad(Object error) {
    return 'Failed to load invite: $error';
  }

  @override
  String groupJoinFailed(Object error) {
    return 'Failed to join chat: $error';
  }

  @override
  String get groupSignInToJoin => 'Sign in to join chats by invite.';

  @override
  String get groupChannelPreview => 'Channel preview';

  @override
  String get groupGroupPreview => 'Group preview';

  @override
  String get groupNoPostsYet => 'No posts yet';

  @override
  String groupManageTitle(Object name) {
    return 'Manage $name';
  }

  @override
  String get groupManageChangeAvatar => 'Change avatar';

  @override
  String get groupManageUploading => 'Uploading...';

  @override
  String get groupManageAvatarUpdated => 'Avatar updated';

  @override
  String get groupManageChatUpdated => 'Chat updated';

  @override
  String get groupManageSaveChanges => 'Save changes';

  @override
  String get groupManageIdentity => 'Identity';

  @override
  String get groupManageLinks => 'Links & metadata';

  @override
  String get groupManageLeaveTitle => 'Leave chat?';

  @override
  String get groupManageLeaveBody => 'You will no longer see this chat.';

  @override
  String get groupManageLeave => 'Leave chat';

  @override
  String get commonEnabled => 'Enabled';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get timeNow => 'now';

  @override
  String get timeYesterday => 'yesterday';

  @override
  String get settingsProfileSetupSubtitle => 'Set up your profile';

  @override
  String get settingsSectionsTitle => 'Settings';

  @override
  String get settingsSectionsSubtitle => 'Only active sections are shown here.';

  @override
  String get settingsStorageTitle => 'Storage';

  @override
  String get settingsStorageSubtitle =>
      'Review app data, drafts, and cleanable cache.';

  @override
  String get settingsStorageBreakdown => 'Storage breakdown';

  @override
  String get settingsStorageBreakdownSubtitle => 'Measured on this device.';

  @override
  String get settingsStorageAppData => 'App data';

  @override
  String get settingsStorageAppDataSubtitle =>
      'Local files required by the app.';

  @override
  String get settingsStorageTemporaryCache => 'Temporary cache';

  @override
  String get settingsStorageTemporaryCacheSubtitle =>
      'Files that can be recreated safely.';

  @override
  String get settingsStorageDrafts => 'Drafts';

  @override
  String settingsStorageDraftsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved drafts',
      one: '1 saved draft',
      zero: 'No saved drafts',
    );
    return '$_temp0';
  }

  @override
  String get settingsStorageActions => 'Actions';

  @override
  String get settingsStorageActionsSubtitle =>
      'Clean only data that is safe to rebuild.';

  @override
  String get settingsStorageRefresh => 'Refresh usage';

  @override
  String get settingsStorageRefreshSubtitle => 'Recalculate local storage now';

  @override
  String get settingsStorageCheckIntegrity => 'Check storage';

  @override
  String get settingsStorageCheckIntegritySubtitle =>
      'Verify schema, folders, and draft records';

  @override
  String get settingsStorageClearTemporary => 'Clear temporary cache';

  @override
  String get settingsStorageClearTemporarySubtitle =>
      'Remove files from the app cache folder';

  @override
  String get settingsStorageClearDrafts => 'Clear message drafts';

  @override
  String get settingsStorageClearDraftsSubtitle =>
      'Remove unsent local draft text';

  @override
  String get settingsStorageClearTemporaryConfirmTitle =>
      'Clear temporary cache?';

  @override
  String get settingsStorageClearTemporaryConfirmBody =>
      'Cached files will be recreated when needed. Account data and settings will stay untouched.';

  @override
  String get settingsStorageClearDraftsConfirmTitle => 'Clear message drafts?';

  @override
  String get settingsStorageClearDraftsConfirmBody =>
      'Unsent draft text saved on this device will be removed.';

  @override
  String get settingsStorageCleared => 'Storage cleaned';

  @override
  String get settingsStorageHealthOkTitle => 'Storage is healthy';

  @override
  String settingsStorageHealthOkBody(int schemaVersion) {
    return 'Local schema version $schemaVersion is ready and no integrity issues were found.';
  }

  @override
  String get settingsStorageHealthIssueTitle => 'Storage needs attention';

  @override
  String get settingsStorageUsedByApp => 'Used by NiosMess on this device';

  @override
  String settingsStorageCleanable(Object size) {
    return '$size can be cleaned without logging out.';
  }

  @override
  String get settingsLegalPoliciesSubtitle =>
      'Policy documents. Licenses are in the hidden menu.';

  @override
  String get settingsHiddenMenuTitle => 'Hidden tools';

  @override
  String get settingsHiddenMenuSubtitle =>
      'Long-press app version to open this menu.';

  @override
  String get settingsDiagnosticsTitle => 'Diagnostics';

  @override
  String get settingsDiagnosticsSubtitle =>
      'Runtime details, API target, and build state';

  @override
  String settingsDiagnosticsStorageSummary(int schemaVersion, Object size) {
    return 'Schema v$schemaVersion, $size stored locally';
  }

  @override
  String get settingsDiagnosticsLogsTitle => 'Local logs';

  @override
  String get settingsDiagnosticsLogsSubtitle =>
      'Last errors and runtime events kept on this device.';

  @override
  String get settingsDiagnosticsNoLogs => 'No local errors recorded';

  @override
  String get settingsDiagnosticsActions => 'Diagnostics actions';

  @override
  String get settingsDiagnosticsRefresh => 'Refresh diagnostics';

  @override
  String get settingsDiagnosticsRefreshSubtitle =>
      'Reload build, storage, sound and log state';

  @override
  String get settingsDiagnosticsTestSound => 'Test interface sound';

  @override
  String get settingsDiagnosticsTestSoundSubtitle =>
      'Play the current navigation click';

  @override
  String get settingsDiagnosticsCopyLogs => 'Copy local logs';

  @override
  String get settingsDiagnosticsCopyLogsSubtitle =>
      'Copy recent errors and events to clipboard';

  @override
  String get settingsDiagnosticsLogsCopied => 'Local logs copied';

  @override
  String get settingsEditProfileSubtitle => 'Change name, avatar, and bio';

  @override
  String get appearanceVariantTonalSpot => 'Tonal spot';

  @override
  String get appearanceVariantVibrant => 'Vibrant';

  @override
  String get appearanceVariantExpressive => 'Expressive';

  @override
  String get appearanceVariantNeutral => 'Neutral';

  @override
  String get appearanceVariantMonochrome => 'Monochrome';

  @override
  String get appearanceVariantFidelity => 'Fidelity';

  @override
  String get appearancePaletteNiosMess => 'NiosMess';

  @override
  String get appearancePaletteOcean => 'Ocean';

  @override
  String get appearancePaletteForest => 'Forest';

  @override
  String get appearancePaletteSunset => 'Sunset';

  @override
  String get appearancePaletteRose => 'Rose';

  @override
  String get appearancePaletteSignal => 'Signal';

  @override
  String get resetPasswordRequestTitle => 'Reset password';

  @override
  String get resetPasswordRequestHeroTitle => 'Reset password';

  @override
  String get resetPasswordRequestHeroSubtitle =>
      'We will send a reset code to your email.';

  @override
  String get resetPasswordRequestEmailLabel => 'Email';

  @override
  String get resetPasswordRequestEmailError => 'Enter valid email';

  @override
  String get resetPasswordRequestSubmit => 'Send code';

  @override
  String get resetPasswordRequestSubmitting => 'Sending...';

  @override
  String get resetPasswordRequestSent => 'Request sent';

  @override
  String get resetPasswordConfirmTitle => 'Confirm reset';

  @override
  String get resetPasswordConfirmHeroTitle => 'Enter code';

  @override
  String get resetPasswordConfirmHeroSubtitle =>
      'Enter the code we sent to your email.';

  @override
  String get resetPasswordConfirmEmailLabel => 'Email';

  @override
  String get resetPasswordConfirmEmailError => 'Enter valid email';

  @override
  String get resetPasswordConfirmCodeLabel => 'Code';

  @override
  String get resetPasswordConfirmCodeError => 'Enter 6 digits';

  @override
  String get resetPasswordConfirmPasswordLabel => 'New password';

  @override
  String get resetPasswordConfirmPasswordError => 'Minimum 8 characters';

  @override
  String get resetPasswordConfirmSubmit => 'Reset password';

  @override
  String get resetPasswordConfirmSubmitting => 'Applying...';

  @override
  String get resetPasswordConfirmDone => 'Password reset successfully';

  @override
  String get sessionsTitle => 'Active sessions';

  @override
  String get sessionsRevokeTitle => 'Revoke session?';

  @override
  String get sessionsRevokeConfirm => 'Revoke';

  @override
  String get sessionsCancel => 'Cancel';

  @override
  String get sessionsRevokeTooltip => 'Revoke session';

  @override
  String get sessionsRevokedSuccess => 'Session revoked';

  @override
  String get sessionsEmpty => 'No active sessions';

  @override
  String get sessionsRetry => 'Retry';

  @override
  String get sessionsRevokeAll => 'Revoke all other sessions';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get contactsRecent => 'Recent';

  @override
  String get contactsRecentPeople => 'Recent people...';

  @override
  String get contactsSearch => 'Search';

  @override
  String get contactsNoRecent => 'No recent contacts yet...';

  @override
  String get contactsTypeUsername => 'Type a username...';

  @override
  String get contactsNoMatches => 'No matches found.';

  @override
  String get contactsMessage => 'Message';

  @override
  String get contactsChat => 'Chat';

  @override
  String get contactDetailTitle => 'Contact';

  @override
  String get contactDetailOverview => 'Contact overview';

  @override
  String get contactDetailSharedContext => 'Shared context';

  @override
  String get contactDetailUsername => 'Username';

  @override
  String get contactDetailBio => 'Bio';

  @override
  String get contactDetailSharedContextDesc =>
      'Mutual groups and shared media will appear here as soon as this data becomes available from the API.';

  @override
  String get contactDetailNoBio => 'No public bio yet';

  @override
  String get contactsSubtitle =>
      'Recent people, quick message actions, and search across users.';

  @override
  String get contactsNotAuth => 'You are not authenticated yet.';

  @override
  String get contactsNoRecentFull =>
      'No recent contacts yet.\nStart a conversation from the Search tab.';

  @override
  String get contactsSearchHint => 'Search by username, name, or text';

  @override
  String get contactsSearchEmpty =>
      'Type a username or name to search users, chats, and messages.';

  @override
  String get contactsUsers => 'Users';

  @override
  String get contactsChats => 'Chats';

  @override
  String get contactsMessages => 'Messages';

  @override
  String get contactsNoMessagesYet => 'No messages yet';

  @override
  String contactsForwardedFrom(Object name) {
    return 'Forwarded from $name';
  }

  @override
  String get mediaActionSave => 'Save';

  @override
  String get mediaActionCopy => 'Copy link';

  @override
  String get mediaActionOpenIn => 'Open in...';

  @override
  String get mediaViewerTitle => 'Attachment';

  @override
  String get mediaViewerCannotPreview => 'Cannot preview this file';

  @override
  String get mediaViewerOpenExternal => 'Open Externally';

  @override
  String get chatUploadCancelTitle => 'Cancel upload?';

  @override
  String get chatUploadCancelBody => 'Media is uploading. Cancel it?';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get chatScrollToBottom => 'Scroll to latest';

  @override
  String chatTypingOne(Object name) {
    return '$name is typing...';
  }

  @override
  String get chatTypingMultiple => 'Several people are typing...';

  @override
  String chatUnreadMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
    );
    return '$_temp0';
  }

  @override
  String get chatEditingMessage => 'Editing';

  @override
  String get chatEditCancel => 'Cancel editing';

  @override
  String get chatScrollLoadingEarlier => 'Loading messages...';

  @override
  String get appearanceOptimizeWeakDevices => 'Optimize for weak devices';

  @override
  String get appearanceOptimizeWeakDevicesSubtitle =>
      'Disables background blur and heavy BackdropFilter effects to increase FPS';

  @override
  String get searchSemantic => 'Semantic search';

  @override
  String get searchSemanticHint => 'Search by meaning using AI';

  @override
  String get searchSemanticFallback =>
      'Semantic search is temporarily unavailable. Regular search performed.';

  @override
  String get chatCreatePersonal => 'Create direct chat';

  @override
  String get chatCreatePersonalSubtitle =>
      'Start a direct conversation by username';

  @override
  String get chatCreatePersonalPrompt => 'Start direct chat';

  @override
  String get chatCreatePersonalUsernameLabel => 'Username';

  @override
  String get chatCreatePersonalUsernameHint => 'username';

  @override
  String get chatCreatePersonalStart => 'Start';

  @override
  String get chatCreatePersonalErrorEmpty => 'Username cannot be empty';

  @override
  String get settingsAdminTitle => 'Admin Panel';

  @override
  String get settingsAdminSubtitle => 'Manage users and chats';

  @override
  String get settingsBadgesTitle => 'Badges';

  @override
  String get settingsBadgesSubtitle => 'View and manage profile badges';

  @override
  String get settingsBotsTitle => 'Bots';

  @override
  String get settingsBotsSubtitle => 'Create and manage your bots';

  @override
  String get settingsSecretChatsTitle => 'Secret Chats';

  @override
  String get settingsSecretChatsSubtitle => 'End-to-end encrypted messaging';

  @override
  String get settingsSecretChatsButton => 'Secret Chat';

  @override
  String adminUserBanned(int id) {
    return 'User $id banned';
  }

  @override
  String adminUserUnbanned(int id) {
    return 'User $id unbanned';
  }

  @override
  String adminUserFrozen(int id) {
    return 'User $id frozen';
  }

  @override
  String adminUserUnfrozen(int id) {
    return 'User $id unfrozen';
  }

  @override
  String adminSpamBlockEnabled(int id) {
    return 'Spam block enabled for user $id';
  }

  @override
  String adminSpamBlockDisabled(int id) {
    return 'Spam block disabled for user $id';
  }

  @override
  String adminChatBanned(int id) {
    return 'Chat $id banned';
  }

  @override
  String adminChatUnbanned(int id) {
    return 'Chat $id unbanned';
  }

  @override
  String adminTabUsers(int count) {
    return 'Users ($count)';
  }

  @override
  String adminTabChats(int count) {
    return 'Chats ($count)';
  }

  @override
  String get adminActionBan => 'Ban';

  @override
  String get adminActionUnban => 'Unban';

  @override
  String get adminActionFreeze => 'Freeze';

  @override
  String get adminActionUnfreeze => 'Unfreeze';

  @override
  String get adminActionSpamBlock => 'Spam Block';

  @override
  String get adminActionUnspamBlock => 'Remove Spam Block';

  @override
  String get badgeCreateTitle => 'Create Badge';

  @override
  String get badgeAwardTitle => 'Award Badge';

  @override
  String get badgeActionCreate => 'Create';

  @override
  String get badgeActionAward => 'Award';

  @override
  String get badgeCreated => 'Badge created';

  @override
  String badgeDeleted(int id) {
    return 'Badge $id deleted';
  }

  @override
  String badgeAwarded(int badgeId, int userId) {
    return 'Badge $badgeId awarded to user $userId';
  }

  @override
  String get badgeNoBadges => 'No badges available';

  @override
  String get badgeListRefresh => 'Refresh';

  @override
  String get botCreateTitle => 'Create Bot';

  @override
  String get botBotToken => 'Bot Token';

  @override
  String get botActionUse => 'Use';

  @override
  String get botTokenCopied => 'Token copied';

  @override
  String get botNoUpdates => 'No updates';

  @override
  String get e2eeKeyGenerated => 'E2EE key generated and uploaded';

  @override
  String get mediaDownloadAndOpen => 'Download & Open';

  @override
  String mediaSavedTo(Object path) {
    return 'Saved to $path';
  }

  @override
  String get mediaDownloadFailedExt =>
      'Could not download. Try opening externally.';

  @override
  String mediaDownloadFailed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String get dialogCancelChatCreationTitle => 'Cancel?';

  @override
  String get dialogCancelChatCreationBody =>
      'Chat creation is in progress. Cancel?';

  @override
  String get dialogCancelCommentTitle => 'Cancel?';

  @override
  String get dialogCancelCommentBody =>
      'Comment sending is in progress. Cancel?';

  @override
  String get emptyStateNoItems => 'No items found';

  @override
  String get emptyStateNoItemsDesc => 'There\'s nothing to show here yet.';

  @override
  String get offlineWaiting => 'Waiting for network...';

  @override
  String get filePreviewSave => 'Save';

  @override
  String get filePreviewLink => 'Link';

  @override
  String get filePreviewOpen => 'Open';

  @override
  String get filePreviewForward => 'Forward';

  @override
  String get filePreviewFileName => 'File name';

  @override
  String get filePreviewClose => 'Close';

  @override
  String get filePreviewLinkCopied => 'Link copied to clipboard';

  @override
  String get filePreviewPathCopied => 'File path copied to clipboard';

  @override
  String get filePreviewSaved => 'File saved';

  @override
  String filePreviewSaveError(Object error) {
    return 'Could not save file: $error';
  }

  @override
  String get filePreviewPause => 'Pause';

  @override
  String get filePreviewPlay => 'Play';

  @override
  String get filePickerGallery => 'Gallery';

  @override
  String get filePickerDocument => 'Document';

  @override
  String get filePickerAudio => 'Audio';

  @override
  String get filePickerFile => 'File';

  @override
  String get filePickerReadError => 'Could not read selected file';

  @override
  String get badgeFieldName => 'Name';

  @override
  String get badgeFieldDescription => 'Description';

  @override
  String get badgeFieldIcon => 'Icon (emoji)';

  @override
  String get badgeFieldColor => 'Color (hex)';

  @override
  String get badgeFieldUserId => 'User ID';

  @override
  String get badgeFieldBadgeId => 'Badge ID';

  @override
  String get badgeAdminPassword => 'Admin Password';

  @override
  String get badgeAdminMode => 'Admin Mode';

  @override
  String get badgeAdminSubtitle => 'Show admin badge management';

  @override
  String get botFieldName => 'Bot Name';

  @override
  String get botFieldUsername => 'Username';

  @override
  String get botFieldDescription => 'Description (optional)';

  @override
  String get botFieldToken => 'Enter bot token';

  @override
  String get botSectionTitle => 'Bots';

  @override
  String get botSectionSubtitle => 'Create and manage your bots.';

  @override
  String get botCreateSubtitle => 'Create a new bot';

  @override
  String get botCreateDescription => 'Register a bot account';

  @override
  String get botUpdatesTitle => 'Bot Updates';

  @override
  String get botGetUpdates => 'Get updates';

  @override
  String get botPollSubtitle => 'Poll for new bot messages and callbacks';

  @override
  String get botCreated => 'Bot created!';

  @override
  String get botCopied => 'Copied';

  @override
  String get fluidPreviewM3Title => 'M3 Expressive Design';

  @override
  String get fluidPreviewM3Subtitle =>
      'New indicators and smooth transitions are already available!';

  @override
  String get profileAvatarUpdated => 'Avatar updated';

  @override
  String profileError(Object error) {
    return 'Error: $error';
  }

  @override
  String get chatImageUnavailable => 'Image unavailable';

  @override
  String get settingsRevokeSession => 'Revoke session';
}

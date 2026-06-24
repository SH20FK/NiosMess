import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'NiosMess'**
  String get appName;

  /// No description provided for @tabChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get tabChats;

  /// No description provided for @tabCalls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get tabCalls;

  /// No description provided for @tabContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get tabContacts;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get commonPreview;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get commonSystem;

  /// No description provided for @commonLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get commonLight;

  /// No description provided for @commonDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get commonDark;

  /// No description provided for @commonAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get commonAutomatic;

  /// No description provided for @commonManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get commonManual;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No public description yet.'**
  String get commonNoDescription;

  /// No description provided for @commonFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String commonFailed(Object error);

  /// No description provided for @commonPasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get commonPasteFromClipboard;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Fluid connection, clear communication'**
  String get splashTagline;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email or username.'**
  String get loginSubtitle;

  /// No description provided for @loginIdentifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get loginIdentifierLabel;

  /// No description provided for @loginIdentifierError.
  ///
  /// In en, this message translates to:
  /// **'Enter email or username'**
  String get loginIdentifierError;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Minimum 4 characters'**
  String get loginPasswordError;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSubmit;

  /// No description provided for @loginSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get loginSubmitting;

  /// No description provided for @loginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get loginCreateAccount;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @twoFaTitle.
  ///
  /// In en, this message translates to:
  /// **'Security check'**
  String get twoFaTitle;

  /// No description provided for @twoFaHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your 2FA code'**
  String get twoFaHeroTitle;

  /// No description provided for @twoFaHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to your email. This keeps your NiosMess session protected.'**
  String get twoFaHeroSubtitle;

  /// No description provided for @twoFaCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get twoFaCodeLabel;

  /// No description provided for @twoFaCodeError.
  ///
  /// In en, this message translates to:
  /// **'Enter 6 digits'**
  String get twoFaCodeError;

  /// No description provided for @twoFaVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get twoFaVerify;

  /// No description provided for @twoFaVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get twoFaVerifying;

  /// No description provided for @twoFaProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected sign-in'**
  String get twoFaProtected;

  /// No description provided for @twoFaExpires.
  ///
  /// In en, this message translates to:
  /// **'Short-lived code'**
  String get twoFaExpires;

  /// No description provided for @twoFaHint.
  ///
  /// In en, this message translates to:
  /// **'Tip: paste the code directly; spaces are ignored.'**
  String get twoFaHint;

  /// No description provided for @twoFaFailed.
  ///
  /// In en, this message translates to:
  /// **'2FA verification failed'**
  String get twoFaFailed;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitle;

  /// No description provided for @registerEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get registerEmailLabel;

  /// No description provided for @registerEmailError.
  ///
  /// In en, this message translates to:
  /// **'Enter valid email'**
  String get registerEmailError;

  /// No description provided for @registerUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get registerUsernameLabel;

  /// No description provided for @registerUsernameError.
  ///
  /// In en, this message translates to:
  /// **'At least 3 characters'**
  String get registerUsernameError;

  /// No description provided for @registerDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get registerDisplayNameLabel;

  /// No description provided for @registerDisplayNameError.
  ///
  /// In en, this message translates to:
  /// **'At least 2 characters'**
  String get registerDisplayNameError;

  /// No description provided for @registerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get registerPasswordLabel;

  /// No description provided for @registerPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get registerPasswordError;

  /// No description provided for @registerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerSubmit;

  /// No description provided for @registerSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get registerSubmitting;

  /// No description provided for @registerFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registerFailed;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get verifyEmailCodeLabel;

  /// No description provided for @verifyEmailCodeError.
  ///
  /// In en, this message translates to:
  /// **'Enter 6 digits'**
  String get verifyEmailCodeError;

  /// No description provided for @verifyEmailSubmit.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyEmailSubmit;

  /// No description provided for @verifyEmailSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifyEmailSubmitting;

  /// No description provided for @verifyEmailDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get verifyEmailDone;

  /// No description provided for @setupWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Nice to meet you!'**
  String get setupWelcomeTitle;

  /// No description provided for @setupWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Let\'s quickly set up NiosMess for you.\nThis takes about 30 seconds.'**
  String get setupWelcomeBody;

  /// No description provided for @setupLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get setupLanguageTitle;

  /// No description provided for @setupTimezoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your time zone'**
  String get setupTimezoneTitle;

  /// No description provided for @setupTimezoneUseDevice.
  ///
  /// In en, this message translates to:
  /// **'Uses your device\'s current time zone'**
  String get setupTimezoneUseDevice;

  /// No description provided for @setupTimezoneChooseManual.
  ///
  /// In en, this message translates to:
  /// **'Choose manually'**
  String get setupTimezoneChooseManual;

  /// No description provided for @setupStartMessaging.
  ///
  /// In en, this message translates to:
  /// **'Start messaging'**
  String get setupStartMessaging;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageRussianNative.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussianNative;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profilePublicView.
  ///
  /// In en, this message translates to:
  /// **'Your public view'**
  String get profilePublicView;

  /// No description provided for @profilePublicProfile.
  ///
  /// In en, this message translates to:
  /// **'Public profile'**
  String get profilePublicProfile;

  /// No description provided for @profileMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileMessage;

  /// No description provided for @profileCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get profileCall;

  /// No description provided for @profileVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get profileVideo;

  /// No description provided for @profileAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAbout;

  /// No description provided for @profileDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayName;

  /// No description provided for @profileUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileUsername;

  /// No description provided for @profileDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get profileDescription;

  /// No description provided for @profilePreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profilePreferences;

  /// No description provided for @profileMyProfile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get profileMyProfile;

  /// No description provided for @profileQuickSettings.
  ///
  /// In en, this message translates to:
  /// **'Quick settings'**
  String get profileQuickSettings;

  /// No description provided for @profileDoNotDisturb.
  ///
  /// In en, this message translates to:
  /// **'Do not disturb'**
  String get profileDoNotDisturb;

  /// No description provided for @profileDoNotDisturbSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pause push notifications on this device'**
  String get profileDoNotDisturbSubtitle;

  /// No description provided for @profileHideOnline.
  ///
  /// In en, this message translates to:
  /// **'Hide online'**
  String get profileHideOnline;

  /// No description provided for @profileHideOnlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep presence quieter in the app UI'**
  String get profileHideOnlineSubtitle;

  /// No description provided for @profileStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get profileStorage;

  /// No description provided for @profileStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used'**
  String profileStorageUsed(Object used, Object total);

  /// No description provided for @profileAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountSection;

  /// No description provided for @profileDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get profileDangerZone;

  /// No description provided for @profileAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearance;

  /// No description provided for @profileAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme mode, colors, density'**
  String get profileAppearanceSubtitle;

  /// No description provided for @profileHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get profileHaptics;

  /// No description provided for @profileHapticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback on taps and controls'**
  String get profileHapticsSubtitle;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// No description provided for @profileAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profile, password, sessions'**
  String get profileAccountSubtitle;

  /// No description provided for @profilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get profilePrivacy;

  /// No description provided for @profilePrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visibility and permissions'**
  String get profilePrivacySubtitle;

  /// No description provided for @profileHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get profileHelp;

  /// No description provided for @profileHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ, support, contacts'**
  String get profileHelpSubtitle;

  /// No description provided for @profileSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get profileSession;

  /// No description provided for @profileLogoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log out from this device only.'**
  String get profileLogoutSubtitle;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogout;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEdit;

  /// No description provided for @profileThemeStudio.
  ///
  /// In en, this message translates to:
  /// **'Theme studio'**
  String get profileThemeStudio;

  /// No description provided for @profileGuestName.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuestName;

  /// No description provided for @profileGuestUsername.
  ///
  /// In en, this message translates to:
  /// **'guest'**
  String get profileGuestUsername;

  /// No description provided for @profileDefaultBio.
  ///
  /// In en, this message translates to:
  /// **'NiosMess user'**
  String get profileDefaultBio;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme studio'**
  String get appearanceStudioTitle;

  /// No description provided for @appearanceStudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tune palette, mode, density, and feedback with a live preview.'**
  String get appearanceStudioSubtitle;

  /// No description provided for @appearancePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get appearancePreviewTitle;

  /// No description provided for @appearancePreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A compact look at your current UI style.'**
  String get appearancePreviewSubtitle;

  /// No description provided for @appearancePreviewChat.
  ///
  /// In en, this message translates to:
  /// **'Preview chat'**
  String get appearancePreviewChat;

  /// No description provided for @appearanceIncomingPreview.
  ///
  /// In en, this message translates to:
  /// **'Incoming message preview'**
  String get appearanceIncomingPreview;

  /// No description provided for @appearanceAccentPreview.
  ///
  /// In en, this message translates to:
  /// **'Accent color preview'**
  String get appearanceAccentPreview;

  /// No description provided for @appearanceThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get appearanceThemeMode;

  /// No description provided for @appearanceModeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow device'**
  String get appearanceModeSystemSubtitle;

  /// No description provided for @appearanceModeLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clean daylight UI'**
  String get appearanceModeLightSubtitle;

  /// No description provided for @appearanceModeDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Low-glare night UI'**
  String get appearanceModeDarkSubtitle;

  /// No description provided for @appearanceAccentPalette.
  ///
  /// In en, this message translates to:
  /// **'Accent palette'**
  String get appearanceAccentPalette;

  /// No description provided for @appearanceAccentPaletteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Material 3 generates the whole color system from this seed.'**
  String get appearanceAccentPaletteSubtitle;

  /// No description provided for @appearanceMaterialVariant.
  ///
  /// In en, this message translates to:
  /// **'Material variant'**
  String get appearanceMaterialVariant;

  /// No description provided for @appearanceInteraction.
  ///
  /// In en, this message translates to:
  /// **'Interaction'**
  String get appearanceInteraction;

  /// No description provided for @appearanceInteractionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Behavior, region and motion preferences.'**
  String get appearanceInteractionSubtitle;

  /// No description provided for @appearanceCompactMode.
  ///
  /// In en, this message translates to:
  /// **'Compact mode'**
  String get appearanceCompactMode;

  /// No description provided for @appearanceCompactModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tighter spacing in chat and list screens'**
  String get appearanceCompactModeSubtitle;

  /// No description provided for @appearanceDarkCallBackdrop.
  ///
  /// In en, this message translates to:
  /// **'Dark call backdrop'**
  String get appearanceDarkCallBackdrop;

  /// No description provided for @appearanceDarkCallBackdropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Darker style on active call screen'**
  String get appearanceDarkCallBackdropSubtitle;

  /// No description provided for @appearanceHapticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap feedback for chips, buttons, and rows'**
  String get appearanceHapticsSubtitle;

  /// No description provided for @appearanceSoundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get appearanceSoundEffects;

  /// No description provided for @appearanceSoundEffectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Message tones, call sounds, and navigation clicks'**
  String get appearanceSoundEffectsSubtitle;

  /// No description provided for @appearanceSoundVolume.
  ///
  /// In en, this message translates to:
  /// **'Sound volume'**
  String get appearanceSoundVolume;

  /// No description provided for @appearanceSoundVolumeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Controls interface clicks, messages and call tones'**
  String get appearanceSoundVolumeSubtitle;

  /// No description provided for @appearanceSoundVolumeValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String appearanceSoundVolumeValue(int percent);

  /// No description provided for @appearanceLanguageRegion.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get appearanceLanguageRegion;

  /// No description provided for @appearanceLanguageRegionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App language, time zone, and regional format'**
  String get appearanceLanguageRegionSubtitle;

  /// No description provided for @languageRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get languageRegionTitle;

  /// No description provided for @languageRegionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose app language and how time is shown.'**
  String get languageRegionSubtitle;

  /// No description provided for @languageRegionAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageRegionAppLanguage;

  /// No description provided for @languageRegionUseSystemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use system language'**
  String get languageRegionUseSystemLanguage;

  /// No description provided for @languageRegionTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get languageRegionTimeZone;

  /// No description provided for @languageRegionTimeZoneMode.
  ///
  /// In en, this message translates to:
  /// **'Time zone mode'**
  String get languageRegionTimeZoneMode;

  /// No description provided for @languageRegionCurrentTime.
  ///
  /// In en, this message translates to:
  /// **'Current time in app'**
  String get languageRegionCurrentTime;

  /// No description provided for @languageRegionSelectTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Select time zone'**
  String get languageRegionSelectTimeZone;

  /// No description provided for @languageRegionSearchTimeZones.
  ///
  /// In en, this message translates to:
  /// **'Search time zones'**
  String get languageRegionSearchTimeZones;

  /// No description provided for @settingsAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountTitle;

  /// No description provided for @settingsCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings center'**
  String get settingsCenterTitle;

  /// No description provided for @settingsCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account, appearance, privacy and support in one place.'**
  String get settingsCenterSubtitle;

  /// No description provided for @settingsQuickControls.
  ///
  /// In en, this message translates to:
  /// **'Quick controls'**
  String get settingsQuickControls;

  /// No description provided for @settingsPersonalizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get settingsPersonalizationTitle;

  /// No description provided for @settingsPersonalizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, language, density and interaction style'**
  String get settingsPersonalizationSubtitle;

  /// No description provided for @settingsAccountSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Account & security'**
  String get settingsAccountSecurityTitle;

  /// No description provided for @settingsAccountSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Identity, recovery, sessions and 2FA'**
  String get settingsAccountSecuritySubtitle;

  /// No description provided for @settingsPrivacyNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & notifications'**
  String get settingsPrivacyNotificationsTitle;

  /// No description provided for @settingsPrivacyNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visibility, alerts, receipts and server limits'**
  String get settingsPrivacyNotificationsSubtitle;

  /// No description provided for @settingsSupportAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'Support & about'**
  String get settingsSupportAboutTitle;

  /// No description provided for @settingsSupportAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help, build info, legal pages and project links'**
  String get settingsSupportAboutSubtitle;

  /// No description provided for @settingsAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profile identity, security, sessions, and account recovery.'**
  String get settingsAccountSubtitle;

  /// No description provided for @settingsAccountAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Account access'**
  String get settingsAccountAccessTitle;

  /// No description provided for @settingsAccountAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verification and recovery tools for your account.'**
  String get settingsAccountAccessSubtitle;

  /// No description provided for @settingsProtectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Protection'**
  String get settingsProtectionTitle;

  /// No description provided for @settingsProtectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep account access under control.'**
  String get settingsProtectionSubtitle;

  /// No description provided for @settingsSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurityTitle;

  /// No description provided for @settingsSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage app access, trusted devices, alerts, and protection levels.'**
  String get settingsSecuritySubtitle;

  /// No description provided for @settingsSecurityCheckupTitle.
  ///
  /// In en, this message translates to:
  /// **'Security checkup'**
  String get settingsSecurityCheckupTitle;

  /// No description provided for @settingsSecurityCheckupEnabled.
  ///
  /// In en, this message translates to:
  /// **'Your account already has a stronger sign-in layer.'**
  String get settingsSecurityCheckupEnabled;

  /// No description provided for @settingsSecurityCheckupDisabled.
  ///
  /// In en, this message translates to:
  /// **'Enable extra protection for sign-in and recovery.'**
  String get settingsSecurityCheckupDisabled;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications, message visibility, and delivery-related account limits.'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsPrivacyVisibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get settingsPrivacyVisibilityTitle;

  /// No description provided for @settingsPrivacyVisibilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What the app surfaces on this device and to other people.'**
  String get settingsPrivacyVisibilitySubtitle;

  /// No description provided for @settingsHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsHelpTitle;

  /// No description provided for @settingsHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support options, common questions, and quick issue reporting.'**
  String get settingsHelpSubtitle;

  /// No description provided for @settingsHelpSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsHelpSupportTitle;

  /// No description provided for @settingsHelpSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get answers, contact support, or send a bug report.'**
  String get settingsHelpSupportSubtitle;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About NiosMess'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build information, diagnostics, legal links, and runtime environment.'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsBuildSnapshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Build snapshot'**
  String get settingsBuildSnapshotTitle;

  /// No description provided for @settingsBuildSnapshotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Structured communication with a clean Material 3 interface.'**
  String get settingsBuildSnapshotSubtitle;

  /// No description provided for @settingsRuntimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime environment'**
  String get settingsRuntimeTitle;

  /// No description provided for @settingsRuntimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Current app target, storage model and backend state.'**
  String get settingsRuntimeSubtitle;

  /// No description provided for @settingsLinksCreditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Project links'**
  String get settingsLinksCreditsTitle;

  /// No description provided for @settingsLinksCreditsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Public pages for NiosMess.'**
  String get settingsLinksCreditsSubtitle;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsApi.
  ///
  /// In en, this message translates to:
  /// **'API'**
  String get settingsApi;

  /// No description provided for @settingsApiEnvironment.
  ///
  /// In en, this message translates to:
  /// **'API environment'**
  String get settingsApiEnvironment;

  /// No description provided for @settingsReleaseChannel.
  ///
  /// In en, this message translates to:
  /// **'Release channel'**
  String get settingsReleaseChannel;

  /// No description provided for @settingsLocalStorage.
  ///
  /// In en, this message translates to:
  /// **'Local storage'**
  String get settingsLocalStorage;

  /// No description provided for @settingsProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get settingsProduction;

  /// No description provided for @settingsClientCache.
  ///
  /// In en, this message translates to:
  /// **'Client cache'**
  String get settingsClientCache;

  /// No description provided for @settingsReleaseLiveHint.
  ///
  /// In en, this message translates to:
  /// **'This build connects to the live NiosMess API.'**
  String get settingsReleaseLiveHint;

  /// No description provided for @settingsLocalStorageHint.
  ///
  /// In en, this message translates to:
  /// **'Messages, drafts, and session data are stored locally.'**
  String get settingsLocalStorageHint;

  /// No description provided for @settingsDevelopers.
  ///
  /// In en, this message translates to:
  /// **'Developers'**
  String get settingsDevelopers;

  /// No description provided for @settingsDevelopersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Meet the people behind NiosMess'**
  String get settingsDevelopersSubtitle;

  /// No description provided for @settingsOpenWebsite.
  ///
  /// In en, this message translates to:
  /// **'Open website'**
  String get settingsOpenWebsite;

  /// No description provided for @settingsOpenWebsiteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open {url} in your browser'**
  String settingsOpenWebsiteSubtitle(Object url);

  /// No description provided for @settingsCopyApiUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy API base URL'**
  String get settingsCopyApiUrl;

  /// No description provided for @settingsApiUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'API base URL copied'**
  String get settingsApiUrlCopied;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review Flutter and package licenses used by the app'**
  String get settingsLicensesSubtitle;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsOfService;

  /// No description provided for @settingsLegalTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegalTitle;

  /// No description provided for @settingsLegalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Policies and licenses'**
  String get settingsLegalSubtitle;

  /// No description provided for @settingsCouldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open link in browser'**
  String get settingsCouldNotOpenLink;

  /// No description provided for @settingsPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get settingsPushNotifications;

  /// No description provided for @settingsPushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Message and call updates on this device'**
  String get settingsPushNotificationsSubtitle;

  /// No description provided for @settingsReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Read receipts'**
  String get settingsReadReceipts;

  /// No description provided for @settingsReadReceiptsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let others know you\'ve seen their messages'**
  String get settingsReadReceiptsSubtitle;

  /// No description provided for @settingsTypingIndicator.
  ///
  /// In en, this message translates to:
  /// **'Typing indicator'**
  String get settingsTypingIndicator;

  /// No description provided for @settingsTypingIndicatorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show when you are typing a message'**
  String get settingsTypingIndicatorSubtitle;

  /// No description provided for @settingsSpamBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Spam block active'**
  String get settingsSpamBlockTitle;

  /// No description provided for @settingsSpamBlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You cannot start new DMs, join groups, or be invited. Contact support if this is a mistake.'**
  String get settingsSpamBlockSubtitle;

  /// No description provided for @settingsServerLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Server-side limits'**
  String get settingsServerLimitsTitle;

  /// No description provided for @settingsServerLimitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Typing indicator and read receipts are currently enforced by the backend and will become configurable later.'**
  String get settingsServerLimitsSubtitle;

  /// No description provided for @settingsTwoFactorStatus.
  ///
  /// In en, this message translates to:
  /// **'Two-factor status'**
  String get settingsTwoFactorStatus;

  /// No description provided for @settingsTwoFactor.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get settingsTwoFactor;

  /// No description provided for @settingsTwoFactorEnabledShort.
  ///
  /// In en, this message translates to:
  /// **'Enabled on your account'**
  String get settingsTwoFactorEnabledShort;

  /// No description provided for @settingsTwoFactorDisabledShort.
  ///
  /// In en, this message translates to:
  /// **'Disabled on your account'**
  String get settingsTwoFactorDisabledShort;

  /// No description provided for @settingsTwoFactorOpenAccount.
  ///
  /// In en, this message translates to:
  /// **'Open account settings to enable or disable 2FA'**
  String get settingsTwoFactorOpenAccount;

  /// No description provided for @settingsTrustedDevices.
  ///
  /// In en, this message translates to:
  /// **'Trusted devices'**
  String get settingsTrustedDevices;

  /// No description provided for @settingsTrustedDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review current sessions and revoke old devices'**
  String get settingsTrustedDevicesSubtitle;

  /// No description provided for @settingsResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get settingsResetPassword;

  /// No description provided for @settingsResetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Request a password reset email code'**
  String get settingsResetPasswordSubtitle;

  /// No description provided for @settingsVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get settingsVerifyEmail;

  /// No description provided for @settingsVerifyEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email for recovery and safer sign-in flows'**
  String get settingsVerifyEmailSubtitle;

  /// No description provided for @settingsActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get settingsActiveSessions;

  /// No description provided for @settingsActiveSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage logged-in devices'**
  String get settingsActiveSessionsSubtitle;

  /// No description provided for @settingsNoUsername.
  ///
  /// In en, this message translates to:
  /// **'No username'**
  String get settingsNoUsername;

  /// No description provided for @settingsUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get settingsUserFallback;

  /// No description provided for @settingsAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get settingsAvatarUpdated;

  /// No description provided for @settingsDisable2faTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable 2FA?'**
  String get settingsDisable2faTitle;

  /// No description provided for @settingsDisable2faBody.
  ///
  /// In en, this message translates to:
  /// **'Your account will be less secure.'**
  String get settingsDisable2faBody;

  /// No description provided for @settingsDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get settingsDisable;

  /// No description provided for @settingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settingsConfirm;

  /// No description provided for @settingsConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get settingsConfirmPassword;

  /// No description provided for @settingsDisable2fa.
  ///
  /// In en, this message translates to:
  /// **'Disable 2FA'**
  String get settingsDisable2fa;

  /// No description provided for @settingsEnable2fa.
  ///
  /// In en, this message translates to:
  /// **'Enable 2FA'**
  String get settingsEnable2fa;

  /// No description provided for @settings2faEnabled.
  ///
  /// In en, this message translates to:
  /// **'2FA enabled'**
  String get settings2faEnabled;

  /// No description provided for @settings2faDisabled.
  ///
  /// In en, this message translates to:
  /// **'2FA disabled'**
  String get settings2faDisabled;

  /// No description provided for @settingsContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get settingsContactSupport;

  /// No description provided for @settingsReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report issue'**
  String get settingsReportIssue;

  /// No description provided for @settingsReportIssueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem you encountered'**
  String get settingsReportIssueSubtitle;

  /// No description provided for @settingsReportIssueHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue...'**
  String get settingsReportIssueHint;

  /// No description provided for @settingsSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get settingsSubmit;

  /// No description provided for @settingsSupportCopied.
  ///
  /// In en, this message translates to:
  /// **'Support email copied to clipboard'**
  String get settingsSupportCopied;

  /// No description provided for @settingsSupportRequestSubject.
  ///
  /// In en, this message translates to:
  /// **'NiosMess Support Request'**
  String get settingsSupportRequestSubject;

  /// No description provided for @settingsSupportRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue here.'**
  String get settingsSupportRequestBody;

  /// No description provided for @settingsBugReportSubject.
  ///
  /// In en, this message translates to:
  /// **'NiosMess Bug Report'**
  String get settingsBugReportSubject;

  /// No description provided for @settingsBugReportEmpty.
  ///
  /// In en, this message translates to:
  /// **'Issue description was not provided.'**
  String get settingsBugReportEmpty;

  /// No description provided for @settingsFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get settingsFaq;

  /// No description provided for @settingsFaqResetQ.
  ///
  /// In en, this message translates to:
  /// **'How do I reset my password?'**
  String get settingsFaqResetQ;

  /// No description provided for @settingsFaqResetA.
  ///
  /// In en, this message translates to:
  /// **'Go to Account > Reset password. Enter your email and follow the link.'**
  String get settingsFaqResetA;

  /// No description provided for @settingsFaq2faQ.
  ///
  /// In en, this message translates to:
  /// **'How do I enable 2FA?'**
  String get settingsFaq2faQ;

  /// No description provided for @settingsFaq2faA.
  ///
  /// In en, this message translates to:
  /// **'Go to Account > Two-factor authentication and confirm with your password.'**
  String get settingsFaq2faA;

  /// No description provided for @settingsFaqJoinQ.
  ///
  /// In en, this message translates to:
  /// **'How do I join a group?'**
  String get settingsFaqJoinQ;

  /// No description provided for @settingsFaqJoinA.
  ///
  /// In en, this message translates to:
  /// **'Use an invite link or tap the link icon on the Chats screen to join by slug.'**
  String get settingsFaqJoinA;

  /// No description provided for @settingsFaqSpamQ.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t I start new chats?'**
  String get settingsFaqSpamQ;

  /// No description provided for @settingsFaqSpamA.
  ///
  /// In en, this message translates to:
  /// **'Your account may have a spam block. Contact support.'**
  String get settingsFaqSpamA;

  /// No description provided for @developersTeamTitle.
  ///
  /// In en, this message translates to:
  /// **'NiosMess Team'**
  String get developersTeamTitle;

  /// No description provided for @developersHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backend, client architecture and sound design in one focused crew.'**
  String get developersHeroSubtitle;

  /// No description provided for @developersSanlsanRole.
  ///
  /// In en, this message translates to:
  /// **'Founder & Backend Architect'**
  String get developersSanlsanRole;

  /// No description provided for @developersSanlsanDescription.
  ///
  /// In en, this message translates to:
  /// **'Server core, API, auth and messaging foundation.'**
  String get developersSanlsanDescription;

  /// No description provided for @developersSh20fkRole.
  ///
  /// In en, this message translates to:
  /// **'App Lead & Client Architect'**
  String get developersSh20fkRole;

  /// No description provided for @developersSh20fkDescription.
  ///
  /// In en, this message translates to:
  /// **'Mobile app, client architecture, product flow and UI.'**
  String get developersSh20fkDescription;

  /// No description provided for @developersKarlovPrimeRole.
  ///
  /// In en, this message translates to:
  /// **'Sound Designer'**
  String get developersKarlovPrimeRole;

  /// No description provided for @developersKarlovPrimeDescription.
  ///
  /// In en, this message translates to:
  /// **'Call, message and interface sound identity.'**
  String get developersKarlovPrimeDescription;

  /// No description provided for @developersTagBackend.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get developersTagBackend;

  /// No description provided for @developersTagApi.
  ///
  /// In en, this message translates to:
  /// **'API'**
  String get developersTagApi;

  /// No description provided for @developersTagAuth.
  ///
  /// In en, this message translates to:
  /// **'Auth'**
  String get developersTagAuth;

  /// No description provided for @developersTagFlutter.
  ///
  /// In en, this message translates to:
  /// **'Flutter'**
  String get developersTagFlutter;

  /// No description provided for @developersTagUx.
  ///
  /// In en, this message translates to:
  /// **'UX'**
  String get developersTagUx;

  /// No description provided for @developersTagClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get developersTagClient;

  /// No description provided for @developersTagSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get developersTagSound;

  /// No description provided for @developersTagCalls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get developersTagCalls;

  /// No description provided for @developersTagIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get developersTagIdentity;

  /// No description provided for @chatListFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chatListFilterAll;

  /// No description provided for @chatListFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get chatListFilterUnread;

  /// No description provided for @chatListFilterGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get chatListFilterGroups;

  /// No description provided for @chatListFilterChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get chatListFilterChannels;

  /// No description provided for @chatListFilterDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get chatListFilterDirect;

  /// No description provided for @chatListFilterBots.
  ///
  /// In en, this message translates to:
  /// **'Bots'**
  String get chatListFilterBots;

  /// No description provided for @chatListSearch.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get chatListSearch;

  /// No description provided for @chatListSearchMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats and messages'**
  String get chatListSearchMessagesHint;

  /// No description provided for @chatListMessageMatches.
  ///
  /// In en, this message translates to:
  /// **'Message matches'**
  String get chatListMessageMatches;

  /// No description provided for @chatListNoChats.
  ///
  /// In en, this message translates to:
  /// **'No chats found.'**
  String get chatListNoChats;

  /// No description provided for @chatListNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'You are not authenticated yet.'**
  String get chatListNotAuthenticated;

  /// No description provided for @chatListMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get chatListMarkRead;

  /// No description provided for @chatListMarkReadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear unread state for this chat'**
  String get chatListMarkReadSubtitle;

  /// No description provided for @chatListMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get chatListMute;

  /// No description provided for @chatListPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatListPin;

  /// No description provided for @chatListArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get chatListArchive;

  /// No description provided for @chatListMuteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mute is not available from API yet'**
  String get chatListMuteSubtitle;

  /// No description provided for @chatListLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave chat'**
  String get chatListLeave;

  /// No description provided for @chatListLeaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this conversation from your account'**
  String get chatListLeaveSubtitle;

  /// No description provided for @chatListFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load chats: {error}'**
  String chatListFailedLoad(Object error);

  /// No description provided for @chatListMuteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Mute is not supported by API yet'**
  String get chatListMuteUnsupported;

  /// No description provided for @chatListPinUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Pin is not supported by API yet'**
  String get chatListPinUnsupported;

  /// No description provided for @chatListArchiveUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Archive is not supported by API yet'**
  String get chatListArchiveUnsupported;

  /// No description provided for @chatListLeft.
  ///
  /// In en, this message translates to:
  /// **'Left chat'**
  String get chatListLeft;

  /// No description provided for @chatListChannelPreview.
  ///
  /// In en, this message translates to:
  /// **'Channel • {preview}'**
  String chatListChannelPreview(Object preview);

  /// No description provided for @chatListGroupPreview.
  ///
  /// In en, this message translates to:
  /// **'Group • {preview}'**
  String chatListGroupPreview(Object preview);

  /// No description provided for @chatListUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String chatListUnreadCount(int count);

  /// No description provided for @chatPreviewForwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {name}'**
  String chatPreviewForwardedFrom(Object name);

  /// No description provided for @chatPreviewPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPreviewPhoto;

  /// No description provided for @chatPreviewVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatPreviewVideo;

  /// No description provided for @chatPreviewAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get chatPreviewAudio;

  /// No description provided for @chatPreviewFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatPreviewFile;

  /// No description provided for @chatTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Chat #{id}'**
  String chatTitleFallback(int id);

  /// No description provided for @chatInvalidId.
  ///
  /// In en, this message translates to:
  /// **'Invalid chat ID'**
  String get chatInvalidId;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @chatMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No members} =1 {1 member} other {{count} members}}'**
  String chatMemberCount(int count);

  /// No description provided for @chatNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatNoMessages;

  /// No description provided for @chatSendFirst.
  ///
  /// In en, this message translates to:
  /// **'Send the first message'**
  String get chatSendFirst;

  /// No description provided for @chatLoadEarlier.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get chatLoadEarlier;

  /// No description provided for @chatNoMoreMessages.
  ///
  /// In en, this message translates to:
  /// **'No more messages'**
  String get chatNoMoreMessages;

  /// No description provided for @chatVoiceCall.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get chatVoiceCall;

  /// No description provided for @chatVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get chatVideoCall;

  /// No description provided for @chatMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get chatMembers;

  /// No description provided for @chatManage.
  ///
  /// In en, this message translates to:
  /// **'Manage chat'**
  String get chatManage;

  /// No description provided for @chatReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// No description provided for @chatResendTo.
  ///
  /// In en, this message translates to:
  /// **'Resend to...'**
  String get chatResendTo;

  /// No description provided for @chatResendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copies message text to another chat'**
  String get chatResendSubtitle;

  /// No description provided for @chatComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get chatComments;

  /// No description provided for @chatCommentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String chatCommentsCount(int count);

  /// No description provided for @chatEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatEdit;

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDelete;

  /// No description provided for @chatEditMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatEditMessageTitle;

  /// No description provided for @chatEditMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message text'**
  String get chatEditMessageHint;

  /// No description provided for @chatDeleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get chatDeleteMessageTitle;

  /// No description provided for @chatDeleteMessageBody.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get chatDeleteMessageBody;

  /// No description provided for @chatMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get chatMessageDeleted;

  /// No description provided for @chatMessageForwarded.
  ///
  /// In en, this message translates to:
  /// **'Message forwarded'**
  String get chatMessageForwarded;

  /// No description provided for @chatMediaSent.
  ///
  /// In en, this message translates to:
  /// **'Media sent successfully'**
  String get chatMediaSent;

  /// No description provided for @chatForwardTo.
  ///
  /// In en, this message translates to:
  /// **'Forward to...'**
  String get chatForwardTo;

  /// No description provided for @chatAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get chatAttachment;

  /// No description provided for @chatOpenAttachment.
  ///
  /// In en, this message translates to:
  /// **'Open attachment'**
  String get chatOpenAttachment;

  /// No description provided for @chatTapToPreview.
  ///
  /// In en, this message translates to:
  /// **'Tap to preview'**
  String get chatTapToPreview;

  /// No description provided for @chatReplyToId.
  ///
  /// In en, this message translates to:
  /// **'Reply to #{id}'**
  String chatReplyToId(int id);

  /// No description provided for @chatForwardedTitle.
  ///
  /// In en, this message translates to:
  /// **'Forwarded message'**
  String get chatForwardedTitle;

  /// No description provided for @chatForwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String chatForwardedFrom(Object name);

  /// No description provided for @chatEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get chatEdited;

  /// No description provided for @chatFailedLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages: {error}'**
  String chatFailedLoadMessages(Object error);

  /// No description provided for @chatCancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get chatCancelReply;

  /// No description provided for @chatAttachMedia.
  ///
  /// In en, this message translates to:
  /// **'Attach media'**
  String get chatAttachMedia;

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get chatMessageHint;

  /// No description provided for @chatOnlyAdminsCanPost.
  ///
  /// In en, this message translates to:
  /// **'Only admins can post in this channel'**
  String get chatOnlyAdminsCanPost;

  /// No description provided for @chatMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} members'**
  String chatMembersTitle(Object name);

  /// No description provided for @chatMembersInviteUser.
  ///
  /// In en, this message translates to:
  /// **'Invite user'**
  String get chatMembersInviteUser;

  /// No description provided for @chatMembersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by username or name'**
  String get chatMembersSearchHint;

  /// No description provided for @chatMembersSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type a name to search'**
  String get chatMembersSearchPrompt;

  /// No description provided for @chatMembersInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited @{username}'**
  String chatMembersInvited(Object username);

  /// No description provided for @chatMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get chatMembersEmpty;

  /// No description provided for @chatMembersRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'owner'**
  String get chatMembersRoleOwner;

  /// No description provided for @chatMembersRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get chatMembersRoleAdmin;

  /// No description provided for @chatMembersRoleMember.
  ///
  /// In en, this message translates to:
  /// **'member'**
  String get chatMembersRoleMember;

  /// No description provided for @chatMembersMuted.
  ///
  /// In en, this message translates to:
  /// **'muted'**
  String get chatMembersMuted;

  /// No description provided for @chatMembersBanned.
  ///
  /// In en, this message translates to:
  /// **'banned'**
  String get chatMembersBanned;

  /// No description provided for @chatMembersBan.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get chatMembersBan;

  /// No description provided for @chatMembersUnban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get chatMembersUnban;

  /// No description provided for @chatMembersMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get chatMembersMute;

  /// No description provided for @chatMembersUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get chatMembersUnmute;

  /// No description provided for @chatMembersPromoteAdmin.
  ///
  /// In en, this message translates to:
  /// **'Promote to admin'**
  String get chatMembersPromoteAdmin;

  /// No description provided for @chatMembersDemoteMember.
  ///
  /// In en, this message translates to:
  /// **'Demote to member'**
  String get chatMembersDemoteMember;

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Post comments'**
  String get commentsTitle;

  /// No description provided for @commentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get commentsEmpty;

  /// No description provided for @commentsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get commentsDeleted;

  /// No description provided for @commentsHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment'**
  String get commentsHint;

  /// No description provided for @commentsFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load comments: {error}'**
  String commentsFailedLoad(Object error);

  /// No description provided for @commentsFailedSend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send comment: {error}'**
  String commentsFailedSend(Object error);

  /// No description provided for @callsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent voice and video activity with quick callback actions.'**
  String get callsSubtitle;

  /// No description provided for @callsNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No call history yet. Start a call from any chat.'**
  String get callsNoHistory;

  /// No description provided for @callsFailedToStart.
  ///
  /// In en, this message translates to:
  /// **'Failed to start call: {error}'**
  String callsFailedToStart(Object error);

  /// No description provided for @callsFailedLoadChats.
  ///
  /// In en, this message translates to:
  /// **'Failed to load chats: {error}'**
  String callsFailedLoadChats(Object error);

  /// No description provided for @callsMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed • {time}'**
  String callsMissed(Object time);

  /// No description provided for @callsDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined • {time}'**
  String callsDeclined(Object time);

  /// No description provided for @callsDeclinedShort.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get callsDeclinedShort;

  /// No description provided for @callsOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing • {time}'**
  String callsOutgoing(Object time);

  /// No description provided for @callsOutgoingShort.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get callsOutgoingShort;

  /// No description provided for @callsIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming • {time}'**
  String callsIncoming(Object time);

  /// No description provided for @callsIncomingShort.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get callsIncomingShort;

  /// No description provided for @callsInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get callsInProgress;

  /// No description provided for @callsTotalCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No calls} =1 {1 call} other {{count} calls}}'**
  String callsTotalCount(int count);

  /// No description provided for @callsMissedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No missed} =1 {1 missed} other {{count} missed}}'**
  String callsMissedCount(int count);

  /// No description provided for @callsVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No video} =1 {1 video} other {{count} video}}'**
  String callsVideoCount(int count);

  /// No description provided for @callsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search calls'**
  String get callsSearchHint;

  /// No description provided for @callsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get callsFilterAll;

  /// No description provided for @callsFilterMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get callsFilterMissed;

  /// No description provided for @callsFilterVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get callsFilterVideo;

  /// No description provided for @callsQuickTitle.
  ///
  /// In en, this message translates to:
  /// **'Call hub'**
  String get callsQuickTitle;

  /// No description provided for @callsLatestCall.
  ///
  /// In en, this message translates to:
  /// **'Latest call with {name}'**
  String callsLatestCall(Object name);

  /// No description provided for @callsQuickPeople.
  ///
  /// In en, this message translates to:
  /// **'Quick call'**
  String get callsQuickPeople;

  /// No description provided for @callsQuickAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get callsQuickAdd;

  /// No description provided for @callsResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No matching calls} =1 {1 matching call} other {{count} matching calls}}'**
  String callsResultCount(int count);

  /// No description provided for @activeCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get activeCallTitle;

  /// No description provided for @activeCallInvalidChat.
  ///
  /// In en, this message translates to:
  /// **'Invalid chat id'**
  String get activeCallInvalidChat;

  /// No description provided for @activeCallRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh call status'**
  String get activeCallRefresh;

  /// No description provided for @activeCallResponseFailed.
  ///
  /// In en, this message translates to:
  /// **'Call response failed: {error}'**
  String activeCallResponseFailed(Object error);

  /// No description provided for @activeCallEndFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to end call: {error}'**
  String activeCallEndFailed(Object error);

  /// No description provided for @activeCallVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get activeCallVoice;

  /// No description provided for @activeCallVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get activeCallVideo;

  /// No description provided for @activeCallRinging.
  ///
  /// In en, this message translates to:
  /// **'Ringing'**
  String get activeCallRinging;

  /// No description provided for @activeCallActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeCallActive;

  /// No description provided for @activeCallEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get activeCallEnded;

  /// No description provided for @activeCallMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get activeCallMissed;

  /// No description provided for @activeCallDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get activeCallDeclined;

  /// No description provided for @activeCallVideoPreview.
  ///
  /// In en, this message translates to:
  /// **'Video preview is ready'**
  String get activeCallVideoPreview;

  /// No description provided for @activeCallCameraOn.
  ///
  /// In en, this message translates to:
  /// **'Camera on'**
  String get activeCallCameraOn;

  /// No description provided for @activeCallCameraOff.
  ///
  /// In en, this message translates to:
  /// **'Camera off'**
  String get activeCallCameraOff;

  /// No description provided for @activeCallAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get activeCallAnswer;

  /// No description provided for @activeCallDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get activeCallDecline;

  /// No description provided for @activeCallEnd.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get activeCallEnd;

  /// No description provided for @activeCallMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get activeCallMute;

  /// No description provided for @activeCallUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get activeCallUnmute;

  /// No description provided for @activeCallSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get activeCallSpeaker;

  /// No description provided for @groupTypeGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupTypeGroup;

  /// No description provided for @groupTypeChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get groupTypeChannel;

  /// No description provided for @groupTypeStep.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get groupTypeStep;

  /// No description provided for @groupDetailsStep.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get groupDetailsStep;

  /// No description provided for @groupPrivacyStep.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get groupPrivacyStep;

  /// No description provided for @groupReviewStep.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get groupReviewStep;

  /// No description provided for @groupWizardTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what you want to create.'**
  String get groupWizardTypeSubtitle;

  /// No description provided for @groupWizardDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set the name and short description.'**
  String get groupWizardDetailsSubtitle;

  /// No description provided for @groupWizardPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Decide if the chat should be public or private.'**
  String get groupWizardPrivacySubtitle;

  /// No description provided for @groupWizardReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your settings before creating.'**
  String get groupWizardReviewSubtitle;

  /// No description provided for @groupNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get groupNewGroup;

  /// No description provided for @groupNewChannel.
  ///
  /// In en, this message translates to:
  /// **'New channel'**
  String get groupNewChannel;

  /// No description provided for @groupCreateOrJoin.
  ///
  /// In en, this message translates to:
  /// **'Create or join'**
  String get groupCreateOrJoin;

  /// No description provided for @groupCreateSharedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a shared chat for members and discussion'**
  String get groupCreateSharedSubtitle;

  /// No description provided for @groupCreateBroadcastSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a broadcast space for posts and updates'**
  String get groupCreateBroadcastSubtitle;

  /// No description provided for @groupJoinByInvite.
  ///
  /// In en, this message translates to:
  /// **'Join by invite'**
  String get groupJoinByInvite;

  /// No description provided for @groupJoinByInviteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste an invite link or slug to enter a chat'**
  String get groupJoinByInviteSubtitle;

  /// No description provided for @groupTypeGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Members can all talk together. Best for teams and friends.'**
  String get groupTypeGroupSubtitle;

  /// No description provided for @groupTypeChannelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Broadcast updates, posts, and announcements to subscribers.'**
  String get groupTypeChannelSubtitle;

  /// No description provided for @groupYourNewChannel.
  ///
  /// In en, this message translates to:
  /// **'Your new channel'**
  String get groupYourNewChannel;

  /// No description provided for @groupYourNewGroup.
  ///
  /// In en, this message translates to:
  /// **'Your new group'**
  String get groupYourNewGroup;

  /// No description provided for @groupEditLater.
  ///
  /// In en, this message translates to:
  /// **'You can edit avatar, members, and links later.'**
  String get groupEditLater;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'My team chat'**
  String get groupNameHint;

  /// No description provided for @groupDescriptionChannelLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel description (optional)'**
  String get groupDescriptionChannelLabel;

  /// No description provided for @groupDescriptionGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group description (optional)'**
  String get groupDescriptionGroupLabel;

  /// No description provided for @groupDescriptionChannelHint.
  ///
  /// In en, this message translates to:
  /// **'What this channel is about'**
  String get groupDescriptionChannelHint;

  /// No description provided for @groupDescriptionGroupHint.
  ///
  /// In en, this message translates to:
  /// **'What this group is for'**
  String get groupDescriptionGroupHint;

  /// No description provided for @groupPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get groupPrivate;

  /// No description provided for @groupPrivateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'People can join only through an invite link.'**
  String get groupPrivateSubtitle;

  /// No description provided for @groupPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get groupPublic;

  /// No description provided for @groupPublicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'People can find it via public username or slug.'**
  String get groupPublicSubtitle;

  /// No description provided for @groupPublicUsername.
  ///
  /// In en, this message translates to:
  /// **'Public username'**
  String get groupPublicUsername;

  /// No description provided for @groupEnableComments.
  ///
  /// In en, this message translates to:
  /// **'Enable comments'**
  String get groupEnableComments;

  /// No description provided for @groupEnableCommentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Members can comment on channel posts in a linked discussion chat.'**
  String get groupEnableCommentsSubtitle;

  /// No description provided for @groupBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get groupBack;

  /// No description provided for @groupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get groupContinue;

  /// No description provided for @groupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get groupCreate;

  /// No description provided for @groupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get groupCreating;

  /// No description provided for @groupAlreadyHaveInvite.
  ///
  /// In en, this message translates to:
  /// **'Already have an invite? Join by link'**
  String get groupAlreadyHaveInvite;

  /// No description provided for @groupVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get groupVisibility;

  /// No description provided for @groupUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get groupUsernameLabel;

  /// No description provided for @groupCreatedChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel created successfully'**
  String get groupCreatedChannel;

  /// No description provided for @groupCreatedGroup.
  ///
  /// In en, this message translates to:
  /// **'Group created successfully'**
  String get groupCreatedGroup;

  /// No description provided for @groupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create chat: {error}'**
  String groupCreateFailed(Object error);

  /// No description provided for @groupNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 3 characters'**
  String get groupNameTooShort;

  /// No description provided for @groupUsernameRules.
  ///
  /// In en, this message translates to:
  /// **'Use 3-32 chars: letters, digits, dot, underscore'**
  String get groupUsernameRules;

  /// No description provided for @groupJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join by invite'**
  String get groupJoinTitle;

  /// No description provided for @groupJoinHeadline.
  ///
  /// In en, this message translates to:
  /// **'Join with invite link or slug'**
  String get groupJoinHeadline;

  /// No description provided for @groupJoinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a private invite link or a public slug to preview the chat before joining.'**
  String get groupJoinSubtitle;

  /// No description provided for @groupInviteLinkOrSlug.
  ///
  /// In en, this message translates to:
  /// **'Invite link or slug'**
  String get groupInviteLinkOrSlug;

  /// No description provided for @groupPreviewInvite.
  ///
  /// In en, this message translates to:
  /// **'Preview invite'**
  String get groupPreviewInvite;

  /// No description provided for @groupInvitePreviewNotFound.
  ///
  /// In en, this message translates to:
  /// **'Invite preview not found.'**
  String get groupInvitePreviewNotFound;

  /// No description provided for @groupJoinChat.
  ///
  /// In en, this message translates to:
  /// **'Join chat'**
  String get groupJoinChat;

  /// No description provided for @groupJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining...'**
  String get groupJoining;

  /// No description provided for @groupInviteFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load invite: {error}'**
  String groupInviteFailedLoad(Object error);

  /// No description provided for @groupJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join chat: {error}'**
  String groupJoinFailed(Object error);

  /// No description provided for @groupSignInToJoin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to join chats by invite.'**
  String get groupSignInToJoin;

  /// No description provided for @groupChannelPreview.
  ///
  /// In en, this message translates to:
  /// **'Channel preview'**
  String get groupChannelPreview;

  /// No description provided for @groupGroupPreview.
  ///
  /// In en, this message translates to:
  /// **'Group preview'**
  String get groupGroupPreview;

  /// No description provided for @groupNoPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get groupNoPostsYet;

  /// No description provided for @groupManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage {name}'**
  String groupManageTitle(Object name);

  /// No description provided for @groupManageChangeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get groupManageChangeAvatar;

  /// No description provided for @groupManageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get groupManageUploading;

  /// No description provided for @groupManageAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get groupManageAvatarUpdated;

  /// No description provided for @groupManageChatUpdated.
  ///
  /// In en, this message translates to:
  /// **'Chat updated'**
  String get groupManageChatUpdated;

  /// No description provided for @groupManageSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get groupManageSaveChanges;

  /// No description provided for @groupManageIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get groupManageIdentity;

  /// No description provided for @groupManageLinks.
  ///
  /// In en, this message translates to:
  /// **'Links & metadata'**
  String get groupManageLinks;

  /// No description provided for @groupManageLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave chat?'**
  String get groupManageLeaveTitle;

  /// No description provided for @groupManageLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You will no longer see this chat.'**
  String get groupManageLeaveBody;

  /// No description provided for @groupManageLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave chat'**
  String get groupManageLeave;

  /// No description provided for @commonEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get commonDisabled;

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// No description provided for @settingsProfileSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get settingsProfileSetupSubtitle;

  /// No description provided for @settingsSectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsSectionsTitle;

  /// No description provided for @settingsSectionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only active sections are shown here.'**
  String get settingsSectionsSubtitle;

  /// No description provided for @settingsStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorageTitle;

  /// No description provided for @settingsStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review app data, drafts, and cleanable cache.'**
  String get settingsStorageSubtitle;

  /// No description provided for @settingsStorageBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Storage breakdown'**
  String get settingsStorageBreakdown;

  /// No description provided for @settingsStorageBreakdownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Measured on this device.'**
  String get settingsStorageBreakdownSubtitle;

  /// No description provided for @settingsStorageAppData.
  ///
  /// In en, this message translates to:
  /// **'App data'**
  String get settingsStorageAppData;

  /// No description provided for @settingsStorageAppDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local files required by the app.'**
  String get settingsStorageAppDataSubtitle;

  /// No description provided for @settingsStorageTemporaryCache.
  ///
  /// In en, this message translates to:
  /// **'Temporary cache'**
  String get settingsStorageTemporaryCache;

  /// No description provided for @settingsStorageTemporaryCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Files that can be recreated safely.'**
  String get settingsStorageTemporaryCacheSubtitle;

  /// No description provided for @settingsStorageDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get settingsStorageDrafts;

  /// No description provided for @settingsStorageDraftsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No saved drafts} =1{1 saved draft} other{{count} saved drafts}}'**
  String settingsStorageDraftsSubtitle(int count);

  /// No description provided for @settingsStorageActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get settingsStorageActions;

  /// No description provided for @settingsStorageActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clean only data that is safe to rebuild.'**
  String get settingsStorageActionsSubtitle;

  /// No description provided for @settingsStorageRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh usage'**
  String get settingsStorageRefresh;

  /// No description provided for @settingsStorageRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recalculate local storage now'**
  String get settingsStorageRefreshSubtitle;

  /// No description provided for @settingsStorageCheckIntegrity.
  ///
  /// In en, this message translates to:
  /// **'Check storage'**
  String get settingsStorageCheckIntegrity;

  /// No description provided for @settingsStorageCheckIntegritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify schema, folders, and draft records'**
  String get settingsStorageCheckIntegritySubtitle;

  /// No description provided for @settingsStorageClearTemporary.
  ///
  /// In en, this message translates to:
  /// **'Clear temporary cache'**
  String get settingsStorageClearTemporary;

  /// No description provided for @settingsStorageClearTemporarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove files from the app cache folder'**
  String get settingsStorageClearTemporarySubtitle;

  /// No description provided for @settingsStorageClearDrafts.
  ///
  /// In en, this message translates to:
  /// **'Clear message drafts'**
  String get settingsStorageClearDrafts;

  /// No description provided for @settingsStorageClearDraftsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove unsent local draft text'**
  String get settingsStorageClearDraftsSubtitle;

  /// No description provided for @settingsStorageClearTemporaryConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear temporary cache?'**
  String get settingsStorageClearTemporaryConfirmTitle;

  /// No description provided for @settingsStorageClearTemporaryConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Cached files will be recreated when needed. Account data and settings will stay untouched.'**
  String get settingsStorageClearTemporaryConfirmBody;

  /// No description provided for @settingsStorageClearDraftsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear message drafts?'**
  String get settingsStorageClearDraftsConfirmTitle;

  /// No description provided for @settingsStorageClearDraftsConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Unsent draft text saved on this device will be removed.'**
  String get settingsStorageClearDraftsConfirmBody;

  /// No description provided for @settingsStorageCleared.
  ///
  /// In en, this message translates to:
  /// **'Storage cleaned'**
  String get settingsStorageCleared;

  /// No description provided for @settingsStorageHealthOkTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage is healthy'**
  String get settingsStorageHealthOkTitle;

  /// No description provided for @settingsStorageHealthOkBody.
  ///
  /// In en, this message translates to:
  /// **'Local schema version {schemaVersion} is ready and no integrity issues were found.'**
  String settingsStorageHealthOkBody(int schemaVersion);

  /// No description provided for @settingsStorageHealthIssueTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage needs attention'**
  String get settingsStorageHealthIssueTitle;

  /// No description provided for @settingsStorageUsedByApp.
  ///
  /// In en, this message translates to:
  /// **'Used by NiosMess on this device'**
  String get settingsStorageUsedByApp;

  /// No description provided for @settingsStorageCleanable.
  ///
  /// In en, this message translates to:
  /// **'{size} can be cleaned without logging out.'**
  String settingsStorageCleanable(Object size);

  /// No description provided for @settingsLegalPoliciesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Policy documents. Licenses are in the hidden menu.'**
  String get settingsLegalPoliciesSubtitle;

  /// No description provided for @settingsHiddenMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Hidden tools'**
  String get settingsHiddenMenuTitle;

  /// No description provided for @settingsHiddenMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long-press app version to open this menu.'**
  String get settingsHiddenMenuSubtitle;

  /// No description provided for @settingsDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnosticsTitle;

  /// No description provided for @settingsDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime details, API target, and build state'**
  String get settingsDiagnosticsSubtitle;

  /// No description provided for @settingsDiagnosticsStorageSummary.
  ///
  /// In en, this message translates to:
  /// **'Schema v{schemaVersion}, {size} stored locally'**
  String settingsDiagnosticsStorageSummary(int schemaVersion, Object size);

  /// No description provided for @settingsDiagnosticsLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Local logs'**
  String get settingsDiagnosticsLogsTitle;

  /// No description provided for @settingsDiagnosticsLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Last errors and runtime events kept on this device.'**
  String get settingsDiagnosticsLogsSubtitle;

  /// No description provided for @settingsDiagnosticsNoLogs.
  ///
  /// In en, this message translates to:
  /// **'No local errors recorded'**
  String get settingsDiagnosticsNoLogs;

  /// No description provided for @settingsDiagnosticsActions.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics actions'**
  String get settingsDiagnosticsActions;

  /// No description provided for @settingsDiagnosticsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh diagnostics'**
  String get settingsDiagnosticsRefresh;

  /// No description provided for @settingsDiagnosticsRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reload build, storage, sound and log state'**
  String get settingsDiagnosticsRefreshSubtitle;

  /// No description provided for @settingsDiagnosticsTestSound.
  ///
  /// In en, this message translates to:
  /// **'Test interface sound'**
  String get settingsDiagnosticsTestSound;

  /// No description provided for @settingsDiagnosticsTestSoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play the current navigation click'**
  String get settingsDiagnosticsTestSoundSubtitle;

  /// No description provided for @settingsDiagnosticsCopyLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy local logs'**
  String get settingsDiagnosticsCopyLogs;

  /// No description provided for @settingsDiagnosticsCopyLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copy recent errors and events to clipboard'**
  String get settingsDiagnosticsCopyLogsSubtitle;

  /// No description provided for @settingsDiagnosticsLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'Local logs copied'**
  String get settingsDiagnosticsLogsCopied;

  /// No description provided for @settingsEditProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change name, avatar, and bio'**
  String get settingsEditProfileSubtitle;

  /// No description provided for @appearanceVariantTonalSpot.
  ///
  /// In en, this message translates to:
  /// **'Tonal spot'**
  String get appearanceVariantTonalSpot;

  /// No description provided for @appearanceVariantVibrant.
  ///
  /// In en, this message translates to:
  /// **'Vibrant'**
  String get appearanceVariantVibrant;

  /// No description provided for @appearanceVariantExpressive.
  ///
  /// In en, this message translates to:
  /// **'Expressive'**
  String get appearanceVariantExpressive;

  /// No description provided for @appearanceVariantNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get appearanceVariantNeutral;

  /// No description provided for @appearanceVariantMonochrome.
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get appearanceVariantMonochrome;

  /// No description provided for @appearanceVariantFidelity.
  ///
  /// In en, this message translates to:
  /// **'Fidelity'**
  String get appearanceVariantFidelity;

  /// No description provided for @appearancePaletteNiosMess.
  ///
  /// In en, this message translates to:
  /// **'NiosMess'**
  String get appearancePaletteNiosMess;

  /// No description provided for @appearancePaletteOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get appearancePaletteOcean;

  /// No description provided for @appearancePaletteForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get appearancePaletteForest;

  /// No description provided for @appearancePaletteSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get appearancePaletteSunset;

  /// No description provided for @appearancePaletteRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get appearancePaletteRose;

  /// No description provided for @appearancePaletteSignal.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get appearancePaletteSignal;

  /// No description provided for @resetPasswordRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordRequestTitle;

  /// No description provided for @resetPasswordRequestHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordRequestHeroTitle;

  /// No description provided for @resetPasswordRequestHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will send a reset code to your email.'**
  String get resetPasswordRequestHeroSubtitle;

  /// No description provided for @resetPasswordRequestEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get resetPasswordRequestEmailLabel;

  /// No description provided for @resetPasswordRequestEmailError.
  ///
  /// In en, this message translates to:
  /// **'Enter valid email'**
  String get resetPasswordRequestEmailError;

  /// No description provided for @resetPasswordRequestSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get resetPasswordRequestSubmit;

  /// No description provided for @resetPasswordRequestSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get resetPasswordRequestSubmitting;

  /// No description provided for @resetPasswordRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get resetPasswordRequestSent;

  /// No description provided for @resetPasswordConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm reset'**
  String get resetPasswordConfirmTitle;

  /// No description provided for @resetPasswordConfirmHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get resetPasswordConfirmHeroTitle;

  /// No description provided for @resetPasswordConfirmHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent to your email.'**
  String get resetPasswordConfirmHeroSubtitle;

  /// No description provided for @resetPasswordConfirmEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get resetPasswordConfirmEmailLabel;

  /// No description provided for @resetPasswordConfirmEmailError.
  ///
  /// In en, this message translates to:
  /// **'Enter valid email'**
  String get resetPasswordConfirmEmailError;

  /// No description provided for @resetPasswordConfirmCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get resetPasswordConfirmCodeLabel;

  /// No description provided for @resetPasswordConfirmCodeError.
  ///
  /// In en, this message translates to:
  /// **'Enter 6 digits'**
  String get resetPasswordConfirmCodeError;

  /// No description provided for @resetPasswordConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetPasswordConfirmPasswordLabel;

  /// No description provided for @resetPasswordConfirmPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get resetPasswordConfirmPasswordError;

  /// No description provided for @resetPasswordConfirmSubmit.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordConfirmSubmit;

  /// No description provided for @resetPasswordConfirmSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Applying...'**
  String get resetPasswordConfirmSubmitting;

  /// No description provided for @resetPasswordConfirmDone.
  ///
  /// In en, this message translates to:
  /// **'Password reset successfully'**
  String get resetPasswordConfirmDone;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke session?'**
  String get sessionsRevokeTitle;

  /// No description provided for @sessionsRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get sessionsRevokeConfirm;

  /// No description provided for @sessionsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sessionsCancel;

  /// No description provided for @sessionsRevokeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Revoke session'**
  String get sessionsRevokeTooltip;

  /// No description provided for @sessionsRevokedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Session revoked'**
  String get sessionsRevokedSuccess;

  /// No description provided for @sessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get sessionsEmpty;

  /// No description provided for @sessionsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sessionsRetry;

  /// No description provided for @sessionsRevokeAll.
  ///
  /// In en, this message translates to:
  /// **'Revoke all other sessions'**
  String get sessionsRevokeAll;

  /// No description provided for @contactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsTitle;

  /// No description provided for @contactsRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get contactsRecent;

  /// No description provided for @contactsRecentPeople.
  ///
  /// In en, this message translates to:
  /// **'Recent people...'**
  String get contactsRecentPeople;

  /// No description provided for @contactsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get contactsSearch;

  /// No description provided for @contactsNoRecent.
  ///
  /// In en, this message translates to:
  /// **'No recent contacts yet...'**
  String get contactsNoRecent;

  /// No description provided for @contactsTypeUsername.
  ///
  /// In en, this message translates to:
  /// **'Type a username...'**
  String get contactsTypeUsername;

  /// No description provided for @contactsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches found.'**
  String get contactsNoMatches;

  /// No description provided for @contactsMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get contactsMessage;

  /// No description provided for @contactsChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get contactsChat;

  /// No description provided for @contactDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactDetailTitle;

  /// No description provided for @contactDetailOverview.
  ///
  /// In en, this message translates to:
  /// **'Contact overview'**
  String get contactDetailOverview;

  /// No description provided for @contactDetailSharedContext.
  ///
  /// In en, this message translates to:
  /// **'Shared context'**
  String get contactDetailSharedContext;

  /// No description provided for @contactDetailUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get contactDetailUsername;

  /// No description provided for @contactDetailBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get contactDetailBio;

  /// No description provided for @contactDetailSharedContextDesc.
  ///
  /// In en, this message translates to:
  /// **'Mutual groups and shared media will appear here as soon as this data becomes available from the API.'**
  String get contactDetailSharedContextDesc;

  /// No description provided for @contactDetailNoBio.
  ///
  /// In en, this message translates to:
  /// **'No public bio yet'**
  String get contactDetailNoBio;

  /// No description provided for @contactsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent people, quick message actions, and search across users.'**
  String get contactsSubtitle;

  /// No description provided for @contactsNotAuth.
  ///
  /// In en, this message translates to:
  /// **'You are not authenticated yet.'**
  String get contactsNotAuth;

  /// No description provided for @contactsNoRecentFull.
  ///
  /// In en, this message translates to:
  /// **'No recent contacts yet.\nStart a conversation from the Search tab.'**
  String get contactsNoRecentFull;

  /// No description provided for @contactsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by username, name, or text'**
  String get contactsSearchHint;

  /// No description provided for @contactsSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Type a username or name to search users, chats, and messages.'**
  String get contactsSearchEmpty;

  /// No description provided for @contactsUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get contactsUsers;

  /// No description provided for @contactsChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get contactsChats;

  /// No description provided for @contactsMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get contactsMessages;

  /// No description provided for @contactsNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get contactsNoMessagesYet;

  /// No description provided for @contactsForwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {name}'**
  String contactsForwardedFrom(Object name);

  /// No description provided for @mediaActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mediaActionSave;

  /// No description provided for @mediaActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get mediaActionCopy;

  /// No description provided for @mediaActionOpenIn.
  ///
  /// In en, this message translates to:
  /// **'Open in...'**
  String get mediaActionOpenIn;

  /// No description provided for @mediaViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get mediaViewerTitle;

  /// No description provided for @mediaViewerCannotPreview.
  ///
  /// In en, this message translates to:
  /// **'Cannot preview this file'**
  String get mediaViewerCannotPreview;

  /// No description provided for @mediaViewerOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'Open Externally'**
  String get mediaViewerOpenExternal;

  /// No description provided for @chatUploadCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel upload?'**
  String get chatUploadCancelTitle;

  /// No description provided for @chatUploadCancelBody.
  ///
  /// In en, this message translates to:
  /// **'Media is uploading. Cancel it?'**
  String get chatUploadCancelBody;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @chatScrollToBottom.
  ///
  /// In en, this message translates to:
  /// **'Scroll to latest'**
  String get chatScrollToBottom;

  /// No description provided for @chatTypingOne.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing...'**
  String chatTypingOne(Object name);

  /// No description provided for @chatTypingMultiple.
  ///
  /// In en, this message translates to:
  /// **'Several people are typing...'**
  String get chatTypingMultiple;

  /// No description provided for @chatUnreadMessages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 unread} other {{count} unread}}'**
  String chatUnreadMessages(int count);

  /// No description provided for @chatEditingMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get chatEditingMessage;

  /// No description provided for @chatEditCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel editing'**
  String get chatEditCancel;

  /// No description provided for @chatScrollLoadingEarlier.
  ///
  /// In en, this message translates to:
  /// **'Loading messages...'**
  String get chatScrollLoadingEarlier;

  /// No description provided for @appearanceOptimizeWeakDevices.
  ///
  /// In en, this message translates to:
  /// **'Optimize for weak devices'**
  String get appearanceOptimizeWeakDevices;

  /// No description provided for @appearanceOptimizeWeakDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disables background blur and heavy BackdropFilter effects to increase FPS'**
  String get appearanceOptimizeWeakDevicesSubtitle;

  /// No description provided for @searchSemantic.
  ///
  /// In en, this message translates to:
  /// **'Semantic search'**
  String get searchSemantic;

  /// No description provided for @searchSemanticHint.
  ///
  /// In en, this message translates to:
  /// **'Search by meaning using AI'**
  String get searchSemanticHint;

  /// No description provided for @searchSemanticFallback.
  ///
  /// In en, this message translates to:
  /// **'Semantic search is temporarily unavailable. Regular search performed.'**
  String get searchSemanticFallback;

  /// No description provided for @chatCreatePersonal.
  ///
  /// In en, this message translates to:
  /// **'Create direct chat'**
  String get chatCreatePersonal;

  /// No description provided for @chatCreatePersonalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a direct conversation by username'**
  String get chatCreatePersonalSubtitle;

  /// No description provided for @chatCreatePersonalPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start direct chat'**
  String get chatCreatePersonalPrompt;

  /// No description provided for @chatCreatePersonalUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get chatCreatePersonalUsernameLabel;

  /// No description provided for @chatCreatePersonalUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get chatCreatePersonalUsernameHint;

  /// No description provided for @chatCreatePersonalStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get chatCreatePersonalStart;

  /// No description provided for @chatCreatePersonalErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Username cannot be empty'**
  String get chatCreatePersonalErrorEmpty;

  /// No description provided for @settingsAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get settingsAdminTitle;

  /// No description provided for @settingsAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage users and chats'**
  String get settingsAdminSubtitle;

  /// No description provided for @settingsBadgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get settingsBadgesTitle;

  /// No description provided for @settingsBadgesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and manage profile badges'**
  String get settingsBadgesSubtitle;

  /// No description provided for @settingsBotsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bots'**
  String get settingsBotsTitle;

  /// No description provided for @settingsBotsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create and manage your bots'**
  String get settingsBotsSubtitle;

  /// No description provided for @settingsSecretChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret Chats'**
  String get settingsSecretChatsTitle;

  /// No description provided for @settingsSecretChatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted messaging'**
  String get settingsSecretChatsSubtitle;

  /// No description provided for @settingsSecretChatsButton.
  ///
  /// In en, this message translates to:
  /// **'Secret Chat'**
  String get settingsSecretChatsButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

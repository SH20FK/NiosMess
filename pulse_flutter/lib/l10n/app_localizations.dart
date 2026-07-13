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

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

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

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

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

  /// No description provided for @commonDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get commonDiscardChanges;

  /// No description provided for @commonDiscardChangesDesc.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes that will be lost.'**
  String get commonDiscardChangesDesc;

  /// No description provided for @commonDiscardChangesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get commonDiscardChangesConfirm;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Fluid connection, clear communication'**
  String get splashTagline;

  /// No description provided for @splashGraphicsOptimization.
  ///
  /// In en, this message translates to:
  /// **'Optimizing graphics...'**
  String get splashGraphicsOptimization;

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

  /// No description provided for @appearancePersonalizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance & themes'**
  String get appearancePersonalizationTitle;

  /// No description provided for @appearancePersonalizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Material 3 palettes, soft accent color haze, and manual visual rhythm tuning.'**
  String get appearancePersonalizationSubtitle;

  /// No description provided for @appearancePaletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get appearancePaletteTitle;

  /// No description provided for @appearancePaletteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose accent colors for the interface, text, and buttons'**
  String get appearancePaletteSubtitle;

  /// No description provided for @appearanceDensityTitle.
  ///
  /// In en, this message translates to:
  /// **'Interface density'**
  String get appearanceDensityTitle;

  /// No description provided for @appearanceDensitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Affects preview size, palette, and visual rhythm of the screen'**
  String get appearanceDensitySubtitle;

  /// No description provided for @appearanceDensitySoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get appearanceDensitySoft;

  /// No description provided for @appearanceDensityRich.
  ///
  /// In en, this message translates to:
  /// **'Rich'**
  String get appearanceDensityRich;

  /// No description provided for @appearanceDensityExpressive.
  ///
  /// In en, this message translates to:
  /// **'Expressive'**
  String get appearanceDensityExpressive;

  /// No description provided for @appearanceThemeParamsTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme parameters'**
  String get appearanceThemeParamsTitle;

  /// No description provided for @appearanceThemeParamsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Material 3 system toggles'**
  String get appearanceThemeParamsSubtitle;

  /// No description provided for @appearanceDynamicColors.
  ///
  /// In en, this message translates to:
  /// **'Dynamic colors'**
  String get appearanceDynamicColors;

  /// No description provided for @appearanceDynamicColorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a more expressive tonal scheme'**
  String get appearanceDynamicColorsSubtitle;

  /// No description provided for @appearanceDarkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get appearanceDarkTheme;

  /// No description provided for @appearanceDarkThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manually switch between light and dark Material 3 theme'**
  String get appearanceDarkThemeSubtitle;

  /// No description provided for @appearanceLabelLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLabelLight;

  /// No description provided for @appearanceLabelDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceLabelDark;

  /// No description provided for @appearanceLabelAmethyst.
  ///
  /// In en, this message translates to:
  /// **'Amethyst'**
  String get appearanceLabelAmethyst;

  /// No description provided for @appearanceLabelLagoon.
  ///
  /// In en, this message translates to:
  /// **'Lagoon'**
  String get appearanceLabelLagoon;

  /// No description provided for @appearanceLabelMeadow.
  ///
  /// In en, this message translates to:
  /// **'Meadow'**
  String get appearanceLabelMeadow;

  /// No description provided for @appearanceLabelEmber.
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get appearanceLabelEmber;

  /// No description provided for @appearanceLabelOrchid.
  ///
  /// In en, this message translates to:
  /// **'Orchid'**
  String get appearanceLabelOrchid;

  /// No description provided for @appearanceLabelSlate.
  ///
  /// In en, this message translates to:
  /// **'Slate'**
  String get appearanceLabelSlate;

  /// No description provided for @appearanceLabelSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get appearanceLabelSky;

  /// No description provided for @appearanceLabelRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get appearanceLabelRose;

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

  /// No description provided for @chatCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get chatCopyText;

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

  /// No description provided for @chatEncryptedMessage.
  ///
  /// In en, this message translates to:
  /// **'Encrypted message'**
  String get chatEncryptedMessage;

  /// No description provided for @chatMessageForwarded.
  ///
  /// In en, this message translates to:
  /// **'Message forwarded'**
  String get chatMessageForwarded;

  /// No description provided for @chatMessageTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied to clipboard'**
  String get chatMessageTextCopied;

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

  /// No description provided for @chatCircleVideo.
  ///
  /// In en, this message translates to:
  /// **'Circle video'**
  String get chatCircleVideo;

  /// No description provided for @chatCircleVideoHoldHint.
  ///
  /// In en, this message translates to:
  /// **'Hold to record, release to send'**
  String get chatCircleVideoHoldHint;

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
  /// **'Refresh'**
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

  /// No description provided for @mediaViewerFlipCamera.
  ///
  /// In en, this message translates to:
  /// **'Flip camera'**
  String get mediaViewerFlipCamera;

  /// No description provided for @mediaViewerRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get mediaViewerRecording;

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

  /// No description provided for @adminUserBanned.
  ///
  /// In en, this message translates to:
  /// **'User {id} banned'**
  String adminUserBanned(int id);

  /// No description provided for @adminUserUnbanned.
  ///
  /// In en, this message translates to:
  /// **'User {id} unbanned'**
  String adminUserUnbanned(int id);

  /// No description provided for @adminUserFrozen.
  ///
  /// In en, this message translates to:
  /// **'User {id} frozen'**
  String adminUserFrozen(int id);

  /// No description provided for @adminUserUnfrozen.
  ///
  /// In en, this message translates to:
  /// **'User {id} unfrozen'**
  String adminUserUnfrozen(int id);

  /// No description provided for @adminSpamBlockEnabled.
  ///
  /// In en, this message translates to:
  /// **'Spam block enabled for user {id}'**
  String adminSpamBlockEnabled(int id);

  /// No description provided for @adminSpamBlockDisabled.
  ///
  /// In en, this message translates to:
  /// **'Spam block disabled for user {id}'**
  String adminSpamBlockDisabled(int id);

  /// No description provided for @adminChatBanned.
  ///
  /// In en, this message translates to:
  /// **'Chat {id} banned'**
  String adminChatBanned(int id);

  /// No description provided for @adminChatUnbanned.
  ///
  /// In en, this message translates to:
  /// **'Chat {id} unbanned'**
  String adminChatUnbanned(int id);

  /// No description provided for @adminTabUsers.
  ///
  /// In en, this message translates to:
  /// **'Users ({count})'**
  String adminTabUsers(int count);

  /// No description provided for @adminTabChats.
  ///
  /// In en, this message translates to:
  /// **'Chats ({count})'**
  String adminTabChats(int count);

  /// No description provided for @adminActionBan.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get adminActionBan;

  /// No description provided for @adminActionUnban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get adminActionUnban;

  /// No description provided for @adminActionFreeze.
  ///
  /// In en, this message translates to:
  /// **'Freeze'**
  String get adminActionFreeze;

  /// No description provided for @adminActionUnfreeze.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze'**
  String get adminActionUnfreeze;

  /// No description provided for @adminActionSpamBlock.
  ///
  /// In en, this message translates to:
  /// **'Spam Block'**
  String get adminActionSpamBlock;

  /// No description provided for @adminActionUnspamBlock.
  ///
  /// In en, this message translates to:
  /// **'Remove Spam Block'**
  String get adminActionUnspamBlock;

  /// No description provided for @badgeCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Badge'**
  String get badgeCreateTitle;

  /// No description provided for @badgeAwardTitle.
  ///
  /// In en, this message translates to:
  /// **'Award Badge'**
  String get badgeAwardTitle;

  /// No description provided for @badgeActionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get badgeActionCreate;

  /// No description provided for @badgeActionAward.
  ///
  /// In en, this message translates to:
  /// **'Award'**
  String get badgeActionAward;

  /// No description provided for @badgeCreated.
  ///
  /// In en, this message translates to:
  /// **'Badge created'**
  String get badgeCreated;

  /// No description provided for @badgeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Badge {id} deleted'**
  String badgeDeleted(int id);

  /// No description provided for @badgeAwarded.
  ///
  /// In en, this message translates to:
  /// **'Badge {badgeId} awarded to user {userId}'**
  String badgeAwarded(int badgeId, int userId);

  /// No description provided for @badgeNoBadges.
  ///
  /// In en, this message translates to:
  /// **'No badges available'**
  String get badgeNoBadges;

  /// No description provided for @badgeListRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get badgeListRefresh;

  /// No description provided for @botCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Bot'**
  String get botCreateTitle;

  /// No description provided for @botBotToken.
  ///
  /// In en, this message translates to:
  /// **'Bot Token'**
  String get botBotToken;

  /// No description provided for @botActionUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get botActionUse;

  /// No description provided for @botTokenCopied.
  ///
  /// In en, this message translates to:
  /// **'Token copied'**
  String get botTokenCopied;

  /// No description provided for @botNoUpdates.
  ///
  /// In en, this message translates to:
  /// **'No updates'**
  String get botNoUpdates;

  /// No description provided for @e2eeKeyGenerated.
  ///
  /// In en, this message translates to:
  /// **'E2EE key generated and uploaded'**
  String get e2eeKeyGenerated;

  /// No description provided for @mediaDownloadAndOpen.
  ///
  /// In en, this message translates to:
  /// **'Download & Open'**
  String get mediaDownloadAndOpen;

  /// No description provided for @mediaSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String mediaSavedTo(Object path);

  /// No description provided for @mediaDownloadFailedExt.
  ///
  /// In en, this message translates to:
  /// **'Could not download. Try opening externally.'**
  String get mediaDownloadFailedExt;

  /// No description provided for @mediaDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String mediaDownloadFailed(Object error);

  /// No description provided for @dialogCancelChatCreationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel?'**
  String get dialogCancelChatCreationTitle;

  /// No description provided for @dialogCancelChatCreationBody.
  ///
  /// In en, this message translates to:
  /// **'Chat creation is in progress. Cancel?'**
  String get dialogCancelChatCreationBody;

  /// No description provided for @dialogCancelCommentTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel?'**
  String get dialogCancelCommentTitle;

  /// No description provided for @dialogCancelCommentBody.
  ///
  /// In en, this message translates to:
  /// **'Comment sending is in progress. Cancel?'**
  String get dialogCancelCommentBody;

  /// No description provided for @emptyStateNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get emptyStateNoItems;

  /// No description provided for @emptyStateNoItemsDesc.
  ///
  /// In en, this message translates to:
  /// **'There\'s nothing to show here yet.'**
  String get emptyStateNoItemsDesc;

  /// No description provided for @offlineWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for network...'**
  String get offlineWaiting;

  /// No description provided for @filePreviewSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get filePreviewSave;

  /// No description provided for @filePreviewLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get filePreviewLink;

  /// No description provided for @filePreviewOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get filePreviewOpen;

  /// No description provided for @filePreviewForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get filePreviewForward;

  /// No description provided for @filePreviewFileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get filePreviewFileName;

  /// No description provided for @filePreviewClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get filePreviewClose;

  /// No description provided for @filePreviewLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get filePreviewLinkCopied;

  /// No description provided for @filePreviewPathCopied.
  ///
  /// In en, this message translates to:
  /// **'File path copied to clipboard'**
  String get filePreviewPathCopied;

  /// No description provided for @filePreviewSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get filePreviewSaved;

  /// No description provided for @filePreviewSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save file: {error}'**
  String filePreviewSaveError(Object error);

  /// No description provided for @filePreviewPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get filePreviewPause;

  /// No description provided for @filePreviewPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get filePreviewPlay;

  /// No description provided for @filePickerGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get filePickerGallery;

  /// No description provided for @filePickerDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get filePickerDocument;

  /// No description provided for @filePickerAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get filePickerAudio;

  /// No description provided for @filePickerFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get filePickerFile;

  /// No description provided for @filePickerReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read selected file'**
  String get filePickerReadError;

  /// No description provided for @badgeFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get badgeFieldName;

  /// No description provided for @badgeFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get badgeFieldDescription;

  /// No description provided for @badgeFieldIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon (emoji)'**
  String get badgeFieldIcon;

  /// No description provided for @badgeFieldColor.
  ///
  /// In en, this message translates to:
  /// **'Color (hex)'**
  String get badgeFieldColor;

  /// No description provided for @badgeFieldUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get badgeFieldUserId;

  /// No description provided for @badgeFieldBadgeId.
  ///
  /// In en, this message translates to:
  /// **'Badge ID'**
  String get badgeFieldBadgeId;

  /// No description provided for @badgeAdminPassword.
  ///
  /// In en, this message translates to:
  /// **'Admin Password'**
  String get badgeAdminPassword;

  /// No description provided for @badgeAdminMode.
  ///
  /// In en, this message translates to:
  /// **'Admin Mode'**
  String get badgeAdminMode;

  /// No description provided for @badgeAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show admin badge management'**
  String get badgeAdminSubtitle;

  /// No description provided for @botFieldName.
  ///
  /// In en, this message translates to:
  /// **'Bot Name'**
  String get botFieldName;

  /// No description provided for @botFieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get botFieldUsername;

  /// No description provided for @botFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get botFieldDescription;

  /// No description provided for @botFieldToken.
  ///
  /// In en, this message translates to:
  /// **'Enter bot token'**
  String get botFieldToken;

  /// No description provided for @botSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Bots'**
  String get botSectionTitle;

  /// No description provided for @botSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create and manage your bots.'**
  String get botSectionSubtitle;

  /// No description provided for @botCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new bot'**
  String get botCreateSubtitle;

  /// No description provided for @botCreateDescription.
  ///
  /// In en, this message translates to:
  /// **'Register a bot account'**
  String get botCreateDescription;

  /// No description provided for @botUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Bot Updates'**
  String get botUpdatesTitle;

  /// No description provided for @botGetUpdates.
  ///
  /// In en, this message translates to:
  /// **'Get updates'**
  String get botGetUpdates;

  /// No description provided for @botPollSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Poll for new bot messages and callbacks'**
  String get botPollSubtitle;

  /// No description provided for @botCreated.
  ///
  /// In en, this message translates to:
  /// **'Bot created!'**
  String get botCreated;

  /// No description provided for @botCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get botCopied;

  /// No description provided for @fluidPreviewM3Title.
  ///
  /// In en, this message translates to:
  /// **'M3 Expressive Design'**
  String get fluidPreviewM3Title;

  /// No description provided for @fluidPreviewM3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'New indicators and smooth transitions are already available!'**
  String get fluidPreviewM3Subtitle;

  /// No description provided for @profileAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get profileAvatarUpdated;

  /// No description provided for @profileError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String profileError(Object error);

  /// No description provided for @chatImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get chatImageUnavailable;

  /// No description provided for @settingsRevokeSession.
  ///
  /// In en, this message translates to:
  /// **'Revoke session'**
  String get settingsRevokeSession;

  /// No description provided for @tabNiosgram.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get tabNiosgram;

  /// No description provided for @niosgramTitle.
  ///
  /// In en, this message translates to:
  /// **'NiosGram'**
  String get niosgramTitle;

  /// No description provided for @niosgramCreatePost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get niosgramCreatePost;

  /// No description provided for @niosgramPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get niosgramPublish;

  /// No description provided for @niosgramWhatMind.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get niosgramWhatMind;

  /// No description provided for @niosgramAttachMedia.
  ///
  /// In en, this message translates to:
  /// **'Attach media'**
  String get niosgramAttachMedia;

  /// No description provided for @niosgramRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get niosgramRemove;

  /// No description provided for @niosgramEmptyFeed.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get niosgramEmptyFeed;

  /// No description provided for @niosgramEmptyFeedDesc.
  ///
  /// In en, this message translates to:
  /// **'Be the first to share something!'**
  String get niosgramEmptyFeedDesc;

  /// No description provided for @niosgramLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get niosgramLoadMore;

  /// No description provided for @niosgramComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get niosgramComments;

  /// No description provided for @niosgramWriteComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get niosgramWriteComment;

  /// No description provided for @niosgramLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get niosgramLike;

  /// No description provided for @niosgramDislike.
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get niosgramDislike;

  /// No description provided for @niosgramDeletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete post?'**
  String get niosgramDeletePost;

  /// No description provided for @niosgramDeletePostConfirm.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get niosgramDeletePostConfirm;

  /// No description provided for @niosgramCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get niosgramCopied;

  /// No description provided for @niosgramEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get niosgramEdit;

  /// No description provided for @niosgramDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get niosgramDelete;

  /// No description provided for @niosgramCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get niosgramCopyText;

  /// No description provided for @niosgramEditPost.
  ///
  /// In en, this message translates to:
  /// **'Edit your post...'**
  String get niosgramEditPost;

  /// No description provided for @niosgramFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File exceeds 10 MB limit'**
  String get niosgramFileTooLarge;

  /// No description provided for @niosgramEmptyContent.
  ///
  /// In en, this message translates to:
  /// **'Write something or attach a file'**
  String get niosgramEmptyContent;

  /// No description provided for @niosgramFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load feed'**
  String get niosgramFailedLoad;

  /// No description provided for @settingsPrivacyBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications, visibility and system account limits.'**
  String get settingsPrivacyBannerSubtitle;

  /// No description provided for @settingsPrivacyNotificationsManage.
  ///
  /// In en, this message translates to:
  /// **'Manage app push notifications'**
  String get settingsPrivacyNotificationsManage;

  /// No description provided for @settingsPrivacyVisibilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Control presence status in the app'**
  String get settingsPrivacyVisibilityDesc;

  /// No description provided for @settingsPrivacyHideOnline.
  ///
  /// In en, this message translates to:
  /// **'Hide online status'**
  String get settingsPrivacyHideOnline;

  /// No description provided for @settingsPrivacyHideOnlineDesc.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show your presence status to other users'**
  String get settingsPrivacyHideOnlineDesc;

  /// No description provided for @settingsStorageBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Memory usage, cache and app drafts.'**
  String get settingsStorageBannerSubtitle;

  /// No description provided for @settingsStorageLegendCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get settingsStorageLegendCache;

  /// No description provided for @settingsStorageLegendDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get settingsStorageLegendDrafts;

  /// No description provided for @settingsStorageCategoryAppData.
  ///
  /// In en, this message translates to:
  /// **'App Data'**
  String get settingsStorageCategoryAppData;

  /// No description provided for @settingsStorageCategoryCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get settingsStorageCategoryCache;

  /// No description provided for @settingsStorageCategoryDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get settingsStorageCategoryDrafts;

  /// No description provided for @settingsAboutBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support, legal information and app details.'**
  String get settingsAboutBannerSubtitle;

  /// No description provided for @settingsAboutHelpDesc.
  ///
  /// In en, this message translates to:
  /// **'FAQ and contact options'**
  String get settingsAboutHelpDesc;

  /// No description provided for @settingsAboutVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'NiosMess'**
  String get settingsAboutVersionTitle;

  /// No description provided for @settingsAboutVersionDesc.
  ///
  /// In en, this message translates to:
  /// **'App version and service items'**
  String get settingsAboutVersionDesc;

  /// No description provided for @settingsAboutLegalDesc.
  ///
  /// In en, this message translates to:
  /// **'Policies and external resources'**
  String get settingsAboutLegalDesc;

  /// No description provided for @settingsAccountBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Login security, email verification and active sessions.'**
  String get settingsAccountBannerSubtitle;

  /// No description provided for @settingsAccountAccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Main actions for access and account recovery'**
  String get settingsAccountAccessDesc;

  /// No description provided for @settingsLanguageBannerDesc.
  ///
  /// In en, this message translates to:
  /// **'App language and UI localization'**
  String get settingsLanguageBannerDesc;

  /// No description provided for @settingsLanguageCurrentLang.
  ///
  /// In en, this message translates to:
  /// **'Current language'**
  String get settingsLanguageCurrentLang;

  /// No description provided for @settingsLanguageTzDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-detection or manual timezone selection'**
  String get settingsLanguageTzDesc;

  /// No description provided for @settingsLanguageTimePreview.
  ///
  /// In en, this message translates to:
  /// **'Date and time preview'**
  String get settingsLanguageTimePreview;

  /// No description provided for @settingsLanguageLocalTime.
  ///
  /// In en, this message translates to:
  /// **'Local time'**
  String get settingsLanguageLocalTime;

  /// No description provided for @sessionsBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your active devices and sessions.'**
  String get sessionsBannerSubtitle;

  /// No description provided for @sessionsRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'This device will be logged out if it\'s the current session.'**
  String get sessionsRevokeBody;

  /// No description provided for @sessionsActive.
  ///
  /// In en, this message translates to:
  /// **'Active: {time}'**
  String sessionsActive(Object time);

  /// No description provided for @sessionsCreated.
  ///
  /// In en, this message translates to:
  /// **'Created: {time}'**
  String sessionsCreated(Object time);

  /// No description provided for @sessionsCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get sessionsCurrent;

  /// No description provided for @onboardingSlide1Title.
  ///
  /// In en, this message translates to:
  /// **'Fast calls with less friction'**
  String get onboardingSlide1Title;

  /// No description provided for @onboardingSlide1Desc.
  ///
  /// In en, this message translates to:
  /// **'Call teammates in one tap and switch between voice and video without leaving the flow.'**
  String get onboardingSlide1Desc;

  /// No description provided for @onboardingSlide2Title.
  ///
  /// In en, this message translates to:
  /// **'Organized conversations'**
  String get onboardingSlide2Title;

  /// No description provided for @onboardingSlide2Desc.
  ///
  /// In en, this message translates to:
  /// **'Keep your chats, calls, and contacts in one focused workspace that stays easy to scan.'**
  String get onboardingSlide2Desc;

  /// No description provided for @onboardingSlide3Title.
  ///
  /// In en, this message translates to:
  /// **'Designed for daily rhythm'**
  String get onboardingSlide3Title;

  /// No description provided for @onboardingSlide3Desc.
  ///
  /// In en, this message translates to:
  /// **'Smooth transitions and clear hierarchy keep communication calm even on a busy day.'**
  String get onboardingSlide3Desc;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @mediaViewerDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get mediaViewerDownload;

  /// No description provided for @mediaViewerImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image: {error}'**
  String mediaViewerImageLoadFailed(Object error);

  /// No description provided for @mediaViewerDownloadWeb.
  ///
  /// In en, this message translates to:
  /// **'Download is not supported in web version'**
  String get mediaViewerDownloadWeb;

  /// No description provided for @mediaViewerDownloadFailedExt.
  ///
  /// In en, this message translates to:
  /// **'Could not download. Try opening externally.'**
  String get mediaViewerDownloadFailedExt;

  /// No description provided for @directResolverResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving @{username}'**
  String directResolverResolving(Object username);

  /// No description provided for @directResolverSecretEstablishing.
  ///
  /// In en, this message translates to:
  /// **'Establishing end-to-end encrypted channel...'**
  String get directResolverSecretEstablishing;

  /// No description provided for @directResolverPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your secure direct conversation in NiosMess.'**
  String get directResolverPreparing;

  /// No description provided for @directResolverUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get directResolverUserNotFound;

  /// No description provided for @directResolverUserNotFoundDesc.
  ///
  /// In en, this message translates to:
  /// **'We could not resolve this user right now.'**
  String get directResolverUserNotFoundDesc;

  /// No description provided for @directResolverSecretTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret Chat'**
  String get directResolverSecretTitle;

  /// No description provided for @postNewPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get postNewPost;

  /// No description provided for @postPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get postPublish;

  /// No description provided for @postHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get postHint;

  /// No description provided for @postRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get postRemove;

  /// No description provided for @postAttachMedia.
  ///
  /// In en, this message translates to:
  /// **'Attach media'**
  String get postAttachMedia;

  /// No description provided for @postFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File exceeds 10 MB limit'**
  String get postFileTooLarge;

  /// No description provided for @postEmptyContent.
  ///
  /// In en, this message translates to:
  /// **'Write something or attach a file'**
  String get postEmptyContent;

  /// No description provided for @chatCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create chat'**
  String get chatCreateFailed;

  /// No description provided for @chatChannelCreated.
  ///
  /// In en, this message translates to:
  /// **'Channel created'**
  String get chatChannelCreated;

  /// No description provided for @chatGroupCreated.
  ///
  /// In en, this message translates to:
  /// **'Group created'**
  String get chatGroupCreated;

  /// No description provided for @chatChooseNextStep.
  ///
  /// In en, this message translates to:
  /// **'Choose what you want to do next.'**
  String get chatChooseNextStep;

  /// No description provided for @chatOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get chatOpenChat;

  /// No description provided for @chatCopyInvite.
  ///
  /// In en, this message translates to:
  /// **'Copy invite'**
  String get chatCopyInvite;

  /// No description provided for @chatInviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied'**
  String get chatInviteLinkCopied;

  /// No description provided for @chatCommentsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get chatCommentsEnabled;

  /// No description provided for @chatCommentsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get chatCommentsDisabled;

  /// No description provided for @profileSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettingsSection;

  /// No description provided for @profileSettingsSectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Main account and app settings'**
  String get profileSettingsSectionDesc;

  /// No description provided for @profileSectionQuickSettings.
  ///
  /// In en, this message translates to:
  /// **'Quick Settings'**
  String get profileSectionQuickSettings;

  /// No description provided for @profileSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get profileSectionPrivacy;

  /// No description provided for @profileSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileSectionAccount;

  /// No description provided for @profileSectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get profileSectionData;

  /// No description provided for @profileSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileSectionAbout;

  /// No description provided for @profileAppearanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Theme, colors'**
  String get profileAppearanceDesc;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get profileLanguageDesc;

  /// No description provided for @profileTeamTools.
  ///
  /// In en, this message translates to:
  /// **'Team & tools'**
  String get profileTeamTools;

  /// No description provided for @profileTeamToolsDesc.
  ///
  /// In en, this message translates to:
  /// **'Project team and additional sections'**
  String get profileTeamToolsDesc;

  /// No description provided for @chatManageInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get chatManageInviteLink;

  /// No description provided for @chatManageCopyInvite.
  ///
  /// In en, this message translates to:
  /// **'Copy invite'**
  String get chatManageCopyInvite;

  /// No description provided for @chatManageShareInvite.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get chatManageShareInvite;

  /// No description provided for @chatManageShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get chatManageShareLink;

  /// No description provided for @chatManageCommentsChatId.
  ///
  /// In en, this message translates to:
  /// **'Comments chat ID'**
  String get chatManageCommentsChatId;

  /// No description provided for @chatManageCopied.
  ///
  /// In en, this message translates to:
  /// **'{title} copied'**
  String chatManageCopied(Object title);

  /// No description provided for @chatManageCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatManageCopy;

  /// No description provided for @chatManageName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get chatManageName;

  /// No description provided for @chatManageDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get chatManageDescription;

  /// No description provided for @chatManageSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get chatManageSaveChanges;

  /// No description provided for @chatManageChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get chatManageChannel;

  /// No description provided for @chatManageGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get chatManageGroup;

  /// No description provided for @adminPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanelTitle;

  /// No description provided for @adminPanelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage users and chats with admin password.'**
  String get adminPanelSubtitle;

  /// No description provided for @adminAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get adminAuthentication;

  /// No description provided for @adminPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin Password'**
  String get adminPasswordLabel;

  /// No description provided for @adminConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get adminConnecting;

  /// No description provided for @adminConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get adminConnect;

  /// No description provided for @adminStatusBanned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get adminStatusBanned;

  /// No description provided for @adminStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminStatusActive;

  /// No description provided for @adminStatusFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get adminStatusFrozen;

  /// No description provided for @adminStatusSpamBlock.
  ///
  /// In en, this message translates to:
  /// **'Spam Block'**
  String get adminStatusSpamBlock;

  /// No description provided for @adminActionUnblockSpam.
  ///
  /// In en, this message translates to:
  /// **'Unblock Spam'**
  String get adminActionUnblockSpam;

  /// No description provided for @adminChatUnban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get adminChatUnban;

  /// No description provided for @adminChatBan.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get adminChatBan;

  /// No description provided for @badgeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badgeScreenTitle;

  /// No description provided for @badgeAvailableBadges.
  ///
  /// In en, this message translates to:
  /// **'Available Badges'**
  String get badgeAvailableBadges;

  /// No description provided for @badgeAdminActions.
  ///
  /// In en, this message translates to:
  /// **'Admin Actions'**
  String get badgeAdminActions;

  /// No description provided for @badgeCopied.
  ///
  /// In en, this message translates to:
  /// **'Badge created'**
  String get badgeCopied;

  /// No description provided for @e2eeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret Chats'**
  String get e2eeScreenTitle;

  /// No description provided for @e2eeBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret Chats (E2EE)'**
  String get e2eeBannerTitle;

  /// No description provided for @e2eeBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted chats are tied to this device. Generate a key pair to enable secret chats.'**
  String get e2eeBannerSubtitle;

  /// No description provided for @e2eeDeviceKey.
  ///
  /// In en, this message translates to:
  /// **'Device Key'**
  String get e2eeDeviceKey;

  /// No description provided for @e2eeKeyPairReady.
  ///
  /// In en, this message translates to:
  /// **'Key pair ready'**
  String get e2eeKeyPairReady;

  /// No description provided for @e2eeNoKeyPair.
  ///
  /// In en, this message translates to:
  /// **'No key pair'**
  String get e2eeNoKeyPair;

  /// No description provided for @e2eeTapToRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Tap to regenerate'**
  String get e2eeTapToRegenerate;

  /// No description provided for @e2eeGenerateKeyPair.
  ///
  /// In en, this message translates to:
  /// **'Generate Curve25519 key pair for E2EE'**
  String get e2eeGenerateKeyPair;

  /// No description provided for @e2eeRotateKey.
  ///
  /// In en, this message translates to:
  /// **'Rotate Key'**
  String get e2eeRotateKey;

  /// No description provided for @e2eeRotateKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate new key pair (old secret chats will break)'**
  String get e2eeRotateKeySubtitle;

  /// No description provided for @e2eeHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get e2eeHowItWorks;

  /// No description provided for @e2eeHowItWorksDesc.
  ///
  /// In en, this message translates to:
  /// **'• Each device generates its own Curve25519 (X25519) key pair\n• Public key is shared with the server\n• Private key stays on this device only\n• Secret chats are visible only on this device\n• Messages are encrypted with AES-256-GCM\n• Shared secret is computed via ECDH (X25519)'**
  String get e2eeHowItWorksDesc;

  /// No description provided for @e2eeCreateSecretChat.
  ///
  /// In en, this message translates to:
  /// **'Create Secret Chat'**
  String get e2eeCreateSecretChat;

  /// No description provided for @e2eeCreateSecretChatDesc.
  ///
  /// In en, this message translates to:
  /// **'To start a secret chat, open a direct chat from contacts.\nSecret chat option will be available after generating your key pair.'**
  String get e2eeCreateSecretChatDesc;

  /// No description provided for @e2eeRotateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Rotate Key?'**
  String get e2eeRotateConfirmTitle;

  /// No description provided for @e2eeRotateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your old secret chats will become undecryptable after key rotation. New messages will use the fresh key.'**
  String get e2eeRotateConfirmBody;

  /// No description provided for @e2eeRotateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get e2eeRotateConfirm;

  /// No description provided for @e2eeGeneratingKeys.
  ///
  /// In en, this message translates to:
  /// **'Generating encryption keys'**
  String get e2eeGeneratingKeys;

  /// No description provided for @e2eeGeneratingKeysDesc.
  ///
  /// In en, this message translates to:
  /// **'Curve25519 key pair is being created...'**
  String get e2eeGeneratingKeysDesc;

  /// No description provided for @e2eeKeyRotated.
  ///
  /// In en, this message translates to:
  /// **'Key rotated and uploaded'**
  String get e2eeKeyRotated;

  /// No description provided for @e2eeEraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Erase Secret Chats'**
  String get e2eeEraseTitle;

  /// No description provided for @e2eeEraseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all secret chat history physically from the server'**
  String get e2eeEraseSubtitle;

  /// No description provided for @e2eeEraseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Erase all secret chats?'**
  String get e2eeEraseConfirmTitle;

  /// No description provided for @e2eeEraseConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All secret chat history and associated files will be permanently deleted from the server. This action cannot be undone.'**
  String get e2eeEraseConfirmBody;

  /// No description provided for @e2eeEraseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get e2eeEraseConfirm;

  /// No description provided for @e2eeEraseDone.
  ///
  /// In en, this message translates to:
  /// **'Deleted {chats} chats and {files} files'**
  String e2eeEraseDone(int chats, int files);

  /// No description provided for @chatMembersBanConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Ban member?'**
  String get chatMembersBanConfirmTitle;

  /// No description provided for @chatMembersUnbanConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unban member?'**
  String get chatMembersUnbanConfirmTitle;

  /// No description provided for @chatMembersBanConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This member will lose access until you restore them.'**
  String get chatMembersBanConfirmBody;

  /// No description provided for @chatMembersUnbanConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Restore this member and let them rejoin the conversation.'**
  String get chatMembersUnbanConfirmBody;

  /// No description provided for @chatMembersMuteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Mute member?'**
  String get chatMembersMuteConfirmTitle;

  /// No description provided for @chatMembersUnmuteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unmute member?'**
  String get chatMembersUnmuteConfirmTitle;

  /// No description provided for @chatMembersMuteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Muted members can stay in the chat but cannot participate normally.'**
  String get chatMembersMuteConfirmBody;

  /// No description provided for @chatMembersUnmuteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Allow this member to participate again.'**
  String get chatMembersUnmuteConfirmBody;

  /// No description provided for @chatMembersFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String chatMembersFailed(Object error);

  /// No description provided for @contactsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String contactsFailedToLoad(Object error);

  /// No description provided for @contactsFailedToSearch.
  ///
  /// In en, this message translates to:
  /// **'Failed to search: {error}'**
  String contactsFailedToSearch(Object error);

  /// No description provided for @contactsCouldNotOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Could not open direct chat'**
  String get contactsCouldNotOpenChat;

  /// No description provided for @contactsFailedToOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Failed to open direct chat: {error}'**
  String contactsFailedToOpenChat(Object error);

  /// No description provided for @contactsMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String contactsMembersCount(int count);

  /// No description provided for @settingsSupportEmail.
  ///
  /// In en, this message translates to:
  /// **'support@ni-os.ru'**
  String get settingsSupportEmail;

  /// No description provided for @settingsPrivacyPolicyUrl.
  ///
  /// In en, this message translates to:
  /// **'ni-os.ru/privacy'**
  String get settingsPrivacyPolicyUrl;

  /// No description provided for @settingsTermsOfServiceUrl.
  ///
  /// In en, this message translates to:
  /// **'ni-os.ru/terms'**
  String get settingsTermsOfServiceUrl;

  /// No description provided for @settingsWebsiteUrl.
  ///
  /// In en, this message translates to:
  /// **'ni-os.ru'**
  String get settingsWebsiteUrl;

  /// No description provided for @settingsAboutNiosMess.
  ///
  /// In en, this message translates to:
  /// **'NiosMess'**
  String get settingsAboutNiosMess;

  /// No description provided for @biometricTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometrics'**
  String get biometricTitle;

  /// No description provided for @biometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled — sign in with fingerprint/face'**
  String get biometricEnabled;

  /// No description provided for @biometricDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get biometricDisabled;

  /// No description provided for @biometricAuthReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm your identity to enable biometrics'**
  String get biometricAuthReason;

  /// No description provided for @chatManageCopiedLabel.
  ///
  /// In en, this message translates to:
  /// **'{title} copied'**
  String chatManageCopiedLabel(Object title);

  /// No description provided for @chatAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get chatAiAssistant;

  /// No description provided for @chatAiProcessed.
  ///
  /// In en, this message translates to:
  /// **'Text successfully processed by AI'**
  String get chatAiProcessed;

  /// No description provided for @chatAiUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get chatAiUndo;

  /// No description provided for @chatAiError.
  ///
  /// In en, this message translates to:
  /// **'AI processing error: {error}'**
  String chatAiError(Object error);

  /// No description provided for @chatAiFixErrors.
  ///
  /// In en, this message translates to:
  /// **'Fix errors'**
  String get chatAiFixErrors;

  /// No description provided for @chatAiFormal.
  ///
  /// In en, this message translates to:
  /// **'Formal'**
  String get chatAiFormal;

  /// No description provided for @chatAiTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get chatAiTranslate;

  /// No description provided for @chatAiLangEn.
  ///
  /// In en, this message translates to:
  /// **'Eng'**
  String get chatAiLangEn;

  /// No description provided for @chatAiLangRu.
  ///
  /// In en, this message translates to:
  /// **'Rus'**
  String get chatAiLangRu;

  /// No description provided for @chatAiLangDe.
  ///
  /// In en, this message translates to:
  /// **'Deu'**
  String get chatAiLangDe;

  /// No description provided for @chatAiLangFr.
  ///
  /// In en, this message translates to:
  /// **'Fra'**
  String get chatAiLangFr;

  /// No description provided for @chatAiLangEs.
  ///
  /// In en, this message translates to:
  /// **'Esp'**
  String get chatAiLangEs;

  /// No description provided for @chatAiLangZh.
  ///
  /// In en, this message translates to:
  /// **'Zho'**
  String get chatAiLangZh;

  /// No description provided for @chatDraftRestored.
  ///
  /// In en, this message translates to:
  /// **'Draft restored on this device'**
  String get chatDraftRestored;

  /// No description provided for @fileOpenerInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid file URL'**
  String get fileOpenerInvalidUrl;

  /// No description provided for @fileOpenerFailedOpenRemote.
  ///
  /// In en, this message translates to:
  /// **'Failed to open remote file'**
  String get fileOpenerFailedOpenRemote;

  /// No description provided for @fileOpenerCannotOpenType.
  ///
  /// In en, this message translates to:
  /// **'Cannot open this file type'**
  String get fileOpenerCannotOpenType;

  /// No description provided for @fileOpenerApkAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'APK files can only be installed on Android devices'**
  String get fileOpenerApkAndroidOnly;

  /// No description provided for @fileOpenerFailedApk.
  ///
  /// In en, this message translates to:
  /// **'Failed to open APK: {error}'**
  String fileOpenerFailedApk(Object error);

  /// No description provided for @fileOpenerExeNotOnMobile.
  ///
  /// In en, this message translates to:
  /// **'EXE files cannot be opened on mobile devices'**
  String get fileOpenerExeNotOnMobile;

  /// No description provided for @fileOpenerFailedExe.
  ///
  /// In en, this message translates to:
  /// **'Failed to open EXE: {error}'**
  String fileOpenerFailedExe(Object error);

  /// No description provided for @fileOpenerNoAppFound.
  ///
  /// In en, this message translates to:
  /// **'No app found to open {type} files'**
  String fileOpenerNoAppFound(Object type);

  /// No description provided for @chatEmojiToggle.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get chatEmojiToggle;

  /// No description provided for @chatVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get chatVoiceMessage;

  /// No description provided for @chatSearchInChat.
  ///
  /// In en, this message translates to:
  /// **'Search in chat'**
  String get chatSearchInChat;

  /// No description provided for @chatTyping.
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get chatTyping;

  /// No description provided for @chatReactedWith.
  ///
  /// In en, this message translates to:
  /// **'Reacted with {emoji}'**
  String chatReactedWith(Object emoji);

  /// No description provided for @chatReadBy.
  ///
  /// In en, this message translates to:
  /// **'Read by'**
  String get chatReadBy;

  /// No description provided for @chatForwardedCard.
  ///
  /// In en, this message translates to:
  /// **'Forwarded message'**
  String get chatForwardedCard;

  /// No description provided for @messageSentByMe.
  ///
  /// In en, this message translates to:
  /// **'Sent by me'**
  String get messageSentByMe;

  /// No description provided for @messageSemantics.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageSemantics;

  /// No description provided for @chatE2eeBanner.
  ///
  /// In en, this message translates to:
  /// **'Messages are end-to-end encrypted. No one outside of this chat can read them.'**
  String get chatE2eeBanner;

  /// No description provided for @chatForwardRestricted.
  ///
  /// In en, this message translates to:
  /// **'Forwarding is not allowed in secret chats'**
  String get chatForwardRestricted;

  /// No description provided for @chatDisappearingMessages.
  ///
  /// In en, this message translates to:
  /// **'Disappearing messages'**
  String get chatDisappearingMessages;

  /// No description provided for @chatDisappearingOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get chatDisappearingOff;

  /// No description provided for @chatDisappearing5s.
  ///
  /// In en, this message translates to:
  /// **'5 seconds'**
  String get chatDisappearing5s;

  /// No description provided for @chatDisappearing1m.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get chatDisappearing1m;

  /// No description provided for @chatDisappearing1h.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get chatDisappearing1h;

  /// No description provided for @chatDisappearing1d.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get chatDisappearing1d;

  /// No description provided for @settingsPredictiveBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get settingsPredictiveBackTitle;

  /// No description provided for @settingsPredictiveBackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'System gestures and back behavior'**
  String get settingsPredictiveBackSubtitle;

  /// No description provided for @settingsPredictiveBackToggle.
  ///
  /// In en, this message translates to:
  /// **'Predictive back gesture'**
  String get settingsPredictiveBackToggle;

  /// No description provided for @settingsPredictiveBackDesc.
  ///
  /// In en, this message translates to:
  /// **'Android 13+ swipe animation'**
  String get settingsPredictiveBackDesc;

  /// No description provided for @settingsBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get settingsBackgroundTitle;

  /// No description provided for @settingsBackgroundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How the app runs in background'**
  String get settingsBackgroundSubtitle;

  /// No description provided for @settingsBackgroundEconomy.
  ///
  /// In en, this message translates to:
  /// **'Economy mode'**
  String get settingsBackgroundEconomy;

  /// No description provided for @settingsBackgroundEconomyDesc.
  ///
  /// In en, this message translates to:
  /// **'No notification, but system may close app rarely'**
  String get settingsBackgroundEconomyDesc;

  /// No description provided for @settingsBackgroundReliable.
  ///
  /// In en, this message translates to:
  /// **'Reliable mode'**
  String get settingsBackgroundReliable;

  /// No description provided for @settingsBackgroundReliableDesc.
  ///
  /// In en, this message translates to:
  /// **'With a cute notification to keep app alive'**
  String get settingsBackgroundReliableDesc;

  /// No description provided for @settingsBackgroundNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Background modes'**
  String get settingsBackgroundNotAvailable;

  /// No description provided for @settingsBackgroundNotAvailableDesc.
  ///
  /// In en, this message translates to:
  /// **'Available only on Android'**
  String get settingsBackgroundNotAvailableDesc;

  /// No description provided for @deepLinkResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving link...'**
  String get deepLinkResolving;

  /// No description provided for @deepLinkNotFound.
  ///
  /// In en, this message translates to:
  /// **'Content not found'**
  String get deepLinkNotFound;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMentionBody.
  ///
  /// In en, this message translates to:
  /// **'{username} mentioned you in a post'**
  String notificationsMentionBody(Object username);

  /// No description provided for @notificationsNewMessageBody.
  ///
  /// In en, this message translates to:
  /// **'New message in {chatName}'**
  String notificationsNewMessageBody(Object chatName);

  /// No description provided for @niosgramFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get niosgramFollow;

  /// No description provided for @niosgramUnfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get niosgramUnfollow;

  /// No description provided for @niosgramFollowers.
  ///
  /// In en, this message translates to:
  /// **'{count} followers'**
  String niosgramFollowers(Object count);

  /// No description provided for @niosgramFollowing.
  ///
  /// In en, this message translates to:
  /// **'{count} following'**
  String niosgramFollowing(Object count);

  /// No description provided for @niosgramLoadComments.
  ///
  /// In en, this message translates to:
  /// **'Load comments'**
  String get niosgramLoadComments;

  /// No description provided for @niosgramCommentSent.
  ///
  /// In en, this message translates to:
  /// **'Comment sent'**
  String get niosgramCommentSent;

  /// No description provided for @niosgramFailedFollow.
  ///
  /// In en, this message translates to:
  /// **'Failed to follow user'**
  String get niosgramFailedFollow;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Next-gen messenger'**
  String get aboutTagline;

  /// No description provided for @aboutFaqQ1.
  ///
  /// In en, this message translates to:
  /// **'What are secret chats and how are they different from regular ones?'**
  String get aboutFaqQ1;

  /// No description provided for @aboutFaqA1.
  ///
  /// In en, this message translates to:
  /// **'Secret chats use end-to-end encryption E2EE (RSA-2048 + AES-256-GCM). Messages are encrypted on your device and decrypted only on the recipient\'s device. The server has no access to the content. Regular chats are encrypted in transit (AES-256-GCM), but the server can read messages.'**
  String get aboutFaqA1;

  /// No description provided for @aboutFaqQ2.
  ///
  /// In en, this message translates to:
  /// **'How to create a secret chat?'**
  String get aboutFaqQ2;

  /// No description provided for @aboutFaqA2.
  ///
  /// In en, this message translates to:
  /// **'Open the Contacts tab, find the user and tap the lock icon next to their name. Or go to their profile and tap Secret Chat. Keys are generated automatically on your devices.'**
  String get aboutFaqA2;

  /// No description provided for @aboutFaqQ3.
  ///
  /// In en, this message translates to:
  /// **'What happens if I lose my device?'**
  String get aboutFaqQ3;

  /// No description provided for @aboutFaqA3.
  ///
  /// In en, this message translates to:
  /// **'Secret chats are tied to a specific device — keys are stored only on it. Losing a device means losing access to secret chat history. Regular chats are restored when you sign in from a new device.'**
  String get aboutFaqA3;

  /// No description provided for @aboutFaqQ4.
  ///
  /// In en, this message translates to:
  /// **'Can I use NiosMess on multiple devices?'**
  String get aboutFaqQ4;

  /// No description provided for @aboutFaqA4.
  ///
  /// In en, this message translates to:
  /// **'Yes, regular chats sync between devices. Secret chats do not — they are tied to one device. To communicate from a secret chat on a new device, you need to create a new secret chat with the same user.'**
  String get aboutFaqA4;

  /// No description provided for @aboutFaqQ5.
  ///
  /// In en, this message translates to:
  /// **'How to join a group or channel?'**
  String get aboutFaqQ5;

  /// No description provided for @aboutFaqA5.
  ///
  /// In en, this message translates to:
  /// **'Tap \"+\" on the Chats tab → Join Group. Enter the invitation code (slug) or open the invite link. Codes are issued by the group creator.'**
  String get aboutFaqA5;

  /// No description provided for @aboutFaqQ6.
  ///
  /// In en, this message translates to:
  /// **'What files can I send?'**
  String get aboutFaqQ6;

  /// No description provided for @aboutFaqA6.
  ///
  /// In en, this message translates to:
  /// **'Images, videos, documents (PDF, DOC, XLS, etc.), audio and voice messages. Maximum file size is 100 MB. Images are automatically compressed to save traffic.'**
  String get aboutFaqA6;

  /// No description provided for @aboutFaqQ7.
  ///
  /// In en, this message translates to:
  /// **'What is NiosGram and how is it different from regular chats?'**
  String get aboutFaqQ7;

  /// No description provided for @aboutFaqA7.
  ///
  /// In en, this message translates to:
  /// **'NiosGram is a social-media-style post feed. You can write posts with Markdown formatting, attach media, like/dislike, comment and follow authors. Unlike chats, content is public and accessible to all users.'**
  String get aboutFaqA7;

  /// No description provided for @aboutFaqQ8.
  ///
  /// In en, this message translates to:
  /// **'How does the AI assistant work in chats?'**
  String get aboutFaqQ8;

  /// No description provided for @aboutFaqA8.
  ///
  /// In en, this message translates to:
  /// **'The AI assistant corrects errors, formalizes text and translates to other languages. Select a message → tap AI → choose an action. The text is processed on the server and is not saved after processing.'**
  String get aboutFaqA8;

  /// No description provided for @aboutFaqQ9.
  ///
  /// In en, this message translates to:
  /// **'Where is my data stored?'**
  String get aboutFaqQ9;

  /// No description provided for @aboutFaqA9.
  ///
  /// In en, this message translates to:
  /// **'Regular messages are stored on the server encrypted. Secret chats exist only on your devices. The local message cache is encrypted with AES-256-GCM with a key stored in the device\'s secure storage (Keystore/Keychain).'**
  String get aboutFaqA9;

  /// No description provided for @aboutFaqQ10.
  ///
  /// In en, this message translates to:
  /// **'How to report a bug or suggest an improvement?'**
  String get aboutFaqQ10;

  /// No description provided for @aboutFaqA10.
  ///
  /// In en, this message translates to:
  /// **'Settings → About NiosMess → tap the Changelog tab → Report a Problem. Describe the issue — the email will be sent to support@ni-os.ru. Or write directly.'**
  String get aboutFaqA10;

  /// No description provided for @aboutChangelogDateJune2026.
  ///
  /// In en, this message translates to:
  /// **'June 2026'**
  String get aboutChangelogDateJune2026;

  /// No description provided for @aboutChangelogDateMarch2026.
  ///
  /// In en, this message translates to:
  /// **'March 2026'**
  String get aboutChangelogDateMarch2026;

  /// No description provided for @aboutChangelogDateJanuary2026.
  ///
  /// In en, this message translates to:
  /// **'January 2026'**
  String get aboutChangelogDateJanuary2026;

  /// No description provided for @aboutChangelogV210C1.
  ///
  /// In en, this message translates to:
  /// **'Predictive back gesture (Android 13+)'**
  String get aboutChangelogV210C1;

  /// No description provided for @aboutChangelogV210C2.
  ///
  /// In en, this message translates to:
  /// **'Background modes — economy and reliable'**
  String get aboutChangelogV210C2;

  /// No description provided for @aboutChangelogV210C3.
  ///
  /// In en, this message translates to:
  /// **'New themes and color schemes'**
  String get aboutChangelogV210C3;

  /// No description provided for @aboutChangelogV210C4.
  ///
  /// In en, this message translates to:
  /// **'Chat list performance optimizations'**
  String get aboutChangelogV210C4;

  /// No description provided for @aboutChangelogV210C5.
  ///
  /// In en, this message translates to:
  /// **'Screenshot protection in secret chats'**
  String get aboutChangelogV210C5;

  /// No description provided for @aboutChangelogV205C1.
  ///
  /// In en, this message translates to:
  /// **'Fixed chat scroll lags'**
  String get aboutChangelogV205C1;

  /// No description provided for @aboutChangelogV205C2.
  ///
  /// In en, this message translates to:
  /// **'Updated emoji picker'**
  String get aboutChangelogV205C2;

  /// No description provided for @aboutChangelogV205C3.
  ///
  /// In en, this message translates to:
  /// **'Improved transition animations'**
  String get aboutChangelogV205C3;

  /// No description provided for @aboutChangelogV205C4.
  ///
  /// In en, this message translates to:
  /// **'Fixed voice message playback'**
  String get aboutChangelogV205C4;

  /// No description provided for @aboutChangelogV200C1.
  ///
  /// In en, this message translates to:
  /// **'Full app redesign'**
  String get aboutChangelogV200C1;

  /// No description provided for @aboutChangelogV200C2.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption (E2EE) for secret chats'**
  String get aboutChangelogV200C2;

  /// No description provided for @aboutChangelogV200C3.
  ///
  /// In en, this message translates to:
  /// **'NiosGram — post feed with reactions and comments'**
  String get aboutChangelogV200C3;

  /// No description provided for @aboutChangelogV200C4.
  ///
  /// In en, this message translates to:
  /// **'AI assistant: error correction, formalization, translation'**
  String get aboutChangelogV200C4;

  /// No description provided for @aboutChangelogV200C5.
  ///
  /// In en, this message translates to:
  /// **'Group chats and channels'**
  String get aboutChangelogV200C5;

  /// No description provided for @aboutChangelogV200C6.
  ///
  /// In en, this message translates to:
  /// **'Voice and video calls'**
  String get aboutChangelogV200C6;

  /// No description provided for @aboutCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version: {version}'**
  String aboutCurrentVersion(Object version);

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill in the details to create an account'**
  String get registerSubtitle;

  /// No description provided for @chatMembersActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String chatMembersActionFailed(Object error);

  /// No description provided for @semanticsToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get semanticsToggle;

  /// No description provided for @semanticsSegmentSelector.
  ///
  /// In en, this message translates to:
  /// **'Segment selector'**
  String get semanticsSegmentSelector;

  /// No description provided for @semanticsClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get semanticsClose;

  /// No description provided for @semanticsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove {fileName}'**
  String semanticsRemove(Object fileName);

  /// No description provided for @semanticsAvatar.
  ///
  /// In en, this message translates to:
  /// **'{name} avatar'**
  String semanticsAvatar(Object name);

  /// No description provided for @semanticsOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get semanticsOn;

  /// No description provided for @semanticsOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get semanticsOff;

  /// No description provided for @appearanceVariantTitle.
  ///
  /// In en, this message translates to:
  /// **'Color scheme'**
  String get appearanceVariantTitle;

  /// No description provided for @appearanceVariantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose tonal variant'**
  String get appearanceVariantSubtitle;

  /// No description provided for @appearanceThemeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch between light, dark, or system'**
  String get appearanceThemeModeSubtitle;

  /// No description provided for @appearanceSystemColors.
  ///
  /// In en, this message translates to:
  /// **'System colors'**
  String get appearanceSystemColors;

  /// No description provided for @appearanceSystemColorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use colors from your device wallpaper'**
  String get appearanceSystemColorsSubtitle;

  /// No description provided for @sessionsTerminateAll.
  ///
  /// In en, this message translates to:
  /// **'Terminate all other sessions'**
  String get sessionsTerminateAll;

  /// No description provided for @sessionsTerminateAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminate all other sessions?'**
  String get sessionsTerminateAllConfirmTitle;

  /// No description provided for @sessionsTerminateAllConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All other devices will be signed out.'**
  String get sessionsTerminateAllConfirmBody;

  /// No description provided for @profileSectionPrivacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get profileSectionPrivacySecurity;

  /// No description provided for @groupProfileShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get groupProfileShare;

  /// No description provided for @groupProfileLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get groupProfileLinkCopied;

  /// No description provided for @groupProfilePublicLink.
  ///
  /// In en, this message translates to:
  /// **'Public link'**
  String get groupProfilePublicLink;

  /// No description provided for @commonChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get commonChat;

  /// No description provided for @chatNotFound.
  ///
  /// In en, this message translates to:
  /// **'Chat not found'**
  String get chatNotFound;

  /// No description provided for @aboutDeveloper.
  ///
  /// In en, this message translates to:
  /// **'About Developer'**
  String get aboutDeveloper;

  /// No description provided for @aboutLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get aboutLatest;

  /// No description provided for @settingsLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsLanguageAuto;

  /// No description provided for @contactDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Contact not found'**
  String get contactDetailNotFound;

  /// No description provided for @dialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogCancel;

  /// No description provided for @appearanceFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get appearanceFontSize;

  /// No description provided for @appearanceFontSizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust the text size throughout the app'**
  String get appearanceFontSizeSubtitle;

  /// No description provided for @appearanceFontSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get appearanceFontSizeSmall;

  /// No description provided for @appearanceFontSizeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get appearanceFontSizeNormal;

  /// No description provided for @appearanceFontSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get appearanceFontSizeLarge;

  /// No description provided for @appearanceFontSizeExtraLarge.
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get appearanceFontSizeExtraLarge;

  /// No description provided for @settingsPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferencesTitle;

  /// No description provided for @settingsPreferencesBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sound, haptics and performance'**
  String get settingsPreferencesBannerSubtitle;

  /// No description provided for @settingsPreferencesSoundHaptics.
  ///
  /// In en, this message translates to:
  /// **'Sound & Haptics'**
  String get settingsPreferencesSoundHaptics;

  /// No description provided for @settingsSoundEffectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play sounds for incoming messages and calls'**
  String get settingsSoundEffectsSubtitle;

  /// No description provided for @settingsVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get settingsVolume;

  /// No description provided for @settingsHapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHapticFeedback;

  /// No description provided for @settingsHapticFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on interactions'**
  String get settingsHapticFeedbackSubtitle;

  /// No description provided for @settingsPreferencesPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get settingsPreferencesPerformance;

  /// No description provided for @settingsCompactModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce spacing and element sizes for a denser layout'**
  String get settingsCompactModeSubtitle;

  /// No description provided for @settingsPredictiveBackDescription.
  ///
  /// In en, this message translates to:
  /// **'Preview the previous screen before returning'**
  String get settingsPredictiveBackDescription;
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

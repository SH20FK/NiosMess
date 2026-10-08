import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'secret_chat_localizations_en.dart';
import 'secret_chat_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SecretChatLocalizations
/// returned by `SecretChatLocalizations.of(context)`.
///
/// Applications need to include `SecretChatLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/secret_chat_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SecretChatLocalizations.localizationsDelegates,
///   supportedLocales: SecretChatLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the SecretChatLocalizations.supportedLocales
/// property.
abstract class SecretChatLocalizations {
  SecretChatLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SecretChatLocalizations? of(BuildContext context) {
    return Localizations.of<SecretChatLocalizations>(
      context,
      SecretChatLocalizations,
    );
  }

  static const LocalizationsDelegate<SecretChatLocalizations> delegate =
      _SecretChatLocalizationsDelegate();

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

  /// No description provided for @secretTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret chat'**
  String get secretTitle;

  /// No description provided for @secretProtected.
  ///
  /// In en, this message translates to:
  /// **'Your conversation is protected'**
  String get secretProtected;

  /// No description provided for @secretDescription.
  ///
  /// In en, this message translates to:
  /// **'Messages are available only on your two devices. Protection is set up automatically.'**
  String get secretDescription;

  /// No description provided for @secretQueued.
  ///
  /// In en, this message translates to:
  /// **'Messages are saved and will send automatically'**
  String get secretQueued;

  /// No description provided for @secretPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing a secure connection'**
  String get secretPreparing;

  /// No description provided for @secretUpdateRequired.
  ///
  /// In en, this message translates to:
  /// **'Your contact needs to update the app. Your messages are saved.'**
  String get secretUpdateRequired;

  /// No description provided for @secretKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'Your contact\'s security key changed'**
  String get secretKeyChanged;

  /// No description provided for @secretKeyChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Your messages are saved on this device. Confirm the new key to resume sending.'**
  String get secretKeyChangedBody;

  /// No description provided for @secretAcceptKey.
  ///
  /// In en, this message translates to:
  /// **'Continue with the new key'**
  String get secretAcceptKey;

  /// No description provided for @secretOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'This chat belongs to another device'**
  String get secretOtherDevice;

  /// No description provided for @secretSignatureInvalid.
  ///
  /// In en, this message translates to:
  /// **'Protection could not be verified. Sending is paused.'**
  String get secretSignatureInvalid;

  /// No description provided for @secretAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Verify protection'**
  String get secretAdvanced;

  /// No description provided for @secretCompare.
  ///
  /// In en, this message translates to:
  /// **'Optionally compare this code with your contact in person or through another trusted channel. This is not required to chat.'**
  String get secretCompare;

  /// No description provided for @secretCodesMatch.
  ///
  /// In en, this message translates to:
  /// **'The codes match'**
  String get secretCodesMatch;

  /// No description provided for @secretVerified.
  ///
  /// In en, this message translates to:
  /// **'Code verified'**
  String get secretVerified;

  /// No description provided for @secretUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This message is not yet available on this device'**
  String get secretUnavailable;

  /// No description provided for @secretSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the message. Your text is still in the composer.'**
  String get secretSaveFailed;

  /// No description provided for @secretCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the secret chat. Please try again.'**
  String get secretCreateFailed;

  /// No description provided for @secretAttachmentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the attachment. Please try sending it again.'**
  String get secretAttachmentSaveFailed;

  /// No description provided for @secretLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Secret chat content is not shared with bots or AI.'**
  String get secretLocalOnly;

  /// No description provided for @secretLogoutWarning.
  ///
  /// In en, this message translates to:
  /// **'Logging out deletes secret history and unsent messages on this device. Your contact\'s history is kept.'**
  String get secretLogoutWarning;

  /// No description provided for @secretRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry sending'**
  String get secretRetry;

  /// No description provided for @secretDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'History, attachments and unsent messages on this device will be deleted. The other person\'s history will remain.'**
  String get secretDeleteWarning;

  /// No description provided for @secretVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the key verification. Your messages have not been deleted.'**
  String get secretVerificationFailed;
}

class _SecretChatLocalizationsDelegate
    extends LocalizationsDelegate<SecretChatLocalizations> {
  const _SecretChatLocalizationsDelegate();

  @override
  Future<SecretChatLocalizations> load(Locale locale) {
    return SynchronousFuture<SecretChatLocalizations>(
      lookupSecretChatLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_SecretChatLocalizationsDelegate old) => false;
}

SecretChatLocalizations lookupSecretChatLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SecretChatLocalizationsEn();
    case 'ru':
      return SecretChatLocalizationsRu();
  }

  throw FlutterError(
    'SecretChatLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

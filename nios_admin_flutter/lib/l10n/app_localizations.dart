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
  /// **'NiosMess Admin'**
  String get appName;

  /// No description provided for @unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin access'**
  String get unlockTitle;

  /// No description provided for @unlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the admin password to manage users, chats, and badges.'**
  String get unlockSubtitle;

  /// No description provided for @unlockPassword.
  ///
  /// In en, this message translates to:
  /// **'Admin password'**
  String get unlockPassword;

  /// No description provided for @unlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockAction;

  /// No description provided for @unlockChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get unlockChecking;

  /// No description provided for @unlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get unlockFailed;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin workspace'**
  String get dashboardTitle;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Moderation tools for users, chats, and badge management.'**
  String get dashboardSubtitle;

  /// No description provided for @dashboardUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'User moderation'**
  String get dashboardUsersTitle;

  /// No description provided for @dashboardUsersBody.
  ///
  /// In en, this message translates to:
  /// **'Open profiles, ban or freeze accounts, manage spam blocks.'**
  String get dashboardUsersBody;

  /// No description provided for @dashboardChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat moderation'**
  String get dashboardChatsTitle;

  /// No description provided for @dashboardChatsBody.
  ///
  /// In en, this message translates to:
  /// **'Ban groups and channels, inspect member counts and state.'**
  String get dashboardChatsBody;

  /// No description provided for @dashboardBadgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Badge system'**
  String get dashboardBadgesTitle;

  /// No description provided for @dashboardBadgesBody.
  ///
  /// In en, this message translates to:
  /// **'Create badges, delete them, and assign or revoke access tokens.'**
  String get dashboardBadgesBody;

  /// No description provided for @usersTitle.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get usersTitle;

  /// No description provided for @usersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search and moderate accounts page by page.'**
  String get usersSubtitle;

  /// No description provided for @usersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by username, email, or display name'**
  String get usersSearchHint;

  /// No description provided for @usersPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String usersPage(int page);

  /// No description provided for @usersNoResults.
  ///
  /// In en, this message translates to:
  /// **'No users on this page.'**
  String get usersNoResults;

  /// No description provided for @usersOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get usersOpen;

  /// No description provided for @usersBan.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get usersBan;

  /// No description provided for @usersUnban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get usersUnban;

  /// No description provided for @usersFreeze.
  ///
  /// In en, this message translates to:
  /// **'Freeze'**
  String get usersFreeze;

  /// No description provided for @usersUnfreeze.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze'**
  String get usersUnfreeze;

  /// No description provided for @usersSpamblock.
  ///
  /// In en, this message translates to:
  /// **'Spamblock'**
  String get usersSpamblock;

  /// No description provided for @usersUnspamblock.
  ///
  /// In en, this message translates to:
  /// **'Remove spamblock'**
  String get usersUnspamblock;

  /// No description provided for @usersReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get usersReason;

  /// No description provided for @userDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'User profile'**
  String get userDetailTitle;

  /// No description provided for @userDetailActions.
  ///
  /// In en, this message translates to:
  /// **'Moderation actions'**
  String get userDetailActions;

  /// No description provided for @userDetailBadges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get userDetailBadges;

  /// No description provided for @userDetailAwardBadge.
  ///
  /// In en, this message translates to:
  /// **'Award badge'**
  String get userDetailAwardBadge;

  /// No description provided for @userDetailRevokeBadge.
  ///
  /// In en, this message translates to:
  /// **'Revoke badge'**
  String get userDetailRevokeBadge;

  /// No description provided for @userStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get userStatusActive;

  /// No description provided for @userStatusBanned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get userStatusBanned;

  /// No description provided for @userStatusFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get userStatusFrozen;

  /// No description provided for @userStatusSpamBlocked.
  ///
  /// In en, this message translates to:
  /// **'Spam blocked'**
  String get userStatusSpamBlocked;

  /// No description provided for @userStatus2fa.
  ///
  /// In en, this message translates to:
  /// **'2FA'**
  String get userStatus2fa;

  /// No description provided for @chatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// No description provided for @chatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Groups and channels moderation.'**
  String get chatsSubtitle;

  /// No description provided for @chatsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or username'**
  String get chatsSearchHint;

  /// No description provided for @chatsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No chats on this page.'**
  String get chatsNoResults;

  /// No description provided for @chatsBan.
  ///
  /// In en, this message translates to:
  /// **'Ban chat'**
  String get chatsBan;

  /// No description provided for @chatsUnban.
  ///
  /// In en, this message translates to:
  /// **'Unban chat'**
  String get chatsUnban;

  /// No description provided for @badgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badgesTitle;

  /// No description provided for @badgesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create, remove, and distribute visual account tokens.'**
  String get badgesSubtitle;

  /// No description provided for @badgesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create badge'**
  String get badgesCreate;

  /// No description provided for @badgesNoResults.
  ///
  /// In en, this message translates to:
  /// **'No badges yet.'**
  String get badgesNoResults;

  /// No description provided for @badgeName.
  ///
  /// In en, this message translates to:
  /// **'Badge name'**
  String get badgeName;

  /// No description provided for @badgeDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get badgeDescription;

  /// No description provided for @badgeIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon or text'**
  String get badgeIcon;

  /// No description provided for @badgeColor.
  ///
  /// In en, this message translates to:
  /// **'HEX color'**
  String get badgeColor;

  /// No description provided for @badgeAward.
  ///
  /// In en, this message translates to:
  /// **'Award'**
  String get badgeAward;

  /// No description provided for @badgeRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get badgeRevoke;

  /// No description provided for @badgeDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this badge?'**
  String get badgeDeleteConfirm;

  /// No description provided for @badgeUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get badgeUserId;

  /// No description provided for @badgePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get badgePreview;

  /// No description provided for @systemError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get systemError;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get createdAt;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersCount;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @chatType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get chatType;

  /// No description provided for @emptyDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get emptyDescription;

  /// No description provided for @moderationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Action completed'**
  String get moderationSuccess;
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

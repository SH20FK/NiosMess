// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NiosMess Admin';

  @override
  String get unlockTitle => 'Admin access';

  @override
  String get unlockSubtitle =>
      'Enter the admin password to manage users, chats, and badges.';

  @override
  String get unlockPassword => 'Admin password';

  @override
  String get unlockAction => 'Unlock';

  @override
  String get unlockChecking => 'Checking...';

  @override
  String get unlockFailed => 'Access denied';

  @override
  String get logout => 'Log out';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get users => 'Users';

  @override
  String get chats => 'Chats';

  @override
  String get badges => 'Badges';

  @override
  String get refresh => 'Refresh';

  @override
  String get search => 'Search';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get dashboardTitle => 'Admin workspace';

  @override
  String get dashboardSubtitle =>
      'Moderation tools for users, chats, and badge management.';

  @override
  String get dashboardUsersTitle => 'User moderation';

  @override
  String get dashboardUsersBody =>
      'Open profiles, ban or freeze accounts, manage spam blocks.';

  @override
  String get dashboardChatsTitle => 'Chat moderation';

  @override
  String get dashboardChatsBody =>
      'Ban groups and channels, inspect member counts and state.';

  @override
  String get dashboardBadgesTitle => 'Badge system';

  @override
  String get dashboardBadgesBody =>
      'Create badges, delete them, and assign or revoke access tokens.';

  @override
  String get usersTitle => 'Users';

  @override
  String get usersSubtitle => 'Search and moderate accounts page by page.';

  @override
  String get usersSearchHint => 'Search by username, email, or display name';

  @override
  String usersPage(int page) {
    return 'Page $page';
  }

  @override
  String get usersNoResults => 'No users on this page.';

  @override
  String get usersOpen => 'Open';

  @override
  String get usersBan => 'Ban';

  @override
  String get usersUnban => 'Unban';

  @override
  String get usersFreeze => 'Freeze';

  @override
  String get usersUnfreeze => 'Unfreeze';

  @override
  String get usersSpamblock => 'Spamblock';

  @override
  String get usersUnspamblock => 'Remove spamblock';

  @override
  String get usersReason => 'Reason';

  @override
  String get userDetailTitle => 'User profile';

  @override
  String get userDetailActions => 'Moderation actions';

  @override
  String get userDetailBadges => 'Badges';

  @override
  String get userDetailAwardBadge => 'Award badge';

  @override
  String get userDetailRevokeBadge => 'Revoke badge';

  @override
  String get userStatusActive => 'Active';

  @override
  String get userStatusBanned => 'Banned';

  @override
  String get userStatusFrozen => 'Frozen';

  @override
  String get userStatusSpamBlocked => 'Spam blocked';

  @override
  String get userStatus2fa => '2FA';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get chatsSubtitle => 'Groups and channels moderation.';

  @override
  String get chatsSearchHint => 'Search by name or username';

  @override
  String get chatsNoResults => 'No chats on this page.';

  @override
  String get chatsBan => 'Ban chat';

  @override
  String get chatsUnban => 'Unban chat';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgesSubtitle =>
      'Create, remove, and distribute visual account tokens.';

  @override
  String get badgesCreate => 'Create badge';

  @override
  String get badgesNoResults => 'No badges yet.';

  @override
  String get badgeName => 'Badge name';

  @override
  String get badgeDescription => 'Description';

  @override
  String get badgeIcon => 'Icon or text';

  @override
  String get badgeColor => 'HEX color';

  @override
  String get badgeAward => 'Award';

  @override
  String get badgeRevoke => 'Revoke';

  @override
  String get badgeDeleteConfirm => 'Delete this badge?';

  @override
  String get badgeUserId => 'User ID';

  @override
  String get badgePreview => 'Preview';

  @override
  String get systemError => 'Something went wrong';

  @override
  String get createdAt => 'Created';

  @override
  String get membersCount => 'Members';

  @override
  String get username => 'Username';

  @override
  String get displayName => 'Display name';

  @override
  String get email => 'Email';

  @override
  String get chatType => 'Type';

  @override
  String get emptyDescription => 'No description';

  @override
  String get moderationSuccess => 'Action completed';
}

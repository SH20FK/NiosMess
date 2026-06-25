import os
import re

def rep(filepath, replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

base = r"E:\Niosmess V2\pulse_flutter\lib\screens"

# 1. admin_screen.dart
rep(os.path.join(base, "admin_screen.dart"), [
    ("Text('User $userId banned')", "Text(context.l10n.adminUserBanned(userId))"),
    ("Text('User $userId unbanned')", "Text(context.l10n.adminUserUnbanned(userId))"),
    ("Text('User $userId ${freeze ? \"frozen\" : \"unfrozen\"}')", "Text(freeze ? context.l10n.adminUserFrozen(userId) : context.l10n.adminUserUnfrozen(userId))"),
    ("Text('Spam block ${block ? \"enabled\" : \"disabled\"} for user $userId')", "Text(block ? context.l10n.adminSpamBlockEnabled(userId) : context.l10n.adminSpamBlockDisabled(userId))"),
    ("Text('Chat $chatId ${ban ? \"banned\" : \"unbanned\"}')", "Text(ban ? context.l10n.adminChatBanned(chatId) : context.l10n.adminChatUnbanned(chatId))"),
    ("Text('Users (${_users.length})')", "Text(context.l10n.adminTabUsers(_users.length))"),
    ("Text('Chats (${_chats.length})')", "Text(context.l10n.adminTabChats(_chats.length))"),
    ("Text('No items'", "Text(context.l10n.emptyStateNoItems"),
    ("const Text('Ban')", "Text(context.l10n.adminActionBan)"),
    ("const Text('Unban')", "Text(context.l10n.adminActionUnban)"),
])

# 2. badge_screen.dart
rep(os.path.join(base, "badge_screen.dart"), [
    ("const Text('Create Badge')", "Text(context.l10n.badgeCreateTitle)"),
    ("const Text('Cancel')", "Text(context.l10n.commonCancel)"),
    ("const Text('Create')", "Text(context.l10n.badgeActionCreate)"),
    ("const Text('Badge created')", "Text(context.l10n.badgeCreated)"),
    ("Text('Badge $badgeId deleted')", "Text(context.l10n.badgeDeleted(badgeId))"),
    ("const Text('Award Badge')", "Text(context.l10n.badgeAwardTitle)"),
    ("const Text('Award')", "Text(context.l10n.badgeActionAward)"),
    ("Text('Badge $badgeId awarded to user $userId')", "Text(context.l10n.badgeAwarded(badgeId, userId))"),
    ("Text('No badges available'", "Text(context.l10n.badgeNoBadges"),
    ("Text('Refresh')", "Text(context.l10n.badgeListRefresh)"),
])

# 3. bot_screen.dart
rep(os.path.join(base, "bot_screen.dart"), [
    ("const Text('Create Bot')", "Text(context.l10n.botCreateTitle)"),
    ("const Text('Cancel')", "Text(context.l10n.commonCancel)"),
    ("const Text('Create')", "Text(context.l10n.botCreateTitle)"),
    ("const Text('Bot Token')", "Text(context.l10n.botBotToken)"),
    ("const Text('Use')", "Text(context.l10n.botActionUse)"),
    ("const Text('Token copied')", "Text(context.l10n.botTokenCopied)"),
    ("Text('No updates')", "Text(context.l10n.botNoUpdates)"),
])

# 4. contact_detail_screen.dart / direct_chat_resolver_screen.dart / e2ee_settings_screen.dart / media_viewer_screen.dart
rep(os.path.join(base, "contact_detail_screen.dart"), [("const Text('Retry')", "Text(context.l10n.commonRetry)")])
rep(os.path.join(base, "direct_chat_resolver_screen.dart"), [("const Text('Retry')", "Text(context.l10n.commonRetry)"), ("const Text('Back')", "Text(context.l10n.groupBack)")])
rep(os.path.join(base, "e2ee_settings_screen.dart"), [("const Text('E2EE key generated and uploaded')", "Text(context.l10n.e2eeKeyGenerated)")])
rep(os.path.join(base, "media_viewer_screen.dart"), [
    ("const Text('Download & Open')", "Text(context.l10n.mediaDownloadAndOpen)"),
    ("Text('Saved to $savePath')", "Text(context.l10n.mediaSavedTo(savePath))"),
    ("const Text('Could not download. Try opening externally.')", "Text(context.l10n.mediaDownloadFailedExt)"),
    ("Text('Download failed: $e')", "Text(context.l10n.mediaDownloadFailed('$e'))"),
])

# 5. create_chat_screen.dart
rep(os.path.join(base, "create_chat_screen.dart"), [
    ("const Text('Отменить?')", "Text(context.l10n.dialogCancelChatCreationTitle)"),
    ("const Text('Идёт создание чата. Отменить?')", "Text(context.l10n.dialogCancelChatCreationBody)"),
    ("const Text('Нет')", "Text(context.l10n.commonNo)"),
    ("const Text('Да')", "Text(context.l10n.commonYes)"),
])

# 6. post_comments_screen.dart
rep(os.path.join(base, "post_comments_screen.dart"), [
    ("const Text('Отменить?')", "Text(context.l10n.dialogCancelCommentTitle)"),
    ("const Text('Идёт отправка комментария. Отменить?')", "Text(context.l10n.dialogCancelCommentBody)"),
    ("const Text('Нет')", "Text(context.l10n.commonNo)"),
    ("const Text('Да')", "Text(context.l10n.commonYes)"),
])

print("Replacements done.")

import json
import os

EN_FILE = r'E:\Niosmess V2\pulse_flutter\lib\l10n\app_en.arb'
RU_FILE = r'E:\Niosmess V2\pulse_flutter\lib\l10n\app_ru.arb'

new_en = {
  "adminUserBanned": "User {id} banned",
  "@adminUserBanned": {"placeholders": {"id": {"type": "int"}}},
  "adminUserUnbanned": "User {id} unbanned",
  "@adminUserUnbanned": {"placeholders": {"id": {"type": "int"}}},
  "adminUserFrozen": "User {id} frozen",
  "@adminUserFrozen": {"placeholders": {"id": {"type": "int"}}},
  "adminUserUnfrozen": "User {id} unfrozen",
  "@adminUserUnfrozen": {"placeholders": {"id": {"type": "int"}}},
  "adminSpamBlockEnabled": "Spam block enabled for user {id}",
  "@adminSpamBlockEnabled": {"placeholders": {"id": {"type": "int"}}},
  "adminSpamBlockDisabled": "Spam block disabled for user {id}",
  "@adminSpamBlockDisabled": {"placeholders": {"id": {"type": "int"}}},
  "adminChatBanned": "Chat {id} banned",
  "@adminChatBanned": {"placeholders": {"id": {"type": "int"}}},
  "adminChatUnbanned": "Chat {id} unbanned",
  "@adminChatUnbanned": {"placeholders": {"id": {"type": "int"}}},
  "adminTabUsers": "Users ({count})",
  "@adminTabUsers": {"placeholders": {"count": {"type": "int"}}},
  "adminTabChats": "Chats ({count})",
  "@adminTabChats": {"placeholders": {"count": {"type": "int"}}},
  "adminActionBan": "Ban",
  "adminActionUnban": "Unban",
  "adminActionFreeze": "Freeze",
  "adminActionUnfreeze": "Unfreeze",
  "adminActionSpamBlock": "Spam Block",
  "adminActionUnspamBlock": "Remove Spam Block",
  
  "badgeCreateTitle": "Create Badge",
  "badgeAwardTitle": "Award Badge",
  "badgeActionCreate": "Create",
  "badgeActionAward": "Award",
  "badgeCreated": "Badge created",
  "badgeDeleted": "Badge {id} deleted",
  "@badgeDeleted": {"placeholders": {"id": {"type": "int"}}},
  "badgeAwarded": "Badge {badgeId} awarded to user {userId}",
  "@badgeAwarded": {"placeholders": {"badgeId": {"type": "int"}, "userId": {"type": "int"}}},
  "badgeNoBadges": "No badges available",
  "badgeListRefresh": "Refresh",
  
  "botCreateTitle": "Create Bot",
  "botBotToken": "Bot Token",
  "botActionUse": "Use",
  "botTokenCopied": "Token copied",
  "botNoUpdates": "No updates",
  
  "e2eeKeyGenerated": "E2EE key generated and uploaded",
  "mediaDownloadAndOpen": "Download & Open",
  "mediaSavedTo": "Saved to {path}",
  "@mediaSavedTo": {"placeholders": {"path": {}}},
  "mediaDownloadFailedExt": "Could not download. Try opening externally.",
  "mediaDownloadFailed": "Download failed: {error}",
  "@mediaDownloadFailed": {"placeholders": {"error": {}}},
  
  "dialogCancelChatCreationTitle": "Cancel?",
  "dialogCancelChatCreationBody": "Chat creation is in progress. Cancel?",
  "dialogCancelCommentTitle": "Cancel?",
  "dialogCancelCommentBody": "Comment sending is in progress. Cancel?",
  
  "emptyStateNoItems": "No items found",
  "emptyStateNoItemsDesc": "There's nothing to show here yet."
}

new_ru = {
  "adminUserBanned": "Пользователь {id} забанен",
  "@adminUserBanned": {"placeholders": {"id": {"type": "int"}}},
  "adminUserUnbanned": "Пользователь {id} разбанен",
  "@adminUserUnbanned": {"placeholders": {"id": {"type": "int"}}},
  "adminUserFrozen": "Пользователь {id} заморожен",
  "@adminUserFrozen": {"placeholders": {"id": {"type": "int"}}},
  "adminUserUnfrozen": "Пользователь {id} разморожен",
  "@adminUserUnfrozen": {"placeholders": {"id": {"type": "int"}}},
  "adminSpamBlockEnabled": "Спам-блок включен для {id}",
  "@adminSpamBlockEnabled": {"placeholders": {"id": {"type": "int"}}},
  "adminSpamBlockDisabled": "Спам-блок отключен для {id}",
  "@adminSpamBlockDisabled": {"placeholders": {"id": {"type": "int"}}},
  "adminChatBanned": "Чат {id} забанен",
  "@adminChatBanned": {"placeholders": {"id": {"type": "int"}}},
  "adminChatUnbanned": "Чат {id} разбанен",
  "@adminChatUnbanned": {"placeholders": {"id": {"type": "int"}}},
  "adminTabUsers": "Пользователи ({count})",
  "@adminTabUsers": {"placeholders": {"count": {"type": "int"}}},
  "adminTabChats": "Чаты ({count})",
  "@adminTabChats": {"placeholders": {"count": {"type": "int"}}},
  "adminActionBan": "Забанить",
  "adminActionUnban": "Разбанить",
  "adminActionFreeze": "Заморозить",
  "adminActionUnfreeze": "Разморозить",
  "adminActionSpamBlock": "Спам-блок",
  "adminActionUnspamBlock": "Снять спам-блок",
  
  "badgeCreateTitle": "Создать бейдж",
  "badgeAwardTitle": "Выдать бейдж",
  "badgeActionCreate": "Создать",
  "badgeActionAward": "Выдать",
  "badgeCreated": "Бейдж создан",
  "badgeDeleted": "Бейдж {id} удалён",
  "@badgeDeleted": {"placeholders": {"id": {"type": "int"}}},
  "badgeAwarded": "Бейдж {badgeId} выдан пользователю {userId}",
  "@badgeAwarded": {"placeholders": {"badgeId": {"type": "int"}, "userId": {"type": "int"}}},
  "badgeNoBadges": "Нет доступных бейджей",
  "badgeListRefresh": "Обновить",
  
  "botCreateTitle": "Создать бота",
  "botBotToken": "Токен бота",
  "botActionUse": "Использовать",
  "botTokenCopied": "Токен скопирован",
  "botNoUpdates": "Нет обновлений",
  
  "e2eeKeyGenerated": "E2EE ключ сгенерирован и загружен",
  "mediaDownloadAndOpen": "Скачать и открыть",
  "mediaSavedTo": "Сохранено в {path}",
  "@mediaSavedTo": {"placeholders": {"path": {}}},
  "mediaDownloadFailedExt": "Не удалось скачать. Попробуйте открыть во внешнем приложении.",
  "mediaDownloadFailed": "Ошибка скачивания: {error}",
  "@mediaDownloadFailed": {"placeholders": {"error": {}}},
  
  "dialogCancelChatCreationTitle": "Отменить?",
  "dialogCancelChatCreationBody": "Идёт создание чата. Отменить?",
  "dialogCancelCommentTitle": "Отменить?",
  "dialogCancelCommentBody": "Идёт отправка комментария. Отменить?",
  
  "emptyStateNoItems": "Ничего не найдено",
  "emptyStateNoItemsDesc": "Здесь пока ничего нет."
}

def update_arb(path, updates):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Merge keys avoiding duplicates
    for k, v in updates.items():
        if k not in data:
            data[k] = v
            
    # Write back
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

update_arb(EN_FILE, new_en)
update_arb(RU_FILE, new_ru)
print("Arb files updated")

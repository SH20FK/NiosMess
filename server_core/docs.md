# NiosMess — Клиент-серверный протокол

## Обзор

Сервер работает на FastAPI + WebSocket. Все запросы идут через одно WebSocket-соединение (`/ws`). HTTP используется только для отдачи SPA (`/`) и статических файлов (`/static/*`).

## Подключение

### WebSocket URL

```
ws://host:port/ws       (HTTP)
wss://host:port/ws      (HTTPS)
```

### Обмен ключом шифрования

Сразу после принятия соединения сервер генерирует уникальный AES-256-GCM ключ для данного подключения и отправляет его клиенту в открытом виде:

```json
{
  "action": "key_exchange",
  "key": "<base64-encoded 32-byte key>"
}
```

Клиент **обязан** сохранить этот ключ и использовать его для шифрования всех последующих сообщений (и входящих, и исходящих).

## Формат сообщений

### Исходящее сообщение (клиент → сервер)

Каждый запрос содержит:

```json
{
  "action": "<имя_действия>",
  "payload": { ... },
  "token": "<Bearer токен из login>",
  "request_id": <уникальный числовой ID>
}
```

Если включено шифрование (после key_exchange), сообщение оборачивается:

```json
{
  "encrypted": true,
  "data": {
    "ciphertext": "<base64>",
    "iv": "<base64>",
    "tag": "<base64>"
  }
}
```

Внутри `data.ciphertext` лежит base64-encoded JSON оригинального сообщения.

### Входящее сообщение (сервер → клиент)

Ответ от сервера:

```json
{
  "action": "<имя_действия>",
  "payload": { ... },
  "request_id": <тот же ID, что был в запросе>,
  "error": null
}
```

При ошибке:

```json
{
  "action": "<имя_действия>",
  "payload": {},
  "request_id": <тот же ID>,
  "error": "Текст ошибки"
}
```

Push-уведомления (например, новое сообщение от другого участника):

```json
{
  "action": "new_message",
  "payload": { ... }
}
```

## Шифрование (AES-256-GCM)

### Алгоритм

1. **Ключ**: 32 байта, генерируется сервером при каждом подключении (base64).
2. **IV**: 12 байт, случайный, генерируется при каждом шифровании.
3. **Данные**: JSON-строка сообщения → UTF-8 bytes → AES-GCM encrypt.
4. **Результат**: ciphertext (без тега) + IV + tag (последние 16 байт) — каждый отдельно в base64.

### Клиентская реализация (Web Crypto API)

```javascript
// Import key
const key = await crypto.subtle.importKey(
  'raw',
  Uint8Array.from(atob(serverKey), c => c.charCodeAt(0)),
  'AES-GCM', false, ['encrypt', 'decrypt']
);

// Encrypt
const iv = crypto.getRandomValues(new Uint8Array(12));
const encrypted = await crypto.subtle.encrypt(
  { name: 'AES-GCM', iv }, key, new TextEncoder().encode(jsonString)
);
const buf = new Uint8Array(encrypted);
const ciphertext = buf.slice(0, -16);
const tag = buf.slice(-16);

// Decrypt
const combined = new Uint8Array([...ciphertext, ...tag]);
const decrypted = await crypto.subtle.decrypt(
  { name: 'AES-GCM', iv }, key, combined
);
const jsonStr = new TextDecoder().decode(decrypted);
```

## Авторизация

### register

```json
{ "action": "register", "payload": { "email": "...", "username": "...", "display_name": "...", "password": "..." } }
```

Ответ: `{ "user_id": 1, "message": "Check your email..." }`

### verify_email

```json
{ "action": "verify_email", "payload": { "email": "...", "code": "123456" } }
```

### login

```json
{ "action": "login", "payload": { "identifier": "...", "password": "..." } }
```

Ответ при 2FA: `{ "two_fa_required": true, "message": "..." }`
Ответ при успехе: `{ "access_token": "...", "token_type": "bearer", "user_id": 1, "username": "...", "display_name": "..." }`

### verify_2fa

```json
{ "action": "verify_2fa", "payload": { "identifier": "...", "code": "123456" } }
```

### logout

```json
{ "action": "logout", "payload": {} }
```

### reset_password_request / reset_password_confirm

```json
{ "action": "reset_password_request", "payload": { "email": "..." } }
{ "action": "reset_password_confirm", "payload": { "email": "...", "code": "...", "new_password": "..." } }
```

## Профиль

### me_info

```json
{ "action": "me_info", "payload": {} }
```

Ответ: `{ "id": 1, "username": "...", "display_name": "...", "bio": "...", "avatar_url": "...", "badges": [...], "two_fa_enabled": false, "spam_block": false }`

### get_profile

```json
{ "action": "get_profile", "payload": { "username": "..." } }
```

### update_profile

```json
{ "action": "update_profile", "payload": { "display_name": "...", "username": "...", "bio": "..." } }
```

### upload_avatar

```json
{ "action": "upload_avatar", "payload": { "data_base64": "...", "filename": "avatar.jpg" } }
```

### toggle_2fa

```json
{ "action": "toggle_2fa", "payload": { "enabled": true, "password": "..." } }
```

### list_sessions

```json
{ "action": "list_sessions", "payload": {} }
```

### kick_session

```json
{ "action": "kick_session", "payload": { "session_id": "..." } }
```

## Чаты

### list_chats

```json
{ "action": "list_chats", "payload": {} }
```

Ответ: массив объектов чата с `id`, `chat_type`, `name`, `username`, `avatar_url`, `last_message`, `unread_count`, `members_count`, `partner_badges`, `invite_link`, `share_link`.

### open_direct

```json
{ "action": "open_direct", "payload": { "username": "..." } }
```

### create_group

```json
{ "action": "create_group", "payload": { "name": "...", "chat_type": "group|channel", "username": "...", "description": "...", "comments_enabled": true } }
```

### get_chat

```json
{ "action": "get_chat", "payload": { "chat_id": 1 } }
```

### get_members

```json
{ "action": "get_members", "payload": { "chat_id": 1 } }
```

### update_chat

```json
{ "action": "update_chat", "payload": { "chat_id": 1, "name": "...", "description": "...", "username": "..." } }
```

### chat_avatar_upload

```json
{ "action": "chat_avatar_upload", "payload": { "chat_id": 1, "data_base64": "...", "filename": "..." } }
```

### invite_user

```json
{ "action": "invite_user", "payload": { "chat_id": 1, "user_id": 2 } }
```

### ban_member / mute_member / promote_member

```json
{ "action": "ban_member", "payload": { "chat_id": 1, "user_id": 2, "ban": true } }
{ "action": "mute_member", "payload": { "chat_id": 1, "user_id": 2, "mute": true } }
{ "action": "promote_member", "payload": { "chat_id": 1, "user_id": 2, "role": "admin" } }
```

### leave_chat

```json
{ "action": "leave_chat", "payload": { "chat_id": 1 } }
```

### mark_read

```json
{ "action": "mark_read", "payload": { "chat_id": 1 } }
```

## Сообщения

### send_message

```json
{ "action": "send_message", "payload": { "chat_id": 1, "content": "...", "reply_to_id": null, "upload_id": null } }
```

Ответ: объект сообщения. Push-уведомление `new_message` отправляется всем участникам чата.

### history

```json
{ "action": "history", "payload": { "chat_id": 1, "page": 1, "page_size": 50, "before_id": null } }
```

Ответ: `{ "messages": [...], "total": N, "page": 1, "page_size": 50 }`

### edit_message

```json
{ "action": "edit_message", "payload": { "chat_id": 1, "message_id": 2, "content": "..." } }
```

### delete_message

```json
{ "action": "delete_message", "payload": { "chat_id": 1, "message_id": 2 } }
```

### react

```json
{ "action": "react", "payload": { "chat_id": 1, "message_id": 2, "emoji": "❤️" } }
```

Ответ: `{ "action": "added"|"removed", "emoji": "❤️" }` — toggle поведение.

### post_comment / get_comments

```json
{ "action": "post_comment", "payload": { "channel_id": 1, "post_id": 2, "content": "...", "upload_id": null } }
{ "action": "get_comments", "payload": { "channel_id": 1, "post_id": 2, "page": 1 } }
```

## Загрузка файлов

### init_upload

```json
{ "action": "init_upload", "payload": { "filename": "photo.jpg", "total_chunks": 5, "file_size": 1048576, "media_subtype": "media|voice|circle" } }
```

Ответ: `{ "upload_id": "...", "chunk_size": 262144 }`

### upload_chunk

```json
{ "action": "upload_chunk", "payload": { "upload_id": "...", "chunk_index": 0, "chunk_base64": "..." } }
```

## Звонки

### initiate_call

```json
{ "action": "initiate_call", "payload": { "chat_id": 1, "is_video": false } }
```

### answer_call

```json
{ "action": "answer_call", "payload": { "call_id": 1, "accept": true } }
```

### end_call

```json
{ "action": "end_call", "payload": { "call_id": 1 } }
```

### get_call

```json
{ "action": "get_call", "payload": { "call_id": 1 } }
```

## Поиск

### search

```json
{ "action": "search", "payload": { "q": "запрос" } }
```

Ответ: `{ "users": [...], "chats": [...], "messages": [...] }`

## Invite-ссылки

### get_invite_info

```json
{ "action": "get_invite_info", "payload": { "slug": "my_channel" } }
```

### join_chat

```json
{ "action": "join_chat", "payload": { "slug": "my_channel" } }
```

## AI

### ai_process_text

```json
{ "action": "ai_process_text", "payload": { "text": "...", "action": "translate|correct|formalize", "target_language": "ru" } }```

## Админка

Все admin-действия требуют передачи `password` в payload (сверка с `settings.ADMIN_PASSWORD`).

| Action | Payload | Описание |
|---|---|---|
| `admin_list_users` | `{ "password": "...", "page": 1, "page_size": 50 }` | Список пользователей |
| `admin_get_user` | `{ "password": "...", "user_id": 1 }` | Инфо о пользователе |
| `ban_user` | `{ "password": "...", "user_id": 1 }` | Бан |
| `unban_user` | `{ "password": "...", "user_id": 1 }` | Разбан |
| `freeze_user` | `{ "password": "...", "user_id": 1, "frozen": true }` | Заморозка |
| `spam_block` | `{ "password": "...", "user_id": 1, "blocked": true }` | Спам-блок |
| `admin_list_chats` | `{ "password": "...", "page": 1 }` | Список чатов |
| `ban_chat` | `{ "password": "...", "chat_id": 1, "banned": true }` | Бан чата |
| `list_badges` | `{ "password": "..." }` | Список бейджей |
| `create_badge` | `{ "password": "...", "name": "Admin", "icon": "⭐", "color": "#ff0000" }` | Создать бейдж |
| `delete_badge` | `{ "password": "...", "badge_id": 1 }` | Удалить бейдж |
| `award_badge` | `{ "password": "...", "user_id": 1, "badge_id": 1 }` | Выдать бейдж |
| `revoke_badge` | `{ "password": "...", "user_id": 1, "badge_id": 1 }` | Отозвать бейдж |

## Save/Load (миры)

### world_save

```json
{ "action": "world_save", "payload": { "owner_id": 1, ... } }
```

### world_load

```json
{ "action": "world_load", "payload": { "owner_id": 1 } }
```

## Формат объекта сообщения

```json
{
  "id": 1,
  "chat_id": 1,
  "sender_id": 1,
  "sender_username": "user",
  "sender_display_name": "Имя",
  "sender_avatar_url": "https://...",
  "sender_badges": [{ "id": 1, "name": "Admin", "icon": "⭐", "color": "#ff0000" }],
  "msg_type": "text|media|voice|circle|call_log",
  "content": "Расшифрованный текст",
  "reply_to_id": null,
  "media_url": "https://...",
  "media_type": "image/jpeg",
  "media_name": "photo.jpg",
  "media_size": 123456,
  "media_duration": 30,
  "comments_count": 0,
  "reactions": { "❤️": 2, "👍": 1 },
  "is_deleted": false,
  "sent_at": "2024-01-01T12:00:00",
  "edited_at": null
}
```

## Формат объекта чата

```json
{
  "id": 1,
  "chat_type": "direct|group|channel",
  "name": "Название",
  "username": "my_chat",
  "avatar_url": "https://...",
  "invite_link": "https://ni-os.ru/join/my_chat",
  "share_link": "https://ni-os.ru/my_chat",
  "last_message": { ... } | null,
  "unread_count": 0,
  "members_count": 5,
  "partner_badges": [],
  "description": "",
  "comments_enabled": true,
  "comments_chat_id": null,
  "partner": { ... } | null
}
```

## Боты (Bot API)

### BotCreator
Встроенный бот `@botcreator` (аналог BotFather). Напишите ему `/start` для меню.

Команды BotCreator:
- `/newbot` — создать бота (интерактивно: спрашивает имя и username)
- `/mybots` — список ботов
- `/token <username>` — получить токен
- `/deletebot <username>` — удалить бота
- `/help` — помощь

### Bot WebSocket API

Боты могут подключаться по WebSocket (`/ws`) и использовать **bot token** как `token` во всех запросах. Сервер аутентифицирует бота по токену автоматически.

Пример подключения бота:
```json
{ "action": "send_message", "payload": { "chat_id": 1, "content": "Hello", "reply_markup": {...} }, "token": "BOT_TOKEN", "request_id": 1 }
```

Бот получает push-уведомления в реальном времени:
- `new_message` — новое сообщение в чате
- `callback_query` — нажатие inline-кнопки

### Bot HTTP API (для polling)

Доступно по `POST /bot-api/{token}/{method}`:

- `getMe` — информация о боте
- `sendMessage` — отправить сообщение (`{ chat_id, text, reply_markup? }`)
- `editMessageReplyMarkup` — изменить клавиатуру (`{ chat_id, message_id, reply_markup }`)
- `deleteMessage` — удалить сообщение (`{ chat_id, message_id }`)
- `getUpdates` — получить updates (`{ offset, limit }`)
- `answerCallbackQuery` — ответить на callback (`{ callback_query_id, text? }`)
- `getChat` — получить информацию о чате (`chat_id`)
- `getChatMember` — получить информацию об участнике (`chat_id`, `user_id`)

### Inline Keyboard

В `reply_markup`:
```json
{
  "inline_keyboard": [
    [{"text": "Кнопка 1", "callback_data": "btn1"}],
    [{"text": "Кнопка 2", "callback_data": "btn2"}]
  ]
}
```

При нажатии фронтенд отправляет `callback_query` через WebSocket, а сервер записывает update для бота и отправляет push.

### Python библиотека

См. `niosbot/README.md`.

## Важные заметки

1. **Токен** — передаётся в каждом сообщении. При `login`/`verify_2fa` сервер возвращает новый токен.
2. **request_id** — уникален для каждого запроса. Сервер возвращает тот же ID в ответе.
3. **Шифрование** — все сообщения шифруются после получения ключа от сервера (`key_exchange`).
4. **Push-уведомления** — `new_message` приходит от сервера без `request_id` при новых сообщениях в чате.
5. **Файлы** — Chunk Size = 262144 (256KB). Голосовые и видеосообщения используют `media_subtype: "voice"` или `"circle"`.
6. **Ограничения** — Circle видео макс 30 секунд.

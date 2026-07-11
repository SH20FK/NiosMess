# Niosmess V2 — Полный API Reference

## Общая архитектура

| Параметр | Значение |
|---|---|
| Фреймворк | FastAPI (Python) |
| БД | SQLite (async SQLAlchemy + aiosqlite) |
| Entry point | `app/main.py` → `run.py` |
| Порт | 8443 (HTTPS) / 8080 (HTTP dev) |
| Фронтенд | SPA в `files/` |

---

## Структура проекта (только app/)

```
app/
├── __init__.py
├── main.py              # FastAPI app, HTTP endpoints, lifespan
├── ws_manager.py        # WebSocket обработчик (2708 строк) — вся логика мессенджера
├── bot_api.py           # Bot HTTP API (Telegram-style endpoints)
├── models.py            # Legacy модели (дублирует models/models.py)
├── models/
│   ├── __init__.py
│   └── models.py        # SQLAlchemy ORM модели
├── config.py            # Pydantic Settings
├── database.py          # Async SQLAlchemy engine + init_db
├── migrations.py        # Auto-migration для SQLite
└── services/
    ├── __init__.py
    ├── auth_svc.py      # Авторизация, сессии, пароли
    ├── bot_svc.py       # CRUD ботов, Bot API helpers
    ├── email_svc.py     # SMTP отправка, верификационные коды
    ├── encryption.py    # AES-256-GCM (текст, файлы, per-connection)
    └── utils.py         # Сериализация, unread, mime, URL-хелперы
```

---

## База данных messenger.db

### users
| Поле | Тип | Описание |
|---|---|---|
| id | Integer PK | ID |
| email | String(255) | Email (unique) |
| username | String(64) | Username (unique) |
| display_name | String(128) | Отображаемое имя |
| bio | Text | О себе |
| avatar_path | String(512) | Путь к аватару |
| hashed_password | String(256) | bcrypt хеш пароля |
| is_active | Boolean | Активен (email подтверждён) |
| is_verified | Boolean | Email подтверждён |
| is_frozen | Boolean | Заморожен |
| is_banned | Boolean | Забанен |
| spam_block | Boolean | Spam-блокировка |
| two_fa_enabled | Boolean | 2FA включена |
| is_bot | Boolean | Это бот |
| public_key | Text | Публичный ключ RSA (base64) для E2EE |
| created_at | DateTime | Дата создания |
| updated_at | DateTime | Обновление |

### sessions
| Поле | Тип | Описание |
|---|---|---|
| id | Integer PK | ID |
| user_id | FK → users | Пользователь |
| token_hash | String(256) | SHA-256 хеш токена |
| device_info | String(512) | Инфо об устройстве |
| ip_address | String(64) | IP адрес |
| created_at | DateTime | Создание |
| last_active | DateTime | Последняя активность |
| is_active | Boolean | Активна ли сессия |

### verification_codes
| Поле | Тип | Описание |
|---|---|---|
| id | Integer PK | ID |
| user_id | FK → users | Пользователь |
| code | String(8) | 6-значный код |
| purpose | String(32) | register / 2fa / reset_password |
| expires_at | DateTime | Время жизни |
| used | Boolean | Использован |

### badges / user_badges
| Поле | Тип | Описание |
|---|---|---|
| badges.name | String(64) | Название бейджа |
| badges.icon | String(256) | Иконка |
| badges.color | String(16) | Цвет (#hex) |
| user_badges.user_id | FK → users | Пользователь |
| user_badges.badge_id | FK → badges | Бейдж |

### chats
| Поле | Тип | Описание |
|---|---|---|
| id | Integer PK | ID |
| chat_type | Enum(ChatType) | direct / group / channel |
| name | String(128) | Название |
| description | Text | Описание |
| username | String(64) | Slug (unique) — для invite-ссылок |
| avatar_path | String(512) | Аватар чата |
| created_by | FK → users | Создатель |
| is_banned | Boolean | Забанен |
| comments_enabled | Boolean | Комментарии включены (для каналов) |
| is_secret | Boolean | Секретный чат (E2EE) |
| user1_public_key | Text | Публичный ключ user1 (secret chat) |
| user2_public_key | Text | Публичный ключ user2 (secret chat) |
| comments_chat_id | FK → chats | Связанный чат комментариев (channel) |
| user1_id | FK → users | User 1 (direct chat) |
| user2_id | FK → users | User 2 (direct chat) |

### chat_members
| Поле | Тип | Описание |
|---|---|---|
| id | Integer PK | ID |
| chat_id | FK → chats | Чат |
| user_id | FK → users | Пользователь |
| role | Enum(MemberRole) | owner / admin / member |
| is_muted | Boolean | Заглушен |
| is_banned | Boolean | Забанен в чате |
| joined_at | DateTime | Дата вступления |

### messages
| Поле | Тип | Описание |
|---|---|---|
| id | Integer PK | ID |
| chat_id | FK → chats | Чат |
| sender_id | FK → users | Отправитель |
| reply_to_id | FK → messages | Ответ на сообщение |
| msg_type | Enum(MessageType) | text / media / voice / circle / call_log |
| encrypted_content | Text | Зашифрованный текст (AES-256-GCM) |
| content_iv | String(64) | IV для расшифровки |
| content_tag | String(64) | Tag для расшифровки |
| e2ee_content | Text | E2EE (клиентское шифрование, base64) |
| is_e2ee | Boolean | Флаг E2EE |
| media_path | String(512) | Путь к медиафайлу |
| media_type | String(64) | MIME-тип |
| media_name | String(256) | Оригинальное имя файла |
| media_size | BigInteger | Размер файла |
| media_duration | Integer | Длительность (секунды, для voice/circle) |
| media_iv | String(64) | IV файла |
| media_tag | String(64) | Tag файла |
| comments_count | Integer | Счётчик комментариев (для постов каналов) |
| is_deleted | Boolean | Soft delete |
| reply_markup | Text | JSON inline-клавиатуры |
| sent_at | DateTime | Отправлено |
| edited_at | DateTime | Отредактировано |

### message_reactions
| Поле | Тип | Описание |
|---|---|---|
| message_id | FK → messages | Сообщение |
| user_id | FK → users | Пользователь |
| emoji | String(16) | Эмодзи |
| UNIQUE | | (message_id, user_id, emoji) |

### unread_counters
| Поле | Тип | Описание |
|---|---|---|
| chat_id | FK → chats | Чат |
| user_id | FK → users | Пользователь |
| count | Integer | Счётчик непрочитанных |
| last_message_id | FK → messages | Последнее непрочитанное |
| UNIQUE | | (chat_id, user_id) |

### media_upload_chunks
| Поле | Тип | Описание |
|---|---|---|
| upload_id | String(64) UUID | ID загрузки |
| user_id | FK → users | Загружающий |
| filename | String(256) | Имя файла |
| total_chunks | Integer | Всего чанков |
| received_chunks | Integer | Получено чанков |
| temp_path | String(512) | Временный путь |
| media_subtype | String(32) | media / voice / circle |

### calls / call_participants
| Поле | Тип | Описание |
|---|---|---|
| calls.chat_id | FK → chats | Чат |
| calls.initiator_id | FK → users | Инициатор |
| calls.is_video | Boolean | Видеозвонок |
| calls.status | Enum(CallStatus) | ringing / active / ended / missed / declined |
| calls.duration_seconds | Integer | Длительность |
| call_participants.call_id | FK → calls | Звонок |
| call_participants.user_id | FK → users | Участник |

### bots / bot_updates
| Поле | Тип | Описание |
|---|---|---|
| bots.user_id | FK → users | Пользователь-бот |
| bots.owner_id | FK → users | Владелец |
| bots.token | String(64) | Токен API |
| bots.name | String(128) | Имя |
| bots.username | String(64) | @username (unique) |
| bot_updates.bot_id | FK → bots | Бот |
| bot_updates.update_type | String(32) | message / callback_query |
| bot_updates.payload | Text | JSON данных |
| bot_updates.is_delivered | Boolean | Доставлено |

### posts / post_reactions / post_comments
| Поле | Тип | Описание |
|---|---|---|
| posts.author_id | FK → users | Автор |
| posts.content | String | Текст |
| posts.media_path | String | Путь к медиа |
| posts.likes_count | Integer | Лайки |
| posts.dislikes_count | Integer | Дизлайки |
| posts.comments_count | Integer | Комментарии |
| post_reactions.post_id | FK → posts | Пост |
| post_reactions.user_id | FK → users | Пользователь |
| post_reactions.is_like | Boolean | True=лайк, False=дизлайк |
| post_comments.post_id | FK → posts | Пост |
| post_comments.author_id | FK → users | Автор |
| post_comments.content | String | Текст комментария |

### subscriptions
| Поле | Тип | Описание |
|---|---|---|
| follower_id | FK → users | Подписчик |
| followed_id | FK → users | На кого подписан |
| UNIQUE | | (follower_id, followed_id) |

### users_fcm_tokens
| Поле | Тип | Описание |
|---|---|---|
| user_id | FK → users | Пользователь |
| fcm_token | String | FCM токен (unique) |
| platform | String | Платформа (android/ios/web) |

---

## HTTP REST API

### Основные (`app/main.py`)

| Метод | Путь | Описание | Авторизация |
|---|---|---|---|
| GET | `/` | SPA index.html | — |
| GET | `/ul`, `/UL` | SPA site.html | — |
| GET | `/cr`, `/constructor` | SPA constructor.html | — |
| GET | `/{full_path}` | SPA catch-all | — |
| POST | `/api/validate-token` | Валидация токена сессии NiosMess | — |
| POST | `/api/ai/generate-flow` | AI-генерация JSON FlowBuilder (Mistral) | token |

### Админ HTTP (header `X-Admin-Key`)

| Метод | Путь | Описание |
|---|---|---|
| GET | `/api/admin/chats` | Список всех чатов техподдержки |
| POST | `/api/admin/reply` | Ответ пользователю (client_ip, text) |
| GET | `/api/admin/licenses` | Список всех лицензий |
| POST | `/api/admin/licenses/generate` | Генерация лицензии |
| DELETE | `/api/admin/licenses/{key}` | Удаление лицензии |

### Статика и медиа

| Метод | Путь | Описание |
|---|---|---|
| GET | `/static/{path}` | Защищённая раздача файлов (auto-decrypt .enc) |
| GET | `/api/media/{path}` | Защищённая раздача медиа (auto-decrypt) |

### Bot API (`/bot-api`)

| Метод | Путь | Описание |
|---|---|---|
| POST | `/bot-api/{token}/getMe` | Информация о боте |
| POST | `/bot-api/{token}/sendMessage` | Отправить сообщение от бота |
| POST | `/bot-api/{token}/editMessageReplyMarkup` | Редактировать inline-клавиатуру |
| POST | `/bot-api/{token}/deleteMessage` | Удалить сообщение бота |
| POST | `/bot-api/{token}/getUpdates` | Получить обновления (long-polling) |
| POST | `/bot-api/{token}/answerCallbackQuery` | Ответ на callback query |
| POST | `/bot-api/{token}/getChat` | Информация о чате |
| POST | `/bot-api/{token}/getChatMember` | Информация об участнике |

---

## WebSocket API

### Основной WebSocket — `/ws`

Клиент отправляет: `{"action": "...", "payload": {...}, "token": "...", "request_id": "...", "message_id": "..."}`
Сервер отвечает: `{"action": "...", "payload": {...}, "request_id": "...", "error": "..."}`

Все ответы шифруются per-connection AES-256-GCM ключом (получается при подключении через `key_exchange`).

#### Системные (исходящие)

| Action | Описание |
|---|---|
| `key_exchange` | Передача AES-ключа соединения (при подключении) |
| `new_message` | Новое сообщение в чате (push) |
| `callback_query` | Callback query от inline-кнопки (push боту) |
| `error` | Ошибка |

---

### Авторизация и безопасность

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `register` | Регистрация | email, username, display_name, password | — |
| `verify_email` | Подтверждение email | email, code | — |
| `login` | Вход | identifier, password | — |
| `verify_2fa` | Подтверждение 2FA | identifier, code | — |
| `logout` | Выход | — | ✓ |
| `reset_password_request` | Запрос сброса пароля | email | — |
| `reset_password_confirm` | Подтверждение сброса | email, code, new_password | — |

---

### Профиль

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `me_info` | Информация о себе | — | ✓ |
| `get_profile` | Профиль пользователя | username / user_id | ✓ |
| `get_profile_encrypted` | Профиль (зашифрованный) | username | ✓ |
| `update_profile` | Обновление профиля | display_name, bio, username | ✓ |
| `upload_avatar` | Загрузка аватара | data_base64, filename | ✓ |
| `toggle_2fa` | Вкл/выкл 2FA | enabled, password | ✓ |
| `list_sessions` | Список сессий | — | ✓ |
| `kick_session` | Завершить сессию | session_id | ✓ |
| `register_fcm_token` | Регистрация FCM токена | fcm_token, platform | ✓ |

---

### Подписки

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `follow_user` | Подписаться | user_id | ✓ |
| `unfollow_user` | Отписаться | user_id | ✓ |

---

### E2EE (End-to-End Encryption)

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `set_public_key` | Сохранить публичный ключ | public_key | ✓ |
| `get_public_key` | Получить публичный ключ | user_id | ✓ |
| `erase_secret` | Удаление секретных чатов и файлов | public_key | — |

---

### Чаты

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `list_chats` | Список чатов | public_key (для секретных) | ✓ |
| `open_direct` | Открыть личный чат | username, is_secret, public_key | ✓ |
| `create_group` | Создать группу/канал | name, chat_type, description, username, comments_enabled | ✓ |
| `get_chat` | Информация о чате | chat_id | ✓ |
| `get_members` | Участники чата | chat_id | ✓ |
| `update_chat` | Настройки чата | chat_id, name, description, comments_enabled, username | ✓ (admin) |
| `chat_avatar_upload` | Аватар чата | chat_id, data_base64, filename | ✓ (admin) |
| `invite_user` | Пригласить | chat_id, user_id | ✓ (admin) |
| `ban_member` | Забанить | chat_id, user_id, ban | ✓ (admin) |
| `mute_member` | Заглушить | chat_id, user_id, mute | ✓ (admin) |
| `promote_member` | Роль | chat_id, user_id, role | ✓ (admin) |
| `leave_chat` | Покинуть | chat_id | ✓ |
| `mark_read` | Прочитано | chat_id | ✓ |

---

### Сообщения

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `send_message` | Отправить | chat_id, content / e2ee_content, reply_to_id, upload_id, reply_markup | ✓ |
| `history` | История | chat_id, page, page_size, before_id | ✓ |
| `edit_message` | Редактировать | chat_id, message_id, content | ✓ |
| `delete_message` | Удалить | chat_id, message_id | ✓ |
| `react` | Реакция | chat_id, message_id, emoji | ✓ |
| `post_comment` | Комментарий к посту канала | channel_id, post_id, content, upload_id | ✓ |
| `get_comments` | Комментарии к посту | channel_id, post_id, page, page_size | ✓ |
| `init_upload` | Начать загрузку | filename, total_chunks, file_size, media_subtype | ✓ |
| `upload_chunk` | Загрузить чанок | upload_id, chunk_index, chunk_base64 | ✓ |

---

### Посты (лента)

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `create_post` | Создать пост | content, upload_id | ✓ |
| `get_feed` | Лента | page | ✓ |
| `react_post` | Лайк/дизлайк | post_id, is_like | ✓ |
| `comment_post` | Комментарий | post_id, content | ✓ |
| `get_post_comments` | Комментарии | post_id, page | ✓ |
| `edit_post` | Редактировать | post_id, content | ✓ |
| `delete_post` | Удалить | post_id | ✓ |

---

### Поиск

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `search` | Поиск | q (строка) | ✓ |

---

### Звонки

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `initiate_call` | Начать звонок | chat_id, is_video | ✓ |
| `answer_call` | Принять/отклонить | call_id, accept | ✓ |
| `end_call` | Завершить | call_id | ✓ |
| `get_call` | Информация | call_id | ✓ |

---

### Инвайты

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `get_invite_info` | Информация по ссылке | slug | — |
| `join_chat` | Вступить | slug | ✓ |

---

### Админ (требует password в payload)

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `admin_list_users` | Список пользователей | password, page, page_size | ✓ + password |
| `admin_get_user` | Пользователь | password, user_id | ✓ + password |
| `ban_user` | Забанить | password, user_id, reason | ✓ + password |
| `unban_user` | Разбанить | password, user_id | ✓ + password |
| `freeze_user` | Заморозить | password, user_id, frozen | ✓ + password |
| `spam_block` | Spam-блокировка | password, user_id, blocked | ✓ + password |
| `admin_list_chats` | Список чатов | password, page, page_size | ✓ + password |
| `ban_chat` | Забанить чат | password, chat_id, banned | ✓ + password |
| `list_badges` | Список бейджей | password | ✓ + password |
| `create_badge` | Создать бейдж | password, name, description, icon, color | ✓ + password |
| `delete_badge` | Удалить бейдж | password, badge_id | ✓ + password |
| `award_badge` | Выдать бейдж | password, user_id, badge_id | ✓ + password |
| `revoke_badge` | Отобрать бейдж | password, user_id, badge_id | ✓ + password |

---

### Боты

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `callback_query` | Inline-кнопка | message_id, chat_id, data | ✓ |

---

### AI

| Action | Описание | Payload | Авторизация |
|---|---|---|---|
| `ai_process_text` | AI-обработка текста | text, action (translate/correct/formalize), target_language | ✓ |

---

## Сервисы

### auth_svc.py
- `validate_password(pw)` — regex: ≥8 chars, 1 uppercase, 1 digit
- `hash_password(pw)` — bcrypt
- `verify_password(plain, hashed)` — bcrypt
- `hash_token(token)` — SHA-256
- `create_session(db, user_id, device_info, ip)` → raw token
- `get_session_by_token(db, token)` → Session
- `get_user_by_id(db, uid)` → User
- `get_user_by_identifier(db, ident)` → User (по email или username)

### email_svc.py
- `send_email(to, subject, html)` — aiosmtplib (или dev print)
- `create_code(db, user_id, purpose, ttl)` → 6-значный код
- `check_code(db, user_id, code, purpose)` → bool
- `send_verify_email(email, name, code)` — письмо подтверждения
- `send_2fa_email(email, name, code)` — письмо 2FA

### encryption.py
- `encrypt_text(plaintext)` → {ciphertext, iv, tag} — AES-256-GCM
- `decrypt_text(ciphertext_b64, iv_b64, tag_b64)` → str
- `encrypt_bytes(data)` → (ciphertext, iv, tag)
- `decrypt_bytes(ciphertext, iv, tag)` → bytes
- `generate_connection_key()` → base64 (32 bytes)
- `encrypt_with_key(plaintext, key_b64)` → {ciphertext, iv, tag}
- `decrypt_with_key(ciphertext_b64, iv_b64, tag_b64, key_b64)` → str
- `encrypt_payload_with_key(payload, key_b64)` → encrypted dict
- `decrypt_payload_with_key(encrypted, key_b64)` → dict
- `encrypt_file(input_path, output_path)` → {iv, tag}
- `decrypt_file(input_path, output_path, iv_b64, tag_b64)`
- `decrypt_file_to_bytes(file_path, iv_b64, tag_b64)` → bytes

### utils.py
- `static_url(path)` → `https://ni-os.ru/static/{path}`
- `chat_link(username)` → `https://ni-os.ru/join/{username}`
- `share_link(username)` → `https://ni-os.ru/{username}`
- `get_user_badges(db, user_id)` → list[dict]
- `serialise_message(msg, db)` → dict (полная сериализация сообщения)
- `increment_unread(db, chat_id, sender_id, message_id)`
- `reset_unread(db, chat_id, user_id)`
- `get_unread(db, chat_id, user_id)` → int

### bot_svc.py
- `ensure_botcreator(db)` → User (создаёт встроенного botcreator)
- `create_bot(db, owner_id, name, username)` → dict
- `get_bot_by_token(db, token)` → Bot
- `get_bot_by_user_id(db, user_id)` → Bot
- `list_user_bots(db, owner_id)` → list[dict]
- `send_bot_message(db, bot, chat_id, text, reply_markup)` → dict
- `edit_bot_message_reply_markup(db, bot, chat_id, message_id, reply_markup)` → dict
- `delete_bot_message(db, bot, chat_id, message_id)` → dict
- `queue_bot_update(db, bot_id, update_type, payload)`
- `get_bot_updates(db, bot_id, limit)` → list[dict]
- `build_callback_query_payload(db, user, message, data)` → dict
- `bot_get_chat(db, bot, chat_id)` → dict
- `bot_get_chat_member(db, bot, chat_id, user_id)` → dict

---

## Шифрование (3 уровня)

1. **Per-connection AES-256-GCM** — каждый WS-сокет получает уникальный ключ при подключении (`key_exchange`)
2. **Server-side AES-256-GCM** — все текстовые сообщения в обычных чатах зашифрованы на сервере
3. **Client-side E2EE** — секретные чаты: клиент генерирует RSA-ключ, шифрует на своей стороне, сервер хранит `e2ee_content` и не может расшифровать

---

## Внешние интеграции

| Сервис | Назначение |
|---|---|
| Mistral AI | AI-хештеги постов, AI-обработка текста, FlowBuilder генерация |
| Firebase FCM | Push-уведомления (Android + iOS) |
| Gmail SMTP | Верификационные коды, коды 2FA |

---

## Порядок запуска

```
1. lifespan: init_db() → migrations → seed licenses
2. Создание директорий uploads (avatars, media, temp, voices, circles) и files/
3. uvicorn serve (HTTPS/HTTP)
```

---

## Конфигурация (.env / config.py)

| Переменная | По умолчанию | Описание |
|---|---|---|
| DATABASE_URL | sqlite+aiosqlite:///./messenger.db | URL базы данных |
| SECRET_KEY | random hex | JWT secret |
| ENCRYPTION_KEY | "default-32-byte-key-change-me!!" | AES-256 ключ |
| SMTP_HOST | smtp.gmail.com | SMTP сервер |
| SMTP_PORT | 587 | SMTP порт |
| SMTP_USER | (пусто) | SMTP логин (пусто = dev mode) |
| SMTP_PASSWORD | (пусто) | SMTP пароль |
| APP_HOST | 0.0.0.0 | Хост |
| APP_PORT | 8443 | Порт |
| UPLOAD_DIR | static/uploads | Директория загрузок |
| FILES_DIR | files | Директория фронтенда |
| SSL_CERTFILE | certs/cert.pem | SSL сертификат |
| SSL_KEYFILE | certs/key.pem | SSL ключ |
| ADMIN_PASSWORD | change-me-admin-password | Пароль админа |
| CHUNK_SIZE | 262144 (256 KB) | Размер чанка загрузки |
| CIRCLE_MAX_SECONDS | 30 | Макс. длительность circle-видео |

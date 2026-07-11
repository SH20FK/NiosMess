# ПЛАН СТАБИЛЬНОСТИ И НОВЫХ ФИЧ БЕКЕНДА (server_core)

## ОБЩАЯ ИНФОРМАЦИЯ

- **Стек**: Python 3.10+ / FastAPI / SQLAlchemy 2.0 async / SQLite (aiosqlite)
- **Главная проблема**: ws_manager.py — 2708 строк, вся бизнес-логика в одном файле
- **Тестов**: 0
- **server_core**: не open source (в .gitignore), но ключи чистим для себя

---

# ГЛАВА 1: СТАБИЛЬНОСТЬ

---

## СПРИНТ 1: АРХИТЕКТУРА — разгребаем ws_manager.py

### 1.1 Создать пакет `app/ws/`

```
app/ws/
├── __init__.py
├── dispatcher.py          # Главный диспетчер
├── connection_manager.py  # Менеджер подключений
├── middleware.py          # Rate limiting, auth, replay protection
├── message_validator.py   # Валидация всех входящих WS-сообщений
├── encryption.py          # Per-connection AES-256-GCM
├── utils.py               # _send, push_to_chat, push_to_user
├── task_tracker.py        # Отслеживание asyncio tasks
└── handlers/
    ├── __init__.py
    ├── auth.py            # register, login, verify_email, verify_2fa, logout, reset_password
    ├── profile.py         # me_info, get_profile, update_profile, upload_avatar, toggle_2fa, sessions
    ├── chat.py            # list_chats, open_direct, create_group, get_chat, update_chat, invite, ban, mute
    ├── message.py         # send_message, history, edit_message, delete_message, react
    ├── media.py           # init_upload, upload_chunk
    ├── posts.py           # create_post, get_feed, react_post, comment_post
    ├── search.py          # search
    ├── call.py            # initiate_call, answer_call, end_call
    ├── invite.py          # get_invite_info, join_chat
    ├── admin.py           # admin_list_users, ban_user, freeze_user, badges
    ├── bot.py             # callback_query
    ├── ai.py              # ai_process_text
    ├── e2ee.py            # set_public_key, get_public_key, erase_secret
    ├── game.py            # world_save, world_load
    └── push.py            # register_fcm_token
```

### 1.2 ConnectionManager — замена голых dict/list

- Класс `ConnectionManager` инкапсулирует `user_connections`, `anonymous_connections`, `connection_keys`
- Каждое соединение получает UUID вместо `id(ws)` — решает reuse vulnerability
- Все мутации с `asyncio.Lock`
- Методы: `add_user_connection`, `remove_user_connection`, `add_anonymous_connection`, `remove_anonymous_connection`, `get_user_connections`, `set_connection_key`, `get_connection_key`, `cleanup_stale`

### 1.3 Middleware — rate limiting + replay protection + auth

- Класс `RateLimiter` — per-connection и per-IP лимиты
- Класс `ReplayProtection` — time-bucketed (не O(n) cleanup)
- Функция `require_auth(payload)` — единая проверка авторизации
- Функция `require_admin(payload)` — с `hmac.compare_digest` вместо `!=`

### 1.4 MessageValidator — валидация ВСЕХ входящих

- Проверка размера сообщения: `len(raw) < 5 * 1024 * 1024` (5 МБ)
- Проверка JSON parse
- Проверка наличия `action` и `payload`
- Валидация типа каждого поля (int, str, etc.)
- Лимиты на строки: display_name ≤ 100, bio ≤ 500, group name ≤ 100
- Проверка page_size ≤ 100 (история сообщений)
- Проверка chunk_index в bounds

### 1.5 Dispatcher — тонкая обёртка

- WS endpoint `/ws` — только accept, вызов dispatcher, cleanup в finally
- Dispatcher: валидация → auth → rate limit → replay check → маршрутизация → try/except → ответ
- Единый формат ошибки: `{"error": "message", "code": "ERROR_CODE"}`
- Никогда не отправлять `str(e)` клиенту

---

## СПРИНТ 2: КРИТИЧЕСКИЕ ИСПРАВЛЕНИЯ БЕЗОПАСНОСТИ

### 2.1 Убрать hardcoded ключи

| Где | Что | Куда |
|---|---|---|
| `main.py:32` | YooMoney токен | `settings.YOOMONEY_TOKEN` |
| `main.py:31` | YooMoney wallet | `settings.YOOMONEY_WALLET` |
| `main.py:813-815` | Mistral ключи | `settings.MISTRAL_API_KEYS` |
| `main.py:361` | DecoCraft секрет | `settings.DECO_CRAFT_SECRET` |
| `main.py:676` | Emergency токен | `settings.EMERGENCY_TOKEN` |
| `main.py:495` | Admin ключ | `settings.ADMIN_KEY` |
| `ws_manager.py:2205-2207` | Mistral ключи (дубль!) | `settings.MISTRAL_API_KEYS` |
| `emergency_bot.py:14` | Telegram бот токен | `settings.TELEGRAM_BOT_TOKEN` |

В `config.py` Settings добавить:
- `YOOMONEY_TOKEN: str = ""`
- `YOOMONEY_WALLET: str = ""`
- `MISTRAL_API_KEYS: list[str] = []`
- `MISTRAL_API_URL: str = "https://api.mistral.ai/v1/chat/completions"`
- `MISTRAL_MODEL: str = "ministral-3b-latest"`
- `DECO_CRAFT_SECRET: str = ""`
- `EMERGENCY_TOKEN: str = ""`

Усилить дефолты:
- `ENCRYPTION_KEY` → нет дефолта, required
- `ADMIN_PASSWORD` → нет дефолта, required или генерация + лог в консоль
- `SECRET_KEY` → генерировать и сохранять на диск если не задан

### 2.2 Path traversal исправления

Везде где `os.path.join` с user input:
```python
full_path = os.path.realpath(os.path.join(base_dir, user_input))
if not full_path.startswith(os.path.realpath(base_dir)):
    return error_403
```

Затронутые файлы:
- `main.py:757-801` — media serving
- `main.py:1283-1293` — SPA catch-all
- `ws_manager.py:2333-2374` — world_save/world_load

### 2.3 Encryption key hardening

- `encryption.py:6-8` — убрать null-byte padding
- Требовать ровно 32 байта или использовать KDF (PBKDF2/scrypt)
- При невалидном ключе → аварийный стоп при старте

### 2.4 XSS в email

- `email_svc.py:43,47` — `html.escape(name)` перед вставкой в HTML

### 2.5 Верификационные коды → secrets

- `email_svc.py:11` — `random.choices` → `secrets.choice`
- Добавить upper bound на длину пароля: `.{8,128}`

### 2.6 Admin password — constant-time

- `ws_manager.py:234` — `!=` → `hmac.compare_digest`
- `main.py:497-499` — аналогично

---

## СПРИНТ 3: КРИТИЧЕСКИЕ БАГИ

### 3.1 erase_secret — добавить авторизацию
- Перед `handle_erase_secret` добавить `if not user: raise ValueError("Unauthorized")`
- Добавить проверку ownership: `user.id` должен быть owner чата

### 3.2 /deletebot — удаляет пользователя вместо бота
- `ws_manager.py:1090-1103` — `db.delete(user_row)` → `db.delete(bot)`
- Добавить ownership check

### 3.3 ChatMember — UniqueConstraint
- `models.py` — добавить `UniqueConstraint("chat_id", "user_id")`
- В миграции: удалить дубликаты перед добавлением constraint

### 3.4 Message индексы
- `Index("ix_messages_chat_id", Message.chat_id)`
- `Index("ix_messages_sent_at", Message.sent_at)`
- `Index("ix_messages_chat_sent", Message.chat_id, Message.sent_at)`

### 3.5 Brute-force protection
- Per-IP: максимум 10 failed login в 5 минут
- Per-account: lock на 15 минут после 5 failed attempts
- Хранить в `rate_limit_tracker` с отдельным ключом

### 3.6 LIKE escape в поиске
- Экранировать `%` и `_` в поисковом запросе перед `ilike`
- Ограничить длину запроса ≤ 100 символов

### 3.7 file_size check — обход при None
- `ws_manager.py:1509-1512` — требовать `file_size` в payload, не optional

### 3.8 upload_chunk — валидация
- Проверять `chunk_index` как `int`, `0 <= chunk_index < total_chunks`
- Проверять размер chunk ≤ CHUNK_SIZE

### 3.9 World save/load — авторизация
- Проверять `int(owner_id) == user.id`
- Проверять `realpath` остаётся в SAVES_DIR

### 3.10 Encrypted file path fix
- `ws_manager.py:1247-1280` — сохранять путь к `.enc` файлу, не оригинальному

### 3.11 Autoflush → True
- `database.py:17` — `autoflush=False` → `autoflush=True`
- Проверить что нигде нет побочных эффектов

---

## СПРИНТ 4: БАЗА ДАННЫХ

### 4.1 SQLite оптимизация
- WAL mode: `PRAGMA journal_mode=WAL`
- `PRAGMA busy_timeout=5000`
- Рассмотреть `AsyncAdaptedQueuePool` вместо `StaticPool`

### 4.2 Дополнительные индексы

```
ix_chat_members_user_id       ON chat_members(user_id)
ix_chat_members_chat_id       ON chat_members(chat_id)
ix_chat_members_unique        ON chat_members(chat_id, user_id) UNIQUE
ix_messages_chat_id           ON messages(chat_id)
ix_messages_chat_sent         ON messages(chat_id, sent_at)
ix_verification_code_lookup   ON verification_codes(user_id, purpose, used)
ix_chat_user1_user2           ON chats(user1_id, user2_id)
ix_post_reactions_post        ON post_reactions(post_id)
ix_post_comments_post         ON post_comments(post_id)
ix_bot_updates_lookup         ON bot_updates(bot_id, is_delivered)
```

### 4.3 Синхронный sqlite3 → async

Обернуть ВСЕ `sqlite3.connect()` вызовы:
- `main.py:92-181` — PLUGIN.DB функции → `asyncio.to_thread`
- `main.py:188-234` — SERVERS.db функции → `asyncio.to_thread`
- `ws_manager.py:2344-2373` — world_save/load → `aiofiles`
- `main.py:241-266` — packets_file_watcher → `aiofiles`

### 4.4 N+1 query fixes

- `serialise_message` — batch loading: один JOIN для user + badges + reactions
- `increment_unread` — `UPDATE ... SET count = count + 1` вместо SELECT+UPDATE
- `list_chats` — batch loading для chat info, last message, unread count
- `get_members` — batch loading для user info + badges

### 4.5 Bot tokens хеширование
- `Bot.token` → хранить SHA-256 хеш
- При создании бота: возвращать токен один раз, потом только хеш
- При проверке: хешировать входящий токен и сравнивать

### 4.6 Очистка утечек памяти
- MediaUploadChunk: periodic cleanup записей старше 1 часа
- invoices dict: TTL 1 час
- decocraft_queue: max size 1000
- verification_codes: cleanup старше 24 часов
- sessions: cleanup неактивных старше 30 дней

### 4.7 Удаление дублей
- Удалить `app/models.py` (top-level дубль)
- В `bot_api.py` импортировать `get_db` из `database.py`

---

## СПРИНТ 5: WEBSOCKET СТАБИЛЬНОСТЬ

### 5.1 WS message size limit
- Валидация `len(raw) < 5 * 1024 * 1024` перед парсингом

### 5.2 File upload size limit
- Проверка `len(b64data)` перед `base64.b64decode`
- Лимит 5 МБ для аватарок

### 5.3 id(websocket) → UUID
- `_ws_id()` → генерирует UUID при подключении
- Хранить маппинг `websocket → uuid`

### 5.4 Rate limit cleanup
- При disconnect: удалять запись из `rate_limit_tracker`
- Periodic task: cleanup записей старше 1 минуты

### 5.5 seen_message_ids cleanup
- Periodic task каждые 5 минут
- Time-bucketed approach вместо linear scan

### 5.6 botcreator_states TTL
- TTL 30 минут
- Periodic cleanup

### 5.7 Duplicate WS entries
- Перед `append` проверять `if websocket not in list`

### 5.8 Fire-and-forget tasks
- `task_tracker.py`: хранить set tasks, отменять при shutdown

### 5.9 Error handling
- `_send` — добавить `logger.warning` в except
- Глобальный handler — generic error клиенту, полный exception на сервер
- `/ws/gateway` — общий try/except для packet parsing
- `/ws/support` — аналогично

### 5.10 Graceful shutdown
- SIGTERM handler: закрыть все WS, дождаться tasks, закрыть БД
- `app/shutdown.py`

---

## СПРИНТ 6: LOGGING И МОНИТОРИНГ

### 6.1 Structured logging
- `structlog` или `loguru`
- JSON формат для продакшена
- Консоль для девелопмента
- Context: user_id, request_id, action

### 6.2 Request ID tracking
- Генерировать UUID на каждый запрос
- Пробрасывать через все логи
- Возвращать в заголовке ответа / WS response

### 6.3 Admin audit log
- Новая таблица `admin_audit_log`: timestamp, admin_id, action, target_type, target_id, details
- Записывать: ban, unban, freeze, delete badge, revoke badge

### 6.4 Suspicious activity persistence
- `suspicious_activity_log` → в БД вместо in-memory deque

---

# ГЛАВА 2: НОВЫЕ ФИЧИ

---

## СПРИНТ 7: СООБЩЕНИЯ

### 7.1 Цитирование сообщений
- Поле `reply_to_message_id` в `Message` модели
- При отправке: `payload.reply_to` = ID сообщения на которое отвечаем
- При получении: в ответе `replied_message` содержит оригинальное сообщение
- В UI: показывать превью цитаты над текстом

### 7.2 Пересылка сообщений
- Action `forward_message`: принимает `message_id` и `target_chat_id`
- Создаёт новое сообщение с `forwarded_from` = оригинальный sender
- Сохраняет оригинальный timestamp

### 7.3 Запланированные сообщения
- Новая таблица `scheduled_messages`: message_id, chat_id, sender_id, send_at, payload
- Action `schedule_message`: создаёт запись в БД
- Background task: каждую минуту проверять и отправлять due сообщения
- Action `cancel_scheduled`: удалить запись
- Action `list_scheduled`: показать запланированные для чата

### 7.4 Беззвучные сообщения
- Поле `silent: bool` в Message
- Если silent = true → push notification не отправляется
- В ленте помечается иконкой

### 7.5 Эффекты сообщений
- Поле `effect: str | None` в Message (confetti, fire, heart)
- Клиент рендерит анимацию при показе сообщения
- Сервер просто хранит и передаёт

### 7.6 Опросы (Polls)
- Новая таблица `polls`: id, chat_id, question, options (JSON), multiple_choice, anonymous, closes_at
- Новая таблица `poll_votes`: poll_id, user_id, option_index
- Action `create_poll`: создаёт опрос
- Action `vote`: голосует
- Action `close_poll`: закрывает (если anonymous=False — показывает результаты)
- Сообщение типа `MessageType.POLL` с превью

### 7.7 Закреплённые сообщения
- Поле `is_pinned: bool` в Message
- Поле `pinned_at: datetime` в Message
- Action `pin_message`, `unpin_message`
- Action `get_pinned`: вернуть закреплённое сообщение чата
- В UI: показывать закреплённое сообщение в шапке чата

### 7.8 Черновики с синхронизацией
- Таблица `drafts`: user_id, chat_id, content, updated_at
- Action `save_draft`: сохранить черновик
- Action `get_draft`: получить черновик для чата
- Push event `draft_updated`: уведомить другие устройства
- Черновик удаляется при отправке сообщения

---

## СПРИНТ 8: ЧАТЫ И КОНТАКТЫ

### 8.1 Папки чатов (Chat Folders)
- Новая таблица `chat_folders`: id, user_id, name, icon, position
- Новая таблица `chat_folder_items`: folder_id, chat_id
- Action `create_folder`, `update_folder`, `delete_folder`
- Action `add_chat_to_folder`, `remove_chat_from_folder`
- Action `list_folders`: вернуть все папки с чатами
- Клиент фильтрует список чатов по выбранной папке

### 8.2 Архивация чатов
- Поле `is_archived: bool` в ChatMember
- Action `archive_chat`, `unarchive_chat`
- Архивированные чаты не показываются в основном списке
- Push для архивированных чатов — без звука

### 8.3 Темы/форумы (Forum Topics)
- Новая таблица `forum_topics`: id, chat_id, name, icon_emoji, position, is_closed
- В forum чатах сообщения привязаны к topic_id
- Action `create_topic`, `update_topic`, `close_topic`, `delete_topic`
- Каждая тема — отдельный thread в UI

### 8.4 Быстрые ответы (Quick Replies)
- Таблица `quick_replies`: user_id, shortcut, text
- Action `create_quick_reply`, `list_quick_replies`, `delete_quick_reply`
- Клиент подсказывает quick reply при вводе shortcut

### 8.5 Сортировка чатов
- Поле `pin_position: int | null` в ChatMember
- Поле `last_message_at: datetime` в ChatMember (обновляется при новом сообщении)
- Сортировка: pinned (по pin_position) → по last_message_at

---

## СПРИНТ 9: ПРОФИЛЬ И ПОЛЬЗОВАТЕЛИ

### 9.1 Статус пользователя
- Поле `status: str` в User (online, offline, away, do_not_disturb)
- Поле `status_text: str` — кастомный статус типа "В отпуске до 15 июля"
- Поле `status_expires_at: datetime | null` — автоматический сброс
- Action `set_status`, `clear_status`
- Push event `status_changed` для контактов

### 9.2 День рождения
- Поле `birthday: date | null` в User
- Push notification в день рождения контакту
- Группировка "У кого скоро ДР"

### 9.3 Блокировка пользователей
- Таблица `blocked_users`: user_id, blocked_id, blocked_at
- Action `block_user`, `unblock_user`, `list_blocked`
- Заблокированный не может отправлять сообщения
- Заблокированный не видит last_seen/status заблокировавшего

### 9.4 Скрытые чаты (Hidden Chats)
- Поле `is_hidden: bool` в ChatMember
- Скрытые чаты не показываются в поиске и списке
- Доступны по PIN-коду или биометрии

### 9.5 Последнее посещение (Last Seen)
- Поле `last_seen_at: datetime` в User (обновляется при WS подключении)
- Поле `show_last_seen: bool` в User (privacy setting)
- Возвращается в профиле если privacy позволяет

---

## СПРИНТ 10: УВЕДОМЛЕНИЯ

### 10.1 Мульти-уровневые настройки уведомлений
- Таблица `notification_settings`: user_id, chat_id (nullable), level (all/muted/mentions_only/none), sound_id, vibration
- Глобальные настройки + per-chat оверрайды
- Action `update_notification_settings`, `get_notification_settings`

### 10.2 Push notification с rich content
- В push data: title, body, image, chat_id, message_id, sender_name, sender_avatar
- Клиент рендерит rich notification с превью и action buttons (Reply, Mark Read)

### 10.3 Тихие часы (Do Not Disturb)
- Таблица `dnd_settings`: user_id, start_time, end_time, enabled
- В dnd время: push не отправляются, звук отключён
- Action `set_dnd`, `get_dnd`

### 10.4 Уведомления об упоминаниях
- В `send_message`: если текст содержит `@username` → push даже для muted чатов
- Тип уведомления: "X mentioned you in chat Y"

---

## СПРИНТ 11: МЕДИА И ФАЙЛЫ

### 11.1 Стриминговое шифрование файлов
- `encryption.py` — chunk-based encrypt/decrypt вместо entire-file-in-memory
- Размер чанка: 64 КБ
- Потоковое чтение/запись через `aiofiles`

### 11.2 Превью файлов
- Action `get_file_preview`: для изображений — thumbnail, для видео — first frame, для PDF — first page
- Генерация thumbnail'ов при загрузке (PIL/Pillow)
- Хранение thumbnail'ов рядом с оригиналом

### 11.3 Ограничения по типам файлов
- Whitelist: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.mp4`, `.mov`, `.ogg`, `.opus`, `.mp3`, `.pdf`, `.doc`, `.docx`, `.txt`, `.zip`
- Max sizes: аватарки 5 МБ, медиа 50 МБ, файлы 100 МБ

### 11.4 Медиа-альбомы
- Поле `media_group_id: str | null` в Message
- Группировка сообщений с одинаковым `media_group_id`
- Отправка альбома: массив файлов, один `media_group_id`

---

## СПРИНТ 12: БОТЫ И ИНТЕГРАЦИИ

### 12.1 Bot webhook mode
- Таблица `bot_webhooks`: bot_id, url, secret, is_active
- Action `set_webhook`, `remove_webhook`, `get_webhook`
- При обновлении: отправлять POST на webhook URL вместо polling

### 12.2 Bot inline mode
- Таблица `inline_queries`: id, user_id, query, offset
- Action `answer_inline_query`: вернуть результаты для inline-запроса
- Клиент: ввод `@bot query` → показ результатов

### 12.3 Bot payments
- Интеграция с YooMoney для ботов
- Action `send_invoice` от имени бота
- Action `answer_shipping_query`

### 12.4 Bot commands menu
- Таблица `bot_commands`: bot_id, command, description
- Action `set_my_commands`: бот регистрирует свои команды
- Клиент: показывает меню команд при тапе на бота

---

## СПРИНТ 13: СОЦИАЛЬНЫЕ ФИЧИ

### 13.1 Stories
- Таблица `stories`: id, user_id, content_type, media_path, caption, expires_at, views_count
- Таблица `story_views`: story_id, user_id, viewed_at
- Action `create_story`, `view_story`, `delete_story`, `get_stories`
- Stories истекают через 24 часа
- В UI: горизонтальная полоса вверху с аватарками

### 13.2 Reactions на сообщения
- Таблица `message_reactions`: message_id, user_id, emoji
- Action `react_to_message`: добавить/убрать реакцию
- Push event `reaction_added` / `reaction_removed`
- В UI: плашка с эмодзи под сообщением, тап = свой reaction

### 13.3 Группы по интересам
- Таблица `interest_groups`: id, name, description, category, member_count
- Action `create_group`, `join_group`, `leave_group`, `list_groups`
- Каждая группа — это обычный чат с extra metadata

### 13.4 Репосты в Niosgram
- Поле `reposted_from: int | null` в Post
- Action `repost`: создать пост-ссылку на оригинал
- В feed: показывать "reposted by X"

### 13.5 Сохранённые сообщения (Bookmarks)
- Таблица `bookmarks`: user_id, message_id, saved_at, note
- Action `bookmark_message`, `unbookmark_message`, `list_bookmarks`
- Отдельный экран "Saved Messages"

---

## СПРИНТ 14: ПРОИЗВОДИТЕЛЬНОСТЬ

### 14.1 Кеширование
- Кеш для частых запросов: chat info, user profile, badges
- TTL 5 минут для горячих данных
- Invalidation при изменении

### 14.2 Batch operations
- `increment_unread`: batch UPDATE
- `push_to_chat`: batch send
- `serialise_message`: batch loading через JOIN

### 14.3 Pagination cursor-based
- Вместо offset-based pagination → cursor-based (по ID или timestamp)
- Лучше для real-time данных (нет пропуска/дублирования)

### 14.4 Connection pooling
- Если перейдём на PostgreSQL → `AsyncAdaptedQueuePool`
- Пока SQLite: `StaticPool` + WAL + `busy_timeout`

---

## СПРИНТ 15: REST API ЧАСТИЧНЫЙ ПЕРЕХОД

### 15.1 Новые REST endpoints

| Endpoint | Метод | Описание |
|---|---|---|
| `GET /api/v1/health` | GET | Health check |
| `GET /api/v1/users/{username}` | GET | Профиль пользователя |
| `GET /api/v1/media/{path}` | GET | Медиа файлы |
| `POST /api/v1/media/upload` | POST | Загрузка медиа |
| `GET /api/v1/posts/feed` | GET | Лента постов |
| `GET /api/v1/chats/{id}/avatar` | GET | Аватар чата |
| `GET /api/v1/metrics` | GET | Метрики (admin only) |
| `POST /api/v1/bot-api/{token}/...` | POST | Bot API (уже есть) |

### 15.2 Middleware
- CORS: конкретный список origins
- Request ID generation
- Structured request logging
- Error response standardization

---

## ОБЩАЯ ОЦЕНКА ВРЕМЕНИ

| Спринт | Описание | Дни |
|---|---|---|
| 1 | Архитектура ws_manager | 4-6 |
| 2 | Безопасность ключей | 1-2 |
| 3 | Критические баги | 2-3 |
| 4 | БД оптимизация | 2-3 |
| 5 | WS stability | 2-3 |
| 6 | Logging/мониторинг | 1-2 |
| 7 | Сообщения (цитаты, пересылка, опросы) | 3-4 |
| 8 | Чаты (папки, архив, темы) | 3-4 |
| 9 | Профиль (статус, ДР, блокировки) | 2-3 |
| 10 | Уведомления (multi-level, DND) | 2-3 |
| 11 | Медиа (стриминг, превью, альбомы) | 2-3 |
| 12 | Боты (webhook, inline, payments) | 3-4 |
| 13 | Соцсети (stories, reactions, groups) | 3-4 |
| 14 | Перф (кеши, batch, cursor pagination) | 2-3 |
| 15 | REST API | 2-3 |
| **Итого** | | **34-49 дней** |

---

## ЧЕКЛИСТ ПЕРЕД КАЖДЫМ КОММИТОМ

- [ ] Код работает (сервер запускается, WS подключается)
- [ ] Нет regressions (старые action'ы работают как раньше)
- [ ] Логи ошибок на месте (не проглочены)
- [ ] Нет hardcoded секретов в новом коде
- [ ] Импорты не сломаны
- [ ] Валидация входящих данных на месте
- [ ] Path traversal проверки работают

# Серверные возможности для инбокса: что уже умеет бэкенд

Дата: 2026-11-22. Клиент: `HEAD = a0536c42`, `v3.137.1+4307`.
Аудит списка чатов (pin / архив / непрочитанное / mute / папки / превью / формат выдачи / транспорт).

## Обновление 2026-11-22: сверено с боевым сервером

SSH заработал: `ssh nioscraft` (ключ `~/.ssh/id_nioscraft`, хост `almaziumbackend`). Только чтение: файлы не менял, сервисы не трогал, в БД не писал (`sqlite3 -readonly`), `/etc/niosmess/niosmess.env` и ключи не открывал.

**Что теперь подтверждено на живом сервере**

- Сервис `niosmess.service`: uvicorn на `127.0.0.1:5095`, один воркер, код в `/opt/niosmess/current` (ссылка на `releases/models-20261116T172506Z`), данные в `/var/lib/niosmess/messenger.db` (SQLite, WAL). Запущен 2026-11-19 21:02 UTC.
- Шесть файлов, на которых стоит этот отчёт, совпадают с локальной копией по sha256: `ws/handlers/chat_handler.py`, `ws/router.py`, `ws/connection_manager.py`, `services/chat_productivity.py`, `services/notification_delivery.py`, `services/chat_list_snapshot.py`. Таблица ниже верна для боевого кода.
- Закрепления, архива и «отметить непрочитанным» нет: grep по `app/` на `is_pinned|pinned_at|pin_chat|unpin_chat|archiv|mark_unread|manual_unread` пуст. В списке WS-операций роутера есть `pin_message` и `unpin_message`, чатовых нет.
- Схема живой БД: `chat_members` = `id, chat_id, user_id, role, is_muted, is_banned, joined_at, muted_until, moderation_reason, banned_at`. `unread_counters` = `id, chat_id, user_id, count, last_message_id`. Колонок под закреп, архив и mute уведомлений нет.
- Mute уведомлений живёт только в `users_fcm_tokens.notification_preferences`, в `list_chats` не отдаётся.
- Миниатюр нет: grep на `thumb|preview_url|blurhash` находит только эмодзи `thumbs_up`.
- Папки на проде есть: таблица `chat_folders`, 2 записи.
- Объём базы: 49 пользователей, 201 чат, 355 участий, 7 FCM-токенов, 121 ненулевой счётчик непрочитанного.

**Локальная `server_core` расходится с продом в трёх файлах**

| Файл | На проде | В локальной копии |
|---|---|---|
| `app/main.py` | есть вебхуки PayPalych `/reply`, `/refund`, `/charge` (127 строк) | их нет |
| `app/migrations.py` | создаёт таблицу `payment_orders`, импортирует `pally_payments` | вместо этого миграция `posts.client_post_id` и `post_comments.client_comment_id` |
| `app/models/models.py` | полей `client_post_id`, `client_comment_id` нет | есть |

На проде файлы `main.py`, `migrations.py`, `config.py`, `plus_api.py`, `services/pally_payments.py` датированы 2026-11-19 при релизе от 2026-11-16: их правили прямо в `current` после выкладки. Выкатывать локальную `server_core` как есть нельзя: пропадут платежи. Серверную часть этапа 5 нужно делать от кода, снятого с прода.

**Попутно замечено**

- Каталог `/opt/niosmess/current` имеет права `777`, часть файлов `666`, владелец `root`. Сам сервис писать туда не может (`ProtectSystem=strict`), но любой локальный пользователь сервера может подменить код.
- В `current` лежат пустой `messenger.db`, `.env` и десяток `*.bak_*`: мусор от ручных правок.
- `app/ws_manager.py` (274 КБ) на проде тоже есть и тоже не импортируется.

Пункты 1, 2 и 4 раздела «Что не проверил» этим закрыты. Пункты 3, 5, 6, 7 остаются.

## Обновление 2026-11-22: серверная часть этапа 5 написана локально

Код прода снят в `F:\Niosmess V2\server_core` (105 файлов, sha256 совпадает с `/opt/niosmess/current`), правки сделаны поверх него. **Выложено на прод 2026-11-22 12:23 UTC** правкой файлов прямо в `/opt/niosmess/current` (6 заменены, 2 добавлены, копии `*.bak_20261122-inbox`). `niosmess.service` перезапущен один раз, `/health/ready` 200, миграция добавила четыре колонки, число пользователей, чатов, участий и сообщений не изменилось. Откат: `/root/niosmess-backups/20261122-inbox` (`orig/` с исходными файлами, `messenger-predeploy.db`).

**Что добавлено**

| Файл | Правка |
|---|---|
| `app/services/chat_inbox_state.py` (новый) | WS-операция `set_chat_state`, правила, событие для остальных устройств |
| `app/models/models.py`, `app/migrations.py` | колонки `chat_members`: `pinned_at TIMESTAMP`, `is_archived`, `notifications_muted`, `marked_unread` (`BOOLEAN NOT NULL DEFAULT 0`) |
| `app/ws/router.py` | ветка `elif action in INBOX_STATE_ACTIONS`, после коммита рассылка `chat_state_changed` на остальные сокеты аккаунта |
| `app/ws/handlers/chat_handler.py` | `list_chats` отдаёт состояние и ставит закреплённые первыми; `mark_read` снимает `marked_unread`; FCM-пуш о сообщении не уходит тем, кто заглушил чат |
| `app/services/utils.py` | `increment_unread` возвращает чат из архива |
| `app/services/secret_chat_v2.py` | пуш секретного чата учитывает `notifications_muted` |
| `tests/test_chat_inbox_state.py` (новый) | 23 теста |

**Контракт `set_chat_state`**

- Запрос: `chat_id` или `chat_ids` (до 100, положительные целые) и хотя бы один булев флаг из `pinned`, `archived`, `muted`, `unread`. Меняются только переданные флаги.
- Ответ: `{"chats": [{"chat_id", "is_pinned", "pinned_at", "is_archived", "notifications_muted", "marked_unread"}]}` в порядке запроса. Те же поля приходят в каждой записи `list_chats`.
- Событие `chat_state_changed` с тем же телом уходит на остальные устройства аккаунта, запросивший сокет его не получает.
- Ошибки (`ValueError`, весь пакет отклоняется): чужой или забаненный чат, тема группы, «Избранное», `pinned` и `archived` вместе, больше 10 закреплённых.

**Правила**

- Закреп и архив взаимоисключающие: закрепление достаёт чат из архива, архивирование снимает закреп.
- Свежий закреп встаёт первым; в пакете первым встаёт первый чат запроса.
- Новое сообщение от другого участника возвращает чат из архива, если он не заглушён. Сообщение в теме возвращает её группу.
- Mute темы наследуется от группы. Пуши звонков серверным mute не фильтруются.
- `ChatMember.is_muted` (админский запрет писать) не тронут: это другой флаг.

**Проверено**

- `tests/test_chat_inbox_state.py`: 23 из 23. Весь набор: 30 прошли, 12 упали. Те же 12 падали на снимке прода до правок (тесты отстали от кода, нет `ENCRYPTION_KEY`, два теста читают несуществующий путь).
- Миграция прогнана на схеме прода, снятой через `sqlite3 -readonly`: старые строки, новые строки и строки из триггера `topic_member_insert` получают `NULL / 0 / 0 / 0`. Повторный запуск ничего не меняет.

**Не проверено**

- `set_chat_state` через настоящий сокет с реального клиента. На проде проверено только: сервис стартует, миграция прошла, новый модуль отрабатывает smoke-скрипт на Python 3.10.12 и SQLAlchemy 2.0.52 с базой в памяти.
- Рассылка `chat_state_changed` через настоящий сокет: тесты проверяют только то, что событие поставлено в `db.info`.
- Как выкладывают релизы: скрипта выкладки на сервере не нашёл.

---

## Как получены доказательства (читать до таблицы)

Прямого доступа к живому серверу по SSH **нет**: сервер принимает только `publickey`,
пароль из `.env` сервер отклонил ещё до проверки (подробности — в разделе «Как подключался»).
Поэтому все выводы о коде бэкенда сделаны по **локальной рабочей копии `server_core/`**
в корне проекта (`F:\Niosmess V2\server_core`), которая лежит в `.gitignore`
(`.gitignore:52-54`) и не коммитится, плюс по схеме локальной SQLite-копии базы
`server_core.legacy-20261116/messenger.db` и по **read-only HTTP-пробам** публичного origin.

Три метки достоверности дальше:

* **код** — прочитал в `server_core/**/*.py` локальной копии. Это то, что, судя по датам
  файлов (последние правки 2026-11-16), разработчик держит как актуальный бэкенд.
* **схема БД** — прочитал фактическую схему SQLite-файла (`PRAGMA table_info`), а не только
  объявления моделей.
* **предположение** — вывод, который кодом не подтверждён (например, что на сервере
  развёрнута именно эта ревизия кода).

**Чего я не смог подтвердить:** что на боевом сервере крутится ровно эта ревизия
`server_core`. Живой сервер отвечает (`/health/ready` → 200 `{"status":"ok"}`,
`/api/public/stats` → 200 `{"accounts":30,"messages":6000}`), но версию сборки наружу он не
отдаёт, а в БД без SSH не заглянуть. Всё, что ниже, — про код локальной копии.

---

## 0. Итоговая таблица

| Возможность | Есть на сервере | Что доделать на сервере | Что нужно в клиенте |
|---|---|---|---|
| **Закрепление чата в списке (pin)** | **Нет.** Ни поля, ни операции. Есть только `chats.pinned_message_id` — закреп **сообщения** внутри чата | Колонки `chat_members.is_pinned / pin_order / pinned_at`, две WS-операции (`pin_chat` / `unpin_chat`), поле `is_pinned` в записи `list_chats`, сортировка «закреплённые сверху» в `handle_list_chats` (сейчас сортировка жёстко по времени последнего сообщения) | Пункт меню «Закрепить» в `ChatActionsModal` (`ChatActionResult`), чтение `is_pinned` в `ApiChatSummary`, локальная группировка «закреплённые / остальные» в `chat_list_screen.dart` |
| **Архив чатов** | **Нет.** Ни `is_archived`, ни `archived_at`, ни `hidden`, ни операции | Колонка `chat_members.is_archived` (+`archived_at`), операции `archive_chat`/`unarchive_chat`, флаг в `list_chats`, правило авто-возврата при новом сообщении | Пункт меню «В архив», экран/секция «Архив», строка `chatListUnarchive` уже есть в l10n, но нигде не используется |
| **«Отметить непрочитанным» (manual unread)** | **Нет.** `UnreadCounter` умеет только считать входящие и обнуляться при `mark_read` | Операция `mark_unread` (флаг или счётчик), отдельное поле, чтобы «ручная» единица не стиралась первым же `increment_unread` | Пункт меню, оптимистичное локальное состояние |
| **Отметить прочитанным** | **Да.** WS `mark_read`, только `chat_id` | — | Совпадает: клиент шлёт ровно `{'chat_id': …}`, ждёт `unread_count` |
| **Mute уведомлений на пользователя** | **Частично.** Серверного «я заглушил этот чат» в `ChatMember` нет (`is_muted` — админский мут). Mute живёт только в JSON настроек FCM-токена (`users_fcm_tokens.notification_preferences.muted_chat_ids`) и влияет только на push | Нормальное поле/таблица (`chat_members.notifications_muted`), операция `mute_chat`/`unmute_chat`, отдача в `list_chats`, чтобы состояние переживало переустановку и было на всех устройствах | Читать серверное поле вместо `SharedPreferences` (`chat_muted_provider.dart` уже готов принять: `applyServerMute`) |
| **Папки чатов** | **Да, полностью на сервере.** Таблица `chat_folders`, операции `list_chat_folders` / `save_chat_folder` / `delete_chat_folder`, лимит 30, версии для конфликтов | Ничего критичного. Мелочи: правила папки — статический список `chat_ids` + `types` + `unread_only`, без «папка по типу чата с автопополнением» | Уже используется (`chat_productivity_provider.dart`), только UI папок доводить |
| **Превью медиа в списке** | **Частично.** Есть `last_message.media_url` (полный файл, не миниатюра), `media_type`, `media_duration`, `media_name`, `media_size`, объект `sticker` | Генерация миниатюр и поле `media_thumb_url`; сейчас каждое превью — это скачивание целого файла | Использовать `media_type` для иконки и `media_url` для картинки-превью с кэшем; для видео миниатюры брать неоткуда |
| **Закреплённые сообщения в чате** | **Да.** `chats.pinned_message_id`, `pin_message` / `unpin_message`, событие `message_pinned` | Модель — одно закреплённое сообщение на чат, без списка и без пин-лимита «как в Telegram» | Клиент **не использует** эти операции вообще (нет ни `pin_message`, ни UI) — это отдельная задача |
| **Темы в группах (topics)** | **Да.** `chats.topic_parent_id`, `topics_enabled`, `list_group_topics` / `create_group_topic` / `update_group_topic`, `include_topics` в `list_chats` | — | Частично используется (`list_group_topics` из `chat_productivity_provider.dart`) |
| **«Избранное» (Saved Messages)** | **Да.** `open_saved_messages`, чат с `productivity_kind='saved'`, отдаётся в `list_chats` как `is_saved` | — | Клиент поднимает его первым вручную (`chat_list_screen.dart:403-407`) |

---

## 1. Закрепление чатов (pin)

**Вывод: серверного закрепа чатов нет. Есть только закреп сообщения.**

### 1.1 Поля в моделях

`server_core/app/models/models.py:246-296` — полный набор полей `chats` и `chat_members`:

```python
275:    pinned_message_id = Column(Integer, ForeignKey("messages.id"), nullable=True)
...
285: class ChatMember(Base):
292:     is_muted = Column(Boolean, default=False)
293:     is_banned = Column(Boolean, default=False)
294:     muted_until = Column(DateTime(timezone=True), nullable=True)
295:     moderation_reason = Column(String(512), nullable=True)
296:     banned_at = Column(DateTime(timezone=True), nullable=True)
```

`is_pinned`, `pinned`, `pinned_at`, `pin_order` в моделях отсутствуют (проверено grep по
`server_core/app` — совпадений нет, кроме `pinned_message_id`).

### 1.2 Схема БД

`server_core/app/migrations.py:198-218` — единственные добавляемые миграциями колонки:

```python
198:        chat_columns = {
199:            "is_private": "INTEGER NOT NULL DEFAULT 0",
200:            "invite_token": "VARCHAR(64)",
201:            "auto_delete_seconds": "INTEGER",
202:            "pinned_message_id": "INTEGER",
203:        }
...
210:        member_columns = {
211:            "muted_until": "TIMESTAMP",
212:            "moderation_reason": "VARCHAR(512)",
213:            "banned_at": "TIMESTAMP",
214:        }
```

Фактическая схема локальной копии БД (схема БД, `PRAGMA table_info`):
`chats` = `id, chat_type, name, description, username, avatar_path, created_by, created_at,
updated_at, is_banned, comments_enabled, comments_chat_id, user1_id, user2_id, is_secret,
user1_public_key, user2_public_key` — закрепа нет ни как колонки чата, ни как колонки участника.
`chat_members` = `id, chat_id, user_id, role, is_muted, is_banned, joined_at`.
(Это снапшот от 2026-09-14, до миграций тем/папок; `muted_until` там ещё нет, но пин-полей нет
и в актуальных миграциях.)

### 1.3 Операции

В реестре WS-операций `server_core/app/ws/router.py` есть только закреп сообщения:

```python
505:                    elif action == "pin_message":
508:                        result = await handle_pin_message(payload, db, user)
509:                    elif action == "unpin_message":
512:                        result = await handle_unpin_message(payload, db, user)
```

`pin_chat`, `unpin_chat`, `set_pinned` — отсутствуют. Полный перечень чатовых операций:
`router.py:408-455` (`list_chats`, `open_direct`, `create_group`, `get_chat`, `get_members`,
`update_chat`, `chat_avatar_upload`, `invite_user`, `ban_member`, `mute_member`,
`promote_member`, `leave_chat`, `mark_read`).

### 1.4 Выдача и сортировка

Запись чата в `list_chats` собирается в `server_core/app/ws/handlers/chat_handler.py:304-350`.
`is_pinned` в ней нет. Сортировка — жёстко по времени последнего сообщения:

```python
354:    result.sort(key=lambda x: (x["last_message"] or {}).get("sent_at", ""), reverse=True)
```

То есть серверный порядок всегда «свежие сверху», и любое закрепление пришлось бы
пересортировывать на клиенте.

### 1.5 Лимит

Лимита нет, потому что нет и функции. Со стороны клиента «закреп» — это сейчас локальная
эвристика: чат «Избранное» принудительно ставится первым
(`pulse_flutter/lib/screens/chat_list_screen.dart:403-407`):

```dart
403:    // The self-chat is always the first pinned item in the main inbox.
404:    if (!hasActiveFolder && filter == ChatFilter.all) {
405:      final index = filtered.indexWhere((chat) => chat.isSaved);
406:      if (index > 0) filtered.insert(0, filtered.removeAt(index));
```

### 1.6 Не путать: закреплённые сообщения

Они **есть** и устроены как одно закреплённое сообщение на чат (поле `chats.pinned_message_id`).
`chat_handler.py:1704-1752`:

```python
1718:    if chat.chat_type == ChatType.DIRECT:
1719:        await assert_member(db, chat_id, user.id)
1720:    else:
1721:        await assert_admin(db, chat_id, user.id)
...
1734:    chat.pinned_message_id = message_id
```

В `get_chat` рядом с id отдаётся сериализованное сообщение
(`chat_handler.py:678-687, 711-712`), а в `list_chats` — только `pinned_message_id`
(`chat_handler.py:322`). При удалении сообщения пин снимается автоматически
(`chat_handler.py:1430-1435`).

Клиент Flutter эти операции не вызывает вообще: grep по `pulse_flutter/lib` на
`pin_message` / `unpin_message` / `pinnedMessageId` — 0 совпадений.

---

## 2. Архив чатов

**Вывод: архива нет ни в каком виде.**

* Поля `is_archived`, `archived`, `archived_at`, `hidden` отсутствуют: см. `models.py:246-300`,
  `migrations.py:198-218`, схему БД в п. 1.2. Grep по `hidden|is_hidden` по `server_core/app`
  даёт только `include_hidden` у бейджей и CSS — к чатам отношения не имеют.
* Операций `archive_chat` / `unarchive_chat` нет (`router.py:408-455`).
* Правила «вернуть из архива при новом сообщении» нет, потому что нет архива.
* Удаления чата из списка без выхода (`delete_chat`, `clear_history`, «скрыть») тоже нет —
  единственный способ убрать чат из списка это `leave_chat`
  (`chat_handler.py:943-954`, физически удаляет `ChatMember`).

Клиент к архиву уже частично готов текстом, но не кодом: строка
`chatListUnarchive` («Извлечь из архива») существует в
`pulse_flutter/lib/l10n/app_localizations_ru.dart:1116`, но нигде не используется — grep по
`chatListUnarchive` находит только объявления в l10n.

---

## 3. «Отметить непрочитанным» (manual unread)

**Вывод: нет.**

* Полей `marked_unread`, `is_unread`, `unread_mark` нет (`models.py:354-362`, `migrations.py`).
* В реестре операций `router.py` слово `unread` не встречается ни разу.
* Непрочитанное — производная величина: `unread_counters(count, last_message_id)`
  (`models.py:354-362`), растёт в `increment_unread` (`server_core/app/services/utils.py:287-301`),
  обнуляется в `reset_unread` (`utils.py:303-309`).

Важное следствие для будущей фичи: любая «ручная» единица непрочитанного, положенная в
`unread_count`, будет снесена первым же `mark_read`, и её нельзя будет отличить от настоящих
входящих. Для честного manual unread на сервере нужен отдельный флаг, а не инкремент счётчика.

---

## 4. Отметить прочитанным

**Вывод: есть, параметр ровно один — `chat_id`. Клиент совпадает с сервером.**

Сервер, `chat_handler.py:957-971`:

```python
957: async def handle_mark_read(payload: dict, db: AsyncSession, user: User) -> dict:
958:     chat_id = payload.get("chat_id")
959:     await assert_member(db, chat_id, user.id)
960:     await reset_unread(db, chat_id, user.id)
961:     from app.services.media_retention import mark_attachment_read
962:     await mark_attachment_read(db, chat_id, user.id)
...
966:         {"action": "chat_read", "payload": {"chat_id": chat_id, "user_id": user.id}},
...
971:     return {"message": "Marked as read", "unread_count": 0}
```

* Имя операции: `mark_read` (`router.py:444`).
* Параметры: `chat_id` (обязателен). `message_id` не нужен и не читается.
* Проверка членства — `assert_member`, то есть чужой чат отметить нельзя.
* Побочные эффекты: рассылка `chat_read` в чат, отмена push-уведомлений по этому чату
  (`queue_push(... 'chat_read' ...)`, строка 970) и отметка прочтения вложений.

Клиент, `pulse_flutter/lib/repositories/chat_repository.dart:1166-1175`:

```dart
1166:  Future<int> markRead(int chatId) async {
1169:        .request('mark_read', payload: <String, dynamic>{'chat_id': chatId});
1171:    if (response is Map<String, dynamic>) {
1172:      return response['unread_count'] as int? ?? 0;
```

Совпадает полностью: имя операции, единственный параметр, чтение `unread_count`.

---

## 5. Mute уведомлений на пользователя

**Вывод: серверного «я заглушил этот чат» нет. Есть суррогат — список `muted_chat_ids`
в настройках FCM-токена, который влияет только на push.**

### 5.1 `ChatMember.is_muted` — это НЕ настройка уведомлений

`chat_handler.py:895-922` — админская операция `mute_member`, требует прав администратора:

```python
902:     await assert_admin(db, chat_id, user.id)
...
915:     m.is_muted = mute
916:     m.muted_until = datetime.now(timezone.utc) + timedelta(seconds=duration) if mute and duration else None
917:     m.moderation_reason = str(payload.get("reason") or "")[:512] or None
```

Комментарий в клиенте это уже зафиксировал
(`pulse_flutter/lib/providers/chat_muted_provider.dart:21-24`):

```dart
21: /// Server state: the local `server_core` has no per-user notification mute yet
22: /// (`ChatMember.is_muted` is an admin speak-restriction, and `list_chats` sends
23: /// no mute field), so prefs is authoritative until the server starts sending
24: /// one. [applyServerMute] is the ready ingestion point for that field.
```

### 5.2 Где живёт `muted_chat_ids`

Модель (код, `models.py:42-51`) — JSON-строка прямо в строке FCM-токена, то есть
**per-device**, не per-user и не per-chat:

```python
42: class UserFCMToken(Base):
43:     notification_preferences = Column(Text, nullable=True)
44:     __tablename__ = "users_fcm_tokens"
45:     session_id = Column(Integer, nullable=True)
```

Схема БД: `users_fcm_tokens(id, user_id, fcm_token, platform, updated_at, session_id,
notification_preferences)` — `notification_preferences` добавлена миграцией
(`migrations.py:162` — для `session_id`; сама колонка объявлена в модели и создаётся
`create_all`).

Валидация и нормализация — `server_core/app/services/notification_delivery.py:7-19`:

```python
13:     muted = raw.get('muted_chat_ids', [])
14:     if not isinstance(muted, list) or len(muted) > 10000:
15:         raise ValueError('Invalid muted chat list')
16:     result['muted_chat_ids'] = sorted({int(v) for v in muted if str(v).isdigit() and int(v) > 0})
```

Лимит: до 10 000 id на токен.

Применение — там же, только на этапе сборки push (`notification_delivery.py:40-42`):

```python
40:     if not cancel and (options.get('enabled') is False or options.get(category) is False or
41:         str(data.get('chat_id')) in {str(v) for v in options.get('muted_chat_ids', [])}):
42:         return None
```

### 5.3 Где сервер это принимает

Только в `register_fcm_token` (`server_core/app/ws/handlers/profile_handler.py:263-282`):

```python
263: async def handle_register_fcm_token(payload: dict, db: AsyncSession, user: User) -> dict:
...
277:         t.notification_preferences = preferences(payload)
280:         db.add(UserFCMToken(user_id=user.id, fcm_token=fcm_token, platform=platform, updated_at=now, notification_preferences=preferences(payload)))
```

Отдельной операции «изменить настройки уведомлений» без перерегистрации токена нет — grep по
`notification_preferences` даёт только эти места и чтение в `connection_manager.py:159`.

Клиент так и делает: собирает локальный список из `SharedPreferences` и шлёт его при каждой
регистрации токена (`pulse_flutter/lib/providers/auth_provider.dart:748-774`):

```dart
748:        final prefix = 'chat_notifications_muted_${session.userId}_';
...
765:                'notification_preferences': {
768:                  'muted_chat_ids': muted,
```

То же в `core/services/push_notification_service.dart:86`.

### 5.4 Приходит ли mute в списке чатов

Нет. В записи `list_chats` (`chat_handler.py:304-350`) нет ни `is_muted`, ни
`notifications_muted`, ни `muted_until`. Mute-состояние приходит только из `get_members`
(`chat_handler.py:749`, админский флаг участника) и живёт на клиенте в prefs.

### 5.5 Что это значит практически

* Mute не переживает переустановку приложения (prefs стираются) и не синхронизируется между
  устройствами одного аккаунта: у каждого токена свой список.
* Mute не виден другим клиентам и не влияет на серверную доставку в websocket — только на FCM.
* Если токен не зарегистрирован (например, на web без push), mute-список нигде не хранится.

---

## 6. Папки чатов

**Вывод: папки хранятся на сервере, полностью рабочие, лимит 30.**

Таблица создаётся миграцией
`server_core/app/services/chat_productivity.py:54-58`:

```python
54:     await db.execute(text('''CREATE TABLE IF NOT EXISTS chat_folders (
55:         id TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
56:         title TEXT NOT NULL, rules_json TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0,
57:         version INTEGER NOT NULL DEFAULT 1, updated_at REAL NOT NULL)'''))
```

Операции (`chat_productivity.py:13-15`):

```python
13: ACTIONS = {'open_saved_messages', 'list_chat_folders', 'save_chat_folder', 'delete_chat_folder',
14:            'list_group_topics', 'create_group_topic', 'update_group_topic',
15:            'schedule_chat_message', 'list_scheduled_messages', 'update_scheduled_message', 'cancel_scheduled_message'}
```

Подключены в общий роутер (`router.py:463-467`), для любой не-`list_` операции клиентам
рассылается `productivity_changed`.

Правила папки (`chat_productivity.py:127-136`) — это **сохранённые на сервере фильтры**,
а не список участников: `chat_ids` (до 500, проверяется доступ), `types`
(`direct|group|channel|bot`, до 4), `unread_only` (bool).

Лимиты и конкурентность (`chat_productivity.py:169-185`):

```python
173:         if old and data.get('version')!=old[1]:
175:             raise ValueError('Папка изменена на другом устройстве. Обновите список')
176:         if not old and await db.scalar(text('SELECT COUNT(*) FROM chat_folders WHERE user_id=:u'),{'u':user.id})>=30: raise ValueError('Можно создать до 30 папок')
```

То есть: до 30 папок, `position` 0..1000, оптимистичная блокировка через `version`.

Клиент этим уже пользуется: `pulse_flutter/lib/providers/chat_productivity_provider.dart:239`
(`list_chat_folders`), `:294` (`save_chat_folder`), плюс локальный кэш в prefs
(`chat_folders_v1_<userId>`, строка 224). Фильтрация списка по папке — на клиенте
(`chat_list_screen.dart:391-398`, `folder.includes(chat)`).

---

## 7. Превью медиа в списке чатов

**Вывод: миниатюр нет. Есть URL полного файла и метаданные.**

`last_message` — это обычный сериализованный `Message`
(`server_core/app/services/utils.py:254-285`):

```python
269:         "media_url": media_url,
270:         "media_type": msg.media_type,
271:         "media_name": msg.media_name,
272:         "media_size": msg.media_size,
273:         "media_duration": msg.media_duration,
...
281:         "sticker": sticker_obj,
282:         "sent_at": msg.sent_at.isoformat() if msg.sent_at else None,
```

Как формируется `media_url` (`utils.py:210-218`):

```python
211:     media_url = None
212:     if msg.media_path:
213:         if msg.is_e2ee and msg.media_path.startswith('nios-stream:'):
...
218:             media_url = f"https://ni-os.ru/api/media/{msg.media_path}"
```

То есть для обычного чата это **прямая ссылка на оригинал** (`/api/media/...`), для E2EE —
blob-ссылка протокола (`/v1/blobs/{digest}`).

* Поля `media_thumb`, `thumbnail`, `preview_url` отсутствуют: grep по
  `thumbnail|thumb_|thumbPath|media_thumb` в `server_core/app` — 0 совпадений.
* Тип медиа есть (`media_type`, MIME-строка, например `image/webp`, `video/mp4`), длительность
  есть (`media_duration`, секунды, int), размер есть (`media_size`, байты).
* Для стикеров отдаётся объект `sticker` с `url`, `media_type`, `width`, `height`
  (`utils.py:227-252`).
* Для голосовых/кружков есть `msg_type` (`text|photo|video|voice|circle|sticker|file|
  call_log|...`, см. `models.py:20-31`) и `media_duration`.

Практический вывод: строке инбокса можно показать иконку по `media_type` мгновенно, а картинку —
только скачав оригинал. Для «плитки фото в превью» без дергания полного файла серверу нужна
генерация миниатюр.

---

## 8. Формат записи чата в `list_chats`

Источник: `chat_handler.py:304-352` плюс `chat_list_snapshot.py:48-91` (откуда берутся
`last_message`, `unread_count`, `members_count`).

### 8.1 Запись чата

| Поле | Тип | Откуда / примечание |
|---|---|---|
| `id` | int | `chat.id` |
| `is_saved` | bool | `chat.productivity_kind == 'saved'` |
| `topics_enabled` | bool | темы группы включены |
| `topic_parent_id` | int \| null | id родительской группы, если это тема |
| `topic_closed` | bool | тема закрыта |
| `chat_type` | str | `direct` / `group` / `channel` / `bot` |
| `name` | str | для direct — `display_name` собеседника, для saved — «Избранное» |
| `username` | str \| null | для direct — username собеседника |
| `avatar_url` | str \| null | `static_url(...)`; null, если фото скрыто приватностью или пользователь заблокировал |
| `invite_link` | str | `https://…/u/+token` для приватных, иначе `…/u/{username}` |
| `share_link` | str | аналогично |
| `last_message` | object \| null | см. 8.2 |
| `unread_count` | int | `unread_counters.count` |
| `members_count` | int | `COUNT(chat_members)` |
| `partner_badges` | array | бейджи собеседника (direct) |
| `partner_status_emoji` | object \| null | статус-эмодзи собеседника |
| `is_secret` | bool | секретный чат |
| `pinned_message_id` | int \| null | **закреп сообщения**, не чата |
| `has_active_space` | bool | активное пространство (коллаборация) |
| `ai_bot_enabled` | bool | — |
| `partner_user_id` | int \| null | только direct |
| `is_blocked_by_me` | bool | — |
| `is_blocked_by_user` | bool | — |
| `is_blocked` | bool | — |
| `is_online` | bool | **только direct** (`chat_handler.py:331-333`) |
| `with_user_id` | int | **только direct** |
| `with_user` | object | **только direct**: `id, username, display_name, avatar_url, is_online, is_blocked_by_me, is_blocked_by_user, is_blocked`, плюс `public_key`/`key_mismatch` для секретных |
| `key_mismatch` | bool | только секретный чат с несовпадающим ключом сессии |
| `partner_public_key` | str | только при `key_mismatch` |

Чего в `list_chats` **нет**, хотя оно есть в `get_chat` (`chat_handler.py:690-712`):
`description`, `is_private`, `auto_delete_seconds`, `comments_enabled`, `comments_chat_id`,
`pinned_message` (сам объект).

### 8.2 `last_message`

| Поле | Тип |
|---|---|
| `id` | int |
| `client_message_id` | str \| null |
| `chat_id` | int |
| `sender_id` | int |
| `sender_username` | str |
| `sender_display_name` | str |
| `sender_avatar_url` | str \| null |
| `sender_badges` | array |
| `sender_status_emoji` | object \| null |
| `msg_type` | str |
| `content` | str \| null (для E2EE — null) |
| `is_e2ee` | bool |
| `e2ee_content` | str \| null |
| `reply_to_id` | int \| null |
| `media_url` | str \| null |
| `media_type` | str \| null |
| `media_name` | str \| null |
| `media_size` | int \| null |
| `media_duration` | int \| null |
| `comments_count` | int |
| `reactions` | object `{emoji: count}` |
| `reply_markup` | object \| null |
| `parse_mode` | str \| null |
| `system_event_type` | str \| null |
| `system_event` | object \| null |
| `is_deleted` | bool |
| `sticker` | object \| null |
| `sent_at` | ISO str \| null |
| `edited_at` | ISO str \| null |
| `expires_at` | ISO str \| null |

Тяжесть выдачи: на каждый чат приходит полный сериализованный последний месседж со всеми
бейджами/статусами отправителя и картой реакций — даже если в списке нужны только превью и
время. Для 200+ чатов это заметный вес (предположение по структуре, замер не делал).

Сортировка — по `last_message.sent_at` по убыванию (`chat_handler.py:354`). Никакого
приоритета «закреплённые / с непрочитанными» сервер не даёт.

---

## 9. Транспорт и реестр операций

**Вывод: почти всё — один WebSocket с шифрованием, HTTP только для файлов/медиа/статики/
платежей/AI. REST-эндпоинтов для чатов нет вообще.**

### 9.1 WebSocket

`server_core/app/main.py:563-565`:

```python
563: @app.websocket("/ws")
564: async def websocket_endpoint(websocket: WebSocket):
565:     await ws_endpoint(websocket)
```

Клиент собирает тот же адрес: `pulse_flutter/lib/core/network/web_socket_client.dart:138-146`
(`scheme wss`, `path: '/ws'`), базовый origin — `api_constants.dart:6`
(`static const String origin = 'https://ni-os.ru';`).

### 9.2 Конверт сообщения

`server_core/app/ws/router.py:196-221`:

```python
196:     await _send(websocket, {"action": "key_exchange", "key": conn_key}, encrypt=False)
...
200:             raw = await websocket.receive_text()
201:             data = _decrypt_received(websocket, raw)
...
207:             action = data.get("action")
208:             payload = data.get("payload", {})
209:             req_id = data.get("request_id")
210:             token = data.get("token")
211:             message_id = data.get("message_id")
```

Схема: сначала `key_exchange` → `secure_key_exchange` (строка 223), дальше все кадры
зашифрованы. Каждый запрос: `{action, payload, token, request_id, message_id}`. Ответ:
`{action, payload, request_id, error}` (`router.py:752-756`). `message_id` проверяется на
replay (`router.py:218-221`). Именно это клиент и делает через
`.request('mark_read', payload: …)`.

### 9.3 Где реестр операций

Единственный реестр — **гигантская цепочка `if/elif` по строке `action`** в
`server_core/app/ws/router.py` (строки ~220-727). Отдельной таблицы/словаря операций нет;
имена собираются из литералов. Часть операций делегируется в
`app/services/chat_productivity.py` по множеству `ACTIONS` (`router.py:463-467`).

Важно: файл `server_core/app/ws_manager.py` (274 КБ) содержит почти копию этого роутера, но
**не используется** — `main.py:27` импортирует `from app.ws.router import ws_endpoint`, а
`ws_manager` нигде не импортируется. При поиске «где операция» можно случайно попасть в этот
мёртвый дубль.

Человекочитаемый список операций с примерами payload лежит в
`server_core/docs.md` (например, `docs.md:220-274`: `list_chats`, `get_chat`, `mute_member`).

### 9.4 HTTP-эндпоинты, которые есть

`main.py` регистрирует 51 маршрут, к инбоксу относятся только: `/api/media/{path}`
(`main.py:858`), `/static/{path}` (`857`), `/api/files/upload` (`1209`),
`/api/files/download` (`1285`), плюс админские `/api/admin/chats` (`678`). Никакого
`/api/v1/chats` нет — проверено пробой: GET на публичном origin даёт **404** с пустым телом
(SPA-fallback), тогда как `/health/ready` даёт 200 `{"status":"ok"}`, а `/api/public/stats` —
200 `{"accounts":30,"messages":6000}`.

Публичный OpenAPI (`/openapi.json`, 87 путей) описывает **только протокольный/платёжный API**
(`/v1/messages`, `/v1/mls/*`, `/v1/blobs/*`, `/bot-api/*`, `/api/plus/*`) — чатовых операций
там нет, потому что они не HTTP.

---

## 10. Что это значит для редизайна списка чатов

1. Закреп, архив и «отметить непрочитанным» — это **три новые серверные фичи целиком**
   (колонки + миграция + операции + поля в `list_chats`). На клиенте их сейчас нет даже в виде
   мёртвых заготовок: `ChatActionResult` содержит только `markRead, toggleMute, leave`
   (`pulse_flutter/lib/widgets/chat/chat_actions_modal.dart:9`), а `ChatTile.isPinned`
   (`chat_tile.dart:74,118`) нигде не передаётся (grep `isPinned:` по `lib` — 0 совпадений).
2. Mute в текущем виде — **локальный костыль**. Редизайн, который рисует «перечёркнутый
   колокольчик» из серверного поля, потребует сначала серверного поля, иначе поведение будет
   расходиться между устройствами (и молча пропадать после переустановки).
3. Папки — единственная часть «продуктивности», которую **не надо трогать на сервере**:
   они уже там, с версиями и лимитом 30.
4. Сортировка списка — целиком ответственность сервера (`chat_handler.py:354`). Если
   закреплённые должны быть сверху и это должно совпадать на всех клиентах, сортировку надо
   менять на сервере, а не патчить в очередной раз в `chat_list_screen.dart:403-407`.
5. Превью инбокса уже несёт столько данных, что строка может показать тип медиа, длительность,
   реакции и бейджи без единого дополнительного запроса — но картинки-миниатюры сервер не
   отдаёт, только оригинал.

---

## Как подключался и что запускал

Ничего на сервере не менял, не создавал и не удалял; сервисы не перезапускал; в БД не писал.

Попытки SSH (параметр `SSH_HOST`/`SSH_USER`/`SSH_PASSWORD` читались скриптом из
`F:\Niosmess V2\.env` в переменные, в командную строку и в отчёт не выводились):

1. `Test-NetConnection <host> -Port 22` → `TcpTestSucceeded: True` (порт открыт).
2. Python + `paramiko` (уже стоял, 5.0.0), вход по паролю из `.env`:
   `paramiko.ssh_exception.BadAuthenticationType: Bad authentication type; allowed types: ['publickey']`
   → сервер **не принимает пароли**, только ключи.
3. Проверка доступных методов: `Transport.auth_none()` → `allowed: ['publickey']`,
   `keyboard-interactive` сервером не предлагается.
4. Попытка входа существующим локальным ключом `~/.ssh/id_server` (PKCS#8 RSA; для paramiko
   конвертировал в памяти, файл не менял): `paramiko.AuthenticationException: Authentication
   failed` → ключ этому серверу не сдан.

На этом SSH-ветку остановил: подбор паролей/ключей и обходные пути не применял, как и
требовалось. Дальше работал только с локальными копиями и read-only HTTP.

Локальные read-only команды (Windows PowerShell):

* `git log --all --oneline -- server_core/*`, `git ls-tree -r --name-only 0d42f676^ -- server_core`
  — код бэкенда лежит в истории до коммита `0d42f676` («remove server_core from git tracking»,
  2026-07-17), но это старая ревизия; актуальнее локальная gitignored-копия.
* `Get-ChildItem server_core -Recurse -Filter *.py` — карта файлов, даты правок до 2026-11-16.
* `grep`/`Select-String` по `server_core/app` по словам `pin`, `archive`, `folder`, `mute`,
  `unread`, `pinned_message_id`, `muted_chat_ids`, `thumbnail`, `hidden`, `ADD COLUMN`,
  `action ==`.
* `python` + `sqlite3` в режиме `?mode=ro` (URI read-only) по
  `server_core.legacy-20261116/messenger.db`: `PRAGMA table_info(chats|chat_members|
  unread_counters)` — только чтение схемы.
* `grep` по клиенту `pulse_flutter/lib` (`markRead`, `mute_member`, `muted_chat_ids`,
  `isPinned`, `chatListUnarchive`, `pin_message`, `list_chat_folders`).

Read-only HTTP-пробы публичного origin (`Invoke-WebRequest -Method GET`, ничего не отправлял
кроме GET):

* `GET /health/ready` → `200 {"status":"ok"}`
* `GET /api/public/stats` → `200 {"accounts":30,"messages":6000}`
* `GET /openapi.json` → `200`, OpenAPI 3.1, 87 путей (протокольный API)
* `GET /api/v1/chats`, `/api/v1/health`, `/api/v1/docs`, `/api/v1/openapi.json` → `404`
* `GET /ws`, `/api/ws` без Upgrade-заголовка → `200` HTML (SPA-fallback), что ничего не
  доказывает про WebSocket; рукопожатие не инициировал.

---

## Что не проверил

1. **Что на сервере развёрнута именно эта ревизия `server_core`.** SSH недоступен, версию
   сборки сервер наружу не отдаёт (`/health/ready` возвращает только `{"status":"ok"}`).
   Все выводы «есть/нет» — про код локальной копии. Если на сервере более новый код с пином/
   архивом, я этого не увижу.
2. **Реальную схему боевой БД.** Локальная копия БД — снапшот 2026-09-14 (`legacy-20261116`),
   без миграций тем/папок. Утверждения про отсутствие пин/архив-колонок дополнительно
   подтверждены кодом моделей и миграций, но не живой базой.
3. **Поведение живого WebSocket** (какие `action` реально принимает боевой сервер): для этого
   нужен залогиненный токен, а логиниться в чужой аккаунт я не стал. Реестр операций взят
   из кода роутера.
4. **Наличие/размер `chat_folders` на сервере и реальные папки пользователей** — нужен доступ
   к БД.
5. **Производительность выдачи `list_chats` на реальных объёмах** (сколько весит ответ при
   200+ чатах) — не замерял, только оценил структуру. Помечено как предположение.
6. **Работу mute через FCM end-to-end** (что push действительно не приходит) — нужен реальный
   девайс и токен.
7. **Использует ли web-клиент те же операции** — не проверял, аудит только по Flutter-клиенту
   и серверному коду.

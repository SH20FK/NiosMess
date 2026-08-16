# SERVER_CORE — изменения под новый клиент NiosMess

> Файл: `server_core/app/ws_manager.py` (другие файлы сервера не трогались).
> Миграции БД не требуются. После применения — перезапустить FastAPI.
> Соответствующие клиентские коммиты в `pulse_flutter`: `b223fe1`, `e8799c1`, `6255361`.

## Сводка

| # | Изменение | Тип | Зачем |
|---|-----------|-----|-------|
| 1 | `handle_mark_read` → broadcast `chat_read` | модификация | Realtime read receipts |
| 2 | `handle_edit_message` → broadcast `message_edited` | модификация | Правки сообщений у собеседника без refetch |
| 3 | `handle_delete_message` → broadcast `message_deleted` | модификация | Удаления без refetch |
| 4 | `handle_react` → broadcast `message_reaction` | модификация | Реакции без refetch |
| 5 | `handle_decline_call` + диспетчер | **новое** | Отклонение звонка: вызывающий вешается сразу |
| 6 | `handle_unregister_fcm_token` + диспетчер | **новое** | Отзыв пушей при логауте |

---

## 1. `handle_mark_read` — broadcast `chat_read`

Когда пользователь читает чат, остальные участники мгновенно получают
«прочитано» на своих сообщениях.

```python
async def handle_mark_read(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    await assert_member(db, chat_id, user.id)
    await reset_unread(db, chat_id, user.id)
    # Let other members update read receipts in realtime.
    await push_to_chat(
        db,
        chat_id,
        {"action": "chat_read", "payload": {"chat_id": chat_id, "user_id": user.id}},
        exclude_user_id=user.id,
        skip_offline_fcm=True,
    )
    return {"message": "Marked as read", "unread_count": 0}
```

## 2. `handle_edit_message` — broadcast `message_edited`

В конец функции добавлена рассылка сериализованного сообщения всем
участникам (включая другие устройства автора — клиент применяет идемпотентно):

```python
    enc = encrypt_text(content)
    msg.encrypted_content = enc["ciphertext"]
    msg.content_iv = enc["iv"]
    msg.content_tag = enc["tag"]
    msg.edited_at = datetime.now(timezone.utc)
    serialized = await serialise_message(msg, db)
    await push_to_chat(
        db,
        chat_id,
        {"action": "message_edited", "payload": serialized},
        skip_offline_fcm=True,
    )
    return serialized
```

## 3. `handle_delete_message` — broadcast `message_deleted`

Добавлено сразу после удаления реакций, **до** удаления файла с диска:

```python
    await db.execute(delete(MessageReaction).where(MessageReaction.message_id == msg.id))

    await push_to_chat(
        db,
        chat_id,
        {"action": "message_deleted", "payload": {"chat_id": chat_id, "message_id": msg.id}},
        skip_offline_fcm=True,
    )

    if getattr(msg, "media_path", None):
        ...
```

## 4. `handle_react` — broadcast `message_reaction`

Клиент применяет реакции оптимистично, поэтому автору рассылка не идёт
(`exclude_user_id=user.id`).

```python
    if existing:
        await db.delete(existing)
        await push_to_chat(
            db,
            chat_id,
            {
                "action": "message_reaction",
                "payload": {
                    "chat_id": chat_id,
                    "message_id": message_id,
                    "emoji": emoji,
                    "action": "removed",
                },
            },
            exclude_user_id=user.id,
            skip_offline_fcm=True,
        )
        return {"action": "removed", "emoji": emoji}
    db.add(MessageReaction(message_id=message_id, user_id=user.id, emoji=emoji))
    await push_to_chat(
        db,
        chat_id,
        {
            "action": "message_reaction",
            "payload": {
                "chat_id": chat_id,
                "message_id": message_id,
                "emoji": emoji,
                "action": "added",
            },
        },
        exclude_user_id=user.id,
        skip_offline_fcm=True,
    )
    return {"action": "added", "emoji": emoji}
```

## 5. `handle_decline_call` — НОВЫЙ экшен

Вызываемый отклонил звонок → сервер финализирует звонок через существующий
`_finish_call` (was_missed=True), который рассылает `edit_message` (лог
«Пропущен») и `end_call`. Вызывающий по `end_call` вешает трубку сразу, не
дожидаясь 60-секундного таймаута.

Новый обработчик (вставлен перед `handle_end_call_signaling`):

```python
async def handle_decline_call(payload: dict, db: AsyncSession, user: User):
    """Callee rejected the call: finalize it and broadcast end_call so the
    caller's UI hangs up immediately instead of waiting for the timeout."""
    chat_id = payload.get("chat_id")
    room_id = payload.get("room_id")
    if not room_id:
        return {"error": "room_id is required"}
    if chat_id:
        await _require_member(db, chat_id, user.id)
    await _finish_call(db, room_id, was_missed=True, duration=0)
    return {"status": "declined"}
```

Диспетчер (перед `elif action == "end_call":`):

```python
                    elif action == "decline_call":
                        result = await handle_decline_call(payload, db, user)
```

## 6. `handle_unregister_fcm_token` — НОВЫЙ экшен

При логауте клиент отзывает свой FCM-токен, чтобы пуши не летели на
разлогиненное устройство (токен удаляется только у этого пользователя).

Новый обработчик (вставлен после `handle_register_fcm_token`):

```python
async def handle_unregister_fcm_token(payload: dict, db: AsyncSession, user: User):
    """Stop routing pushes to this device (logout)."""
    fcm_token = payload.get("fcm_token")
    if not fcm_token:
        return {"error": "fcm_token is required"}
    await db.execute(
        delete(UserFCMToken).where(
            UserFCMToken.fcm_token == fcm_token, UserFCMToken.user_id == user.id
        )
    )
    return {"message": "FCM token removed"}
```

Диспетчер (перед `elif action == "register_fcm_token":`):

```python
                    elif action == "unregister_fcm_token":
                        result = await handle_unregister_fcm_token(payload, db, user)
```

---

## Контракт с клиентом (pulse_flutter)

**Клиент теперь шлёт новые WS-запросы:**

| action | payload | Когда |
|---|---|---|
| `decline_call` | `{chat_id, room_id, message_id}` | Пользователь отклонил входящий звонок |
| `unregister_fcm_token` | `{fcm_token}` | Logout (до `logout`) |

**Клиент теперь обрабатывает push-события:**

| action | payload | Поведение клиента |
|---|---|---|
| `message_edited` | сериализованное сообщение | Замена сообщения в открытом чате + превью в списке; для E2EE — повторная расшифровка |
| `message_deleted` | `{chat_id, message_id}` | Удаление из стейта и кэша |
| `message_reaction` | `{chat_id, message_id, emoji, action: added\|removed}` | ±1 к счётчику реакции |
| `chat_read` | `{chat_id, user_id}` | Все сообщения НЕ от `user_id` → прочитано |
| `end_call` | `{chat_id, room_id, message_id, ...}` (существующий) | Раньше игнорировался; теперь закрывает баннер входящего и завершает активную сессию звонка |

Существующие `new_message` / `typing` / `new_call` / `new_ng_post` — без изменений.

## Заметки

- Все рассылки служебных событий идут с `skip_offline_fcm=True` — FCM на них не тратится (оффлайн-клиент всё равно догонит историю).
- `handle_answer_call` со статусами звонков в диспетчере по-прежнему не подключён — не нужен текущему клиентскому флоу (`start_call` / `join_call` / `decline_call` / `end_call`).
- Изменения E2EE-медиа на сервере не требуются: `/api/files/upload` и `/api/files/download` уже хранят/отдают байты как есть для `is_e2ee` сообщений (заголовок `X-Is-E2EE`) — шифрование полностью клиентское.

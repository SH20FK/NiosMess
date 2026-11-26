# Правка бэкенда: `get_invite_link` / `rotate_invite_link` (2026-11-26)

Приложение (`pulse_flutter/lib/screens/chat_manage_screen.dart`) запрашивает два
WS-действия, которых на проде не было: `get_invite_link` и `rotate_invite_link`.
В роутере существовали только `invite_user` и `get_invite_info`, поэтому блок
«ссылка-приглашение» в управлении чатом всегда получал `Unknown action`.

## Где правилось

Хост: `almaziumbackend` (`ssh nioscraft`), сервис `niosmess.service`
(`uvicorn app.main:app --host 127.0.0.1 --port 5095`).
Код: `/opt/niosmess/current/app` → симлинк на
`/opt/niosmess/releases/sec-upgrade-20261126T105632Z`.

Файлы:

| Файл | Что сделано |
|---|---|
| `app/ws/handlers/chat_handler.py` | добавлены `handle_get_invite_link` и `handle_rotate_invite_link` рядом с `handle_get_invite_info` |
| `app/ws/router.py` | импорт обоих обработчиков и две ветки dispatch (`get_invite_link`, `rotate_invite_link`) |

Бэкапы рядом с файлами:
`chat_handler.py.bak_invite_link_20261126-161805`,
`router.py.bak_invite_link_20261126-161805`.

## Поведение

`get_invite_link` (`{chat_id}`):

- чат должен существовать, быть не `DIRECT` и не забаненным;
- пользователь должен быть участником;
- для приватного чата возвращается `https://ni-os.ru/u/+<invite_token>`
  (токен создаётся, если его не было), для публичного — канонический
  `chat_link(username)`;
- `can_rotate` = `true` только для приватного чата и роли `OWNER`/`ADMIN`.

`rotate_invite_link` (`{chat_id}`):

- требует `assert_admin` (owner/admin), иначе `{"error": ...}`;
- для публичного чата ссылка не меняется (`rotated: false`) — публичная ссылка
  задаётся username;
- для приватного — новый `secrets.token_urlsafe(24)`, коммит и новая ссылка.

Ответы содержат `invite_link`, `share_link`, `is_private` и `can_rotate`
(у ротации — `rotated`), то есть ровно те поля, которые читает клиент в
`_loadInviteLink`/`_rotateInviteLink`.

## Проверка

```
python3 -m py_compile app/ws/handlers/chat_handler.py app/ws/router.py   # OK
systemctl restart niosmess.service && systemctl is-active niosmess.service  # active
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:5095/            # 200
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:5095/docs        # 200
```

Сервис поднялся без ошибок импорта (роутер импортирует оба новых обработчика,
значит опечатка в имени уронила бы старт).

## Важно про деплой

Исходного репозитория бэкенда на сервере нет — только релизные снапшоты.
Правка сделана **в текущем релизе**, поэтому:

1. при выкатке нового релиза её нужно перенести в исходники;
2. откат — вернуть файлы из `.bak_invite_link_20261126-161805` и перезапустить
   сервис;
3. локальная копия `server_core/` в репозитории **устарела** относительно прода
   (в ней нет ни support-действий, ни HTTP-загрузок, ни `client_hello`) — при
   сверке контрактов использовать прод, а не её.

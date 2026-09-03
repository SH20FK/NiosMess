NiosMess | WebSocket frontend integration

**NiosMess: изменения WebSocket сервера**

**Документация для интеграции во Flutter-клиент**

|**Серверный файл**|server\_core/app/ws\_manager.py|
| :- | :- |
|**База данных**|Миграции не требуются|
|**После деплоя**|Перезапустить FastAPI|
|**Объём изменений**|6 изменений: 4 realtime-события + 2 новых WS action|

|**Для фронтенда:** Главное изменение — больше не нужно делать refetch после read/edit/delete/reaction. Сервер сам рассылает realtime-события. Кроме этого, клиент должен отправлять decline\_call при отклонении входящего звонка и unregister\_fcm\_token перед logout.|
| :- |

# **Кратко: что нужно внедрить на клиенте**
- Добавить обработчики входящих событий: chat\_read, message\_edited, message\_deleted, message\_reaction.
- Обрабатывать существующий end\_call как команду немедленно закрыть входящий баннер и завершить локальную call-сессию.
- При отклонении входящего звонка отправлять WS action decline\_call.
- Перед logout отправлять WS action unregister\_fcm\_token с FCM-токеном текущего устройства.
- Существующие new\_message / typing / new\_call / new\_ng\_post не менять.
# **1. Формат WebSocket обмена**
Клиентские запросы по-прежнему передаются как action + payload. Сервер отвечает тем же action и возвращает payload/error; для request/response корреляции используется request\_id. Realtime broadcast приходит как отдельное событие с action и payload.

// Запрос клиента (схематично)\
{\
`  `"action": "<action>",\
`  `"payload": { ... },\
`  `"request\_id": "<client request id>",\
`  `"token": "<access token>"\
}\
\
// Обычный ответ сервера\
{\
`  `"action": "<same action>",\
`  `"payload": { ... },\
`  `"request\_id": "<same request id>",\
`  `"error": null\
}\
\
// Realtime broadcast\
{\
`  `"action": "message\_edited | message\_deleted | message\_reaction | chat\_read | end\_call",\
`  `"payload": { ... }\
}

|**Транспорт:** В ws\_manager уже есть шифрование WebSocket-пакетов/обмен ключами. Эта документация описывает логический action/payload после расшифровки; существующий транспортный слой менять не нужно.|
| :- |

# **2. Новый/изменённый контракт**

|**Направление**|**action**|**payload**|**Статус**|**Что делает клиент**|
| :- | :- | :- | :- | :- |
|Client -> Server|mark\_read|{chat\_id}|Уже существовал|Теперь инициирует chat\_read для остальных участников|
|Server -> Client|chat\_read|{chat\_id, user\_id}|НОВОЕ событие|Обновить read receipts без refetch|
|Client -> Server|edit\_message|{chat\_id, message\_id, content}|Уже существовал|После успеха сервер рассылает message\_edited|
|Server -> Client|message\_edited|serialized message|НОВОЕ событие|Заменить сообщение/preview; E2EE повторно расшифровать|
|Client -> Server|delete\_message|{chat\_id, message\_id}|Уже существовал|После удаления сервер рассылает message\_deleted|
|Server -> Client|message\_deleted|{chat\_id, message\_id}|НОВОЕ событие|Удалить сообщение из state/cache|
|Client -> Server|react|{chat\_id, message\_id, emoji}|Уже существовал|Toggle своей реакции|
|Server -> Client|message\_reaction|{chat\_id, message\_id, emoji, action}|НОВОЕ событие|action = added | removed; изменить счётчик|
|Client -> Server|decline\_call|{chat\_id, room\_id, message\_id}|НОВЫЙ action|Отклонить звонок и сразу завершить его у caller|
|Server -> Client|end\_call|{chat\_id, room\_id, message\_id, was\_missed, duration, message}|Существовал|Теперь обязательно закрывает call UI/сессию|
|Client -> Server|unregister\_fcm\_token|{fcm\_token}|НОВЫЙ action|Удалить push token текущего устройства перед logout|

# **3. Read receipts: chat\_read**
Что изменено на сервере: после mark\_read сервер сбрасывает unread для текущего пользователя и рассылает остальным участникам чата событие chat\_read. Пользователь, который сам вызвал mark\_read, broadcast не получает.

// Клиент -> сервер\
{\
`  `"action": "mark\_read",\
`  `"payload": { "chat\_id": 123 }\
}\
\
// Broadcast остальным участникам\
{\
`  `"action": "chat\_read",\
`  `"payload": {\
`    `"chat\_id": 123,\
`    `"user\_id": 42\
`  `}\
}

Рекомендуемая обработка на клиенте:

**1.**  Найти чат payload.chat\_id.

**2.**  Для сообщений, которые НЕ отправлены payload.user\_id, обновить локальный read-state согласно текущей модели клиента.

**3.**  Обновить видимые галочки/read receipts без повторного запроса истории.

**4.**  Не ждать FCM: служебное событие отправляется только по WebSocket (skip\_offline\_fcm=True).
# **4. Редактирование сообщений: message\_edited**
После успешного edit\_message сервер сериализует обновлённый Message и рассылает message\_edited всем участникам чата. Автор также может получить broadcast (включая другие его соединения); поэтому обновление должно быть идемпотентным.

// Broadcast\
{\
`  `"action": "message\_edited",\
`  `"payload": {\
`    `// полный serialized message в том же формате,\
`    `// который использует сервер для сообщений\
`  `}\
}

- Upsert/replace сообщения по message.id, а не добавлять новый элемент.
- Если редактировалось последнее сообщение — обновить preview в списке чатов.
- Если сообщение E2EE — выполнить повторную клиентскую расшифровку нового содержимого.
- Сохранить обновлённую версию в локальный cache.

|**Идемпотентность:** Не считайте response на собственный edit и broadcast двумя разными сообщениями. Оба должны сходиться в один message.id.|
| :- |

# **5. Удаление сообщений: message\_deleted**
При delete\_message сервер удаляет реакции сообщения и рассылает message\_deleted. После этого удаляются media-файл (если был) и само сообщение.

{\
`  `"action": "message\_deleted",\
`  `"payload": {\
`    `"chat\_id": 123,\
`    `"message\_id": 987\
`  `}\
}

- Удалить message\_id из state открытого чата.
- Удалить его из локального cache/database.
- Если это было последнее сообщение — пересчитать/обновить preview чата из локального состояния или существующего механизма синхронизации.
- Повторное message\_deleted для уже отсутствующего сообщения должно быть безопасным no-op.
# **6. Реакции: message\_reaction**
Существующий react работает как toggle реакции текущего пользователя. Если такая реакция уже есть — сервер удаляет её; иначе добавляет. Для других участников теперь отправляется message\_reaction. Инициатор broadcast не получает, потому что клиент уже применяет реакцию оптимистично.

// Добавление\
{\
`  `"action": "message\_reaction",\
`  `"payload": {\
`    `"chat\_id": 123,\
`    `"message\_id": 987,\
`    `"emoji": "👍",\
`    `"action": "added"\
`  `}\
}\
\
// Удаление: payload.action = "removed"

- На своём устройстве оставить текущую optimistic update логику.
- На входящем message\_reaction: added => +1 / добавить реакцию; removed => -1 / удалить реакцию.
- Не ожидать echo broadcast для собственного react: сервер исключает user\_id инициатора.
- Не отправлять push для этого события: используется skip\_offline\_fcm=True.
# **7. Отклонение звонка: decline\_call**
Добавлен новый WS action decline\_call. Он нужен, чтобы caller не ждал 60-секундный ringing timeout после того, как callee уже нажал «Отклонить». Сервер финализирует активный звонок как пропущенный и рассылает end\_call.

// Callee -> сервер\
{\
`  `"action": "decline\_call",\
`  `"payload": {\
`    `"chat\_id": 123,\
`    `"room\_id": "abc123...",\
`    `"message\_id": 987\
`  `}\
}\
\
// Ответ на request\
{\
`  `"action": "decline\_call",\
`  `"payload": { "status": "declined" },\
`  `"error": null\
}

|**Нюанс текущего backend:** message\_id присутствует в клиентском контракте, но обработчик decline\_call фактически использует room\_id. \_finish\_call достаёт chat\_id/message\_id из server-side active\_calls. Для совместимости контракт не упрощайте: отправляйте chat\_id + room\_id + message\_id.|
| :- |

При финализации сервер формирует end\_call примерно такого вида:

{\
`  `"action": "end\_call",\
`  `"payload": {\
`    `"chat\_id": 123,\
`    `"room\_id": "abc123...",\
`    `"message\_id": 987,\
`    `"was\_missed": true,\
`    `"duration": 0,\
`    `"message": { /\* serialized call-log message \*/ }\
`  `}\
}

Что клиент должен делать на end\_call:

**1.**  Если room\_id соответствует входящему звонку — закрыть incoming-call banner/dialog.

**2.**  Если room\_id соответствует активной call session — немедленно завершить локальную сессию (WebRTC/media/timers/route).

**3.**  Обновить call-log message из payload.message, если клиент использует это поле.

**4.**  Обработчик должен быть идемпотентным: повторный end\_call не должен повторно ломать навигацию/cleanup.

|**Важно:** В \_finish\_call сервер также рассылает существующее событие edit\_message для call-log, а затем end\_call. Если старый клиент уже слушает edit\_message, не удаляйте этот обработчик из-за новых message\_edited событий.|
| :- |

# **8. Logout и FCM: unregister\_fcm\_token**
Добавлен новый action для отзыва push-токена конкретного устройства. Сервер удаляет запись только если одновременно совпадают fcm\_token и текущий user.id.

// Перед logout\
{\
`  `"action": "unregister\_fcm\_token",\
`  `"payload": {\
`    `"fcm\_token": "<current device token>"\
`  `}\
}\
\
// Успех\
{\
`  `"action": "unregister\_fcm\_token",\
`  `"payload": { "message": "FCM token removed" },\
`  `"error": null\
}

Рекомендуемый порядок logout:

**1.**  Получить текущий FCM token устройства из существующего push-сервиса клиента.

**2.**  Отправить unregister\_fcm\_token и дождаться response (если WebSocket ещё доступен).

**3.**  После этого выполнить существующий logout / очистку access token и локальной сессии.

**4.**  Если fcm\_token отсутствует, сервер вернёт error: "fcm\_token is required".

|**Зачем:** Разлогиненное устройство перестаёт получать пуши пользователя. Удаляются не все токены аккаунта, а только переданный токен текущего пользователя.|
| :- |

# **9. Пример роутера событий во Flutter/Dart**
Ниже — пример структуры клиентской интеграции. Названия методов state/cache/callService нужно заменить на реальные методы проекта.

void onWsEvent(Map<String, dynamic> event) {\
`  `final action = event['action'] as String?;\
`  `final p = (event['payload'] as Map?)?.cast<String, dynamic>() ?? {};\
\
`  `switch (action) {\
`    `case 'chat\_read':\
`      `chats.markReadByUser(\
`        `chatId: p['chat\_id'],\
`        `readerUserId: p['user\_id'],\
`      `);\
`      `break;\
\
`    `case 'message\_edited':\
`      `messages.upsertSerialized(p); // replace by message.id\
`      `chats.refreshPreviewFromMessage(p);\
`      `break;\
\
`    `case 'message\_deleted':\
`      `messages.remove(p['chat\_id'], p['message\_id']);\
`      `cache.removeMessage(p['message\_id']);\
`      `break;\
\
`    `case 'message\_reaction':\
`      `messages.applyReactionDelta(\
`        `chatId: p['chat\_id'],\
`        `messageId: p['message\_id'],\
`        `emoji: p['emoji'],\
`        `added: p['action'] == 'added',\
`      `);\
`      `break;\
\
`    `case 'end\_call':\
`      `callService.finishRemote(\
`        `roomId: p['room\_id'],\
`        `wasMissed: p['was\_missed'] == true,\
`        `duration: p['duration'] ?? 0,\
`      `);\
`      `break;\
`  `}\
}
# **10. Примеры отправки новых action**
Future<void> declineIncomingCall(CallSession call) async {\
`  `await ws.request('decline\_call', {\
`    `'chat\_id': call.chatId,\
`    `'room\_id': call.roomId,\
`    `'message\_id': call.messageId,\
`  `});\
}\
\
Future<void> unregisterPushBeforeLogout(String fcmToken) async {\
`  `await ws.request('unregister\_fcm\_token', {\
`    `'fcm\_token': fcmToken,\
`  `});\
}
# **11. Realtime, offline и синхронизация**
- chat\_read, message\_edited, message\_deleted и message\_reaction отправляются с skip\_offline\_fcm=True: эти служебные события не дублируются через FCM.
- Если клиент был offline, он должен догнать актуальное состояние через уже существующую загрузку истории/чатов при reconnect.
- new\_message / typing / new\_call / new\_ng\_post в рамках этих изменений не менялись.
- Для edit/delete/read/reaction realtime-путь должен обновлять локальный state без refetch в момент события.
# **12. Минимальные тест-кейсы для фронтенда**

|**Сценарий**|**Действие**|**Ожидаемый результат**|
| :- | :- | :- |
|Read receipt|A читает чат|У B без refetch меняются read receipts по chat\_read|
|Edit|A редактирует сообщение|У B текст меняется сразу; у A нет дубликата|
|Delete|A удаляет сообщение|У B сообщение исчезает из state/cache|
|Reaction add|A ставит emoji|A видит optimistic update; B получает added|
|Reaction remove|A снимает emoji|A видит optimistic update; B получает removed|
|Decline call|B отклоняет звонок A|A получает end\_call сразу, не ждёт 60 секунд|
|Logout push|A выходит с device X|Токен X удалён; другие токены A не удалены|
|Reconnect|B был offline во время edit/delete|После reconnect состояние догоняется обычной историей/списком чатов|

# **13. Чеклист интеграции**
☐ Добавлен case chat\_read.

☐ Добавлен case message\_edited с upsert по message.id.

☐ Добавлен case message\_deleted с удалением из state и cache.

☐ Добавлен case message\_reaction (added/removed).

☐ end\_call закрывает incoming UI и активную call session.

☐ Кнопка «Отклонить» отправляет decline\_call.

☐ Logout сначала отправляет unregister\_fcm\_token.

☐ Собственные реакции остаются optimistic (не ждать broadcast echo).

☐ Служебные события не завязаны на FCM.

☐ Проверены два клиента одновременно + reconnect/offline сценарий.
# **14. Что сервер не менял**
- Миграции БД не требуются.
- E2EE media upload/download на сервере не менялись: сервер хранит/отдаёт байты как есть для is\_e2ee; шифрование остаётся клиентским.
- handle\_answer\_call отдельно в dispatcher не подключался и для текущего start\_call / join\_call / decline\_call / end\_call flow не требуется.

|**После выката backend:** Перезапустить FastAPI, затем проверить контракт на двух устройствах/аккаунтах.|
| :- |

Стр. 

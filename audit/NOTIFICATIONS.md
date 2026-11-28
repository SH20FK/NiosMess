# Аудит уведомлений NiosMess (Flutter + server_core)

Дата: 2026-11-28 · Режим: только чтение, код не менялся.
Клиент: `F:\Niosmess V2\pulse_flutter` (Firebase Messaging 17.1.0, flutter_local_notifications 23.0.4).
Сервер: `F:\Niosmess V2\server_core` (FCM-отправка — `app/ws/connection_manager.py`, `app/services/notification_delivery.py`).

---

## TL;DR

1. «secret message» приходит **не из клиента**, а из сервера. Для **обычных E2EE-чатов** он отправляет литерал
   `"New secret message"` (`server_core/app/ws/handlers/chat_handler.py:1212-1213`) и **не переводит его**:
   `prepare_device_push` переписывает body только при `is_secret == 'true'`
   (`server_core/app/services/notification_delivery.py:73-76`). Клиент тоже не узнаёт эту строку
   (`push_notification_service.dart:354` знает только `encrypted message` / `Зашифрованное сообщение`).
   Итог: в русском интерфейсе видно английское «New secret message».
2. Для **секретных** чатов generic-строка — не баг локализации, а следствие E2EE: сервер физически не имеет
   plaintext, а в FCM-payload **нет ciphertext**, поэтому в фоне/на убитом приложении текст показать нельзя.
3. В **foreground** (и при живом клиенте) plaintext уже есть в памяти (secret engine/journal), но уведомление
   никто не обновляет — вот это чинится.

---

# ЧАСТЬ 1. Почему вместо текста generic-строка

## 1.1 Все места, где формируются title/body

| # | Файл:строка | Что делает | Когда исполняется |
|---|---|---|---|
| 1 | `lib/providers/chat/chat_list_provider.dart:799-848` | `_notifyMessage`: собирает `title`/`body`/`is_secret` для локального пути | WS-пуш `new_message` при живом сокете |
| 2 | `lib/providers/notifications_provider.dart:219-338` | `accept`: единственный шлюз доставки (mute/prefs/preview), затем `showLocalNotification` | WS, FCM-foreground, напоминания |
| 3 | `lib/core/services/push_notification_service.dart:294-421` | `showLocalNotification`: финальный выбор body + пост локального уведомления | foreground и `onBackgroundMessage` (data-only) |
| 4 | `lib/core/services/push_notification_service.dart:208-292` | `_buildNotificationDetails`: каналы, стиль, actions, звук | все локальные посты |
| 5 | `lib/core/services/push_notification_service.dart:18-22` | `_onBackgroundMessage` | фон/terminated |
| 6 | `lib/core/services/push_notification_service.dart:572-601` | `_onForegroundMessage`: склеивает `message.data` c `notification.title/body` | foreground FCM |
| 7 | `server_core/app/ws/handlers/chat_handler.py:1211-1237` | `title`/`body_text` для FCM по сообщению | отправка сообщения |
| 8 | `server_core/app/services/secret_chat_v2.py:338-346` | FCM для секретного чата: `title='NiosMess'`, `body='New secret message'` | secret-сообщение |
| 9 | `server_core/app/services/notification_delivery.py:36-90` | `prepare_device_push`: финальная замена body под prefs/locale | перед каждой отправкой |
| 10 | `server_core/app/ws/connection_manager.py:102-125` | `send_push`: собирает `AndroidNotification`/`ApsAlert` | отправка |
| 11 | `server_core/app/services/chat_productivity.py:289-295` | напоминания (`type: reminder`) | отложенные сообщения |
| 12 | `server_core/firebase-messaging-sw.js:16-47` | web-воркер: `title`/`body` | web push |

Ключевой факт: для сообщений сервер **всегда** кладёт `notification`-блок, кроме `call_ended`/`chat_read`/`call_v2`
(`connection_manager.py:108-114`). А клиент в фоне при наличии `notification` выходит сразу:

```dart
// push_notification_service.dart:18-22
if (message.notification != null) return;   // локальный body не считается вообще
```

→ вся клиентская логика `preview`/`is_secret`/локализации в фоне **мертва** для обычных сообщений.
Фон показывает ровно то, что прислал сервер.

## 1.2 Откуда берётся generic-строка: условия

| Условие | Где | Что видит пользователь |
|---|---|---|
| `is_secret == 'true'` (секретный чат) | `notification_delivery.py:73-74` | `Зашифрованное сообщение` / `Encrypted message` (по `locale`) |
| `is_secret != 'true'`, но `e2ee_content != null` (обычный E2EE-чат) | `chat_handler.py:1212-1213` → строка не переписывается (`notification_delivery.py:75` её не знает) | **`New secret message`** — английский литерал, всегда |
| `preview == false` | `notification_delivery.py:75-76`, `push_notification_service.dart:350-351` | `Новое сообщение` |
| `chat.isSecret == true` (локальный путь) | `chat_list_provider.dart:804-807` → `820-821` | `noticeEncrypted` |
| `message.isE2ee && !message.isDecrypted` (локальный путь) | `chat_list_provider.dart:822-823` | `noticeNewMessage` |
| есть `upload_id` | `chat_handler.py:1217-1218` | `Sent a media file` (тоже английский) |
| fallback web | `firebase-messaging-sw.js:20` | `Новое событие` |

Итог по жалобе владельца: **«secret message» = `New secret message` из `chat_handler.py:1213`**, попадающий в
обычные (не секретные) E2EE-чаты. Это не «политика», это незалокализованный fallback.

Дополнительно: клиентская карта фолбэков

```dart
// push_notification_service.dart:352-357
: data['is_secret']?.toString() == 'true' ? strings.noticeEncrypted
: (event.body.toLowerCase() == 'encrypted message' || event.body == 'Зашифрованное сообщение')
    ? strings.noticeNewMessage
: event.body;                      // "New secret message" проходит как есть
```
— не содержит `new secret message`, поэтому даже в foreground строка не подменяется.

## 1.3 Что реально приходит в FCM-payload

`data_payload` (`chat_handler.py:1222-1234`, дополняется в `notification_delivery.py:85-89`):

```
chat_id, message_id, sender_name, is_secret ("true"/"false"), created_at, type=new_message,
body, title, chat_kind (private|group|channel), account_id, locale,
notification_protocol, notification_sound, event_id, (expires_at для звонков)
```

| Поле | Есть? |
|---|---|
| `body` (готовый текст) | да — но это уже результат серверной логики |
| `text` / `content` | нет |
| `ciphertext` / `e2ee_content` | **нет** |
| ключи/эпоха/`message_key` | нет |

Секретный путь (`secret_chat_v2.py:339-341`) — только `type, is_secret, chat_id, message_id, title, body`.
То есть **в пуше нет ничего, из чего можно расшифровать сообщение**. Ни в фоне, ни в foreground.

## 1.4 Можно ли показать текст

| Вариант | Реально? | Почему |
|---|---|---|
| Обычный (не E2EE) чат | **уже работает** | сервер имеет `content` в момент отправки → `body = preview[:100]` (`chat_handler.py:1214-1216`) |
| Обычный E2EE чат, foreground | **уже работает частично** | `chat_list_provider.dart:601-639`: клиент расшифровывает и вызывает `_notifyMessage(decoded)` с реальным текстом |
| Обычный E2EE чат, фон | **нет** | payload без `e2ee_content`; OS показывает серверный body |
| Обычный E2EE чат, фон — если добавить ciphertext | технически возможно, но хрупко | нужен `e2ee_content` в payload + расшифровка в фоновом isolate |
| Секретный чат | **нет, по дизайну** | см. ниже |

Блокеры для расшифровки в `onBackgroundMessage`:

1. Ключи секретных чатов лежат в Hive-боксе `secret_journal_v2_<userId>`, ключ бокса — в
   `FlutterSecureStorage` под `niosmess.secret.<id>.v2.key` (`secret_chat_provider.dart:87,145-150`).
   Фоновый isolate FCM — отдельный движок: platform-channel'ы (secure storage) в нём не
   зарегистрированы, нужен `BackgroundIsolateBinaryMessenger`/свой registrant.
2. Hive не безопасен для двух isolate'ов в одном процессе: главный isolate держит бокс открытым
   (`Hive.openBox` в `secret_chat_provider.dart:146`), повторное открытие из фона грозит порчей журнала.
3. Ключи обычного E2EE — тоже `FlutterSecureStorage` (`ordinary_e2ee_service.dart:33,92-97`) + возможное
   состояние `locked` (биометрия/app lock). В фоне разблокировать нечем.
4. Даже если всё это собрать — plaintext уйдёт в системный трей, т.е. на экран блокировки. Это уже
   продуктовое решение, а не техническое.

## 1.5 Настройка «показывать текст» — есть и читается

| Слой | Файл:строка | Поведение |
|---|---|---|
| UI-переключатель | `widgets/notifications/notification_settings_section.dart:220-226` | `preview` + hint `noticePreviewHint` |
| Строки | `l10n/secret/generated/secret_chat_localizations_ru.dart:1013-1017` | «Показывать текст» / «Секретные сообщения всегда скрыты в системных push.» |
| Хранение | `providers/notification_preferences_provider.dart:29-40,90-110` | `notification_preferences_<account>`, `preview` |
| Отправка на сервер | `providers/auth_provider.dart:777-806` | `notification_preferences` в `register_fcm_token` |
| Сервер | `services/notification_delivery.py:75-76` | `preview == false` → «Новое сообщение» |
| Клиент (foreground) | `push_notification_service.dart:350-351`, `notifications_provider.dart:297-302` | то же |

Работает. Но: (а) на секретные чаты не влияет вообще; (б) не спасает от `New secret message`, потому что
эта ветка срабатывает **после** проверки `is_secret`, а для обычного E2EE `body` уже испорчен сервером.

## 1.6 Обычные vs секретные: политика или техника

| | Обычный чат | Обычный E2EE | Секретный чат |
|---|---|---|---|
| plaintext у сервера | да | **нет** | **нет** |
| текст в push | да (100 симв.) | нет (`New secret message`) | нет (`Зашифрованное сообщение`) |
| клиент может расшифровать | — | да (foreground) | да (foreground, journal) |
| реальное ограничение | — | техническое (payload без ciphertext) | техническое + политика («всегда скрыто») |

Вывод: «секретные нельзя» — **техническое** ограничение (нет plaintext и нет ciphertext в пуше), а поверх него
уже лежит продуктовая политика, зашитая в `noticePreviewHint`. Для обычных E2EE ограничение **снимается
на клиенте** — и частично уже снято (п.1.4), просто не доведено до системы.

---

# ЧАСТЬ 2. Аудит уведомлений и дизайна

## 2.1 Каналы Android

`push_notification_service.dart:458-503`

| id | name | importance | priority | звук | вибрация | где используется |
|---|---|---|---|---|---|---|
| `niosmess_messages` | Сообщения NiosMess | high | high | да | `[0,200,100,200]` | сообщения со звуком |
| `niosmess_messages_silent` | (noticeSilentMessages) | high | — | нет | нет | `sound=false` |
| `niosmess_calls` | Звонки NiosMess | max | max | да | `[0,400,200,400]` | звонки |
| `niosmess_updates` | Обновления NiosMess | low | — | нет | нет | OTA (`ota_update_provider.dart:549,584`) |

Замечания:
- `niosmess_messages_silent` имеет `importance: high` при `playSound: false` — канал «тихий» только по звуку,
  но всё равно делает heads-up. Имя обещает больше, чем даёт.
- Каналы создаются только в `init()` главного isolate. `showLocalNotification` из фонового isolate
  (`push_notification_service.dart:367-377`) создаёт канал неявно из `NotificationDetails` — кастомный
  `vibrationPattern` из `init()` там не применится.
- Android 13+ (`POST_NOTIFICATIONS`, manifest:22) — ок, но при отзыве разрешения каналы не пересоздаются.

## 2.2 Параметры одного уведомления

`_buildNotificationDetails`, `push_notification_service.dart:208-292`

| Параметр | Значение | Комментарий |
|---|---|---|
| small icon | `@mipmap/ic_launcher` (:235) | **дефект** — см. D3 |
| `color` / `ledColor` | `0xFF6750A4` (:236, :255) | baseline-фиолетовый M3, тема приложения — пользовательский seed + нейтральные поверхности (`app_theme.dart:23-29,62`) → **дефект** D5 |
| style | `MessagingStyleInformation` (:242-247) | только direct-чаты выглядят верно, см. D4 |
| `conversationTitle` | `title` (:244) | для групп = имя группы |
| `Person` (автор сообщения) | `Person(name: title)` (:246, :384) | для групп «автор = имя группы» |
| «мой» Person | `Person(name: 'NiosMess')` (:243) | хардкод вместо имени аккаунта |
| `onlyAlertOnce` | `false` (:251) | осознанно (одно уведомление на чат) |
| `groupKey` | `niosmess_chats` / `niosmess_calls` (:252) | summary-уведомления нет → бандл без сводки |
| `setOnlyAlertOnce`/`autoCancel` | не заданы явно | автоотмена по умолчанию true |
| звук | `RawResourceAndroidNotificationSound('notification')` (:261) | файл должен быть в `android/app/src/main/res/raw` |
| вибрация/свет | `enableVibration: true`, `led*` (:254-258) | на Android 8+ свет не работает (каналы) |
| BigText | только звонки (:240-241) | для длинного текста сообщения нет «развернуть» — MessagingStyle сам умеет |
| actions | только звонки `accept`/`decline` (:263-279) | нет «Ответить»/«Прочитано» → **улучшение** |
| `timeoutAfter` | 60000 только звонки (:248) | ок |
| `fullScreenIntent` | `true` для звонка (:280) | нет разрешения → D2 |
| iOS | `presentAlert/Badge/Sound`, `interruptionLevel` (:282-290) | `presentBadge: true`, но `badgeNumber` нигде не задаётся → бейдж всегда «1»/не обновляется |
| `threadIdentifier` | `chat_<id>` (:289) | ок |

## 2.3 Поведение по сценариям

| Сценарий | Что происходит | Оценка |
|---|---|---|
| Тап по уведомлению | `_onNotificationTap`/`_onNotificationTap2` → `handleNotificationData` (:704-719) → `_messages.add` (:765) + `go('/chat/id')` | дубль-риск, см. D6 |
| Несколько сообщений в чате | одно уведомление на чат, `chatNotificationId` (`:46-47`), MessagingStyle-тред до 8 сообщений (`:381-392`) | ок |
| Активный чат | `accept` ставит `present=false` при `currentChatId == chatId` (`notifications_provider.dart:290-296`) | ок; но `setCurrentChat` ставится только в `initState` чата (`chat_detail_screen.dart:296,388`) |
| Звонок | отдельный канал max, `fullScreenIntent`, accept/decline, `timeoutAfter 60s`, «завершённые» комнаты в prefs (`:300-320,664-691`) | логика зрелая, но D2 ломает full-screen |
| Foreground | локальное уведомление через `showLocalNotification` | ок; переинициализация плагина на каждое сообщение (D7, low) |
| Background | OS показывает серверный `notification`-блок; клиентский код не участвует (`:18-22`) | D1 |
| Terminated | OS показывает серверный body; тап → `getInitialMessage`/`getNotificationAppLaunchDetails` (`:449-455,519-522`) | ок |
| Web | свой SW (`firebase-messaging-sw.js`), настройки из `syncNotificationWorker` **никто не слушает** (в SW нет `message`-хендлера) | мёртвый мост |
| Чтение чата | read-receipt `chat_read` → `cancelChatNotification` (`notifications_provider.dart:184-196`, сервис `:693-702`) | ок |
| Mute чата | prefs `chat_notifications_muted_*` → `muted_chat_ids` при регистрации токена (`auth_provider.dart:781-801`), сервер режет (`notification_delivery.py:59-62`) + локальный гейт (`notifications_provider.dart:267-269`) | ок, двойной гейт |
| «Выключить всё» | `unregisterFcmToken` (`auth_provider.dart:732-737`) + `_local.cancelAll()` (`:75-79`) | ок |

## 2.4 История, дедуп, PII

- История: `notification_history_store.dart` — Hive-бокс `notification_history_v2_<account>`, ключ в
  `FlutterSecureStorage` (`:26-52`), один атомарный снапшот (`:54-65`), лимит 100 (`:79`), стирание при
  logout (`:103-110`). Legacy-записи уходят в отдельный зашифрованный архив
  (`legacy_notification_archive.dart:8-40`). **Хорошо.**
- Дедуп: `mergeNotification` по `event_id` (`notification_event.dart:121-132`) + `_handledClicks` на 128
  (`push_notification_service.dart:38,733-739`) + `previous != null` в `accept` (`:319-325`). Ок.
- PII в логах: `debugPrint` в путях уведомлений не печатает ни title, ни body
  (`push_notification_service.dart:102,170,419,556,566`; `notifications_provider.dart:181,313,349,399`). Ок.
  Единственный риск — `'[Push] LOCAL_NOTIFICATION_ERROR $error'` (:419): текст исключения плагина может
  содержать payload. Низкий.
- История хранит **полный текст** превью (включая «Новое сообщение»), но не апгрейдится после расшифровки.

## 2.5 Дизайн в приложении

- In-app баннеров/тостов уведомлений **нет** — они удалены осознанно (`notifications_provider.dart:315-318`),
  foreground показывается системным уведомлением. То есть «дизайн уведомления в приложении» = центр
  уведомлений.
- Центр (`widgets/notifications/notification_center.dart`): на широком экране — `Dialog` с
  `surfaceContainerHigh` + `RoundedSuperellipseBorder(28)` (:14-24), на узком — `AppModal.showSheet` (:28-35).
  M3E-консистентно с остальным приложением.
- Строка списка: `surfaceContainerLow` (прочитано) / `secondaryContainer` (не прочитано) (:127-131) —
  тональные поверхности есть, но `secondaryContainer` в нейтральной теме выглядит как акцентная плашка,
  а не как «непрочитано».
- Иконки-заглушки по типу (:148-154), время `DateFormat.MMMd().add_Hm()` (:177-184), точка непрочитанного
  8pt без семантики (:193-204).
- Нет аватара чата, нет группировки по чату, нет swipe-to-dismiss, нет «Ответить из центра».
- Движение: центр использует стандартные `Dialog`/sheet без `widgets/motion` (там есть `M3Reveal`,
  `M3StaggeredList`, `M3SpringSwitcher`) — единственное место в приложении, где список уведомлений
  появляется без motion-обёртки.

## 2.6 Дефекты (по убыванию)

**D1. Английский литерал `New secret message` в обычных E2EE-чатах** — причина жалобы.
`server_core/app/ws/handlers/chat_handler.py:1212-1213`:
```python
if is_secret or e2ee_content:
    body_text = "New secret message"
```
`notification_delivery.py:73-76` переписывает body только при `is_secret == 'true'`, а `chat_handler.py:1226`
ставит `is_secret: "false"` для обычного E2EE. Клиент (`push_notification_service.dart:354`) эту строку не знает.
Evidence: `prepare_device_push` возвращает `(title, 'New secret message', data)` как есть → `AndroidNotification(body=...)`.
Цена фикса: ~2-4 ч (сервер: `body_text` под `locale` + `preview_kind`; клиент: маппинг).

**D2. Звонок не открывается на весь экран** — `fullScreenIntent: true`
(`push_notification_service.dart:280`) без `android.permission.USE_FULL_SCREEN_INTENT` в
`android/app/src/main/AndroidManifest.xml` (отсутствует; grep по всему `android/` — 0 совпадений).
На Android 10+ система молча игнорирует full-screen intent → звонок на заблокированном телефоне
остаётся heads-up'ом и может быть пропущен. Цена: ~15 мин.

**D3. small icon = adaptive launcher icon** — `AndroidManifest.xml:93-94`
(`com.google.firebase.messaging.default_notification_icon = @mipmap/ic_launcher`) и
`push_notification_service.dart:235`. На Android 8+ small icon обязан быть монохромным `drawable`;
adaptive/mipmap-иконка рендерится как белый/серый квадрат или пустое пятно. Отдельного
`res/drawable/ic_notification.*` в проекте нет (в `res/` только `drawable/launch_background.xml`).
Цена: ~1-2 ч (нужен mono-SVG + `default_notification_color`).

**D4. MessagingStyle врёт об авторе в группах и каналах** — `push_notification_service.dart:242-247`:
```dart
MessagingStyleInformation(
  const Person(name: 'NiosMess'),      // «я» — хардкод
  conversationTitle: title,
  messages: conversation ?? [Message(body, DateTime.now(), Person(name: title))],
)
```
Для direct-чата `title` = имя собеседника → случайно верно. Для группы `title` = имя группы
(`chat_handler.py:1211`) → уведомление «Группа: текст» с автором «Группа».
Плюс: серверный пуш для группы вообще не префиксует отправителя (`chat_handler.py:1214-1216`), а локальный
путь префиксует (`chat_list_provider.dart:834`) → фон и foreground выглядят по-разному. Цена: ~3-4 ч.

**D5. Брендинг уведомлений не связан с темой** — `0xFF6750A4` в `:236,255`, при том что тема
строится из пользовательского seed и «нейтрализуется» (`app_theme.dart:23-29,62`, `app_surfaces.dart`).
Фиолетовый accent + фиолетовый LED на монохромных поверхностях = чужой бренд. Цена: ~2 ч.

**D6. Тап по пушу может пере-опубликовать уведомление** — `handleNotificationData`
(`push_notification_service.dart:765`) кладёт data в `_messages`, `accept` (`notifications_provider.dart:219`)
вызывается с `present: true`; suppression по открытому чату не срабатывает, т.к. `currentChatId` ещё `null`
(ставится в `chat_detail_screen.dart:296`). Если приложение было убито, `previous == null` → `:330-334`
постит локальное уведомление заново, уже после тапа. Repro: убить приложение → получить пуш → тапнуть.
Цена: ~1 ч (`present: false` для пути тапа + `markRead`).

**D7. Переинициализация плагина на каждое уведомление** — `push_notification_service.dart:366-377`:
`_local.initialize(...)` внутри `showLocalNotification`, т.е. лишний platform-round-trip на каждое
сообщение в foreground и повторная регистрация `_onNotificationTap`. Для фонового isolate инициализация
нужна, для главного — нет. Цена: ~1 ч (флаг «уже инициализирован в этом isolate»).

Дополнительно (низкий приоритет, но стоит записать):

| # | Файл:строка | Суть |
|---|---|---|
| N1 | `firebase-messaging-sw.js` | SW не слушает `postMessage` от `syncNotificationWorker` (`notification_web_bridge_web.dart:23-40`) → настройки на web не применяются; `badge` = цветной png вместо монохрома |
| N2 | `push_notification_service.dart:495-499` | «silent» канал с `importance: high` всё равно даёт heads-up |
| N3 | `push_notification_service.dart:191-206` | `_shouldIgnorePush` выбрасывает легитимный текст «new activity» и любые пустые body |
| N4 | `push_notification_service.dart:111` | `_conversationThreads.clear()` только в `clearAccount`, не в `cancelAll` — текст живёт в памяти после отмены |
| N5 | `notifications_provider.dart:315-318` | комментарий «banners removed», но `accept` по-прежнему принимает `present` — мёртвый параметр на одном из путей |
| N6 | `chat_productivity.py:289-295` | `is_secret: 'false'` захардкожен для напоминаний — напоминание о секретном чате не защищено |
| N7 | `notification_center.dart:193-204` | точка непрочитанного — `Icon(Icons.circle)` без `Semantics` |

## 2.7 Улучшения дизайна (с ценой)

| # | Что | Зачем | Цена |
|---|---|---|---|
| U1 | Монохромный small icon + `default_notification_color` из `scheme.primary`; убрать `0xFF6750A4` | уведомление перестаёт выглядеть «сломанным» и становится частью бренда | 0.5 дня (иконка + код + проверка на Android 8/13/14) |
| U2 | Осмысленный MessagingStyle: `Person` = отправитель (передавать `sender_name` из payload), `conversationTitle` = чат, `isGroupConversation` для групп, summary-уведомление на `groupKey` | группы читаются как в Telegram/WhatsApp, а не «Группа написала Группе» | 1 день |
| U3 | Действия «Ответить» и «Прочитано» | ответ без открытия приложения — главный сценарий мессенджера | 2-3 дня (inline-reply требует нативного RemoteInput: во `flutter_local_notifications` его нет, нужен platform-channel) |
| U4 | Центр уведомлений: аватар чата, группировка по чату, swipe-to-dismiss, `M3StaggeredList` при появлении, тональный шаг `surfaceContainerHighest` вместо `secondaryContainer` для непрочитанного | центр сейчас — плоский список без иерархии и motion | 1-1.5 дня |
| U5 | Обновление текста уведомления после расшифровки (secret/ordinary) + опция «показывать текст в секретных чатах» с предупреждением про экран блокировки | закрывает саму жалобу владельца по существу | 2 дня (хук в `secret_chat_engine._commit` + `_local.show` с тем же id + тесты) |

---

# ЧАСТЬ 3. Что менять в каком порядке

| Шаг | Действие | Файлы | Оценка | Эффект |
|---|---|---|---|---|
| 1 | Убрать английские литералы из пушей: `body_text` по `locale`, `preview_kind` вместо магических строк; клиентский маппинг `new secret message` → `noticeNewMessage` | `chat_handler.py:1212-1216`, `secret_chat_v2.py:339-346`, `notification_delivery.py:73-77`, `push_notification_service.dart:352-357` | 4 ч | **жалоба владельца закрыта** (текст перестаёт быть «secret message»), RU-локаль перестаёт течь |
| 2 | `USE_FULL_SCREEN_INTENT` + проверка звонка на заблокированном Android 12-14 | `AndroidManifest.xml` | 1 ч | звонки не теряются |
| 3 | Монохромный small icon + цвет из темы | `res/drawable/ic_notification.*`, manifest, `push_notification_service.dart:235` | 4 ч | уведомление выглядит как продукт, а не как debug-сборка |
| 4 | Тап: `present: false` и `markRead` на пути `handleNotificationData` | `push_notification_service.dart:721-768`, `notifications_provider.dart:219` | 1 ч | нет «фантомных» уведомлений после тапа |
| 5 | MessagingStyle по отправителю + summary-группа | `push_notification_service.dart:208-292`, `chat_handler.py:1222-1231` | 1 день | группы и каналы читаются правильно |
| 6 | Текст в уведомлении для секретных чатов при живом клиенте (opt-in через `preview`) | `secret_chat_engine._commit`, `secret_chat_provider`, `push_notification_service` | 2 дня | закрывает запрос «надо само сообщение» там, где это технически возможно |
| 7 | Ответ/«прочитано» из уведомления + центр уведомлений (аватары, группировка, motion) | нативный channel, `notification_center.dart` | 3-4 дня | уровень «как у людей» |
| 8 | Мелкое: канал `silent` → importance default, `_shouldIgnorePush`, `_conversationThreads`, web-SW `message`-хендлер | см. N1-N5 | 0.5 дня | гигиена |

**Итого минимум для жалобы + видимых дефектов: ~1.5 дня (шаги 1-4).**
Полный пакет: ~8-9 дней.

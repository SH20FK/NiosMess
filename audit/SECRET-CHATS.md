# Секретные и обычные чаты: что на самом деле в коде

Дата: 2026-11-28
Область: `F:\Niosmess V2\pulse_flutter` (Flutter 3.50.1) + сервер `F:\Niosmess V2\server_core`
Метод: чтение и трассировка вызовов, без изменений кода. Живую БД не смотрел — все выводы из кода; там, где нужен ответ по данным, это помечено.

---

## 0. Короткий вердикт

1. **`isSecret` — это серверный persisted-флаг `chats.is_secret`, а не вычисляемое свойство клиента.** Клиент его только читает из `list_chats`/`get_chat`/`open_direct` и складывает в `ApiChatSummary.isSecret`. По умолчанию везде `false`.
2. **Клиент нигде не заставляет все чаты быть секретными.** Новый личный чат по основному пути создаётся обычным (`is_secret=false`). Секретный создаётся только явным действием «Секретный чат».
3. **«Особой разницы нет» — это правда, но по другой причине:** обычные личные чаты **тоже E2EE**, причём автоматически. Клиент при первом открытии создаёт ordinary-ключи, после чего сервер запрещает открытый текст в этих чатах (`E2E_REQUIRED`). Пользователь сравнивает два шифрованных режима, а не «шифр vs открытый текст».
4. Реальная разница, которая осталась: **привязка к устройству и восстановимость** (secret — device-bound Double Ratchet, ordinary — аккаунтный keyring с recovery), **где лежит история** и **набор запретов** (в secret отключены copy/forward/«Избранное»/напоминания/отложенные/интерактив/геопозиция).
5. Если владелец видит замок у **всех** чатов — это данные (чаты исторически созданы как secret), а не дефолт кода. Плюс есть баг, из-за которого кнопка «Написать» в профиле может открыть существующий **секретный** чат вместо обычного.

Проверить данные одним запросом:

```sql
SELECT is_secret, COUNT(*) FROM chats WHERE chat_type='direct' GROUP BY is_secret;
```

---

## 1. Откуда берётся `isSecret`

### 1.1 Слои и значения

| Слой | Файл:строка | Что происходит |
|---|---|---|
| Модель сервера | `server_core/app/models/models.py:263` | `is_secret = Column(Boolean, default=False)` — колонка в `chats` |
| Миграция | `server_core/app/migrations.py:285-288` | `ALTER TABLE chats ADD COLUMN is_secret INTEGER DEFAULT 0` — у старых строк `0` |
| Сервер: список | `server_core/app/ws/handlers/chat_handler.py:322` | `"is_secret": chat.is_secret` в каждой строке `list_chats` |
| Сервер: открыть личку | `server_core/app/ws/handlers/chat_handler.py:392,471-538,558-565` | `is_secret = payload.get("is_secret", False)`; `true` → ищет/создаёт `Chat(is_secret=True)`, `false` → `Chat(is_secret=False)`; в ответе `chat.is_secret` |
| Сервер: создать группу/канал | `server_core/app/ws/handlers/chat_handler.py:578,604-613` | `is_secret` **читается, но не применяется**: `Chat(...)` создаётся без него → всегда обычный |
| Клиент: модель | `lib/models/api/chat_summary_model.dart:64,103,331` | конструктор `this.isSecret = false`; поле `final bool isSecret`; парсинг `_parseBool(json['is_secret'])` |
| Клиент: кэш | `lib/models/api/chat_summary_model.dart:445`, `lib/core/storage/cache_service.dart:160` | `is_secret` пишется/читается как есть; для secret обнуляется только `last_message` |
| Клиент: кэш списка | `lib/providers/chat/chat_list_provider.dart:270,302` | кэш делится на `!isSecret` и `isSecret` — флаг не пересчитывается |
| Клиент: ответ `open_direct` | `lib/models/api/chat_actions_models.dart:44` | `isSecret` из ответа сервера (4 варианта bool/int/string) |
| Клиент: репозиторий | `lib/repositories/chat_repository.dart:124-133` | `openDirectChat({bool isSecret = false})` кладёт `'is_secret': isSecret` |

**Вывод:** флаг серверный. Источников «истины» два: колонка `chats.is_secret` (БД) и параметр `is_secret` в `open_direct`. Локального состояния/настройки, которое делает чат секретным, нет.

### 1.2 Где клиент выставляет `true`

Все места — создание/синтез, ни одно не «перекрашивает» существующий чат:

| Место | Файл:строка | Условие |
|---|---|---|
| Явное действие «Секретный чат» в профиле | `lib/screens/public_profile_screen.dart:210-228` | пользователь нажал пункт меню |
| Пикер людей в режиме `secret` | `lib/features/chats/presentation/people_picker_screen.dart:51-60` | маршрут `/new-message?mode=secret` |
| Создание через движок secret | `lib/services/secret_chat/secret_chat_engine.dart:649-703` | `open_direct` с `is_secret: true` при первой отправке |
| Синтетическая строка из ответа | `lib/core/navigation/direct_chat_navigator.dart:208,224` | `result.isSecret \|\| isSecret` |
| Строка из журнала secret | `lib/providers/secret_chat_provider.dart:624-651` | `isSecret: true` для каждой беседы движка |
| Мёртвый диалог | `lib/widgets/chat_creation_surfaces.dart:46` | `showStartSecretChatDialog` — **нет ни одного вызова** |

---

## 2. Правда ли все чаты секретные

### 2.1 Новый чат: какой тип выставляется

Основной путь (кнопка «+» в инбоксе → «Написать»):

```
InboxComposeButton (lib/widgets/chat/inbox_compose_button.dart:64-72)
  → openComposeActions (lib/features/chats/presentation/compose_action_sheet.dart:28-39)
      case message  → '/new-message'
      case secret   → '/new-message?mode=secret'
  → app_router.dart:333-341  mode = secret ? secret : direct
  → PeoplePickerScreen.mode (lib/features/chats/presentation/people_picker_screen.dart:51)
  → navigateToDirectChat(isSecret: false|true (lib/core/navigation/direct_chat_navigator.dart:27-28))
  → ChatRepository.openDirectChat(isSecret: false) (lib/repositories/chat_repository.dart:127-132)
  → WS open_direct  →  server chat_handler.py:392,520-538  → Chat(is_secret=False)
```

Другие входы, все — обычные (`isSecret` не передаётся, дефолт `false`):

* контакты: `lib/screens/contacts_screen.dart:113-130` через `openDirectChatByUsername` (`chat_repository.dart:163-173`);
* поиск в инбоксе: `lib/features/chats/presentation/inbox_search_results.dart:207-212`;
* звонок из профиля: `lib/screens/calls/outgoing_call_screen.dart:84`;
* профиль, кнопка «Написать»: `lib/screens/public_profile_screen.dart:181-208`.

**Итог:** по умолчанию новый личный чат — обычный. Секретный требует отдельного пункта меню.

### 2.2 Существующие чаты: что приходит с сервера

`list_chats` отдаёт `is_secret` из БД (`chat_handler.py:322`). Клиент не додумывает:

* `_fetch` берёт серверный список, импортирует из него только secret-чаты в движок, затем **выкидывает все серверные secret-строки** и **добавляет их заново из локального журнала**:
  `lib/providers/chat/chat_list_provider.dart:963-1011`, `lib/providers/secret_chat_provider.dart:605-657`.
* Внутри `mergeChats` стоит ровно один фильтр:
  `lib/providers/secret_chat_provider.dart:606` — `remote.where((c) => !c.isSecret)`.
* Строки движка помечаются `isSecret: true` (`:637`) и получают `id = ui_id`, который для импортированного чата равен серверному id (`secret_chat_engine.dart:178`), а для нового — отрицательный timestamp.

**Итог:** обычный чат остаётся обычным, пока в БД `is_secret=0`. Секретный показывается из журнала, а не из серверной строки.

### 2.3 Есть ли ветка «обычный чат» и в каком она состоянии

Да, живая и основная:

| Признак | Где |
|---|---|
| Отправка | `lib/providers/chat/chat_messages_provider.dart:2317-2352` — ветка `chat?.isSecret != true` шифрует ordinary E2EE |
| История | `:694` `EncryptedHistoryArchive.open`, `:739` `EncryptedMessageCache.loadMessages` — только для обычных (secret выходит раньше, `:598-631`) |
| Расшифровка | `:1237-1257` — `isSecretChat` выбирает протокол |
| Список | `lib/providers/chat/chat_list_provider.dart:270-313`, `:641-663` — превью расшифровываются только для `!isSecret` |
| UI | `lib/widgets/chat/chat_detail_app_bar.dart:272-276` — обычный чат получает `OrdinaryPeerKeyNotice`, а не плашку secret |
| Настройки | `lib/widgets/settings/ordinary_e2ee_settings.dart:53-66` — пикер контактов ordinary E2EE |

### 2.4 Две реальные причины, почему «кажется, что всё секретное»

**(A) Обычные личные чаты тоже E2EE и включаются сами.**
`OrdinaryE2eeService.open()` вызывается при построении инбокса (`chat_list_provider.dart:163-180`). Если у аккаунта ещё нет ordinary-identity, сервис создаёт ключи и регистрирует их (`ordinary_e2ee_service.dart:292-300`). После этого сервер считает E2EE обязательным для всех личных чатов пользователя:

* `server_core/app/services/ordinary_e2ee.py:84` — ordinary E2EE только для `chat_type=DIRECT` и `not chat.is_secret`;
* `:88-90` — `required = own identity+enabled OR peer identity+enabled`;
* `server_core/app/ws/handlers/chat_handler.py:1043-1057` — открытый текст в таком чате **отклоняется**: `E2E_REQUIRED`.

То есть после первого запуска приложения переписка в обычном чате шифруется, и внешне «всё секретное».

**(B) Баг разрешения чата в профиле.**
`public_profile_screen.dart:97-114` берёт **первый** direct-чат с этим username независимо от `isSecret` и кладёт его в `_resolvedChatId`. Кнопка «Написать» передаёт его как `knownChatId` (`:189-195`), а навигатор в обычной ветке слепо доверяет положительному `knownChatId`:
`direct_chat_navigator.dart:89-100`. Если первым в списке оказался секретный чат — «Написать» открывает **секретный** чат. Новый обычный чат при этом не создаётся. Это может усиливать впечатление «все чаты секретные».

### 2.5 Мёртвый дубль сервера (не причина, но объясняет расхождения)

`server_core/app/ws_manager.py:1392-1506` содержит **вторую** реализацию `open_direct`. Живой роутер — `app/ws/router.py` (`main.py:27`), он зовёт `chat_handler.py`. `ws_manager.py` никто не импортирует (проверено grep по `app/`), но его правки легко принять за поведение сервера.

---

## 3. Чем секретный чат отличается от обычного сейчас

Обычный путь для личных чатов = ordinary E2EE. Для групп/каналов ordinary E2EE не применяется (`ordinary_e2ee.py:84`), но это отдельный случай и в таблице отмечен.

| Свойство | Секретный чат | Обычный личный чат | Файл(ы) |
|---|---|---|---|
| Кто владеет флагом | сервер `chats.is_secret=true` | сервер `chats.is_secret=false` | `models.py:263`, `chat_handler.py:322` |
| Модель ключей | device-bound X25519 + Ed25519, seed в `flutter_secure_storage`, привязка к сессии/устройству | аккаунтный keyring (DH+Ed25519+recovery), хранится в secure storage и восстанавливается кодом | `secret_chat_provider.dart:144-218`; `ordinary_e2ee_service.dart:261-327` |
| Протокол E2EE | Double Ratchet в движке | конверт X25519+HKDF+AES-GCM на аккаунт | `secret_chat_engine.dart:39,844`; `ordinary_e2ee_codec.dart` |
| Что хранит сервер | шифртекст в `messages.e2ee_content` + `secret_events` + `secret_operations` | шифртекст в `messages.e2ee_content` | `server_core/app/services/secret_chat_v2.py:23-48,280-295` |
| Локальное хранилище | Hive `secret_journal_v2_<uid>` + AES-ключ в secure storage; вложения — `SecretAttachmentStore` | Hive `EncryptedHistoryArchive` + `EncryptedMessageCache`; медиа — зашифрованный файл + `e2eeFileKey` | `secret_chat_provider.dart:146-181`; `secret_journal.dart:61-93`; `chat_messages_provider.dart:694,739` |
| Черновики | в журнале движка (`state['draft']`), никогда в `DraftStorage` | `DraftStorage` + live-карта + серверные encrypted drafts | `secret_chat_engine.dart:66-76`; `chat_draft_controller.dart:91-150`; `server_core/app/services/encrypted_drafts.py:22` |
| Уведомления | push без текста: «Encrypted message»; в приложении — «Зашифрованное сообщение» | расшифрованное превью, обычный текст | `notification_delivery.py:73-76`; `secret_chat_v2.py:339-346`; `chat_list_provider.dart:804-807` |
| Превью в списке | всегда заглушка, без иконки типа | расшифрованный текст | `chat_list_screen.dart:1394,1407` |
| Архив/пин/мут/непрочитанное | да, через серверный inbox-state и `remote_id` | да | `chat_list_provider.dart:1165-1170`; `chat_summary_model.dart:136-137` |
| История между устройствами | нет: журнал и ключи на устройстве; на новом устройстве чат скрыт/`keyMismatch` | да: сервер + аккаунтные ключи; recovery-код | `secret_chat_provider.dart:605-657,470-603`; `ordinary_e2ee_service.dart:292-327` |
| Восстановление после потери устройства | невозможно (стирание ключа = потеря истории) | возможно recovery-кодом/сопряжением | `ordinary_e2ee_service.dart:1126-1201` |
| Звонки | есть, из overflow-меню | есть, иконками в шапке | `chat_detail_app_bar.dart:73-78,357-368` |
| Медиа | шифруется на клиенте, ключ внутри ratchet-сообщения, файл в `SecretAttachmentStore` | шифруется на клиенте, ключ в ordinary-конверте | `secret_chat_provider.dart:676-793`; `upload_queue_provider.dart:230-234` |
| Поиск по сообщениям | не находится (сервер ищет только `encrypted_content`, у secret он `NULL`) | тоже не находится (то же условие) | `server_core/app/ws/handlers/chat_handler.py:1636-1643` |
| Экспорт | отсутствует в продукте | отсутствует | grep `exportChat/chatExport` — 0 совпадений |
| Копирование текста | запрещено | разрешено | `message_context_menu_sheet.dart:164-173` |
| Пересылка | запрещена | разрешена | `:191-200` |
| «Избранное»/напоминание | скрыто | есть | `:216-243`; `chat_productivity_provider.dart:111` |
| Отложенные сообщения | скрыто | есть | `chat_detail_screen.dart:1865`; `server_core/app/services/chat_productivity.py:225` |
| Интерактив (опросы и т.п.) | скрыто/запрещено | есть | `chat_detail_screen.dart:1883`; `chat_handler.py:1028` |
| Геопозиция | скрыто | есть | `chat_detail_screen.dart:1855` |
| Запрос файла заново | скрыто | есть | `message_context_menu_sheet.dart:141` |
| Защита от скриншотов | включается | не включается | `chat_detail_screen.dart:354,1515`; `screen_security_service.dart:6-12` |
| Реализация защиты экрана | **только Android** | — | `android/app/src/main/kotlin/com/niosmess/pulse/MainActivity.kt:43-48`; на iOS/desktop/web канал молча глотает ошибку |
| Подпись в шапке | «Секретный чат» + чип защиты | «Ключ изменился» только при смене ключа | `chat_detail_app_bar.dart:262-276,287-292` |

---

## 4. Что сломано или бессмысленно

Формат: подозрение → подтверждено/опровергнуто → доказательство.

### 4.1 «`ordinary_e2ee` и `chat.isSecret`-ветки дублируют друг друга» — **подтверждено частично**

Это не копипаста, а **два независимых E2EE-стека с одинаковой пользовательской целью**. Оба включены для личных чатов:

* ordinary включается сам: `chat_list_provider.dart:179` → `ordinary_e2ee_service.dart:292-300`;
* secret включается флагом `is_secret`.

Серверные проверки взаимоисключающие (`ordinary_e2ee.py:84`), но пользователь видит «шифрование» в обоих случаях. Отдельно: в `chat_messages_provider.dart:2259-2315` и `:2837-2861` остался **легаси-путь secret через `e2eeService` (DR, без `client_message_id`)**. Для реального secret-чата он не работает: экран отправляет через движок (`chat_detail_screen.dart`, `chat_messages_provider.dart:2109-2124`), а сервер требует `client_message_id` (`secret_chat_v2.py:404-408`, `router.py:473-480`). То есть ветка мертва, но выглядит как рабочая.

### 4.2 «Настройки секретных чатов управляют ничем» — **подтверждено частично, причина в смешении двух систем**

Экран называется «Секретные чаты / Сквозное шифрование (E2EE)» (`settings_security_screen.dart:57-60`), но содержит три разных блока:

1. ключ устройства secret-чатов и стирание secret-истории — `e2ee_settings_screen.dart:229-293`;
2. общий блок «как это работает» — `:294-313`;
3. **настройки ordinary E2EE** (тумблер «Шифровать», recovery, сопряжение, отпечатки) — `e2ee_settings_screen.dart:315-317` → `ordinary_e2ee_settings.dart`.

Тумблер `settingsE2eeEncrypt` (`ordinary_e2ee_settings.dart:284-297`) управляет только ordinary-ключами. Если у пользователя все чаты secret, он действительно не влияет ни на что; если все обычные — блок ключа устройства и «стереть секретные чаты» управляют пустотой. Название страницы обещает одно, а внутри два несовместимых набора.

### 4.3 «Переключатель в создании чата не влияет» — **опровергнуто, но есть мёртвый дубль**

В живой шторке создания нет переключателя: есть два равноправных пункта «Написать» и «Секретный чат» (`compose_action_sheet.dart:29-57`), и они реально меняют `is_secret`. Мёртвый код — `chat_creation_surfaces.dart`: `showStartDirectChatDialog` (`:15`), `showStartSecretChatDialog` (`:28`), `showCreateChatMenu` (`:117`), `showCreateChatModal` (`:59`) **не вызываются ниоткуда** (grep по `lib/`). Именно там захардкожен `isSecret: true` (`:46`), который легко принять за «все чаты секретные».

### 4.4 «Секретная группа/канал» — **подтверждено: флаг молча игнорируется**

`handle_create_group` читает `is_secret` (`chat_handler.py:578`), но `Chat(...)` создаётся без него (`:604-613`). Клиент `createChat` вообще не отправляет `is_secret` (`chat_repository.dart:175-210`). Секретных групп не существует, ошибки пользователю нет.

### 4.5 «Сообщения secret не хранятся на сервере» — **опровергнуто**

Текст продукта: `secretChatFeature2 => 'Сообщения не сохраняются на сервере'` (`lib/l10n/app_localizations_ru.dart:4593`; `en:4564`). Факт: secret-сообщение пишется в `messages` (`e2ee_content`) и в `secret_events`, плюс FCM-пуш (`secret_chat_v2.py:280-295,317-346`). На сервере лежит шифртекст и метаданные. Обещание неверно и опасно для доверия.

### 4.6 «Поиск — отличие secret» — **опровергнуто**

Серверный поиск сообщений смотрит только `Message.encrypted_content != None` (`chat_handler.py:1640`). И secret, и ordinary E2EE пишут `e2ee_content`, а `encrypted_content = None`. Ни те, ни другие не находятся. Локального поиска по истории в продукте нет (grep `searchMessages` — только воркер-клиент без UI).

### 4.7 «Защита секретного чата работает» — **опровергнуто на не-Android**

`ScreenSecurityService.setSecureFlag` — MethodChannel (`screen_security_service.dart:6-12`), обработчик есть только в Android `MainActivity.kt:43-48`. На iOS/Windows/macOS/web исключение проглатывается. Secret-чат там не защищён от скриншотов, хотя UI показывает чип защиты.

### 4.8 Редактирование в secret-чате идёт мимо протокола — **подтверждено**

Контекстное меню разрешает edit в secret (нет проверки `isSecret`: `message_context_menu_sheet.dart:261-277`). Дальше `ChatComposerController` → `chat_messages_provider.editMessage` (`:2766`) → легаси-ветка `e2eeService` (`:2837-2861`) → `edit_message` **без** `client_operation_id` (`chat_repository.dart:1136+`). Сервер такой запрос принимает (`chat_handler.py:1388-1399`), но **не пишет `secret_events`**, поэтому собеседник правку не получит: движок читает изменения из `secret_sync`. Правка «есть у меня, нет у него».

---

## 5. Где именно теряется разница

Задумано два типа, и точки ветвления есть. Проблема в том, что после ветвления оба пути сходятся в «шифрованный личный чат с одинаковым UI».

| Точка, где должно быть ветвление | Что происходит на самом деле |
|---|---|
| Выбор при создании (`compose_action_sheet.dart:29-57`) | Ветвление есть и работает, но из 5 пунктов только у secret есть подзаголовок-объяснение. Обычный и секретный выглядят как «ещё один способ начать чат». |
| Сервер (`chat_handler.py:471-538`) | Ветвление есть и честное: две разные строки `chats` с `is_secret` 1/0. |
| Шифрование (`chat_messages_provider.dart:2259` vs `:2317`) | Ветвление есть, но **оба результата шифруют**. В UI нет индикатора, что обычный чат уже E2EE, поэтому «секретный» перестаёт быть особенным. |
| Список чатов (`chat_list_provider.dart:963-1011`) | Secret-строки заменяются локальными, с `id = remote_id`; обычные остаются серверными. Пользователь видит одинаковые строки, разница только в замке и заглушке превью. |
| Профиль (`public_profile_screen.dart:97-114` + `direct_chat_navigator.dart:89-100`) | **Здесь разница теряется сильнее всего:** «Написать» может открыть найденный secret-чат, потому что `knownChatId` проверяется без `isSecret`. Обычный чат не создаётся. |
| Настройки (`e2ee_settings_screen.dart:315-317`) | Два стека свалены на одну страницу с названием «Секретные чаты». Пользователь не может понять, какой тумблер к какому типу чата. |
| Тексты (`app_localizations_ru.dart:4591-4597`) | Обещают «не хранится на сервере» и «E2EE v1» — оба пункта не соответствуют коду (см. 4.5). |

Короткая формула: **разница должна была проявляться в модели угроз (устройство vs аккаунт) и в ограничениях, а проявляется только в иконке замка.** Всё остальное — либо одинаково (шифрование, звонки, архив), либо невидимо (где лежит история), либо неверно описано.

---

## 6. Что чинить (направления, не код)

### Вариант A. «Один продукт — два режима», явно и в UI

Признать оба типа, но сделать разницу видимой и осмысленной:

* переименовать раздел настроек: «Шифрование» (общее) + два подраздела «Личные чаты (восстановимые)» и «Секретные (только это устройство)»;
* в шапке обычного чата показывать реальный статус E2EE (не только при смене ключа), иначе пользователь не понимает, что уже защищён;
* у secret явно писать «история не переносится на другое устройство» и убрать ложное «не хранится на сервере»;
* починить `knownChatId`/`_resolvedChatId`, чтобы «Написать» всегда открывал/создавал обычный чат.

Оценка: средняя трудоёмкость (UI + тексты + один баг), низкий риск для крипто, высокий эффект на восприятие. Это самый дешёвый способ убрать жалобу.

### Вариант B. «Секретный = единственный E2EE», ordinary = транспорт

Оставить один E2EE-стек (secret), а ordinary-чаты перевести в «серверное шифрование + E2EE по желанию», убрав автопровижининг ordinary-ключей. Тогда флаг снова будет означать «шифрование vs обычный чат».

Оценка: высокая трудоёмкость и высокий риск: нужно мигрировать существующие ordinary-чаты, снять `E2E_REQUIRED`, сохранить историю и совместимость со старыми клиентами. Без миграции данных ломает переписку. Не начинать без отдельного плана.

### Вариант C. «Секретный = отдельная песочница», ordinary — основной мессенджер

Оставить оба стека, но развести их по продукту: secret-чаты вынести в отдельный раздел/папку с собственными настройками, а обычный инбокс не смешивать с ними. Убрать смешение в профиле, поиске, пересылке. Дополнительно: закрыть дырки secret-пути (edit мимо `secret_events`, screenshot на не-Android) или честно отключить эти действия.

Оценка: средняя трудоёмкость, средний риск (много UI-точек), но именно это соответствует уже написанному коду: два стора, два списка, два набора ограничений. Хорошо ложится на текущую архитектуру `mergeChats`.

### Приоритет

1. **A** — сразу, потому что жалоба про восприятие, а не про крипто.
2. **C** — как основной продуктовый вектор.
3. **B** — только если решено сокращать поддержку двух E2EE-стеков; иначе не трогать.

Обязательные точечные фиксы независимо от варианта:

* `direct_chat_navigator.dart:89-100` + `public_profile_screen.dart:97-114` — не открывать secret по `knownChatId` из обычного действия;
* `handle_create_group` — либо поддержать `is_secret`, либо вернуть ошибку, а не молча игнорировать;
* edit в secret — либо через движок с `client_operation_id`, либо запретить в UI;
* `ScreenSecurityService` — либо реализовать на iOS/desktop, либо не показывать чип защиты там, где его нет;
* тексты `secretChatFeature1/2` — привести к фактическому поведению.

---

## Приложение: цепочки вызовов

### Создание обычного чата

```
InboxComposeButton.onPressed
  → openComposeActions → ComposeActionId.message → '/new-message'
  → PeoplePickerScreen(mode: direct)
  → navigateToDirectChat(isSecret: false)
      fast path: chatsProvider, chatType=='direct' && !isSecret && username
      slow path: ChatRepository.openDirectChat(isSecret: false, ...)
  → WS open_direct {is_secret:false}
  → chat_handler.handle_open_direct → Chat(is_secret=False)
  → ApiChatSummary(isSecret: false)
```

### Создание секретного чата

```
PublicProfileScreen._handleSecretChatTap
  → navigateToDirectChat(isSecret: true)
  → SecretChatCoordinator.engine.open(peerId, ...)   // локальный ui_id
  → SecretChatEngine._resolve → WS open_direct {is_secret:true, public_key, target_public_key}
  → chat_handler.handle_open_direct → Chat(is_secret=True, user1_public_key, user2_public_key)
  → mergeChats: серверная secret-строка отброшена, строка движка добавлена с isSecret:true
```

### Почему обычный чат тоже шифруется

```
ChatsNotifier.build
  → ordinaryE2eeProvider → OrdinaryE2eeService.open()
      → status: identity == null
      → OrdinaryKeys.create + _register('register')      // ключи аккаунта
  → ChatRepository.listChats(publicKey: secretKey)
  → отправка: ordinary.prepare(chatId)
      → server ordinary_e2ee.required == true (своя identity есть)
      → e2eeContent = ordinary.encrypt(...)
  → server send_message: content пуст, e2ee_content есть → сообщение принято
  → если клиент пришлёт plaintext: E2E_REQUIRED (chat_handler.py:1056-1057)
```

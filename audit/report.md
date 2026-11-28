# Отчёт аудита

Сырых находок: 155. После дедупа и фильтра evidence: 154.

## По severity

| severity | шт |
|---|---|
| high | 19 |
| medium | 101 |
| low | 34 |

## По правилам

| правило | severity | шт |
|---|---|---|
| ARCH-1 | high | 4 |
| ARCH-2 | high | 5 |
| ARCH-3 | high | 5 |
| LAG-1 | high | 10 |
| LAG-2 | high | 8 |
| LAG-5 | high | 7 |
| MESS-1 | high | 12 |
| SEC-3 | high | 1 |
| SEC-4 | high | 2 |
| UI-6 | high | 8 |
| CODE-3 | medium | 3 |
| CODE-5 | medium | 6 |
| LAG-4 | medium | 2 |
| LEAK-4 | medium | 1 |
| LIST-1 | medium | 1 |
| M3E-1 | medium | 3 |
| M3E-2 | medium | 7 |
| M3E-3 | medium | 10 |
| MESS-2 | medium | 12 |
| MESS-3 | medium | 12 |
| MESS-4 | medium | 3 |
| MOTION-1 | medium | 12 |
| MOTION-2 | medium | 7 |
| MOTION-4 | medium | 2 |
| UI-3 | medium | 4 |
| UI-4 | medium | 1 |
| UI-5 | medium | 2 |
| CODE-4 | low | 3 |
| UI-2 | low | 1 |

## Все находки

### ARCH-1 · high · `lib/core/services/app_url_launcher.dart:7`

```dart
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
```

Второй цикл core <-> router: app_url_launcher.dart:7 импортирует router/app_router.dart (только за AppRouter.navigatorKey/incomingRoute), а app_router.dart:63 импортирует core/services/app_url_launcher.dart. Router держит 68 импортов экранов, поэтому core-сервис ссылок оказывается в одном цикле со всем UI-графом; это же ломает любую попытку вынести навигацию из core.

Влияние: Цикл фиксирует навигацию внутри core: тесты сервиса ссылок подтягивают app_router со всеми экранами.

Правка: Отдать AppUrlLauncher колбэк navigate(String route) из router, убрать импорт app_router из core/services.

### ARCH-1 · high · `lib/core/services/push_notification_service.dart:15`

```dart
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
```

Цикл core -> providers -> core: push_notification_service.dart:15 импортирует notification_preferences_provider.dart, тот (строка 4) импортирует providers/auth_provider.dart, а auth_provider.dart:23 импортирует обратно push_notification_service.dart. Из-за этого core-слой нельзя собрать/протестировать без Riverpod-провайдеров авторизации, а любой импорт push-сервиса из UI тянет auth_provider + backend_chat_provider; при добавлении поля в AuthState компилятор валит и push-путь, и наоборот.

Влияние: Хрупкая сборка: любое изменение auth-провайдера пересобирает весь push-слой; невозможно покрыть тестами сервис уведомлений без контейнера провайдеров.

Правка: Вынести чтение настроек в колбэк-параметр configureAccount (prefs-снапшот), убрать импорт провайдеров из core/services.

### ARCH-1 · high · `lib/providers/auth_provider.dart:20`

```dart
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
```

Первая строка — auth_provider.dart:20, вторая — web_socket_provider.dart:7. Это прямой двусторонний цикл: auth_provider создаёт AuthNotifier, который держит сессию и токен, а web_socket_provider читает authProvider, чтобы взять accessToken. Через auth_provider замкнуты ещё четыре ребра: auth_provider:9 <-> secret_chat_provider:25 (логаут должен закрывать секретную сессию), auth_provider:3 <-> call_incoming_provider:2, auth_provider:29 <-> notifications_provider:8, auth_provider:21 <-> repositories/auth_repository.dart:12. Итог: auth_provider — хаб из шести циклов, любая правка контракта AuthState тянет весь граф пересборки, а циклическая инициализация уже обходится защитой `if (_current(epoch))` во всех ветках build(). Направление должно быть одно: token/сессия в отдельном низком модуле, который не знает ни о сокете, ни о секретах.

Влияние: Любое изменение AuthState компилируется во всю полосу providers/repositories; причинно-следственная связь между модулями не восстановима без чтения всего графа.

Правка: Вынести AuthState + token чтение в lib/providers/auth_session_core.dart, auth_provider/web_socket/secret/calls/notifications импортируют только его.

### ARCH-1 · high · `lib/providers/backend_chat_provider.dart:41`

```dart
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
```

Строки из backend_chat_provider.dart:41 и websocket_dispatcher_provider.dart:8. Диспетчеру нужны ChatPushEvent и chatsProvider.notifier (upsertChat/refresh), а чат-провайдеру нужен WebSocketPushDispatcher.registerChat/_ChatListPushSync. Так как backend_chat_provider — 4927-строчный монолит, цикл делает его ещё и узким местом компиляции: любой push-тип (edited/deleted/reaction/read/status/blocked/call) обязан быть объявлен в диспетчере, а обработан — в двух разных notifier'ах этого файла.

Влияние: Маршрутизация пушей размазана по двум файлам, которые нельзя разнести без разрезания цикла; новые типы пушей правятся в двух местах.

Правка: Вынести ChatPushEvent/ChatPushEventKind в lib/models/push/chat_push_event.dart и оставить диспетчер зависящим только от него + callback-интерфейса нотифаера.

### ARCH-2 · high · `lib/repositories/auth_repository.dart:1`

```dart
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
```

Слой данных импортирует слой состояния: все 11 репозиториев берут транспорт и токен из providers (auth_repository:1,12; chat_repository:21; sticker/search/privacy/call/bot/support/post_comments — `providers/web_socket_provider.dart`). Из-за этого замкнут цикл auth_repository -> web_socket_provider -> auth_provider -> auth_repository, а сами репозитории становятся Riverpod-провайдерами (`chatRepositoryProvider`), то есть их нельзя ни протестировать, ни переиспользовать без ProviderContainer. Транспорт (WebSocketClient) и токен — это инфраструктура, а не состояние UI.

Влияние: Репозитории не тестируемы без Riverpod; цикл через auth не даёт разложить граф инициализации при старте.

Правка: Ввести lib/core/network/api_transport.dart (интерфейс + token supplier) и передавать его в конструкторы репозиториев из одного composition root.

### ARCH-2 · high · `lib/screens/chat_detail_screen.dart:74`

```dart
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/repositories/report_repository.dart';
import 'package:pulse_flutter/repositories/ai_repository.dart';
```

Виджеты и экраны ходят в репозитории напрямую, минуя провайдер: 45 импортов `repositories/` в screens/widgets/features, среди них chat_detail_screen (chat/report/ai), media_viewer_screen, chat_members_screen, chat_manage_screen, create_post_screen, support_center_screen, badge_picker_sheet, user_search_picker_sheet. Каждый такой вызов — `ref.read(chatRepositoryProvider).getMembers(...)` прямо из build/onTap, то есть UI сам решает, когда и с какими аргументами идти в сеть. Кэш, инвалидация и ошибки не проходят через провайдеры: например, после inviteUser в chat_members_screen список участников обновляется локальным setState, а не chatMembersProvider.

Влияние: Один и тот же эндпоинт дёргается из двух слоёв, состояние экранов расходится с провайдерами; тестировать экран без сети невозможно.

Правка: Для каждого прямого вызова завести метод в существующем notifier'е (chatMembersProvider, chatManage, support) и удалить импорты repositories из screens/widgets.

### ARCH-3 · high · `lib/providers/backend_chat_provider.dart:4881`

```dart
final postCommentsProvider = AsyncNotifierProvider.autoDispose
    .family<PostCommentsNotifier, List<ApiMessage>, PostCommentsArgs>(
      PostCommentsNotifier.new,
    );

class ChatMembersNotifier extends AsyncNotifier<List<ApiChatMember>> {
```

4927 строк и пять независимых нотифаеров в одном файле: ChatsNotifier (инбокс, read-receipts, mute-upload, push-роутинг), ChatMessagesNotifier (окно истории, архив, кэш, mesh, expiry, E2EE-расшифровка и HELO-хендшейк), PostCommentsNotifier (комментарии ленты с 8-секундным поллингом), ChatMembersNotifier и family-провайдеры. Зоны не связаны: комментарии к посту не имеют отношения к истории чата, а E2EE-хендшейк — к инбоксу. Цена: файл пересобирается целиком на любую правку, а `_decryptE2eeMessages` (2697-2876) и `_send` (3531-3968) живут в том же классе, что и список чатов.

Влияние: Любая правка в истории чата инвалидирует компиляцию инбокса и комментариев; границы ответственности нельзя увидеть по имени файла.

Правка: Разрезать на 5 файлов: inbox_notifier.dart (ChatsNotifier+push), chat_history_notifier.dart (окно/архив/кэш), e2ee_message_opener.dart (2697-2990), message_sender.dart (send/edit/delete/reaction), post_comments_provider.dart + chat_members_provider.dart.

### ARCH-3 · high · `lib/screens/chat_detail_screen.dart:109`

```dart
class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _inputController = CustomEmojiTextController();
  late final ChatScrollCoordinator _scrollCoordinator;
```

Один State на 3276 строк владеет всем сразу: AI-обработкой текста (`_processTextWithAi`:442), E2EE-верификацией (:391), детектом скриншота (:299), автосохранением черновика (:437, :759), тремя путями загрузки (:929, :1064, :1081), стикерами (:1103), правкой (:1284), удалением (:1447), реакциями (:1481), форвардом (:1517), репортом (:1686) и медиа-действиями (:1885). Любая правка любой из этих функций задевает файл, в котором живёт главный экран пользователя, а сценарии нельзя собрать/протестировать по отдельности. Плюс это главный источник конфликтов при параллельной разработке.

Влияние: Стоимость поддержки главного экрана приложения; риск регрессий в отправке сообщений при правке форварда/репорта.

Правка: Вынести композер (ai/reply/draft), медиа-конвейер и меню действий сообщения в отдельные контроллеры под `lib/features/chat/`, оставив экрану только сборку дерева.

### LAG-1 · high · `lib/core/utils/docx_parser.dart:95`

```dart
final RegExp elementRegex = RegExp(r'<w:(p|tbl)[\s>].*?<\/w:\1>', dotAll: true);
    final Iterable<Match> matches = elementRegex.allMatches(xml);
```

Разбор DOCX целиком синхронный: ZipDecoder().decodeBytes (inflate всего архива) + шесть последовательных проходов регулярками с dotAll и ленивым .*? по всему word/document.xml, причём RegExp создаются заново внутри циклов (runRegex на каждый абзац :151, textRegex на каждый run :161, rowRegex/cellRegex на каждую строку таблицы :189,:196). Вызывается из _DocxViewerState._parse после await — то есть прямо в кадре UI-изолята (screens/native_file_viewer_screen.dart:617).

Влияние: Открытие .docx на 50–200 КБ = сотни миллисекунд блокировки кадра: белый экран вместо документа, дрожание всего приложения, а не только вьюера.

Правка: Вынести DocxParser.parseBytes в Isolate.run/compute (результат сериализуем) и поднять RegExp в static final. Кандидат в Rust/изолят: inflate + XML-скан — чистый CPU-bound.

### LAG-1 · high · `lib/models/interactive_message.dart:48`

```dart
final start = text.lastIndexOf(marker);
    if (start < 0) return null;
    try {
      final raw = jsonDecode(text.substring(start + marker.length));
```

InteractiveMessage.parse — это полный повторный разбор полезной нагрузки до 12 КБ: lastIndexOf по всему тексту, два substring (копии), jsonDecode в Map, затем ~10 проверок и RegExp-валидация. Он вызывается дважды на один бабл в одном кадре: в itemBuilder (chat_message_list.dart:744) ради preview и снова в build бабла (message_bubble.dart:1570) ради isDocument — то есть на каждое перестроение строки при скролле это 2×(jsonDecode + валидация) синхронно в UI-изоляте. Дополнительно parse дёргается в chat_detail_screen.dart:1285 и 1977 и в контекстном меню (:264, :359). Результат детерминирован для строки, но нигде не запоминается.

Влияние: Каждый кадр скролла чата с интерактивными сообщениями: 2 разбора JSON на такой бабл; на 300-сообщенном окне с десятком опросов это десятки разборов за кадр.

Правка: Разбирать один раз: перенести разбор в слой данных (ApiMessage.parseInteractive при fromJson/декоде) и хранить готовый InteractiveMessage? рядом с сообщением; в UI оставить чтение геттера. Кандидат в изолят при пакетном декоде истории.

### LAG-1 · high · `lib/widgets/settings/custom_color_picker_sheet.dart:75`

```dart
final scheme = Theme.of(context).colorScheme;
final preview = ColorScheme.fromSeed(
  seedColor: _selected,
  brightness: scheme.brightness,
  dynamicSchemeVariant: DynamicSchemeVariant.expressive,
);
```

Пикер акцента пересобирается на каждый кадр перетаскивания: onPanUpdate → _select() → setState() (строка 215), а build() строит целую палитру ColorScheme.fromSeed с dynamicSchemeVariant.expressive. fromSeed с expressive — самая дорогая ветка генерации схемы (проект держит LRU-кэш на 64 ThemeData именно чтобы не считать её на кадре). Тянем область цвета — получаем fromSeed 60-120 раз в секунду плюс 13 HSV-конверсий, три AnimatedContainer и DeocratedBox-градиенты; кадр не успевает, ползунок отстаёт от пальца. Второй такой же fromSeed стоит в списке пресетов (строка 371) — на каждый элемент на каждый билд.

Влияние: Выбор кастомного акцента в Appearance (web и desktop тоже) — самый лагучий интерактив настроек.

Правка: Считать ColorScheme.fromSeed один раз на изменение _selected через late/кэш (или ThemeCache проекта) и отдавать пресетам готовый onPrimary из уже посчитанной схемы.

### LAG-2 · high · `lib/screens/calls/active_video_call_screen.dart:459`

```dart
final session = ref.watch(callSessionProvider);
```

Экран по-прежнему пересобирается 2-3 раза в секунду, хотя палитра уже закэширована (P0-1 закрыт наполовину). Механизм: WebRtcCallSession зовёт onStateChanged и _stateController.add на каждый тик (_startDurationTimer, webrtc_call_session.dart:562 — раз в секунду; _statsTimer, :229 — раз в 2 с; _sampleQuality тоже), оба канала попадают в CallSessionManager._onSessionData (providers/call_session_provider.dart:301), а тот делает ref.read(callSessionProvider.notifier).notify() -> `state = null; state = cur;` (:63-67). Смена identity провайдера перестраивает каждого watcher-а: весь _buildStage (GridView.count с tiles, все RTCVideoView, _StageBadge), CallControlDock из 10 кнопок и MediaQuery-чтения. То есть layout всего 875-строчного экрана считается 2-3 раза в секунду при неизменной картинке; на Android это видно как ровные просадки кадра в звонке.

Влияние: Постоянные пропуски кадров во время активного звонка; чем больше участников, тем дороже (GridView.count строит все плитки сразу).

Правка: Убрать notify() из _onSessionData и отдавать данные через ValueListenable/select (например, watch(callSessionProvider.select((m) => m?.state))) — экран не должен зависеть от тика длительности.

### LAG-5 · high · `lib/services/ordinary_e2ee/ordinary_e2ee_codec.dart:297`

```dart
!await verify(
          p['body'] as String,
          p['signature'] as String,
          sender['ed'] as String,
        )) {
```

На главном изоляте: 1 Ed25519-verify (297), 1 X25519 shared secret + HKDF (317, `_wrap` 197-218), 2×AES-GCM (315-319, 322) — всё pure-Dart `cryptography`. В pubspec только `cryptography: ^2.9.0`, `cryptography_flutter` нет, `FlutterCryptography` не встречается ни разу (0 в lib/), то есть нативной крипты нет. Вызывается по одному сообщению (`ordinary_e2ee_service.dart:723`) в последовательном цикле страницы/догона, поэтому N сообщений = N×(verify+dh+aes) подряд в кадре. Паттерн выноса в проекте уже есть и работает в других местах: `Isolate.run` в `core/storage/encrypted_message_cache.dart:148-153` и `core/storage/encrypted_history_archive.dart:96,124`, `compute` в `services/blob_hasher.dart:100`, `Isolate.run` в `core/network/web_socket_client.dart:657-683`. В ordinary_e2ee и secret_chat таких вызовов нет ни одного.

Влияние: Открытие чата и догон истории после офлайна залипают: сотни миллисекунд CPU на страницу 80 сообщений, до секунды на окно 300.

### LAG-5 · high · `lib/services/secret_chat/secret_journal.dart:298`

```dart
final encrypted = await _aes.encrypt(
          utf8.encode(jsonEncode(tx)),
          secretKey: key,
          aad: _aad(_sequence),
        );
        await backend.append(base64Encode(encrypted.concatenation()));
```

Один коммит = jsonEncode всей транзакции + AES-GCM + base64 + `box.flush()` (69-72) на КАЖДОЕ событие синка, всё в главном изоляте. Чекпоинт (306-332) сериализует и шифрует снапшот всей истории всех секретных чатов (`jsonEncode(snapshot)`) прямо посреди отправки/приёма. `restore()` (206-240) прогоняет base64+AES+jsonDecode+`secretFreeze` по всей пачке записей синхронно до первого кадра инбокса: он ждётся из `providers/secret_chat_provider.dart:181` внутри `_open`, который ожидает `ChatsNotifier.build()`. В `lib/services/secret_chat/` нет ни одного `Isolate.run`/`compute` (проверено grep по `lib/services`).

Влияние: 100 событий страницы = 100 fsync + 100 AES + 100 jsonEncode в кадре; холодный старт с секретными чатами блокирует список чатов на сотни миллисекунд.

### MESS-1 · high · `lib/widgets/wallpaper/chat_wallpaper_background.dart:11`

```dart
Widget build(BuildContext context) =>
      ColoredBox(color: AppSurfaces.of(context));
```

Обои не рисуются вообще: `chatId` игнорируется, вьюпорт чата получает плоский ColoredBox. При этом наличие кастомных обоев читается в screens/chat_detail_screen.dart:2380-2385 и выключает тональную палитру чата (`nios_chroma.dart:24 if (hasCustomWallpaper) return false;`), т.е. действие пользователя в Wallpaper Studio отнимает expressive-окраску чата и не даёт взамен ничего: настройки imagePath/imageDim/imageBlur (models/chat_wallpaper_config.dart:120-122) сохраняются в SharedPreferences, но их не читает ни один рендерер (в chat_wallpaper_painter.dart 0 вхождений imagePath), а WallpaperPreviewPane вообще не использует переданный `config`. Итог — сломанный сценарий: 6 пресетов, 8 слайдеров и «Применить» не меняют ни пикселя.

Влияние: Пользователь правит фон студии и теряет цветовую схему чата; фича выглядит работающей.

Правка: Либо подключить реальный рендер (WallpaperImageCache.render → RawImage в ChatWallpaperBackground по chatId+config), либо убрать студию, провайдер и флаг hasCustomWallpaper из chat_detail_screen.

### SEC-3 · high · `lib/core/utils/screen_security_service.dart:6`

```dart
static Future<void> setSecureFlag({required bool enabled}) async {
  try {
    await _channel.invokeMethod('setSecureFlag', enabled);
  } catch (e) {
    // Platform not supported or not available
  }
```

Защита от скриншотов реализована только на Android (MainActivity.kt:43-48). На iOS обработчика канала нет вообще: grep по ios/ не находит setSecureFlag, а исключение молча проглатывается. Значит в секретном чате на iOS скриншот и запись экрана работают, хотя настройка обещает обратное. На Windows/macOS/web — так же.

Влияние: Секретные чаты на iOS и десктопе: скриншоты и запись экрана не блокируются

Правка: Реализовать канал на iOS (secure UITextField-трюк) или честно скрыть настройку там, где защиты нет

### SEC-4 · high · `lib/services/ordinary_e2ee/ordinary_e2ee_service.dart:1080`

```dart
final target = data['target_key'] as String,
        request = data['request_id'] as String;
    final packet = await OrdinaryCodec.pair(
      _keys!,
      _recovery!,
      target,
```

Ручное сопряжение принимает произвольную внешнюю строку `niosmess-e2e:...`; из неё проверяется только самозаявленные `v` и `user_id`. `target_key` выбирает получателя, и в него шифруется весь `_keyring` (все эпохи, см. `old:` в codec:344-348) вместе с `_recovery` — кодом, которым открывается серверный backup. Публичный числовой userId виден в профиле и ссылках, поэтому любой может сгенерировать такой код и прислать его в чат: одно нажатие «сопрячь» в настройках (widgets/settings/ordinary_e2ee_settings.dart:565) отдаёт атакующему полный ключевой материал. В отличие от auto-enrollment (строки 831-893) здесь нет ни proof NiosID, ни привязки target-ключа к аккаунту, ни подтверждения, что код выпущен своим устройством. Описание, без патча.

Влияние: Полная компрометация ordinary-E2EE аккаунта и возможности восстановления при социальной инженерии одного действия.

### UI-6 · high · `lib/widgets/chat_creation_surfaces.dart:277`

```dart
title: 'Новый секретный чат',
subtitle: 'Сквозное E2EE-шифрование, без следов на сервере',
```

Экран создания чата — первое, что видит пользователь, и он целиком захардкожен по-русски (269-287: четыре actionTile с title/subtitle). По правилу проекта такие строки берутся только из l10n.

Влияние: Первый экран после онбординга в EN-локали

Правка: Завести ключи в arb для 4 плиток и заменить литералы

### UI-6 · high · `lib/widgets/m3_file_picker_bottom_sheet.dart:767`

```dart
label: const Text('Выбрать фото'),
```

Правило проекта (AGENTS.md, п.10) требует все пользовательские строки через context.l10n.key. Здесь и ещё в 21 месте этого файла строки захардкожены по-русски: английская локаль получит русский UI. Это не данные, а именно подписи кнопок и hintText.

Влияние: Английская локаль (RU/EN заявлены в AGENTS.md), скринридеры, будущие языки

Правка: Вынести строки в lib/l10n/app_*.arb и брать через context.l10n

### ARCH-2 · medium · `lib/core/utils/app_time.dart:2`

```dart
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
```

Слой core/utils (и через него models) тянет вверх provider-слой: models/api/message_model.dart → core/utils/datetime_helpers.dart → core/utils/app_time.dart → providers/ui_settings_provider.dart, а тот импортирует material_ui и flutter_riverpod. При этом сам datetime_helpers.dart:132-135 утверждает, что «must never import package:flutter — dart test runs those models without dart:ui». Цепочка это утверждение нарушает: любая попытка прогнать модели в чистом dart test падает на dart:ui, а модели начинают зависеть от глобальных static-настроек UI.

Влияние: Модели нельзя покрыть юнит-тестами без Flutter-рантайма; часовой пояс/локаль меняются глобально, минуя провайдер, и любой код, читающий модель, зависит от порядка инициализации.

Правка: Вынести AppTimeZoneMode и настройку времени в core (например core/time/app_time_config.dart) без riverpod, а provider пусть пишет в неё; models импортируют только core.

### ARCH-2 · medium · `lib/providers/ota_update_provider.dart:431`

```dart
if (context != null && context.mounted) {
        final bool confirmed = await AppModal.confirm(
          context: context,
```

Провайдер состояния импортирует BuildContext, material_ui и core/modal/app_modal.dart и сам показывает диалоги/шиты (`installUpdate({BuildContext? context})` 397, `_showPermissionDialog` 511). У `ota_update_provider.dart` появляется зависимость от дерева виджетов: таймер проверки обновления может сработать при размонтированном экране и молча завершиться, а тест обновления требует WidgetTester. То же направление у chat_wallpaper_provider (импорт widgets/wallpaper/wallpaper_image_cache.dart) — провайдеры тянут UI-модули.

Влияние: Логика обновления непроверяема без UI; при закрытом экране диалог подтверждения просто не показывается, и апдейт остаётся в состоянии 'ждёт подтверждения'.

Правка: Провайдер публикует state.pendingInstall, а диалог показывает экран/шелл, слушающий этот флаг.

### ARCH-3 · medium · `lib/core/network/ws_media_fetcher.dart:27`

```dart
class WsMediaFetcher {
  static Future<Uint8List> Function(String)? secretLocalLoader;
```

Один статический класс на 950 строк совмещает пять несвязанных зон: транспорт (HTTP POST /api/files/download + WS get_file fallback), два CacheManager (private/playback), собственный RAM-LRU с двумя бюджетами, менеджмент staging-каталогов с проверкой симлинков и purge, и разбор путей/расширений. Плюс глобальные статические лоадеры (secretLocalLoader и др.), которые назначаются снаружи, — то есть поведение зависит от порядка инициализации в services.

Влияние: Любая правка кэша затрагивает сеть и файловую безопасность; тестировать один слой нельзя.

Правка: Разделить на MediaDownloadTransport, MediaDiskCache, MediaMemoryCache, StagingWorkspace.

### ARCH-3 · medium · `lib/core/services/push_notification_service.dart:24`

```dart
class PushNotificationService {
  static const String kVapidKey =
```

722 строки в одном статическом классе: FCM-регистрация и токены, локальные уведомления с каналами, чтение/разбор prefs-настроек, дедуп кликов, ring/ended-call состояние, навигация через AppRouter.navigatorKey.go (767), запуск APK через OpenFile (760) и разрешение экрана уведомлений. Это пять ответственностей с разными жизненными циклами (background isolate vs UI), и все они делят статические поля _accountId/_routingReady/_currentChatId.

Влияние: Гонки между background-хендлером и UI-путём идут через одни статические поля; правка одного сценария ломает другой.

Правка: Разнести на PushRegistrar, LocalNotificationPresenter, NotificationRouter; навигацию — через колбэк.

### ARCH-3 · medium · `lib/providers/secret_chat_provider.dart:861`

```dart
Future<Uint8List> readStream(String uri, Uint8List key) {
    final streams = _streams;
    if (streams == null) throw StateError('Secret streaming unavailable');
    return streams.readBytes(_streamFile(uri, key));
  }
```

Один класс SecretChatCoordinator (1112 строк) совмещает: транспорт и поллинг (`register`, `_runTick`, `_schedulePoll`), журнал и expiry (`_scheduleExpiry`, `_expireLocalMessages`), вложения (`enqueueAttachment`, `enqueueAttachmentFile`, `upload`, `_attachmentJob`), медиа-стриминг (этот `readStream`, `openStreamPlayback`, `exportStream`), слияние чатов (`importChats`/`mergeChats`), lifecycle (`setBackground`, `didChangeAppLifecycleState`) и уничтожение аккаунта (`close({erase})`). Это шесть зон, каждая со своим состоянием и своими таймерами; сбой в одной (например, загрузка вложения) держит `tick` и журнал того же объекта.

Влияние: Нельзя отдельно профилировать поллинг и вложения; изменение формата вложения задевает класс, который держит транспорт секретов.

Правка: Вынести SecretAttachmentCrypto (enqueue/read/upload/stream) и SecretChatPoller (register/tick/expiry) в services/secret_chat/, оставив координатору только importChats/close.

### CODE-3 · medium · `lib/providers/api_provider.dart:9`

```dart
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  const String fromDefine = String.fromEnvironment('API_BASE_URL');
```

Мёртвая параллельная реализация сетевого слоя: `ApiClient` (lib/core/network/api_client.dart, 149 строк, get/post/put/patch/delete/_request/postBytes) не упоминается ни в одном файле lib, кроме собственного объявления и этого провайдера (grep по `ApiClient` — 4 вхождения: файл класса, его конструктор и api_provider). Весь реальный трафик идёт через WebSocketClient, который репозитории берут из webSocket_provider. То есть в проекте два HTTP-клиента, один из которых никто не конструирует, и провайдер, который никто не читает; `String.fromEnvironment('API_BASE_URL')` тоже ни на что не влияет.

Влияние: Читатель делает вывод, что запросы идут через ApiClient с обработкой 401, хотя реальный путь другой; мёртвый код маскирует точку входа в сеть.

Правка: Удалить lib/providers/api_provider.dart и lib/core/network/api_client.dart (или подключить ApiClient как единственный транспорт, если он задуман).

### CODE-3 · medium · `lib/widgets/wallpaper/wallpaper_image_cache.dart:159`

```dart
static Future<ui.Image?> render({
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    required Size size,
    double pixelRatio = 1.0,
```

render/getSyncCachedImage/evictExcept/loadPatternSvg не имеют ни одного вызова вне своего файла (grep по lib/), ChatWallpaperPainter.paintToCanvas вызывается только из мёртвого render. В бандл (включая web-сборку из CI) при этом входят chat_wallpaper_painter.dart 789 строк, material_symbols_data.dart 8563 строки map-литералов, icon_sources_catalog.dart 364 строки, cupertino_icons_data.dart 216 строк — ~270 КБ исходников на фичу, которая не запускается. Дополнительно провайдер вызывает WallpaperImageCache.clear() на каждое изменение (chat_wallpaper_provider.dart:128,141,174,183) — обход и dispose пустых карт на каждое движение слайдера.

Влияние: Вес бандла, время парсинга стартового snapshot на web, ложное впечатление живой фичи; 4 бесполезных clear() на каждую правку конфига.

Правка: Удалить widgets/wallpaper/{wallpaper_image_cache,chat_wallpaper_painter,material_symbols_data,icon_sources_catalog,cupertino_icons_data,curated_wallpaper_catalog,wallpaper_color_resolver}.dart и вызовы clear() из провайдера.

### CODE-5 · medium · `lib/core/storage/niosgram_saved_store.dart:19`

```dart
Future<T> _serial<T>(Future<T> Function() action) {
    final previous = _tails[accountId] ?? Future<void>.value();
    final operation = previous.then((_) async {
```

Один и тот же нетривиальный каркас «очередь на аккаунт + _generations + _tails + двойная проверка _valid» скопирован дословно в NiosgramSavedStore (19-32, 64-75) и NiosgramDraftStore (99-112, 186-209), а его третий вариант — EncryptedHistoryArchive._serialized (71-89). Все три отличаются поведением при ошибке: draft/saved глушат ошибку в _tails, архив удаляет tail только по identical — правки рассинхронизируются.

Влияние: Три копии одного примитива сериализации: исправление гонки при logout нужно вносить трижды.

Правка: Вынести AccountSerialQueue(accountId, generations) в core/storage и использовать во всех трёх сторах.

### CODE-5 · medium · `lib/repositories/chat_repository.dart:609`

```dart
Future<String> _parallelBinaryUpload({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
```

Один и тот же запрос 'залить файл' реализован четырежды в одном классе: `uploadStreamInChunks` (489, параллельные чанки), `_parallelBinaryUpload` (609), `_httpMultipartUpload`/`_httpMultipartUploadOwned` (880/911, multipart через http), `_wsChunkedUpload` (1047, чанки по WS) и поверх них `uploadSecretCiphertext` (828). У каждой ветки свои сигнатуры, свои CancellationToken/BackgroundService.retainWork и своя логика прогресса; выбор ветки зависит от флагов внутри `uploadStreamInChunks`. Правка контракта загрузки (например, ключ идемпотентности localId) должна быть внесена в 5 местах, и любая забытая ветка даёт дубли или потерю файла.

Влияние: Дублирование критичного пути с ретраями и прогрессом: разъехавшиеся ветки дают разные баги загрузки в зависимости от размера/типа медиа.

Правка: Оставить один транспортный примитив uploadChunked(transport, chunks, cancel) и сделать остальные тонкими обёртками, выбирающими только endpoint.

### CODE-5 · medium · `lib/screens/media_viewer_screen.dart:592`

```dart
Future<void> _init() async {
    try {
      final source = await WsMediaFetcher.acquirePlaybackSource(
        filePath: widget.url,
```

В одном файле два почти идентичных инициализатора плеера: `_MediaViewerScreenState._initMedia` (:205-243) и `_InlineVideoPlayerState._init` (:592-621) — оба делают `acquirePlaybackSource` → `VideoPlayerController.networkUrl/file` → `initialize()` → `ChewieController(customControls: M3VideoOverlayControls(...), placeholder: AppLoadingIndicator(size: 32))`. Они уже разошлись: только в первом есть `deviceOrientationsAfterFullScreen`, а условие автоплея разное (`!kIsWeb` против `isActive && !kIsWeb`). Правка поведения видео (например, safe-close источника или новый placeholder) требует помнить о двух местах.

Влияние: Дрейф поведения видео в плейлисте против видео внутри экрана: разная ориентация и автоплей.

Правка: Один хелпер `createChewieFor(MediaSource, {bool autoPlay, bool withOrientations})` на файл и вызов из обоих мест.

### CODE-5 · medium · `lib/services/ordinary_e2ee/ordinary_e2ee_service.dart:317`

```dart
value: jsonEncode({
        'keys': keys.secret(),
        'recovery': OrdinaryCodec.recoveryCode(_recovery!),
        'old': _keyring.values
```

Схема key-bundle `{keys, recovery, old}` собирается литералами в трёх местах: `_save` (317-324), `resetAfterLoss`/pending (1036-1039) и `OrdinaryCodec.pair` (codec:344-348, уходит на другое устройство), а разбирается кастами в `_open` (263-271), auto-pair (880) и `completePairing` (1110). Общей модели нет, поэтому добавление поля (версия, pending-флаг) в одну ветку означает тихую потерю старых эпох при восстановлении с другого устройства — парсер ждёт ровно эти ключи.

Влияние: Дрейф схемы ключевого бандла = невосстановимые старые сообщения после смены эпохи; ошибка проявится только у пользователя с бэкапом.

### LAG-1 · medium · `lib/core/utils/app_time.dart:55`

```dart
try {
        return tz.TZDateTime.from(
          base.toUtc(),
          tz.getLocation(_timeZoneId!.trim()),
        );
```

AppTimeSettings.resolve — геттер-путь, который дергается из ApiMessage.resolvedSentAt (models/api/message_model.dart:164). При ручном часовом поясе каждый вызов делает tz.getLocation(строка) (разбор id + поиск в карте) и создаёт TZDateTime — без кеша Location. resolvedSentAt в свою очередь вызывается 4 раза на строку в chat_message_list.dart (строки 641, 699, 719, 891, 934) и в message_layout_store.dart:36,46. Плюс сама настройка читается из глобальных static-полей (строки 9-12), то есть модель «знает» о UI-настройках.

Влияние: При выбранном вручную поясе — 4-6 tz-локаций на каждую строку списка на каждое перестроение; на 20 видимых строках это ~100 разборов id пояса за кадр.

Правка: Кешировать tz.Location по id при configure(); в ApiMessage хранить resolvedSentAt (или вычислить один раз в fromJson), а не геттером.

### LAG-1 · medium · `lib/core/utils/datetime_helpers.dart:55`

```dart
final locale = (localeCode ?? AppTimeSettings.localeCode)
      .split(RegExp(r"[_-]"))
      .first;
```

formatRelativeTime на каждом вызове компилирует новый RegExp и режет строку локали через split + List, затем делает AppTimeSettings.resolve (toLocal/tz), сравнения дат, DateFormat.format и Intl.plural с загрузкой данных локали. Вызывается из itemBuilder инбокса (chat_list_screen.dart:1186), из post_card.dart:593 и call_log_view.dart:388 — то есть на каждую видимую строку на каждое перестроение, хотя результат зависит только от (дата, локаль, настройка часового пояса).

Влияние: Инбокс из 20 видимых строк при новом сообщении/скролле: 20× (RegExp + split + DateFormat + Intl.plural) в кадре; Intl.plural — самый дорогой из них.

Правка: RegExp и извлечение языка — в static final/const (локаль уже приходит готовой строкой); разбор оставить, но кешировать пару (минута, локаль) → готовая подпись для повторяющихся значений.

### LAG-1 · medium · `lib/core/utils/message_preview_text.dart:36`

```dart
final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  for (final node in document.parseLines(source.split('\n'))) {
```

На каждый вызов строится новый md.Document с полным GitHub-flavored набором инлайн-синтаксисов, source режется split('\n'), дерево обходится рекурсивно, затем RegExp(r'\s+') по результату. Кеш MessagePreviewFormatter есть, но в инбоксе он отключён для секретных чатов (chat_list_screen.dart:1416 `cache: !chat.isSecret`) и обходится для черновика (:1183 `messagePreviewText(draft!)`), а всё это — внутри itemBuilder списка чатов.

Влияние: Секретный чат в инбоксе переразбирает markdown последнего сообщения на каждое перестроение строки при скролле; живой черновик — на каждый кадр набора текста.

Правка: Кешировать по содержимому без исключения для секретных чатов (это проекция уже расшифрованного текста, не шифртекст), и брать кеш для draft.

### LAG-1 · medium · `lib/models/api/custom_emoji_model.dart:4`

```dart
int customEmojiLength(String text) =>
    text.replaceAll(customEmojiPattern, '\uFFFC').characters.length;
```

Функция делает полную копию строки через replaceAll по всему тексту, а затем полную графемную сегментацию .characters — два O(n) прохода с аллокацией. Она стоит в TextInputFormatter на каждом нажатии клавиши (widgets/chat/custom_emoji_text.dart:159, подключён в create_post_screen.dart:870 с лимитом 10000, interactive_composer.dart:289,388,618, chat_productivity.dart:508), а также вызывается прямо в build ради счётчика символов (create_post_screen.dart:935,941).

Влияние: Пост/подпись на 10000 символов: каждое нажатие = копия всей строки + сегментация в графемы, плюс то же самое в build; на 120 Гц ввод начинает отставать от пальца.

Правка: Считать длину без replaceAll: разность (text.length - вхождения шорткодов) с поправкой на графемы только вокруг совпадений, результат кешировать по (text identity/hash). Кандидат в Rust/изолят при пакетной валидации длинных текстов.

### LAG-1 · medium · `lib/models/interactive_message.dart:21`

```dart
String get fingerprint {
    final keys = data.keys.toList()..sort();
    return sha256
        .convert(utf8.encode(jsonEncode({for (final k in keys) k: data[k]})))
```

fingerprint — геттер, который каждый раз сортирует ключи, сериализует весь Map в JSON и считает SHA-256. Он читается в build карточки опроса (widgets/chat/interactive_message_card.dart:98 внутри _stateFor) и дважды в didUpdateWidget (:124) ради сравнения с прошлым значением, плюс в InteractiveState (строка 165) и при отправке голоса (:199). Данные неизменяемы (Map.unmodifiable в parse), значит хеш стабилен и должен считаться один раз при разборе.

Влияние: Голосование/опрос: sha256 + сортировка + jsonEncode на каждое перестроение карточки и на каждый апдейт виджета; на доске с несколькими опросами это лишние хеши в кадре.

Правка: Считать fingerprint в parse() и хранить final-полем InteractiveMessage; геттер оставить как чтение поля.

### LAG-1 · medium · `lib/widgets/contacts/call_log_view.dart:388`

```dart
Text(
                                      '$statusText • ${formatRelativeTime(entry.timestamp)}',
                                      style: textTheme.bodySmall?.copyWith(
```

formatRelativeTime (core/utils/datetime_helpers.dart, регулярки — см. perf 04) вызывается в itemBuilder на каждую строку журнала при каждой пересборке: смена фильтра, обновление callHistoryProvider, любое setState родителя. Плюс в том же build дважды считаются O(n)-срезы: `allEntries.where((e) => e.isMissed).length` в label чипа (:197) и фильтр списка (:157) — на журнале в сотни записей это двойной полный проход на каждый кадр смены фильтра. Для одного и того же entry.timestamp строка пересчитывается заново каждый раз.

Влияние: Регулярки × N строк на каждую пересборку журнала; O(n) сканы дважды за build.

Правка: Считать relative time один раз в модели/провайдере (или мемоизировать по entry.id в Map) и держать missedCount отдельным полем состояния.

### LAG-1 · medium · `lib/widgets/settings/about_changelog_expander.dart:71`

```dart
for (final change in widget.changes) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: change, style: style),
    textDirection: direction,
    textScaler: scaler,
  )..layout(maxWidth: constraints.maxWidth);
```

Заметки о релизе измеряются TextPainter.layout() на каждый элемент на каждый проход layout внутри LayoutBuilder. Это тот же класс дефекта, что перф-аудит отметил в core/modal/app_modal_content.dart:134. Здесь он в новом коде: смена text scale, поворот, ресайз панели и любая пересборка таба «Что нового» заново раскладывает весь список строк (обычно 5-15), чтобы получить одно число fullHeight, которое зависит только от текста и ширины.

Влияние: Вкладка «Что нового» в About на ресайзе окна / смене масштаба текста.

Правка: Считать fullHeight один раз при смене widget.changes/constraints.maxWidth/scaler и кэшировать в State.

### LAG-2 · medium · `lib/features/chats/presentation/inbox_search_results.dart:49`

```dart
final List<ApiChatSummary> allChats =
        ref.watch(chatsProvider).value ?? const <ApiChatSummary>[];
```

ConsumerWidget поиска подписан на весь chatsProvider без select и тут же перебирает все чаты (83-90) плюс строит Map known (77-79) и список rows на каждый build. Любое входящее сообщение или read-подтверждение меняет chatsProvider → весь поисковый sliver перестраивается и заново гоняет O(n) contains по имени/username/описанию каждого чата, пока пользователь печатает запрос. Подписка на список целиком тут не нужна: совпадения считает контроллер.

Влияние: Печать в поиске инбокса нагружает UI-изолятор на каждом входящем сообщении, а не на изменении запроса.

Правка: Перенести фильтрацию chatHits в inboxSearchController (один расчёт на query+снимок чатов), в виджете читать готовые hits через select.

### LAG-2 · medium · `lib/features/sessions/presentation/sessions_screen.dart:185`

```dart
pending:
    ref.watch(sessionsControllerProvider) is SessionsReady &&
    (ref.read(sessionsControllerProvider) as SessionsReady).revokingIds
        .contains(session.id),
```

Каждая строка устройства подписана на весь sessionsControllerProvider и внутри build делает ref.read того же провайдера с приведением типа. Один revoke или terminateOthers (флаг pending меняется на каждом тике) пересобирает все строки списка, а не одну; при этом строка в рантайме полагается на то, что read вернёт ровно то же значение, что и watch — хрупко при любой асинхронной вставке между ними.

Влияние: Список устройств в Security → Devices при отзыве сессии.

Правка: ref.watch(sessionsControllerProvider.select((s) => s is SessionsReady && s.revokingIds.contains(session.id))) и вынести строку в отдельный ConsumerWidget.

### LAG-2 · medium · `lib/features/wallpaper/presentation/wallpaper_studio_screen.dart:67`

```dart
void _updateConfig(ChatWallpaperConfig newConfig) {
    setState(() {
      _draftConfig = newConfig;
    });
  }
```

Каждое событие слайдера (density/cellSize/iconAlpha/imageDim/imageBlur, divisions 9-24) поднимает setState в корень 328-строчного экрана: пересобираются Scaffold, AppBar с MenuAnchor (создаются menuChildren), TabBar, два ChoiceChip, панель bottomActions и TabBarView. На драге слайдера это 60-120 событий в секунду, и ни одно из них не меняет видимый результат: WallpaperPreviewPane игнорирует config, а чат обои не рисует. Чистая работа в кадре на пустом месте.

Влияние: Jank при драге слайдеров в студии; rebuild ~40 виджетов на событие.

Правка: Держать черновик в ValueNotifier<ChatWallpaperConfig> и перестраивать только затронутый таб/подпись значения, а не экран.

### LAG-2 · medium · `lib/screens/contacts_screen.dart:303`

```dart
ref.listen<AsyncValue<List<ApiChatSummary>>>(chatsProvider, (prev, next) {
      final List<ApiChatSummary>? freshChats = next.asData?.value;
      if (freshChats != null) {
        final List<ApiChatSummary> direct = _recentDirectChats(freshChats);
        _cachedDirectContacts = direct;
        ref.read(cacheServiceProvider).saveContacts(direct);
```

`chatsProvider` публикует новый List на каждый пуш нового сообщения/прочтения/presence (ChatsNotifier._applyNewMessagePush -> state = AsyncData(...)), поэтому этот listen в открытом экране контактов срабатывает на каждое сообщение в приложении: фильтр по direct по всем чатам, конвертация в JSON и запись всей коллекции контактов в Hive (`saveContacts` -> `contacts.map((e) => e.toJson())` + `box.put`) прямо в UI-изоляте. При активном канале это несколько записей в секунду, а данные контактов меняются раз в день. Строка 300 того же build дополнительно подписывает весь экран на список инбокса.

Влияние: Дисковый ввод-вывод на каждое входящее сообщение, пока экран контактов открыт; сериализация всех direct-чатов без изменения данных.

Правка: Заменить listen на список id+имени в отдельном provider.select по хэшу direct-строки и писать кэш только при реальном изменении.

### LAG-2 · medium · `lib/screens/public_profile_screen.dart:338`

```dart
final List<ApiChatSummary> chats =
        ref.watch(chatsProvider).value ?? const <ApiChatSummary>[];
```

Экран чужого профиля подписан на весь инбокс, хотя использует только одно: есть ли direct-чат с этим username и онлайн ли он (351: `matchingChat?.isOnline`). Каждое сообщение в любом чате создаёт новый List в chatsProvider, ref.watch отдаёт новое значение, и пересобирается весь CustomScrollView профиля (hero-шапка, бейджи, вкладки), а в build крутится линейный скан всех чатов (341-349). Сидя в профиле при активной переписке, пользователь получает полную пересборку страницы несколько раз в секунду; тот же паттерн в user_search_picker_sheet.dart:121.

Влияние: Полный rebuild тяжёлого экрана + O(N) скан на каждое сообщение в приложении.

Правка: Завести в backend_chat_provider family-провайдер по username, отдающий только (chatId, isOnline), и его watch'ить.

### LAG-2 · medium · `lib/widgets/settings/ordinary_e2ee_settings.dart:581`

```dart
Widget _contactSection() {
  final chats = ref.watch(chatsProvider).value ?? const [];
  final candidates = chats
      .where((c) => c.chatType == 'direct' && !c.isSecret && !c.isBotChat)
      .toList();
```

P1-14 из перф-аудита жив (было 574, стало 581). Подписка на весь chatsProvider без select: любое входящее сообщение, unread или presence-апдейт пересобирает _contactSection вместе с фильтром по всем чатам и пересоздаёт items: DropdownButtonFormField (по элементу на каждый direct-чат). Пользователь, сидящий в E2EE-настройках, платит полный build+layout страницы на каждое событие чатов.

Влияние: Открытые настройки E2EE при активной переписке на другом устройстве.

Правка: Вынести секцию в отдельный ConsumerWidget с ref.watch(chatsProvider.select((v) => v.value?.where(...).map((c) => (c.id, c.name)).toList())) или отдельным directChatOptionsProvider.

### LAG-4 · medium · `lib/widgets/media/m3_video_controls.dart:242`

```dart
child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              curve: M3SpringCurves.expressiveDecel,
              duration: context.reduceMotion
                  ? Duration.zero
                  : M3Durations.short3,
```

Ребёнок AnimatedOpacity — Center → ConstrainedBox → M3VideoPlaybackBar, внутри Slider, 6 IconButton, MenuAnchor и LayoutBuilder; RepaintBoundary внутри нет, поэтому RenderAnimatedOpacity не может применить альфу на композитинге и делает saveLayer + полную перерисовку панели каждый кадр на протяжении M3Durations.short3 при каждом показе/скрытии контролов (тап по видео). Это происходит одновременно с декодом видео — самый дорогой момент экрана. Ровно этот порядок уже исправлен в m3_route_tab_switcher.dart:213-224 (RepaintBoundary внутрь Opacity), здесь — нет.

Влияние: 3-5 лишних растеризаций панели за показ контролов при работающем декодере.

Правка: AnimatedOpacity(child: RepaintBoundary(child: Center(...))) — или заменить на FadeTransition с RepaintBoundary-ребёнком.

### LAG-4 · medium · `lib/widgets/settings/settings_skeleton.dart:103`

```dart
child: AnimatedBuilder(
  animation: _opacity,
  builder: (BuildContext context, Widget? child) => Opacity(
    opacity: _reduceMotion ? 1.0 : _opacity.value,
    child: child,
```

Скелетон настроек (он же «загрузка» для SettingsAsyncSwitcher) пульсирует альфой 0.55→1.0 на общем контроллере, и Opacity стоит над всей колонкой из widget.rows строк (7 строк на Notifications, 5 на Privacy). Ребёнок не RepaintBoundary, поэтому каждый кадр 1200-мс цикла — saveLayer на всю высоту группы и перезапись всех DecoratedBox. Это тот же дефект, что перф-аудит нашёл в pulse_skeleton.dart#m6, только в новом файле: показывается он именно в момент, когда страница и так занята первым layout+запросом.

Влияние: Первый кадр страниц Notifications/Privacy/Storage на слабом Android.

Правка: Opacity(..., child: RepaintBoundary(child: child)) — альфа применится на композитинге кэшированного слоя.

### LAG-5 · medium · `lib/core/storage/chat_media_cache.dart:140`

```dart
final List<ApiMessage> existing = getCachedMediaSync(chatId);
      final Map<int, ApiMessage> byId = <int, ApiMessage>{};
```

getCachedMediaSync синхронно читает Hive и разбирает до 300 Map в ApiMessage (95-105), и saveMediaMessages вызывает его на КАЖДОЕ сохранение снапшота сообщений — то есть при активной переписке полный декод кэша медиа повторяется много раз в секунду, а потом ещё сортируется (159-160). Из виджетов тот же sync-декод вызывается в profile_shared_media_tab_view.dart:108,121 прямо из состояния экрана.

Влияние: Лишние O(300) декодов + sort на каждое обновление сообщений в чате с медиа.

Правка: Держать Map<int,ApiMessage> кэша в памяти рядом с боксом и обновлять инкрементально.

### LAG-5 · medium · `lib/core/storage/encrypted_history_archive.dart:203`

```dart
for (final message in messages) {
      final previous = await _box.get(_identity(message.id));
      if (previous != null && previous != orderKey(message)) {
```

_writeRows вызывается на каждое сохранение окна истории (до 300 сообщений) и делает последовательный await _box.get на каждое сообщение ПЕРЕД единственным putAll: 300 микрозадач + 300 map-конструкций toJson (строка 191-198) на UI-изоляте, плюс N get для remove. В perf-аудите этот путь не разбирался (там только M2 про saveMessages), а это вторая, более частая запись: выход из чата стабильно даёт синхронный блок на 300 итераций.

Влияние: Пропуск кадра при каждом сохранении окна истории; стоимость растёт линейно с размером окна и с числом remove.

Правка: Собирать identity-ключи и отдавать всю пачку в один _box.getAll/_runCompute до putAll.

### LAG-5 · medium · `lib/core/storage/encrypted_message_cache.dart:335`

```dart
return messagesJson.map((e) => ApiMessage.fromJson(e)).toList();
```

Обратная сторона находки P1-20: jsonDecode ушёл в Isolate.run, но разбор 2000 Map в ApiMessage (каждый — десятки полей, вложенные reactions/reply/system_event) остаётся на UI-изоляте. Это путь открытия секретного чата: 2000 моделей на главном потоке — единый блок, которого perf-аудит (M2) не покрывал, он смотрел только сериализацию на запись.

Влияние: Открытие секретного чата с длинной историей теряет кадр; чем длиннее кэш, тем хуже.

Правка: Возвращать из _runCompute уже List<ApiMessage> (модель передаётся через SendPort), а не Map-ы.

### LAG-5 · medium · `lib/services/secret_chat/secret_chat_engine.dart:731`

```dart
for (final event in ordered) {
        await _serial.run(key, () => _receive(key, event));
      }
```

Страница синка до 100 событий (`limit: 100`, строка 711) обрабатывается строго по одному событию: DR-расшифровка (`DoubleRatchetService` → HKDF+AES-GCM), `jsonDecode`, затем коммит журнала (AES+jsonEncode+flush) — всё на UI-изоляте, без батча. Цикл страниц ограничен только счётчиком 50 (706), не временем. Отправка симметрична: `_sendNext` шифрует ратчет и весь body (1313-1331) в главном изоляте, `pump` крутит до 32 сообщений подряд (552-554).

Влияние: Синк после реконнекта и массовая отправка очереди идут сериями блокировок кадра; при 100 событиях — секунды без отрисовки.

### LEAK-4 · medium · `lib/core/services/call_history_service.dart:96`

```dart
List<CallLogEntry> build() {
    _loadFromStorage();
    return const <CallLogEntry>[];
```

build() запускает незаадрешенный Future, который после await SharedPreferences.getInstance() присваивает state (строка 113) и ещё раз читает ref.read(chatsProvider) (119), не проверяя, жив ли нотифаер. Тот же паттерн в FavoriteContactsNotifier.build (favorite_contacts_service.dart:10, state = loaded на 22). Контейнер провайдеров пересоздаётся на logout/смене аккаунта; если диск ответит после dispose, riverpod 3 бросит StateError из оторванного нотифаера.

Влияние: Необработанное исключение при выходе из аккаунта на медленном диске; часть записей истории звонков теряется.

Правка: Хранить Future в поле и проверять ref.mounted (или закрывать через ref.onDispose) перед state =.

### LIST-1 · medium · `lib/features/chats/presentation/people_picker_screen.dart:201`

```dart
return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
```

Список recent-контактов собран нелениво: строка 250 разворачивает `...state.recentCandidates.map((c) => _buildCandidateTile(...))` внутрь ListView(children:) — все строки с PulseAvatar/CachedNetworkImage строятся до первого кадра, независимо от высоты экрана. Для того же PeoplePickerController в create_group_members_screen.dart:241 уже сделан правильный ListView.separated, то есть один источник данных имеет две реализации списка с разной ценой.

Влияние: Открытие «Новое сообщение» на аккаунте с сотнями контактов строит все аватары сразу.

Правка: ListView.builder: быстрые действия отдельными sliver/индексами, дальше recentCandidates[index].

### M3E-1 · medium · `lib/core/theme/app_theme.dart:227`

```dart
iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          iconColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.38)
```

Единственная точка, где M3E-опт-ин реально доступен и уместен, — центральная тема, и она его не включает: `IconButtonThemeData({this.style, this.variant})` (material_ui 1.11.1, lib/src/icon_button_theme.dart:43) принимает `variant: StyleVariant.material3Expressive`, а здесь передан только `style`. В lib/ 128 вызовов `IconButton(` и 0 вхождений `StyleVariant` — значит все 128 иконок (AppBar, композер, шиты, десктопные тулбары) рисуются по старому M3: круглые state-layer вместо M3E-формы и M3E press. Одна строка в теме меняет внешний слой всего приложения; проектный AGENTS.md прямо называет это ожидаемым способом включения M3E.

Влияние: Весь иконочный слой приложения (128 мест) остаётся на M3, хотя M3E заявлен как цель; правка — одна строка в теме, без touching call-sites.

Правка: app_theme.dart:227 — добавить `variant: StyleVariant.material3Expressive` в IconButtonThemeData; при откате на поддеревьях — IconButtonTheme(variantOf).

### M3E-2 · medium · `lib/features/chats/presentation/create_channel_screen.dart:96`

```dart
// Channel Avatar Placeholder (Squircle M3E)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
```

Комментарий обещает «Squircle M3E», а форма — обычный rounded rect (borderRadius: AppRadii.lg ниже): правило 5 требует flutter_m3shapes/сквиркл, и пакет в проекте уже подключён. Канон в приложении другой — empty_state_widget.dart:52-61 рисует ShapeDecoration(shape: AppRadii.lgSuperellipse()). Те же 64x64-заглушки в create_group_details_screen.dart:96 и 40x40 акцент-иконки в compose_action_sheet.dart:81 дают третью и четвёртую форму «аватара» в одном флоу создания чата.

Влияние: Форма заглушки меняется от экрана к экрану, заявленный M3E-сквиркл не рисуется.

Правка: ShapeDecoration(color: scheme.tertiaryContainer, shape: AppRadii.lgSuperellipse()) в трёх местах.

### M3E-2 · medium · `lib/features/chats/presentation/create_group_members_screen.dart:404`

```dart
trailing: AnimatedContainer(
        duration: M3Durations.short4,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
```

Правило 6 проекта (Switch/Checkbox без M3-стиля запрещены) нарушено: чекбокс выбора участника — самодельный 26x26 AnimatedContainer с BoxShape.circle и иконкой check, без Semantics(checked:) и без onChanged, поэтому для скринридера строка остаётся простой кнопкой и выбранность никак не объявляется. Внутри одной фичи создания чата это третий вид «галочки»: список чатов, поиск и здесь.

Влияние: Недоступное состояние выбора при создании группы; расхождение с M3 Checkbox в остальном приложении.

Правка: Checkbox(value:, onChanged:) в trailing + M3SelectionMotion на всю строку.

### M3E-2 · medium · `lib/screens/calls/active_video_call_screen.dart:355`

```dart
style: textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            shadows: const [Shadow(blurRadius: 4)],
```

Правило 7 запрещает Colors.white/Colors.black. В полосе звонков они ещё и работают против тёмной нейтрализованной схемы: Colors.white (:356), Colors.black54 для бейджа реакции (:335), Colors.black под spotlight (:394), Colors.transparent в скриме (:541), плюс call_overlay.dart:266,406 и outgoing_call_screen.dart:357. Ручная тень Shadow(blurRadius: 4) — это ровно та тень, которую правило 3 заменяет тональной поверхностью; на видео она ещё и дешёвая, но не темизируется: в светлой теме приложения подписи на видео остаются белыми литералами вне ColorScheme.

Влияние: Нетематизируемый текст/поверхности на видео, нарушение двух обязательных правил (3 и 7), риск потери контраста при смене accent/темы.

Правка: Заменить литералы на scheme.onSurface/scrim/AppSurfaces-тональности и обернуть подпись в тональный пилл вместо Shadow.

### M3E-2 · medium · `lib/widgets/calls/call_control_dock.dart:215`

```dart
PopupMenuButton<String>(
              tooltip: 'Реакция',
              color: CallTokens.darkSurfaceContainerHigh,
```

Правило 4 проекта прямо запрещает PopupMenuButton («MenuAnchor или свой expressive-шит»). Здесь он ещё и единственный элемент дока, который открывает не M3-поверхность: color задан вручную из токена, пункты — сырые PopupMenuItem с текстом, без тональных поверхностей и без M3E-моушена остальных кнопок; на фоне TouchContainer-кнопок с пружиной (scaleDown/releaseCurve) меню появляется дефолтным Material-путём. Это же место — единственный путь к реакциям в звонке, то есть самый частый интерактив в звонке обходит дизайн-систему.

Влияние: Меню реакций выбивается из M3E-дока и нарушает обязательное правило проекта.

Правка: Заменить на MenuAnchor с CallTokens.darkSurfaceContainerHigh-поверхностью и MenuItemButton, либо на AppModal.showSheet с сеткой эмодзи.

### M3E-2 · medium · `lib/widgets/chat/chat_empty_state.dart:151`

```dart
Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: containerColor,
```

Правило 5 (акцентные иконки/бейджи не плоскими прямоугольниками): иконка сидит в контейнере 58×58 с BorderRadius.circular(18) — обычный rounded rect, без m3shapes/сквиркла. Соседний виджет того же слоя уже использует RoundedSuperellipseBorder (e2ee_status_card.dart:91), то есть в одном чате встречаются две разные формы акцентных плашек. Второй такой же контейнер — 234-240 (52×52, radius 16).

Влияние: Пустое состояние — первый экран нового чата; расхождение форм видно рядом с баблами и E2EE-карточкой.

Правка: ShapeDecoration(shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(18))) либо сквиркл из flutter_m3shapes.

### M3E-2 · medium · `lib/widgets/chat/inline_query_overlay.dart:42`

```dart
return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 4,
      shadowColor: scheme.shadow.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
```

Правило 3 (глубина — тональными поверхностями, а не тенью): оверлей инлайн-запроса получает depth через elevation 4 + shadowColor, хотя вся остальная система в полосе строит depth на surfaceContainer*. Рядом, строкой 47, стоит clipBehavior: Clip.antiAlias на контейнере, внутри которого лежит скроллящийся ListView (169) — это saveLayer на каждую перерисовку оверлея при вводе.

Влияние: Оверлей открыт во время набора текста и пересобирается на каждый ввод: тень + save-слой над полем ввода.

Правка: Убрать elevation/shadowColor и Clip.antiAlias; тональный surfaceContainerHigh + Border, как у остальных панелей.

### M3E-3 · medium · `lib/core/modal/m3_modal_surface.dart:118`

```dart
Widget surface = Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
```

Это единственная поверхность, через которую проходят ВСЕ диалоги и шиты (`AppModal.showDialog/showSheet/showActions` → M3ModalSurface), и она — обычный `RoundedRectangleBorder`, тогда как вся остальная система уже на expressive-сквирклах (`RoundedSuperellipseBorder` — 48 вхождений, dialogTheme/bottomSheetTheme в app_theme.dart:195,212). Плюс радиус берётся из `const AppRadii.xlRadius` (:55-61), а не из `AppRadiiTheme`, поэтому пользовательская настройка `uiCornerRadius` до модалок не доходит вообще. Итог: самый заметный слой (шиты) выглядит иначе, чем тема, и не слушается настройки формы.

Влияние: Каждый диалог/шит в приложении — не-M3E форма и фиксированные 28 dp вместо пользовательского радиуса.

Правка: _resolveBorderRadius() → RoundedSuperellipseBorder из AppRadii.of(context) (lg/xl), shape: `AppRadii.superellipse(radius)`; локальный const-радиус убрать.

### M3E-3 · medium · `lib/core/theme/app_colors.dart:8`

```dart
/// Unified semantic online presence green across all screens.
  static const Color statusOnline = Color(0xFF22C55E);

  /// Unified semantic call decline and destructive red across all screens.
  static const Color statusDanger = Color(0xFFE53935);
```

`statusDanger` — это ровно роль `colorScheme.error`, зашитая литералом: при смене палитры (ColorScheme.fromSeed + palettes/contrast в app_theme.dart:23-28) красный «отклонить звонок» и «удалить» остаётся #E53935 и перестаёт совпадать с `scheme.error` в тех же рядах (где рядом FilledButton с `scheme.error`, m3_modal_surface:36). Пользователь с высоким контрастом или тёмной палитрой получает два разных красных в одном экране. `statusOnline` не проходит проверку контраста ни к одной поверхности из `AppSurfaces.neutralize` (жёсткие #F2F2F2/#1A1A1A).

Влияние: Деструктивные элементы и присутствие не следуют теме; рассинхрон с scheme.error в смежных виджетах.

Правка: statusDanger убрать (брать `Theme.of(context).colorScheme.error`); statusOnline оставить только как seed для tertiary/своего extension с двумя значениями по brightness.

### M3E-3 · medium · `lib/core/theme/app_theme.dart:94`

```dart
outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(settings.uiCornerRadius),
```

Три семейства кнопок получают три разные геометрии: Outlined — `circular(uiCornerRadius)` (по умолчанию 20 dp), FilledButton и TextButton — `AppShape.controlBorder()` = 12 dp (:88, :109), FAB — литерал 16 (:120). Рядом литералы 16/28/8 у snackBar/sheet/tooltip (:188, :213, :299), хотя в файле и импортированы `AppRadii`/`AppShape`/`AppRadiiTheme`, и `AppRadiiTheme.lg` уже несёт пользовательский радиус. Из-за этого в одной строке действий (FilledButton 12 + OutlinedButton 20) два разных сквиркла, а ползунок «скругление» в настройках двигает только часть контролов.

Влияние: Дизайн-система сама не соблюдает свои токены: соседние кнопки разной формы, настройка радиуса применяется частично.

Правка: В themed() заменить literals на AppShape.controlBorder()/AppRadii.superellipse(AppRadiiTheme.fromCornerRadius(...).lg / xl) для всех button/snackbar/sheet/tooltip.

### M3E-3 · medium · `lib/features/settings/presentation/settings_row.dart:70`

```dart
decoration: BoxDecoration(
  color: highlighted
      ? scheme.primaryContainer.withValues(alpha: 0.38)
      : Colors.transparent,
  borderRadius: BorderRadius.circular(16),
),
```

Радиус подсветки строки-якоря задан литералом 16, хотя в проекте есть AppRadii.of(context) (superellipse/адаптивный радиус) и пользовательская настройка формы (settings_appearance_shape_screen меняет uiCornerRadius). Из-за литерала рамка поиска остаётся «круглой 16» при любой выбранной форме — то есть M3E-выразительность формы работает везде, кроме подсветки, которую видит пользователь сразу после поиска по настройкам. Тот же литеральный набор (10/14/18/20/24/28) повторяется в profile_shared_media_tab_view.dart:496,544,590,621, working_hours_widget.dart:44,53,66, my_qr_code_sheet.dart:125, about_memorial_sheet.dart:39,76,107.

Влияние: Настройка «форма/скругления» перестаёт действовать на подсветку строк и на профильные карточки.

Правка: AppRadii.of(context).mdRadius / .superellipse(...) вместо BorderRadius.circular(16) и остальных литералов в перечисленных местах.

### M3E-3 · medium · `lib/screens/calls/active_video_call_screen.dart:813`

```dart
Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
```

_StageBadge — единственное место экрана, где текст берётся из темы приложения, а не из переданных dark textTheme/scheme. Экран принудительно тёмный (CallTokens.darkSurface + AppSurfaces.neutralize(dark)), а Theme.of(context).textTheme.labelSmall в светлой теме приложения даёт тёмный onSurface. Итог: подписи бейджей («1080p · NiosPlus», «VPN · TCP/TLS», эмодзи-верификация, «Рука поднята») рисуются тёмно-серым по scheme.surfaceContainerHigh.withValues(alpha: 0.85) — то есть почти не читаются; при этом рядом _NoVideoPlaceholder корректно получает textTheme параметром.

Влияние: Нечитаемые бейджи состояния звонка (высота видео, VPN-режим, SAS-эмодзи) в светлой теме приложения.

Правка: Передавать в _StageBadge textTheme/scheme.onSurface, как уже сделано для _NoVideoPlaceholder (убрать Theme.of(context) из бейджа).

### M3E-3 · medium · `lib/widgets/chat/bubble/bubble_footer.dart:92`

```dart
formattedTime,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: footerTextColor,
          ),
```

Размеры типографики заданы числами поверх уже взятого из темы стиля: 11 и 10 здесь (81-84, 88, 94, 206), 11 в статус-бейдже message_bubble.dart:727, 11 в бейдже длительности bubble_circle_player.dart:296, 12 в счётчике карусели bubble_carousel.dart:120, 10/11 в оверлее загрузки. Числа не масштабируются textScaler: при системном масштабе 2.0 тело сообщения вырастает, а время, «изменено», замок E2EE и статус доставки остаются 10-11 px — ровно в футере, где пользователь ищет подтверждение отправки, текст перестаёт читаться. Токен AppTypography/labelSmall для этого уже есть и используется в том же файле.

Влияние: Нарушение доступности при крупном системном шрифте и обход типографической шкалы в самом частом элементе UI.

Правка: Убрать fontSize, оставить textTheme.labelSmall (или AppTypography) и один размер на все баблы.

### M3E-3 · medium · `lib/widgets/chat/bubble/bubble_upload_overlay.dart:92`

```dart
color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.88,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
```

В одном бабле шесть радиусов числами при наличии AppRadii (4/8/12/16/28) и AppShape (bubble 20, media 16, control 12): 8 в bubble_circle_player.dart:290,313; 10 здесь (95, 252), в bubble_carousel.dart:114, message_bubble.dart:711 и bubble_header.dart:53; 12 в bubble_upload_overlay.dart:120,145 и по умолчанию в bubble_carousel.dart:17; 20 и 24 в media_album_bubble.dart:129,171; 6 в message_bubble.dart:1229. Итог в одном сообщении-альбоме: карточка 20, плашка поверх 10, бейдж времени 10, кнопка повтора 12 — четыре геометрии, которые не следуют ни шкале, ни пользовательской настройке uiCornerRadius.

Влияние: Форма бабла перестаёт быть системной: при смене uiCornerRadius половина внутренних элементов остаётся прежней.

Правка: Перевести на AppRadii.sm/md/lg и AppShape.media/bubble(.superellipse) во всех семи файлах bubble/.

### M3E-3 · medium · `lib/widgets/chat/chat_detail_fab.dart:40`

```dart
unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
```

Счётчик на FAB собран из голого Badge + литеральный TextStyle(fontSize: 11, bold) и BorderRadius.circular(16) (строка 58) вместо textTheme/AppShape. В проекте уже есть готовый M3AnimatedBadge (lib/widgets/motion/m3_animated_badge.dart), и он используется в инбоксе (chat_list_screen.dart:422) — то есть один и тот же бейдж в двух местах приложения выглядит и анимируется по-разному.

Влияние: Кнопка «вниз» в каждом чате: бейдж мимо токенов типографики и мимо готового блока, метрика плашки не совпадает с инбоксом.

Правка: M3AnimatedBadge(count: unreadCount) вокруг FloatingActionButton.small; shape из темы FAB, без литерала 16.

### MESS-1 · medium · `lib/core/worker/headless_worker_client.dart:11`

```dart
final headlessWorkerClientProvider = Provider<HeadlessWorkerClient>((ref) {
  final client = HeadlessWorkerClient();
  ref.onDispose(() => unawaited(client.dispose()));
```

Весь каталог core/worker (3 файла, ~470 строк: изолят + SqliteWalDurableStore + AES/ChaCha + поиск) не используется нигде в lib/ — grep по HeadlessWorkerClient/headlessWorkerClientProvider/WorkerAction даёт только сами эти файлы и test/unit/headless_worker_test.dart. При этом в dispose() строка 209 ставит _closed = true, а строка 213 вызывает execute(WorkerAction.shutdown), который на строке 83 сразу бросает StateError('HeadlessWorkerClient is closed') — то есть graceful close SQLite не выполняется никогда, изолят просто убивают. Мёртвый код маскирует реальный дефект.

Влияние: 470 строк второго стека шифрования/БД/поиска выглядят как боевой путь; при первом же включении изолят завершается без закрытия SQLite/WAL.

Правка: Удалить core/worker целиком вместе с тестом, либо перенести _closed = true после shutdown-RPC.

### MESS-1 · medium · `lib/router/app_router.dart:247`

```dart
// Временный dev-экран сравнения просмотрщиков изображений.
      GoRoute(
        path: ExtendedImageDemoScreen.routePath,
        pageBuilder: (context, state) =>
            _page(state, const ExtendedImageDemoScreen()),
```

Отладочный экран «сравнение двух просмотрщиков изображений» (543 строки, 15 обращений к `Colors.white`) зарегистрирован в боевом роутере и доступен по `/dev/...` — путь входит в `isPublic` (`:226`), то есть открывается даже без авторизации. Он же единственный в зоне, кто делает `Navigator.push(PageRouteBuilder(...))` (`extended_image_demo_screen.dart:52-53`), обходя `M3SharedAxisPageTransitionsBuilder` из темы. Реальный просмотрщик (`MediaViewerScreen`) при этом один — второй, «сравниваемый», живёт только здесь.

Влияние: Публично доступный отладочный код с собственными цветами и собственной навигацией; лишний вес и путаница «какой просмотрщик настоящий».

Правка: Убрать `GoRoute` и `initialLocation`-ветку `IMAGE_DEMO` из `app_router.dart`, а экран — в `test/` или за `--dart-define` в отдельном entrypoint.

### MESS-1 · medium · `lib/screens/chat_redirect_screen.dart:8`

```dart
class ChatRedirectScreen extends ConsumerStatefulWidget {
  const ChatRedirectScreen({required this.slug, super.key});
```

Три экрана объявлены и не имеют ни одной ссылки: `ChatRedirectScreen` (87 строк), `DirectChatResolverScreen` (`direct_chat_resolver_screen.dart:11`, 67 строк), `CreateChatScreen` (`create_chat_screen.dart:6`, 87 строк). Grep по именам классов во всём `lib/` возвращает только сами объявления — ни роутов, ни `context.go`, ни `Navigator.push`. 241 строка, которую читают как «действующий сценарий»; в `CreateChatScreen` вдобавок лежит запрещённый `BoxShadow` (:55), который легко скопировать в живой код.

Влияние: Читаемость зоны и риск, что новый экран сделают по образцу мёртвого.

Правка: Удалить три файла; маршруты давно живут в `/chat/create` → `/new-message|/new-group/members|/new-channel` и `/u/:slug` → `/profile/:username`.

### MESS-1 · medium · `lib/screens/settings_security_screen.dart:72`

```dart
SettingsRow(
  leading: Icon(Icons.link_rounded, color: scheme.primary),
  title: l.settingsSecretLinkPreviewsTitle,
  control: ToggleControl(
    value: secretChats.linkPreviews,
```

Мёртвые настройки: grep по linkPreviewsInSecretChats / secureScreenshotsInSecretChats по всему lib/ находит только объявление в ui_settings_provider.dart и этот экран. Ни один потребитель не читает флаги: превью ссылок в секретных чатах не гасятся, FLAG_SECURE / защита от скриншотов не включаются нигде (слова FLAG_SECURE в lib/ нет вообще). Пользователь видит включённый по умолчанию тумблер «защита от скриншотов» (secureScreenshotsInSecretChats = true) и считает, что секретный чат защищён, — это ложное обещание безопасности, а не косметика.

Влияние: Доверие к разделу Security; расхождение «тумблер включён — защиты нет».

Правка: Либо подключить флаги к secret-chat рендеру (превью ссылок) и к FLAG_SECURE в main_shell/auth-gate, либо убрать оба ряда до реализации.

### MESS-1 · medium · `lib/services/calls/e2ee_key_manager.dart:5`

```dart
class E2eeKeyManager {
  E2eeKeyManager();

  final Ecdh _ecdh = Ecdh.p256(length: 256);
  final AesGcm _aesGcm = AesGcm.with256bits();
```

Целый мёртвый параллельный стек звонков: e2ee_key_manager.dart (109 строк, ECDH P-256 + AES-GCM + свой SAS), video_pipeline.dart (232, camera+JPEG-кадры), video_output_pipeline.dart (53), ws_transport.dart (94) — 488 строк, у которых ноль ссылок и в lib/, и в test/ (grep по всему репозиторию: только call_transport/quic_transport/binary_packet/nios_calls_api имеют тесты). Реальный E2EE в звонке — DTLS-SRTP + SAS-эмодзи из SDP в webrtc_call_session.dart:584-603, реальный транспорт — WebRtcSignalingClient. Мёртвый E2eeKeyManager опаснее обычного мусора: он выглядит как «настоящее E2EE звонков» и при следующем security-аудите или правке шифрования агент/человек пойдёт по ложному следу (плюс дублирует список SAS-эмодзи, расходящийся с рабочим).

Влияние: Ложная модель безопасности звонков и 488 строк, которые никто не компилирует в сценарий; риск «починить» не тот файл.

Правка: Удалить e2ee_key_manager.dart, video_pipeline.dart, video_output_pipeline.dart, ws_transport.dart (и call_transport/quic_transport/binary_packet/nios_calls_api после переноса их тестов).

### MESS-1 · medium · `lib/widgets/chat/chat_state_surface.dart:7`

```dart
class ChatStateSurface extends StatelessWidget {
  const ChatStateSurface({
```

112-строчный «адаптер» не вызывается ни разу: grep по lib/ даёт 10 совпадений и все — внутри самого файла. При этом ChatStateSurface.secret требует `required List<String> features` (строка 41) и молча его выбрасывает: build передаёт в ChatEmptyState только variant/title/description/icon/actionLabel/onAction (103-110). Второй публичный API одного и того же пустого состояния, с потерянным параметром.

Влияние: 112 мёртвых строк и вторая точка входа для пустых состояний чата; ChatEmptyState напрямую используется в chat_detail_screen.dart:2920/2928/2994.

Правка: Удалить файл целиком; после удаления проверить, что export 'chat_empty_state.dart' никто не импортировал через этот путь.

### MESS-2 · medium · `lib/core/modal/app_date_picker.dart:31`

```dart
datePickerTheme: DatePickerThemeData(
              backgroundColor: scheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.xlRadius,
```

`AppTheme.themed` уже задаёт `datePickerTheme` и `timePickerTheme` (app_theme.dart:324-339) — то есть эти хелперы переписывают то, что тема уже настроила, и переписывают иначе: в теме `RoundedSuperellipseBorder(circular(uiCornerRadius))` без борта, в хелперах `RoundedRectangleBorder(AppRadii.xlRadius)` + `outlineVariant` борт 1 px. Один и тот же пикер получает две разные геометрии в зависимости от того, открыли его через AppDatePicker или напрямую; правка темы не долетает; app_time_picker.dart:29-34 повторяет то же слово в слово.

Влияние: Два источника правды для пикеров; смена формы в теме не работает, а код-дубль надо править в трёх местах.

Правка: Удалить локальный `Theme(copyWith(datePickerTheme/timePickerTheme))` в app_date_picker.dart и app_time_picker.dart — оставить showDatePicker/showTimePicker на теме.

### MESS-2 · medium · `lib/models/api/chat_summary_model.dart:212`

```dart
bool get isBotChat =>
      partnerBadges.any(
        (ApiBadge b) =>
            b.name.toLowerCase().contains('bot') ||
            b.name.toLowerCase().contains('ai') ||
```

В проекте две несовпадающие реализации «это бот»: этот геттер (бейджи: подстрока 'bot'/'ai' + username endsWith('_bot')) и core/utils/bot_detector.dart:2 с комментарием «Unified bot detection logic across NiosMess» (clean == 'bot' || endsWith('bot')). Геттер используют 12+ мест (chat_list_screen.dart:658,662, filters, call_starter, mesh, file_request_action), а bot_detector — только contacts/profile/call_starter через BotDetector.isBot. Один и тот же чат классифицируется по-разному в инбоксе и в контактах, а «единая» функция остаётся мёртвым дублем.

Влияние: Фильтры инбокса и списки контактов могут разойтись в том, кого считать ботом; логика детекта меняется в двух местах; в hot path — toLowerCase() на каждый бейдж на каждый ребилд строки.

Правка: Оставить один предикат (в модели, с учётом бейджей) и заменить BotDetector.isBot вызовом геттера; бейджи нормализовать один раз в fromJson.

### MESS-2 · medium · `lib/screens/calls/active_video_call_screen.dart:100`

```dart
_stateSubscription = session.stateStream.listen((CallSessionData data) {
      if (!mounted) return;
      if (data.state == CallSessionState.connected &&
          lastState != CallSessionState.connected) {
        ref.read(appSoundProvider).playEvent(SoundEvent.callConnected);
      }
```

Блок «подписка на stateStream + звук connected/ended + AppToast по fatalError + _popOrGoHome + обновление _timerNotifier» скопирован в active_voice_call_screen.dart:80-100 почти дословно (video 100-120, voice 80-100), плюс _popOrGoHome продублирован третий раз в active_call_screen.dart:69 и четвёртый в call_overlay.dart:106. Любая правка сценария завершения звонка (например, не показывать тост при minimize, или не попать дважды) требует трёх одинаковых правок, и уже сейчас video и voice расходятся в мелочах (video вызывает _popOrGoHome внутри слушателя до обновления таймера, voice — после).

Влияние: Расхождение поведения видео/голосовых звонков при доработках; риск двойного pop и двойного тоста.

Правка: Вынести слушатель в общий миксин/хелпер (CallLifecycleListener) в lib/services/calls или widgets/calls, по одному вызову из обоих экранов.

### MESS-2 · medium · `lib/screens/calls/active_video_call_screen.dart:184`

```dart
void _snapPip(DragEndDetails details, double screenWidth) {
    final double velocity = details.velocity.pixelsPerSecond.dx;
    const double width = CallTokens.videoPipWidth;
    final bool toStart = velocity.abs() >= _pipMinFlingVelocity
        ? velocity < 0
```

Та же физика «drag + fling + пружина к ближнему краю» реализована второй раз в call_overlay.dart:68-82 (_snapToEdge) с тем же порогом 700 px/s (_minFlingVelocity против _pipMinFlingVelocity) и вторым SingleMotionController + ValueNotifier. Вторая параллельная реализация PiP: _VideoOverlayTile (call_overlay.dart:409-511) и PiP в видеоэкране (:686-753) рисуют один и тот же мини-видеоплеер с разными радиусами (CallTokens.pipBorderRadius против 20/27) и разным поведением кнопок (28 dp GestureDetector против 6-px padding). Правка поведения PiP (safe-area, снап, клампы) нужна в двух местах.

Влияние: Два разных PiP в одном приложении: пользователь видит разный радиус, размер кнопок и разное поведение при перетаскивании.

Правка: Один виджет CallPipTile + один DragSnapper в widgets/calls, использовать и в видеоэкране, и в оверлее.

### MESS-2 · medium · `lib/screens/media_viewer_screen.dart:604`

```dart
_videoController = source.uri != null
          ? VideoPlayerController.networkUrl(source.uri!)
          : VideoPlayerController.file(File(source.filePath!));
      await _videoController!.initialize();
      _chewieController = ChewieController(
```

Один и тот же бутстрап плеера написан трижды: media_viewer_screen.dart:205-243 (_MediaViewerScreenState._initMedia), :592-633 (_InlineVideoPlayerState._init) и native_file_viewer_screen.dart:127-…,1109 (ChewieController). В каждом — свой порядок освобождения (chewie → controller → source.close в unawaited-замыкании), свой `placeholder`, свои allowedScreenSleep. Любой баг «capability-source не закрыт» или «autoPlay на web» правится в трёх местах; каталог lib/widgets/media/ уже существует и содержит общие контролы, но не общий плеер.

Влияние: Расхождение поведения (autoPlay/ориентации/sleep) между чатом и файловым просмотрщиком; тройная цена правки.

Правка: Вынести StatefulWidget (MediaPlaybackView) в lib/widgets/media/: acquirePlaybackSource → VideoPlayerController → ChewieController → единый dispose, параметры isActive/autoPlay/onVisibilityChanged.

### MESS-2 · medium · `lib/screens/settings_appearance_accent_screen.dart:33`

```dart
class _PaletteEntry {
  const _PaletteEntry(this.color, this.getName);
  final Color color;
  final String Function(AppLocalizations l10n) getName;
```

`_PaletteEntry`, список из 8 seed-цветов `_palettes`, `_appearanceThemeProvider` и вся обёртка `DynamicColorBuilder` + `ValueListenableBuilder(CircularThemeSwitcher.revealing)` + `AnimatedTheme` продублированы дословно в `settings_appearance_screen.dart:33-56,89-129` и здесь (:33-56,:80-117). Восемь hex-литералов заданы дважды: добавление палитры или правка правила `customSelected` в одном файле молча рассинхронизирует сетку на «Быстром» экране и селектор на «Акцентном».

Влияние: Рассинхронизация двух экранов настроек темы — пользователь видит на одном экране выбранным не то, что на другом.

Правка: Вынести `_PaletteEntry`/`_palettes`/провайдер темы и обёртку `AnimatedTheme` в общий файл (например `lib/features/settings/presentation/appearance_palette.dart`).

### MESS-2 · medium · `lib/widgets/chat/bubble/bubble_gestures.dart:24`

```dart
class SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _maxDrag = 64;
```

Второй свайп-движок рядом с общим SwipeActionRow (lib/widgets/chat/swipe_action_row.dart, 192 строки, используется для строк инбокса): свой SingleMotionController, своя резина _rubberBand/_inverseRubberBand/_rubberBandSlope (40-62), свой порог 64 px и своя логика хинта. SwipeActionRow уже покрывает ровно этот сценарий через enabled/threshold/onEndTriggered/endBackground/onArmed, включая reduceMotion и springTo по скорости пальца. Разные пороги и разная резина → свайп по строке чата и свайп по сообщению ощущаются по-разному, а любой фикс свайпа нужно делать дважды.

Влияние: Дублирование 144 строк жестовой логики и несогласованная тактильность свайпа в двух местах приложения.

Правка: SwipeToReply = SwipeActionRow(onEndTriggered: onReply, endBackground: круг с Icons.reply_rounded), удалить резину.

### MESS-2 · medium · `lib/widgets/chat/chat_detail_input_area.dart:144`

```dart
width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
```

isBlockedByMe (140-180) и isBlockedByUser (182-226) — два рукописных баннера с одинаковым каркасом: SafeArea → Container(width infinity, margin 16/8, padding 16/12, radius 20, Border.all alpha 0.3) → Row(icon 22, gap 12, текст). Третий вариант того же паттерна уже есть виджетом — SpamBlockBanner (spamblock_banner.dart:42), и он тут же используется строкой 232.

Влияние: Дубли ~80 строк; три разных набора отступов/радиусов у одного и того же «баннера в композере».

Правка: Вынести ChatComposerBanner({tone, icon, title, subtitle, action}) и переиспользовать в обеих ветках; SpamBlockBanner оставить как его контент.

### MESS-2 · medium · `lib/widgets/chat/chat_input_bar.dart:606`

```dart
borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(color: scheme.primary, width: 3),
                            ),
```

Панель «редактирование» (596-655) и панель «ответ» (666-708) — один и тот же блок: Container + margin bottom 6 + padding 12/8 + radius 12 + цветная полоса 3dp слева + Row(icon 16, текст, IconButton close 18). Отличаются тремя литералами (primaryContainer/secondaryContainer, edit/reply, chatEditingMessage/chatReply). Копипаста закрепляет и RTL-баг: `Border(left:)` физический, поэтому в RTL полоса встаёт справа от текста в обеих панелях.

Влияние: ~120 строк копипасты в панели, которая пересобирается на каждый кадр клавиатуры.

Правка: Один приватный _ComposerContextPanel({icon, accent, label, text, onClose}), вызванный дважды; border через BorderDirectional(start:).

### MESS-2 · medium · `lib/widgets/chat/chat_message_list.dart:1189`

```dart
color: isMissed
              ? scheme.errorContainer.withValues(alpha: isDark ? 0.40 : 0.60)
              : (isDark
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.60)
                    : scheme.surfaceContainerHigh.withValues(alpha: 0.80)),
```

_CallEventPill (1184-1228) и _SystemEventPill (1254-1296) — один пилл: Container + margin vertical 6 + padding 14/7-8 + borderRadius 16 + border 0.8 alpha .25 + Row(Icon 16, gap 8, labelMedium w600, gap 8, labelSmall 11 время). Разница только в иконке, цвете и тексте. Оба вручную ветвят `isDark` и подмешивают альфу к тональным токенам (0.60/0.80) вместо того, чтобы взять готовый тон темы.

Влияние: Два одинаковых виджета-пилла на каждой строке системного события; тона пиллов не совпадают с баблами при смене темы.

Правка: Один _EventPill({icon, accent, label, time}); цвет — scheme.surfaceContainerHigh без ручного isDark.

### MESS-2 · medium · `lib/widgets/message_bubble.dart:359`

```dart
child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
```

Reply-превью реализовано дважды в одном build: 274-303 (padding 8/4, фон primary/secondary с alpha 0.12, левая полоса 3) и здесь, для стикера (padding 10/5, фон surfaceContainerHighest с alpha 0.9). Один и тот же ответ на сообщение выглядит двумя разными плашками в зависимости от типа сообщения, и правка стиля ответа делается в двух местах.

Влияние: Визуальная несогласованность ответа на стикер/медиа и удвоенная цена правки.

Правка: Один Widget _replyPreview({required bool dense}) — плотность вместо второго Container.

### MESS-2 · medium · `lib/widgets/message_bubble.dart:746`

```dart
Icon(
                            isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 12,
```

Стикер-бабл рендерит собственный статус доставки (701-757) вместо импортированного рядом MessageBubbleFooter: другой набор иконок (done_rounded вместо check_rounded в bubble_footer.dart:150), другой размер (12 вместо 14), нет AnimatedSwitcher — смена «отправлено → прочитано» происходит скачком, нет Semantics(liveRegion: true) и нет Tooltip. То есть для одного типа сообщения две разные реализации одного элемента, и стикер проигрывает по доступности и анимации.

Влияние: Скринридер не объявляет смену статуса у стикеров; поведение статуса зависит от типа сообщения.

Правка: Внутрь floating-бейджа положить MessageBubbleFooter(isUnframed: true) на scrim-подложке, руками оставить только padding.

### MESS-3 · medium · `lib/core/services/app_url_launcher.dart:228`

```dart
if (path.startsWith('/join/')) {
      final String slug = path.substring(6);
      if (slug.isNotEmpty) {
        return Uri(path: '/join', queryParameters: {'slug': slug}).toString();
```

resolveInternalAppRoute (170-320) — вторая, независимая от go_router таблица маршрутов: /join, /u, /c, /g, /niosgram/post, /stickers, /w, /wallpaper, /chat, /settings, /legal, /call, /main. Любой новый маршрут надо править в двух местах, иначе диплинк молча не откроется; внутри этого же резолвера статический сервис лезет в ProviderScope.containerOf(navigatorKey.currentContext) (строка 177), то есть core знает про DI и виджеты.

Влияние: Дрейф таблицы маршрутов: ссылка из веба перестаёт открывать экран, а ошибка не видна ни в одном тесте.

Правка: Возвращать Uri и отдавать его в go_router (routerDelegate/parseRouteInformation) вместо собственного списка путей.

### MESS-3 · medium · `lib/core/services/push_notification_service.dart:367`

```dart
await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
```

FlutterLocalNotificationsPlugin.initialize вызывается повторно внутри showLocalNotification на КАЖДОЕ уведомление, хотя init() уже сделал это на строке 440 (и создал каналы). В фоновом изоляте _onBackgroundMessage -> showLocalNotification это platform-channel roundtrip + повторная регистрация onDidReceiveNotificationResponse перед каждым показом; при пачке пушей — N инициализаций.

Влияние: Лишний канал-вызов и риск гонки колбэков тапа на каждый пуш; дублирует уже существующую инициализацию.

Правка: Убрать initialize() из showLocalNotification, гарантировать init() один раз (_initialized флаг).

### MESS-3 · medium · `lib/core/services/push_notification_service.dart:594`

```dart
if ((prefs.getBool('ui.notifications') ?? true) &&
          options['calls'] != false) {
```

Один и тот же JSON notification_preferences_$account читается в файле тремя способами: сырой Map здесь (594) и в showIncomingCallNotification (636-639, options['sound']), а в showLocalNotification (330-336) — через NotificationPreferences.fromJson с messagesEnabledFor(chat_kind). Разные интерпретации одного формата дают разное поведение для одного пользователя: выключенные «сообщения» учитываются только в одном пути, а отсутствующий ключ 'calls' трактуется как включённый.

Влияние: Настройки уведомлений работают по-разному в foreground-пути и в фоновом показе — жалобы «мьютил, а звонок пришёл».

Правка: Везде NotificationPreferences.fromJson + один гейт isAllowed(event, prefs).

### MESS-3 · medium · `lib/features/account_deletion/presentation/account_deletion_screen.dart:155`

```dart
AnimatedSize(
  duration: M3Durations.medium2,
  curve: M3SpringCurves.expressiveDecel,
  alignment: Alignment.topCenter,
  child: AnimatedSwitcher(
```

Экран уже держит AsyncValue<AccountDeletionStatus> в руках (строка 139) и сам сводит его к трём формам, но переключает их вручную AnimatedSize+AnimatedSwitcher — то есть переписывает SettingsAsyncSwitcher<T>(value:, data:, loading:, error:) из lib/widgets/settings/settings_async_switcher.dart, который делает ровно это (M3SpringSwitcher + Stack с IgnorePointer/ExcludeFocus для уходящей формы). Результат расходится в деталях: здесь уходящий ребёнок остаётся кликабельным и фокусируемым, в SettingsAsyncSwitcher — нет.

Влияние: Переход loading→pending/форма удаления аккаунта; поведение фокуса у уходящей формы.

Правка: Заменить ручную пару на SettingsAsyncSwitcher<AccountDeletionStatus> с теми же тремя билдерами.

### MESS-3 · medium · `lib/providers/ui_settings_provider.dart:179`

```dart
final bool linkPreviewsInSecretChats;
```

Второй мёртвый тумблер того же экрана: «превью ссылок в секретных чатах» сохраняется, загружается и имеет watcher (ui_settings_provider.dart:751-754), но значение не читает ни один потребитель — grep по lib/ даёт только plumbing и l10n-ключ. Что бы пользователь ни выбрал, поведение не меняется.

Влияние: Экран настроек секретных чатов управляет ничем

Правка: Либо применить настройку в рендере превью ссылок, либо убрать оба тумблера

### MESS-3 · medium · `lib/providers/ui_settings_provider.dart:180`

```dart
final bool secureScreenshotsInSecretChats;
```

Настройка «Screenshot protection in secret chats» сохраняется и загружается, но её значение не читает ни один вызывающий: единственные вызовы ScreenSecurityService.setSecureFlag (chat_detail_screen.dart:293/367/2352/2376) зависят только от isSecret. Тумблер мёртв: выключение ничего не меняет.

Влияние: UI обещает управление, которого нет

Правка: Прокинуть secureScreenshotsInSecretChats в setSecureFlag (и в iOS-реализацию) либо убрать тумблер

### MESS-3 · medium · `lib/services/secret_chat/secret_chat_engine.dart:1160`

```dart
await AesGcm.with256bits().decrypt(
              SecretBox(
                base64Decode(packet['ciphertext'] as String),
                nonce: base64Decode(packet['iv'] as String),
                mac: Mac(base64Decode(packet['tag'] as String)),
```

Формат v1 ({ciphertext, iv, tag} + X25519 shared secret + AES-GCM/256) реализован дважды: здесь (1143-1168, легаси-ветка секретного чата) и в `services/e2ee_service.dart:204-219`, а шифрование — здесь же и в `e2ee_service.dart:168-187`. Это один и тот же конверт, но две независимые реализации с разными путями ошибок: правка одной (например добавление AAD или проверки длины iv) не доедет до второй, а история старых чатов читается обеими.

Влияние: Двойная поддержка одного формата: любая правка безопасности делается в двух местах, расхождение читается как «часть сообщений не расшифровалась».

### MESS-3 · medium · `lib/services/secret_chat/secret_journal.dart:215`

```dart
final box = SecretBox.fromConcatenation(
        packed,
        nonceLength: 12,
        macLength: 16,
      );
```

Байтовый AEAD-конверт `base64(nonce12 | ciphertext | mac16)` реализован дважды: `OrdinaryCodec.seal/open` (codec:100-125 — `[...box.nonce, ...box.cipherText, ...box.mac.bytes]` и обратный `sublist(12, …)`/`b.length - 16`) и здесь (`_aes.encrypt` + `concatenation()` на 303, `fromConcatenation(nonceLength: 12, macLength: 16)` на 215). Дублируются не протоколы, а именно кодек байтового формата и магические 12/16 — два места, где одинаковый формат может разъехаться.

Влияние: Дубли codec'ов: смена раскладки (или добавление версии конверта) требует синхронной правки в двух несвязанных модулях, иначе журнал перестаёт восстанавливаться.

### MESS-3 · medium · `lib/widgets/calls/screen_share_picker_dialog.dart:27`

```dart
return showDialog<ScreenShareChoice>(
    context: context,
    builder: (_) => _ScreenSharePickerDialog(maxScreenHeight: maxScreenHeight),
  );
```

Сырой showDialog + AlertDialog с actions вместо AppModal.showDialog, хотя во всей остальной полосе звонков модалки идут через AppModal (call_devices_dialog.dart:21, voice_effect_picker_sheet.dart:12). Следствие не косметическое: AppModal даёт единый M3-поверхностный стиль, maxWidth и поведение на web/desktop, а этот AlertDialog рисует дефолтную платформенную панель (fixed 640x420 контент) — на маленьком окне Windows/вебе диалог может вылезти за экран, и он единственный в звонках не подчиняется смене темы поверхностей.

Влияние: Пикер шаринга экрана выбивается из дизайн-системы и может не влезть в окно на desktop/web.

Правка: showScreenSharePicker -> AppModal.showDialog<ScreenShareChoice>(context:, maxWidth: 680, builder: ...) с OverflowBar для действий.

### MESS-3 · medium · `lib/widgets/message_bubble.dart:1073`

```dart
} else if (uploadTask?.stage == UploadStage.processing) {
      progressSubtitle = 'Обработка файла...';
    } else if (uploadTask?.stage == UploadStage.sendingMessage) {
      progressSubtitle = 'Отправка сообщения...';
```

Тот же расчёт подписи стадии загрузки целиком повторён в bubble_upload_overlay.dart:39-59, и тексты уже разошлись: 'Обработка...' против 'Обработка файла...', 'Отправка...' против 'Отправка сообщения...'. Плюс в обоих местах строки захардкожены по-русски вместо AppLocalizations, хотя в этом же файле соседние строки берутся из context.l10n (1234, 1104). Один и тот же аплоад показывает разные подписи в зависимости от того, круглая это видеозаметка или обычная картинка.

Влияние: Расхождение копий и невозможность перевести статус загрузки: 6 захардкоженных русских строк в двух файлах.

Правка: Один хелпер uploadStageLabel(stage, metrics, l10n) в bubble_upload_overlay.dart, вызывать из _mediaPreview.

### MESS-3 · medium · `lib/widgets/profile/profile_shared_media_tab_view.dart:537`

```dart
return Padding(
  padding: const EdgeInsets.only(right: 8),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        HapticService.selection();
```

Параллельная реализация уже существующего компонента: в этой же настрой-зоне лежит SettingsChoiceButtons<T> — пill-группа из ChoiceChip с M3SelectionMotion, тональным треком и общим звуком/хаптиком. Здесь тот же паттерн собран вручную (Material+InkWell+AnimatedContainer, haptic прямо в onTap), со своими радиусами 20/10/14 (строки 496, 544, 553) и своим AnimatedSwitcher для контента таба (399-419) вместо M3SpringSwitcher. Итог: два разных вида «выбора одного из N» и две разные физики в одном аккаунте, а правка пружины требует двух файлов.

Влияние: Профиль → «Общие медиа»: табы визуально и тактильно не совпадают с остальными переключателями.

Правка: Заменить _buildPillBar на SettingsChoiceButtons<int> (label с count) и AnimatedSwitcher на M3SpringSwitcher(type: fade).

### MESS-4 · medium · `lib/widgets/message_bubble.dart:63`

```dart
class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    required this.text,
    required this.formattedTime,
    required this.isMine,
```

1625 строк в одном файле. Внутри одного класса: 5 медиа-веток в build (стикер, кружок, эмодзи, картинка, файл), 6 widget-хелперов (_buildStickerContent, _buildCircleVideoContent, _mediaPreview, _buildUnframedMessage, _buildInlineKeyboard, _buildMessageTextAndFooter), 4 места, где собирается футер/статус (498, 518, 1372 и самодельный бейдж 701-757), второй расчёт прогресса загрузки (1068-1097) и два inline reply-превью (274-303, 356-387). Любая правка бабла — правка файла, в котором одновременно живут текст, медиа, аплоад и стикер; профиль пересборки строки списка смотреть негде, потому что всё в одном build.

Влияние: Риск регрессии в самом горячем виджете приложения: правка статуса доставки перезапускает и медиа-ветку, и файловую карточку.

Правка: Разрезать по ветке build: bubble_text.dart, bubble_media.dart, bubble_file_card.dart, bubble_sticker.dart; MessageBubble остаётся арбитром выбора.

### MOTION-1 · medium · `lib/screens/calls/active_video_call_screen.dart:390`

```dart
if (spotlight != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black, child: spotlight),
```

_buildStage возвращает три разные корневые ветки (spotlight при шаринге экрана :390, сетка при 2+ участниках :413, одиночное видео :438), и переключение между ними происходит в одном кадре: когда второй участник включает камеру или кто-то начинает шарить экран, дерево целиком подменяется — сетка 3x3 c childAspectRatio 3/4 мгновенно превращается в spotlight, все плитки пересоздаются и RTCVideoView перепривязываются без кроссфейда. Это ровно тот случай, где нужен готовый M3SpringSwitcher (M3SwitcherType.fade для смены раскладки: сохраняет обе ветки на время перехода и не даёт «прыжка»), который уже есть в lib/widgets/motion/.

Влияние: Резкий скачок раскладки в момент старта шаринга/подключения участника — визуальный «провал» в самом нагруженном моменте звонка.

Правка: Обернуть результат _buildStage в M3SpringSwitcher(type: M3SwitcherType.fade, duration: M3Durations.medium2, child: KeyedSubtree(key: ValueKey(branch), child: stage)).

### MOTION-1 · medium · `lib/screens/calls/outgoing_call_screen.dart:199`

```dart
PulseAvatar(
                      name: displayName,
                      avatarUrl: widget.args.avatarUrl,
                      radius: 64,
```

Это экран состояния ringing/connecting, но единственная анимация на нём — AppLoadingIndicator-спиннер (:300). Аватар статичен, хотя тот же «звоним» в других местах живёт: входящий оверлей пульсирует кольцом (_PulsingCallIcon, incoming_call_overlay.dart:437-450), голосовой экран — CallAudioRipple вокруг аватара (active_voice_call_screen.dart:241-248), а голосовой статус-пилл даже не имеет перехода при смене «Звоним…» -> таймер (ValueListenableBuilder отдаёт разные контейнеры без M3SpringSwitcher). Абонент, который ждёт ответа 10-20 секунд, видит замороженную картинку.

Влияние: Исходящий звонок выглядит «подвисшим» до ответа, в отличие от входящего.

Правка: Обернуть PulseAvatar в существующий CallAudioRipple с AnimationController (isActive: !_errorMessage) — как на голосовом экране; смену статус-пилла провести через M3SpringSwitcher.

### MOTION-1 · medium · `lib/screens/legal_viewer_screen.dart:242`

```dart
title: _searchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
```

Включение поиска — самое резкое изменение состояния на экране: заголовок, три `actions` и всё тело документа меняются одним кадром (`setState(() => _searchActive = true)` :292), без анимации. При этом `AppBar` — это `PreferredSize` фиксированной высоты, поэтому переход дешёвый: пересобираются только title/actions и один `SliverList`-подобный Column. Подходящий готовый блок — `M3SpringSwitcher` из `lib/widgets/motion/m3_spring_switcher.dart` (`type: M3SwitcherType.fadeSlideY`, он же сам гасит анимацию по `MediaQuery.disableAnimations`).

Влияние: Поиск по документу «щёлкает» вместо M3-перехода; экран, который открывают чаще всего из настроек.

Правка: Обернуть `title:` и блок `actions` в `M3SpringSwitcher` с разными `key` для режима поиска; телу дать тот же свитчер вокруг результатов.

### MOTION-1 · medium · `lib/screens/media_viewer_screen.dart:392`

```dart
} else if (item.mediaType == MediaType.video) {
            return _InlineVideoPlayer(
              key: ValueKey('video_${item.heroTag ?? index}'),
              url: item.url,
              e2eeFileKey: key,
```

Каждому элементу плейлиста выдан heroTag (chat_detail_screen.dart:1918), но страница видео не обёрнута в MediaHero — Hero-flight не имеет ни источника, ни цели, поэтому видео открывается жёсткой подменой экрана, тогда как изображение перелетает (:750 `Widget build(BuildContext context) => MediaHero(`). Готовый блок уже есть в моей полосе: widgets/media/media_hero.dart (учёт reduceMotion, flightShuttleBuilder держит миниатюру, пока грузится полноразмер). Цена: один Hero на страницу, перестраивается только на push/pop.

Влияние: Рассинхронизация ощущения: картинки «летят», видео «прыгает»; heroTag для видео — мёртвая проводка.

Правка: Обернуть _InlineVideoPlayer в MediaHero(tag: item.heroTag, child: …) и обернуть видео-превью в пузыре (widgets/chat/video_message_preview.dart) тем же тегом.

### MOTION-1 · medium · `lib/widgets/chat/bubble/bubble_upload_overlay.dart:159`

```dart
] else ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
```

Пять состояний аплоада (queued/processing/uploading/sendingMessage/failed) переключаются if/else-деревом прямо в build: кольцо прогресса, проценты и пара кнопок «Повторить/Отменить» появляются и исчезают мгновенно, без AnimatedSwitcher. Переход uploading→failed — самый заметный момент (медиа не ушло) — это скачок на месте. AnimatedSwitcher там, где он уже нужен, в bubble/ есть: счётчик реакции анимируется (bubble_reaction_chip.dart:96-104, M3Durations.short4), а M3SpringSwitcher лежит в widgets/motion. Цена: перестраивается только оверлей (~10 детей внутри одного RepaintBoundary строки).

Влияние: Смена стадии загрузки читается как баг рендера, а не как ответ приложения.

Правка: Обернуть центральный блок в M3SpringSwitcher / AnimatedSwitcher с ValueKey(stage) и M3Durations.short3.

### MOTION-1 · medium · `lib/widgets/chat/interactive_message_card.dart:737`

```dart
child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: percentage, end: percentage),
                        duration: duration,
```

begin == end == percentage: анимация нулевая по значению, поэтому результат голосования меняется скачком, хотя duration и reduce-motion посчитаны выше (649-651). Второй такой бар в том же файле (849-858) идёт от begin: 0, то есть при любом rebuild заново «вырастает» из нуля. Ни один из двух не анимирует переход старое → новое, при этом это две разные реализации одной полосы результата.

Влияние: После голосования проценты в опросе/списке дёргаются; на медленном устройстве читается как лаг, а не как ответ системы.

Правка: tween: Tween<double>(end: percentage) (begin null — старт от прошлого end) и один общий виджет бара на оба места.

### MOTION-1 · medium · `lib/widgets/common/touch_container.dart:194`

```dart
foregroundDecoration: widget.stateLayer && _isPressed
          ? BoxDecoration(color: stateLayerColor, borderRadius: effectiveRadius)
          : null,
```

У самой используемой pressable-обёртки (29 call-sites в lib/) state layer привязан только к `_isPressed` из onTapDown/onTapUp (:119-150) — нет ни `MouseRegion`, ни `onHover`, ни `FocusableActionDetector`. На Windows и Web (оба — цели сборки) ни одна плитка, чип или карточка на TouchContainer не реагирует на наведение: M3E-отклик появляется только по нажатию. Дёшево: тот же AnimatedContainer уже анимирует decoration на `M3SpringCurves.effectsFast/effectsDefault` (:178-185), достаточно добавить `MouseRegion(onEnter/onExit)` и второй флаг hover в уже существующее условие — одна правка, 29 вызовов получают hover сразу.

Влияние: Нулевой hover-отклик на всём десктопе/вебе при 29 call-sites; самый дешёвый прирост «жизни» интерфейса.

Правка: В _TouchContainerState добавить `_isHovered` через MouseRegion (enabled && _isInteractive) и включить его в foregroundDecoration вместе с _isPressed, альфа 0.08 одинаково.

### MOTION-1 · medium · `lib/widgets/message_bubble.dart:421`

```dart
InkWell(
                borderRadius: bubbleRadius,
                onDoubleTap: onReactionTap != null
                    ? () {
```

Бабл — единственная нажимаемая поверхность чата без M3 press-scale: строки инбокса и строки поиска идут через TouchContainer (inbox_search_results.dart:398-403, scaleDown 0.98, releaseCurve M3SpringCurves.spatialFast), а здесь голый InkWell с ripple. Долгое нажатие — главный жест (открывает панель действий) и не даёт ни сжатия, ни «взятия» бабла: экран отвечает только haptic (434-439), визуально ничего не происходит до появления шита. Готовый блок M3PressScale (widgets/motion/m3_press_scale.dart:10) подключается одним обёртыванием по onHighlightChanged; перестраивается один бабл, не список.

Влияние: Основной жест (long-press → действия) ощущается как рывок; баблы выпадают из общей тактильной системы.

Правка: Обернуть child InkWell в M3PressScale(pressed: _pressed) с onHighlightChanged; второй такой же для медиа-ветки.

### MOTION-2 · medium · `lib/core/illustration/app_illustration.dart:113`

```dart
_fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
```

`_SubtleEntranceIllustration` — рукописная копия готового `M3Entrance` (scaleFrom + fade, one-shot): свой AnimationController в initState (:101-104), scale 0.94→1.0 на `M3SpringCurves.expressiveDecel` (:106-111), альфа на чужой кривой `Curves.easeOut`. Существующий блок умеет ровно это и уже умеет reduce-motion и TickerMode: `M3Entrance(scaleFrom: 0.94)` с `M3SpringCurves.effectsDefault` на альфе (m3_entrance.dart:47-60). Цена дубля: 65 строк, вторая реализация entrance, кривая не из M3-токенов и рассинхрон с остальной системой по длительности (`M3Durations.medium2` вместо `spatialDefault`).

Влияние: Две разные entrance-анимации для одного и того же «появился виджет»; иллюстрации (4 call-site) живут по своим правилам.

Правка: Удалить _SubtleEntranceIllustration целиком; в AppIllustration.build вернуть `M3Entrance(scaleFrom: 0.94, delay: Duration.zero, child: ...)` вместо ветки motionPolicy.

### MOTION-2 · medium · `lib/widgets/chat/chat_input_bar.dart:1326`

```dart
return FadeTransition(
      opacity: anim.drive(CurveTween(curve: M3SpringCurves.effectsDefault)),
      child: ScaleTransition(
        scale: anim.drive(
          Tween<double>(
```

_iconSwapTransition — рукописная копия M3SpringSwitcher(type: M3SwitcherType.scale) из lib/widgets/motion/m3_spring_switcher.dart: там тот же fade на expressiveDecel/Accel и тот же scale 0.6→1.0 (136-150). В файле ещё три таких места: 810-834 (эмодзи↔клавиатура), 1049-1067 (микрофон↔отправить), 1342-1346 (отправить↔галочка). Свой вариант не переключается при смене reduce-motion на лету — M3SpringSwitcher в этом случае отдаёт child без анимации (build, 236-238).

Влияние: 4 копии одного перехода в панели, которую пересобирает каждый кадр клавиатуры.

Правка: Заменить все четыре AnimatedSwitcher/Fade+Scale на M3SpringSwitcher(type: M3SwitcherType.scale, child: ...).

### MOTION-2 · medium · `lib/widgets/settings/ordinary_e2ee_settings.dart:701`

```dart
Widget _reveal(String key, Widget? child) => AnimatedSize(
  duration: context.reduceMotion
      ? Duration.zero
      : M3Durations.medium2,
  curve: M3SpringCurves.expressiveStandard,
```

Раскрытие секций E2EE (recovery-код, отпечаток, QR-код пары, отпечаток собеседника — 4 вызова _reveal) сделано ручным AnimatedSize + KeyedSubtree, хотя для этого ровно есть M3Reveal(revealed:, child:, type: M3RevealType.expandY) с нормализованной пружиной, fade и внутренней проверкой reduce motion. Показательно, что в этой же зоне M3Reveal уже используется в account_security_section.dart:141, background_delivery_section.dart:121, account_deletion_screen.dart:279, sessions_screen.dart:88 — то есть один экран E2EE выбивается из общего поведения (нет fade, только высота).

Влияние: Раскрытие блоков на странице E2EE и на соседних страницах Security/Account ощущается по-разному.

Правка: Заменить _reveal на M3Reveal(revealed: child != null, child: child ?? SizedBox.shrink()).

### MOTION-4 · medium · `lib/core/motion/smooth_text_streamer.dart:10`

```dart
SmoothTextStreamer({
    required this.onUpdate,
    this.onDone,
    this.onError,
    this.initialText = '',
```

Все остальные примитивы движения в проекте спрашивают `context.reduceMotion` (m3_press_scale:30, m3_reveal:130, m3_morphing_icon:109, m3_spring_switcher:234, nios_dismissible:184), а стример текста — нет: конструктор не имеет ни `reduceMotion`, ни `Duration`, и `_advance()` (:140-183) всегда набирает текст по 1-N символов за кадр. Пользователь с «убрать анимацию» получает единственную неотключаемую анимацию в приложении — посимвольную печать ответа AI в поле ввода (chat_detail_screen.dart:464-495). Готовый API для гейта — `context.reduceMotion` / `motionDuration(...)` из M3ReduceMotion (m3_motion.dart:51-56).

Влияние: Нарушение reduced-motion на самом частом анимированном пути (AI-ответ); доступность ломается системно, а не в одном месте.

Правка: Добавить в SmoothTextStreamer поле `reduceMotion`; при true в `_onTickerTick` писать сразу `_target` (или звать `completeStream` без набора) и не создавать Ticker.

### SEC-4 · medium · `lib/services/ordinary_e2ee/ordinary_e2ee_codec.dart:291`

```dart
if (h['v'] != 1 ||
        h['chat'] != chat ||
        h['sender'] != from ||
        h['epoch'] != sender['epoch'] ||
        sender['user_id'] != from ||
```

`h['id']` входит в AAD (`_aad`, строка 193 — `p['id']`), то есть подписан, но при расшифровке не сверяется с `message.id`: проверяются только chat/sender/epoch/reply/edit (291-296). Валидный конверт можно переотдать под другим id — подпись сойдётся, `h['edit']` останется null, и сообщение появится в истории как новое (реплей сервером или тем, кто может писать в очередь доставки). Содержимое подделать нельзя, но привязка «конверт ↔ конкретное сообщение» объявлена в AAD и не проверяется. Описание, без патча.

Влияние: Реплей и дублирование подписанных сообщений ordinary-E2EE под новыми id; сорванная дедупликация и «воскрешение» старых отправок.

### UI-3 · medium · `lib/screens/contacts_screen.dart:652`

```dart
child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
```

В зоне 25 литеральных радиусов и `fontSize` в 5 файлах (`contacts_screen` 8, `chat_detail_screen` 7, `chat_members_screen` 6, `circle_video_recorder_screen` 2, `chat_manage_screen` 2), при том что `AppRadii`/`AppRadiiTheme` уже есть в `expressive_tokens.dart`, а в теме радиус управляется настройкой `settings.uiCornerRadius` (`app_theme.dart:224`). Эти поверхности не читают `AppRadiiTheme`, поэтому пользовательский слайдер «скругление углов» на них не действует — настройка выглядит сломанной: часть карточек перестраивается, часть нет.

Влияние: Настройка формы применяется выборочно; визуальная несогласованность одного экрана с остальным приложением.

Правка: Заменить литералы на `AppRadiiTheme.of(context).lgRadius/mdRadius` (или `AppRadii.lgRadius`, если поверхность не масштабируется).

### UI-3 · medium · `lib/screens/group_profile_screen.dart:182`

```dart
boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
```

Нарушено правило проекта «глубина — тональными поверхностями»: карточка-шапка группы кладёт мягкую тень поверх `Container` с радиусом 24. Тень на каждой пересборке шапки — это saveLayer на скруглённом прямоугольнике; в `native_file_viewer_screen.dart:1409` и `:1494` (обложка аудио и второй блок) то же самое, в `create_chat_screen.dart:55` — `blurRadius: 36`. Глубина при этом не следует `surfaceContainer*`, поэтому в тёмной теме тень невидима, а в светлой даёт грязный ореол.

Влияние: Лишний слой растеризации на шапке профиля канала/группы и на экране аудио; разная глубина в двух темах.

Правка: Убрать `boxShadow`, поднять `surfaceContainerHigh`/добавить `outlineVariant`-обводку, как это сделано в остальных карточках.

### UI-3 · medium · `lib/widgets/contacts/call_log_view.dart:187`

```dart
side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
```

Геометрия задана числами там, где в проекте есть токены: core/theme/expressive_tokens.dart:30-35 даёт AppRadii.xs..fullRadius (и AppRadiiTheme как ThemeExtension). В этой полосе литералы: 12/18 в call_log_view.dart (:60,76,92,113,187,216,312,332), 14/16 в features/wallpaper/presentation/widgets/tabs/* и wallpaper_studio_screen.dart:199,214,272,314, 8/16/18 в app_update_dialog.dart:65,102,144,274, 16 в app_nav_item.dart:308. При смене радиуса в токенах половина карточек/чипов/шитов остаётся на старых числах — радиусы расходятся между соседними экранами.

Влияние: Разъезжающаяся геометрия, дубли чисел, невозможность поменять радиус темы одним изменением.

Правка: Заменить BorderRadius.circular(n) на AppRadiiTheme.of(context).{md,lg,xl}Radius, локальные константы — на токены.

### UI-4 · medium · `lib/screens/calls/outgoing_call_screen.dart:356`

```dart
child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(CallTokens.meetEndButtonHeight / 2),
                  clipBehavior: Clip.antiAlias,
```

Кнопка «отменить звонок» реализована здесь четвёртым способом: Material+InkWell+Container с ручным радиусом и Clip.antiAlias, тогда как в call_control_dock.dart:277 и active_call_screen.dart:303 та же красная стадион-кнопка — TouchContainer с scaleDown 0.94 и M3SpringCurves.spatialFast. Пользователь нажимает одну и ту же кнопку в трёх экранах и получает три разных отклика: у outgoing нет пружинного press-эффекта и тактильной отдачи (enableHaptics), зато есть saveLayer от Clip.antiAlias на всю кнопку. Это самодельная дизайн-система поверх существующего общего виджета.

Влияние: Неконсистентный отклик главного действия звонка + лишний saveLayer в момент нажатия.

Правка: Использовать TouchContainer (как в доке) с CallTokens.meetEndButton* и onTap: _cancelAndPop.

### UI-5 · medium · `lib/widgets/calls/call_overlay.dart:353`

```dart
visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
```

Быстрые действия плавающего оверлея звонка ужаты ниже минимума 48 dp: mute 32x32 (:355), «завершить» 32x32 на голосовом пилле (:361-363) и 28x28 на видео-плитке (:468-470, :486-490), причём последние — голые GestureDetector без tooltip и Semantics(label:). Это самый частый жест в звонке (заглушить/сбросить) и он делается вслепую, без подписи для screen reader; в доке те же действия — 52 dp с tooltip, то есть внутри одного приложения цель попадания различается в 3 раза.

Влияние: Промахи по mute/end в оверлее, недоступность для TalkBack/VoiceOver.

Правка: Поднять цели до 48 dp (или обернуть в TouchContainer с hit-test padding) и добавить Semantics(label:)+Tooltip на все GestureDetector-кнопки оверлея.

### UI-5 · medium · `lib/widgets/chat/spamblock_banner.dart:172`

```dart
minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
```

Кнопка «Оспорить» явно выключает минимальную зону: Size.zero + shrinkWrap дают цель высотой с текст (~20 dp) у правого края баннера поверх поля ввода. Рядом, строкой 174, ещё и RoundedRectangleBorder(radius 8) вместо StadiumBorder, которым живут остальные кнопки полосы.

Влияние: Зона нажатия меньше 48 dp на самом видном месте (композер) — промахи пальцем и нарушение M3/WCAG.

Правка: Убрать minimumSize/tapTargetSize override; TextButton по умолчанию (48 dp) со StadiumBorder.

### UI-6 · medium · `lib/core/utils/app_error_formatter.dart:47`

```dart
title: l10n?.errorNoInternet ?? 'Нет подключения к интернету',
```

Здесь l10n есть, но с русским fallback-литералом. В файле 61 такая строка: если l10n не передан (а вызывающих без него надо проверить), пользователь видит русский текст в EN-сборке. Это не нарушение само по себе, но маскирует пропущенную передачу l10n.

Влияние: Диагностические сообщения пользователю

Правка: Проверить вызывающих: если l10n всегда есть — убрать fallback, иначе завести EN-fallback

### UI-6 · medium · `lib/models/api/chat_summary_model.dart:147`

```dart
if (sec < 3600) {
      final int m = (sec / 60).round();
      return '$m мин.';
    } else if (sec < 86400) {
      final int h = (sec / 3600).round();
      return '$h ч.';
```

Модель сама форматирует интервал автоудаления русскими литералами ('мин.', 'ч.', 'дн.', 'мес.') без AppLocalizations и без учёта localeCode; рядом в fromJson:317 так же захардкожено 'Избранное', а models/live_location.dart:20 — 'Геопозиция'. Потребитель (group_profile_screen.dart:365, chat_detail_screen.dart:2788) вынужден подставлять свой fallback, потому что строка уже русская.

Влияние: Английский/другой язык интерфейса получает русские подписи в настройках чата и в превью «Избранного»; строки нельзя перевести через ARB, они не попадают в l10n-аудит.

Правка: Вернуть из модели числа (autoDeleteSeconds / isSaved), а подпись собирать в UI через AppLocalizations (Intl.plural для единиц).

### UI-6 · medium · `lib/screens/support_center_screen.dart:325`

```dart
title: const Text('Поддержка и Спам-Блок'),
```

Приложение локализовано на ru/en, но 22 пользовательские строки в 8 экранах заданы литералами: `support_center_screen` 7 (`'Чат с @Support'`, `'Мой тикет'`, `'Да'`, `'Отмена'`, `'Закрыть'`), `chat_detail_screen` 4 (диалог копирайта: `'Нарушение авторских прав (copyright)'` и т.д.), `sticker_set_screen` 4 (`'Добавить'`, `'Удалить из набора'`), по одной — `plus_activation_screen`, `legal_viewer_screen:231/908`, `support_ticket_detail_screen`, `active_voice_call_screen`. У англоязычного пользователя эти диалоги и тост останутся на русском, причём `'Да'`/`'Отмена'` — это кнопки разрушающего действия.

Влияние: Английская локаль: русские кнопки подтверждения в диалогах удаления и копирайта.

Правка: Завести ключи в `AppLocalizations` для этих 22 строк и заменить литералы на `context.l10n.*`.

### UI-6 · medium · `lib/widgets/chat/spamblock_banner.dart:78`

```dart
if (widget.until == null) return 'Бессрочно';
    final DateTime local = widget.until!.toLocal();
    final String untilText = DateFormat('dd.MM, HH:mm').format(local);
```

Целый пользовательский баннер собран из русских литералов мимо AppLocalizations: 'Бессрочно', 'Срок истёк', 'До …', 'Нарушение правил платформы', 'Ограничение аккаунта', 'Ограничение на отправку', 'Оспорить' (78-101, 122-179). Так же по полосе: chat_empty_state 250-311, chat_detail_app_bar 338/371/378, live_location_card 43-203, file_request_action 109-112, encrypted_draft_conflict_notice 34-115, auto_delete_bottom_sheet 80-86/198-207/289/347, interactive_message_card 141/814, chat_input_bar 488.

Влияние: ≥9 файлов полосы вне l10n; баннер спам-блока — единственный текст, который пользователь видит вместо поля ввода, и в не-русской локали он остаётся русским.

Правка: Ключи spamBlockForever/spamBlockExpired/spamBlockUntil(...) в AppLocalizations и context.l10n в перечисленных местах.

### UI-6 · medium · `lib/widgets/contacts/online_presence_radar.dart:117`

```dart
title: const Text('Видеозвонок'),
```

Весь блок контактов собран на русских литералах вместо AppLocalizations: 'Недавние диалоги', 'Добавить в избранное', 'Информация о контакте' (online_presence_radar.dart), 'Позвонить', 'Видеозвонок', 'Открыть чат', 'Удалить из журнала', 'Пропущенный • Исходящий • Входящий', 'Очистить историю звонков?' (call_log_view.dart:65,81,97,119,137,262,388). В проекте есть context.l10n (l10n.dart) и остальные экраны им пользуются — значит смена локали или новый язык не переведёт именно эти два виджета, а строки нельзя проверить линтером.

Влияние: Фича остаётся ru-only независимо от локали приложения; дубли строк для перевода.

Правка: Завести ключи в l10n (calls*/contacts*) и заменить литералы на context.l10n.*.

### ARCH-2 · low · `lib/models/settings/settings_node.dart:4`

```dart
import 'package:pulse_flutter/core/localization/secret_chat_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
```

Модель узла дерева настроек для одного enum-типа SettingsSectionId импортирует провайдер навигации, который сам тянет riverpod/Flutter. Тип-справочник лежит в presentation-слое, поэтому модель не может быть использована (и протестирована) без UI-слоя; ветка «models → providers» в графе зависимостей появляется ради одного enum.

Влияние: Модель настроек нельзя переиспользовать в чистом Dart (генерация дерева, тесты, серверная валидация); при переносе экранов навигации придётся править модели.

Правка: Перенести SettingsSectionId в models/settings (или в core), провайдер пусть импортирует его оттуда.

### CODE-3 · low · `lib/providers/call_video_provider.dart:43`

```dart
StreamSubscription<Uint8List> startListeningToVideoFrames(
  WidgetRef ref,
  Stream<Uint8List> frameStream, {
  StreamSubscription<Uint8List>? existingSub,
}) {
```

Файл целиком мёртв: три провайдера (remoteVideoFrameProvider:14, localVideoEnabledProvider:25, localCameraControllerProvider:37) и эта функция не имеют ни одной ссылки вне самого файла — grep по каждому имени даёт только объявления и внутреннее `ref.read(remoteVideoFrameProvider.notifier)`. Живой видеозвонок использует session.isLocalVideoEnabled (active_video_call_screen.dart:706) и setLocalVideoEnabled в call_session_provider:530, то есть второй, работающий механизм. Также без ссылок: isCallScreenVisibleProvider (call_incoming_provider.dart:114), stickerSetByIdProvider (sticker_provider.dart:153), activeChatUploadsProvider (upload_queue_provider.dart:573). Пять мёртвых состояний на 43+ файла провайдеров.

Влияние: Читатель выбирает мёртвый провайдер для новой фичи (PiP-превью) и получает состояние, которое никто не обновляет.

Правка: Удалить lib/providers/call_video_provider.dart и четыре перечисленных провайдера.

### CODE-4 · low · `lib/repositories/chat_repository.dart:24`

```dart
class ChatRepository {
```

1628 строк в одном классе: 40+ методов от listChats/getHistory до uploadChatAvatar/inviteUsers/banUser/promoteUser/downloadMedia/resolveShortLink и пяти реализаций загрузки. В том же каталоге repositories 11 файлов, и только этот превышает 1000 строк; в providers превышают backend_chat_provider.dart (4927) и secret_chat_provider.dart (1112). Один класс держит пять зон: чаты/история, участники и роли, инвайты, медиа/загрузки, комментарии. Для сравнения: call_repository — 123 строки, search_repository — 34.

Влияние: Поиск нужного метода и ревью правок идут по 1628 строкам; любой merge конфликтует в одном файле.

Правка: Разделить на chat_repository (чаты/история), chat_members_repository (участники/роли/инвайты) и media_upload_repository (upload*/downloadMedia).

### CODE-4 · low · `lib/screens/chat_list_screen.dart:1`

```dart
lib/screens/chat_detail_screen.dart: 3276
lib/screens/chat_list_screen.dart: 1719
lib/screens/native_file_viewer_screen.dart: 1568
lib/screens/contacts_screen.dart: 1453
lib/screens/legal_viewer_screen.dart: 1321
```

Восемь файлов зоны перевалили за 1000 строк: кроме перечисленных — `public_profile_screen.dart` 1234, `create_post_screen.dart` 1075, `main_shell_screen.dart` 1007. В сумме 12 653 строки в 8 файлах — 34% всей зоны. Каждый такой файл держит 30-60 приватных виджетов и `_build*`-методов, поэтому любая правка требует чтения всего файла, а `dart analyze`/diff/review по ним нечитаемы.

Влияние: Стоимость любой правки в зоне; конфликты при параллельной работе над одним экраном.

Правка: Резать по границам уже выделенных `_Scope`-виджетов (`_ChatHeaderScope`, `_ChatMessagesScope`, `_ChatComposerScope` — в отдельные файлы).

### CODE-4 · low · `lib/services/secret_chat/secret_chat_engine.dart:22`

```dart
class SecretChatEngine {  // 1402 строки в lib/services/secret_chat/secret_chat_engine.dart
```

1402 строки в одном классе: handshake/ратчет (782-982), транспортный цикл и ретраи (533-583, 1253-1375), проекции сообщений (312-423), импорт легаси (195-269), удаление/архив сессий (588-621, 984-991). Правка любой из зон требует держать в голове сериализацию `_serial` и порядок коммитов журнала, из-за чего цена ревью и риск регрессии растут непропорционально.

Влияние: Читаемость и риск регрессии в самом чувствительном модуле (ключи, ратчет, потеря сообщений).

### CODE-5 · low · `lib/models/api/message_model.dart:8`

```dart
bool _parseBool(dynamic value) {
  return value == true ||
      value == 1 ||
      value == '1' ||
      value == 'true';
}
```

Один и тот же парсер булевых значений из JSON скопирован дословно в четырёх моделях: message_model.dart:8, chat_summary_model.dart:5 (в одну строку), chat_member_model.dart:4, sticker_model.dart:5. Все четыре — приватные копии, поэтому разойтись они могут незаметно: например, добавив поддержку 'yes'/'on' в одной, вы получите три модели, которые по-прежнему возвращают false.

Влияние: Разбор флагов (is_e2ee, is_read, is_deleted) ведёт себя по-разному в зависимости от модели; исправление требует правки в 4 файлах.

Правка: Завести один jsonBool(dynamic) в models/api (или core/utils/json.dart) и заменить четыре копии.

### CODE-5 · low · `lib/repositories/chat_repository.dart:1281`

```dart
Future<List<ApiMessage>> getComments(
    int channelId,
    int postId, {
    int page = 1,
    int pageSize = 50,
```

Комментарии к посту реализованы дважды: здесь (`getComments` 1281, `sendComment` 1225) и в repositories/post_comments_repository.dart (`page`, `request`), причём второй — единственный используемый (post_comments_screen.dart:34, backend_chat_provider.dart:4595). Методы этого файла не вызываются ниоткуда: grep по `.getComments(`/`.sendComment(` вне объявления даёт 0. Это не только мёртвый код — две реализации одного запроса с разными page/pageSize, так что при починке пагинации комментариев легко починить не ту.

Влияние: Мёртвый дубль сетевого контракта рядом с живым; путает, какая пагинация настоящая.

Правка: Удалить getComments/sendComment из ChatRepository, оставив комментарии только в PostCommentsRepository.

### LAG-2 · low · `lib/widgets/nav/shell_window_title.dart:102`

```dart
if (!_browser) {
      // Like Title below, the name is handed to the platform while building.
      // The service drops a title that is already shown.
      DesktopWindowService.instance.setTitle(title);
```

Побочный эффект в build(): на каждую пересборку обёртки (а это корень шелла, зависящий от clientCapabilitiesProvider и desktopSelectedSettingsSectionProvider) вызывается platform-channel setTitle, а перед этим `SettingsRegistry.getAllNodes().whereType<SettingsNavNode>().where(...)` — полный обход реестра настроек и построение строки заголовка. Плюс `_themeColor` мутируется прямо в build (:106). Заголовок меняется только при смене секции/таба, т.е. почти всё это — работа впустую в горячем корне дерева.

Влияние: Лишние аллокации и platform-вызов на каждом rebuild шелла; скрытая мутация состояния в build.

Правка: Считать title в didChangeDependencies/слушателе провайдера и отправлять в платформу оттуда; реестр индексировать по sectionId один раз.

### LAG-5 · low · `lib/core/notifications/notification_history_store.dart:71`

```dart
final values = jsonDecode(raw) as List;
    return values
        .map(
          (raw) => NotificationEvent.fromJson(
            jsonDecode(raw as String) as Map<String, dynamic>,
```

restore() вызывается на старте (провайдер истории уведомлений) и разбирает историю дважды: внешний jsonDecode списка + до 100 вложенных jsonDecode строк (следствие двойного jsonEncode из perf m8). Каждый NotificationEvent.fromJson копирует всю map через {...json}. На холодном старте это лишняя работа до первого кадра.

Влияние: Двойной парсинг 100 событий на UI-изоляте при старте, поверх уже отмеченного m8.

Правка: Хранить List<Map> (как cache_service), читать один jsonDecode и убрать внутренний.

### M3E-1 · low · `lib/widgets/calls/call_control_dock.dart:68`

```dart
IconButton.filledTonal(tooltip: context.l10n.callDevicesTitle,
              onPressed: () => showCallDevicesDialog(context, video: isVideoCall, onApply: session.setDevices),
              icon: const Icon(Icons.tune_rounded)),
```

M3E-опт-ин в material_ui 1.11.1 существует у IconButton (IconButtonTheme.variantOf / StyleVariant.material3Expressive), и в проекте он не включён ни разу. Здесь это особенно заметно: единственная stock-IconButton дока стоит в одном Wrap с самодельными _CallDockButton 52x52 (CallTokens.buttonBorderRadius, scaleDown 0.92, M3SpringCurves.spatialFast) и отличается от них размером, формой и тактильным откликом — при том что это та же по важности кнопка «устройства».

Влияние: Одна кнопка из десяти в доке ведёт себя и выглядит иначе; M3E-возможность SDK не используется.

Правка: Навесить IconButtonTheme.variantOf(StyleVariant.material3Expressive) на поддерево дока либо заменить IconButton.filledTonal на _CallDockButton.

### M3E-1 · low · `lib/widgets/chat/chat_list_header.dart:126`

```dart
IconButton(
              key: const ValueKey<String>('inbox-search-open'),
              tooltip: l10n.chatListSearchMessagesHint,
              onPressed: () => ref.read(inboxSearchProvider.notifier).open(),
              iconSize: 24,
```

StyleVariant.material3Expressive в проекте не включён ни разу (0 вхождений), а у IconButton опт-ин возможен только через IconButtonThemeData(variant: ...) — проверено по исходникам material_ui 1.11.1 (icon_button.dart:199-202). Значит все 30+ IconButton полосы (chat_list_header 126/139/226/367/424, chat_detail_app_bar 101/294/299/319, custom_emoji_picker 39/332, expression_picker_panel 170/176/185/516, chat_input_bar 646/699) рендерятся обычным M3, без expressive-формы и размера.

Влияние: Иконки-кнопки инбокса и шапки чата — самая частая точка нажатия в приложении; expressive-вариант доступен без нового кода.

Правка: Обернуть рельс/шапку в IconButtonTheme(data: IconButtonThemeData(variant: StyleVariant.material3Expressive), child: ...); системно — в AppTheme.themed.

### M3E-2 · low · `lib/widgets/chat/chat_filter_bar.dart:598`

```dart
decoration: BoxDecoration(
        color: alert ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
```

Счётчик непрочитанных в пилюле папки — плоский Container с BorderRadius.circular(10), то есть прямоугольная плашка внутри stadium-рельса; правило 5 требует сквиркл/m3shapes для бейджей. Плюс тон бейджа не зависит от `selected`: на выбранной пилюле (secondaryContainer) он остаётся surfaceContainerHighest и читается как отдельная серая клякса.

Влияние: Бейдж есть на каждой папке и перерисовывается при каждом обновлении счётчиков.

Правка: StadiumBorder или сквиркл + тон, производный от selected; смену числа отдать M3AnimatedBadge.

### M3E-3 · low · `lib/core/theme/markdown_theme.dart:56`

```dart
blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(3),
      border: Border(
        left: BorderSide(color: scheme.primary, width: 3),
```

Импорт уже мигрирован на material_ui (единственный theme-файл, который PROJECT-CONTEXT держал под подозрением, — здесь чисто: вхождения `package:flutter/material.dart` на :7 внутри doc-комментария), но геометрия — литералы: blockquote 3 dp, codeblock 2 dp (:66), горизонтальная линия `width: 5.0` (:70) при том, что в системе AppRadii.sm=8 / divider 1 dp (app_theme.dart:294). Markdown — это ответы AI, посты NiosGram и описания, т.е. регулярно видимый контент: скругления и толстая линия выбиваются из expressive-сетки и не слушаются AppRadiiTheme.

Влияние: Контент markdown живёт по своим числам; отсутствие темы формы для него заметно в AI-ответах и постах.

Правка: Литералы 3/2/5.0 заменить на AppRadii.smRadius / OutlineVariant thickness из DividerTheme; padding — AppSpacing.

### M3E-3 · low · `lib/widgets/motion/m3_animated_badge.dart:172`

```dart
child: Text(
        _displayString,
        style: widget.textStyle ??
            TextStyle(
              color: fg,
              fontSize: 11,
```

Бейдж — motion-блок дизайн-системы — задаёт свою типографику литералами (`fontSize: 11`, `FontWeight.w700`, `height: 1.0`) вместо роли M3, хотя центральная тема уже маппит бейджи: `badgeTheme: BadgeThemeData(textStyle: textTheme.labelSmall)` (app_theme.dart:353-357). Итог: `M3AnimatedBadge` и `Badge` в одном экране печатают числа разными размерами/весами, а смена типографики в AppTypography на бейджи не действует. Роль есть — `textTheme.labelSmall` (11/16, w500).

Влияние: Счётчики непрочитанного у бейджа и у Material Badge выглядят по-разному; типографика мимо системы.

Правка: `style: widget.textStyle ?? textTheme.labelSmall?.copyWith(color: fg, height: 1.0)` — взять textTheme из Theme.of(context) рядом с scheme (:156).

### MESS-1 · low · `lib/core/storage/local_storage_service.dart:212`

```dart
Future<LocalStorageHealth> checkIntegrity() async {
```

checkIntegrity() и класс LocalStorageHealth (~55 строк вместе с проверкой директорий и ключей черновиков) не вызываются нигде: grep по lib/ и test/ даёт только само объявление. При этом экран настроек хранилища использует только snapshot()/clear*, то есть вся ветка диагностики целостности — мёртвый груз, который читается как действующая проверка.

Влияние: Ложное впечатление, что целостность хранилища проверяется; код сопровождается без пользы.

Правка: Либо подключить checkIntegrity в settings_health_controller, либо удалить метод и класс.

### MESS-1 · low · `lib/core/utils/datetime_helpers.dart:99`

```dart
String formatCallDuration(Duration duration) {
  if (duration.isNegative) return '00:00';
```

formatCallDuration (строка 99) и computeCallElapsed (строка 117) не вызываются нигде: grep по lib+test находит только объявления. При этом в проекте есть FileTypeDetector.formatDuration (core/utils/file_type_detector.dart:247) с тем же форматом mm:ss/hh:mm:ss, а экраны звонков считают длительность сами. То есть форматирование длительности существует в двух-трёх местах, а «каноническая» версия — мёртвая.

Влияние: Формат длительности звонка меняют в одном из живых мест, мёртвая копия продолжает лгать о намерениях; ещё одна копия — widgets/update/app_update_dialog.dart:29.

Правка: Удалить обе функции из datetime_helpers, оставить один formatDuration в FileTypeDetector (или перенести его сюда как единственный).

### MESS-1 · low · `lib/core/utils/shared_utilities.dart:15`

```dart
IconData getIconForFileType(String? mimeType, {String? fileName}) {
  final String type = (mimeType ?? '').toLowerCase();
  final String ext = (fileName ?? '').toLowerCase();
```

getIconForFileType (строка 15) и getIconColorForFileType (строка 52) — 57 строк с ручным перебором расширений, при этом файл импортируют 14 модулей, но обе функции не вызываются ни разу (grep по lib+test: только объявления). Живую задачу решает core/utils/file_type_detector.dart (FileTypeCategory + getIconDataByName в этом же файле), то есть это вторая, мёртвая реализация «mime/extension → иконка», ещё и с цветами из ColorScheme внутри util-функции.

Влияние: Новые форматы файлов правят в двух местах, и правка в shared_utilities не даёт эффекта; читателю кажется, что иконки типов задаются здесь.

Правка: Удалить обе функции; если нужен цвет — брать FileTypeCategory из FileTypeDetector и мапить на scheme в виджете.

### MESS-1 · low · `lib/models/comment_thread.dart:12`

```dart
List<CommentThreadRow> buildCommentThread(
  List<ApiMessage> messages, {
  Set<int> collapsed = const <int>{},
}) {
```

Весь файл (67 строк: CommentThreadRow + buildCommentThread с обходом дерева, подсчётом поддерева и свёрнутыми ветками) не используется вне себя: grep по lib+test даёт только объявления и внутренние ссылки (стр. 3, 12, 58, 63). Актуальная лента комментариев собирает список иначе (screens/post_comments_screen.dart + comment_item.dart), так что это заброшенная реализация веток обсуждений.

Влияние: Мёртвая модель дерева комментариев выглядит как действующий контракт: новый код может начать строить треды через неё и разойтись с реальным поведением ленты.

Правка: Удалить models/comment_thread.dart целиком.

### MESS-1 · low · `lib/widgets/chat/bubble/bubble_text_renderer.dart:27`

```dart
final bool isLink;
```

Поле ParsedTextToken.isLink записывается дважды (строки 150 и 164) и нигде не читается: grep по всему lib/ находит только объявление и эти две записи, а _updateSpans ветвится по isMention. Мёртвое поле в парсере ссылок заставляет читателя искать третью ветку отрисовки, которой нет.

Влияние: Ложный сигнал при чтении парсера; при добавлении новых типов токенов поле будет заполняться неверно.

Правка: Убрать поле и обе записи isLink:.

### MESS-3 · low · `lib/widgets/common/app_pill_field.dart:121`

```dart
border: OutlineInputBorder(
            borderRadius: AppRadii.fullRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
```

Поле ввода существует в трёх параллельных реализациях: глобальный `inputDecorationTheme` (app_theme.dart:358-396: filled surfaceContainerHigh, радиус uiCornerRadius, bort outlineVariant 0.25), этот AppPillField (те же fill/padding, но 999 dp и четыре переписанных борта, OutlineInputBorder вместо сквиркла) и сырой TextField в user_search_picker_sheet.dart:192-199 (радиус-литерал 16, свой fill). Ни один не совпадает по геометрии и ни один не даёт M3E-форму, а правка темы меняет лишь третий случай. AppPillField при этом используется один раз (chat_members_screen:103) — 140 строк ради одного поля.

Влияние: Три геометрии поля ввода, правка темы не работает; лишний класс-дубль в дизайн-системе.

Правка: Оставить один путь: AppPillField убрать в пользу TextField на теме (при нужде — `shape: AppShape.pill` через InputDecorationTheme.pill в теме), user_search_picker_sheet перевести на AppPillField/тему.

### MESS-4 · low · `lib/widgets/chat/chat_input_bar.dart:90`

```dart
class _ChatInputBarState extends ConsumerState<ChatInputBar>
    with WidgetsBindingObserver {
```

1409 строк в одном State: IME-handoff, запись голоса с тремя ValueNotifier, панель эмодзи, десктопное attach-меню, планировщик сообщений. Второй файл полосы — chat_message_list.dart, 1297 строк (пиллы системных событий, якоря истории, upload-обёртки). Оба пересобираются в горячем пути и оба за порогом 1000.

Влияние: Любая правка ввода или списка — правка файла на 1400/1300 строк; конфликты при параллельной работе.

Правка: Вынести voice-recording, host панели выражений и attach-меню из ChatInputBar; _CallEventPill/_SystemEventPill/_HistoryAnchor — из списка.

### MESS-4 · low · `lib/widgets/profile/profile_shared_media_tab_view.dart:31`

```dart
class ProfileSharedMediaTabView extends ConsumerStatefulWidget {
  const ProfileSharedMediaTabView({
```

1507 строк в одном файле (лимит проекта — 1000): внутри один State с загрузкой медиа всех чатов (_loadAllChatMedia), свой pill bar, четыре независимых билдера списков (_buildMediaGrid, _buildVoiceList, _buildFilesList, _buildLinksList), шиммер, плейсхолдеры и три вспомогательных виджета со скачиванием файла (_SharedFileTile). Любая правка одного таба требует чтения всего файла, а сами табы уже не связаны ничем, кроме _selectedTabIndex.

Влияние: Сопровождение профиля; риск конфликтов при параллельных правках табов.

Правка: Разнести на profile_shared_media_grid/voice/files/links.dart + отдельный контроллер загрузки, оставив в файле только каркас с табами.

### MOTION-1 · low · `lib/features/sessions/presentation/sessions_screen.dart:138`

```dart
children: [
  for (final session in ready.otherSessions)
    _deviceRow(context, ref, session, pending),
],
```

Список устройств приходит из сети одним куском и появляется в один кадр: M3Reveal прячет только спиннер, а сами строки вставляются без входа. В настройках для этого уже есть M3StaggeredItem(index:) (settings_ui.dart:196, max 8 элементов, дальше рендер сразу), и сессий обычно 2-6 — цена: пересборка одной строки SettingsListItem на элемент, ровно столько же, сколько сейчас. Ещё заметнее при отзыве: строка исчезает мгновенно, хотя соседние табы «умеют» пружину.

Влияние: Security → Devices: появление и исчезновение устройств.

Правка: Обернуть _deviceRow в M3StaggeredItem(index: i) и скрывать отозванную строку через M3Reveal(revealed:false).

### MOTION-1 · low · `lib/screens/chat_members_screen.dart:118`

```dart
child: users.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(context.l10n.chatMembersSearchPrompt),
                          )
```

В шите приглашения подсказка «начните вводить» заменяется списком результатов без перехода: каждый ввод/очистка поиска — мгновенная подмена поддерева внутри `ConstrainedBox(maxHeight: 40% экрана)`. Высота при этом меняется скачком, и шит дёргается. Готовый блок — `M3SpringSwitcher(type: M3SwitcherType.fadeSlideY)`; пересобирается только содержимое ограниченного бокса, а не шит.

Влияние: Поиск участников при добавлении в группу дёргается на каждом пустом/непустом результате.

Правка: Обернуть ветку `users.isEmpty ? ... : ListView` в `M3SpringSwitcher` с `key` по `users.isEmpty`.

### MOTION-1 · low · `lib/widgets/contacts/call_log_view.dart:174`

```dart
onSelected: (_) {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.tap();
                  }
                  setState(() => _filter = _CallFilter.all);
```

Переключение фильтра «Все / Пропущенные» подменяет содержимое 443-строчного Column (Expanded → ListView.separated) мгновенно, без перехода: строки исчезают и появляются одним кадром, хотя меняется целый набор элементов. Готовый блок: widgets/motion/m3_spring_switcher.dart (M3SpringSwitcher, type: M3SwitcherType.fade, 300 мс, нормированные кривые) — достаточно обернуть ListView с ключом по фильтру. Цена: перестраивается только видимая часть списка.

Влияние: Резкая смена состояния там, где уместен spring-переход; нет ориентира «что изменилось».

Правка: M3SpringSwitcher(child: ListView.separated(key: ValueKey(_filter), …)) вокруг списка журнала.

### MOTION-1 · low · `lib/widgets/contacts/online_presence_radar.dart:212`

```dart
return InkWell(
                onTap: () {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.tap();
                  }
                  context.push('/chat/${chat.id}');
```

Тап по аватару радара мгновенно пушит чат: у плитки нет ни press-scale, ни state layer поверх аватара (InkWell без customBorder вообще не рисует скругление). Готовый блок для этого уже есть и применён в этой же полосе: widgets/motion/m3_press_scale.dart — app_nav_item.dart:239 `icon = M3PressScale(pressed: _pressed, scale: 0.9, child: icon);`. Цена: перестраивается только нажатая плитка (до 15 в радаре), аватар 48dp — дешёвый RepaintBoundary-ребёнок.

Влияние: Сухая реакция на тап в самой частой точке входа в чат.

Правка: Обернуть содержимое плитки в M3PressScale с локальным `_pressed` из onHighlightChanged, как в AppNavItem.

### MOTION-2 · low · `lib/screens/calls/active_video_call_screen.dart:836`

```dart
return IgnorePointer(
      ignoring: !visible,
      child: FadeTransition(opacity: opacity, child: child),
    );
```

Рукописный показ/скрытие дока (_controlsFadeController + CurvedAnimation + _CallControlsFade + свой Timer на 4 с) дублирует готовый M3Reveal(revealed:, type: M3RevealType.fade) из lib/widgets/motion/m3_reveal.dart, который сам держит контроллер, гасит анимацию при reduceMotion (_motionDisabled) и учитывает TickerMode. Из-за ручной реализации reduceMotion обрабатывается в четырёх местах (:140-144, :153-165) и легко забыть пятое; _areControlsVisible и значение контроллера — два источника истины, которые уже приходится синхронизировать вручную в каждом обработчике.

Влияние: Дублирование моушен-механики и хрупкая синхронизация состояния дока при reduced motion.

Правка: Заменить _CallControlsFade на M3Reveal(revealed: _areControlsVisible, type: M3RevealType.fade), удалив _controlsFadeController/_controlsFadeAnimation.

### MOTION-2 · low · `lib/screens/profile_screen.dart:657`

```dart
final Widget switcher = AnimatedSwitcher(
      duration: reduced ? Duration.zero : M3Durations.medium1,
      reverseDuration: reduced ? Duration.zero : M3Durations.short3,
      switchInCurve: M3SpringCurves.expressiveDecel,
      switchOutCurve: M3SpringCurves.expressiveAccel,
```

`_animatedDetail` вручную воспроизводит `M3SpringSwitcher` (`lib/widgets/motion/m3_spring_switcher.dart`): те же две пружины, тот же fade+slide, тот же `Duration.zero` при reduced motion — который сам `M3SpringSwitcher` делает внутри `build()` по `context.reduceMotion`. Разница только в `layoutBuilder` (`ExcludeFocus`/`IgnorePointer` на уходящей панели), то есть это копия готового блока плюс полезный фикс, который копия не вернёт в общий блок. Итог: две разные политики перехода панелей настроек, которые разойдутся.

Влияние: Любое улучшение M3-свитчера (например, новая политика overshoot) не доедет до панели настроек.

Правка: Добавить в `M3SpringSwitcher` параметр «изолировать уходящего» (или сделать такой `layoutBuilder` дефолтом) и вызывать его здесь.

### MOTION-2 · low · `lib/screens/settings_about_screen.dart:462`

```dart
class _TabTravelTransition extends StatelessWidget {
  const _TabTravelTransition({
    required this.animation,
    required this.travel,
    required this.child,
```

Новый класс (строки 462-492, 40 строк) вручную собирает FadeTransition + AnimatedBuilder(Transform.translate) — это ровно M3SpringSwitcher(type: M3SwitcherType.fadeSlideY) из lib/widgets/motion/m3_spring_switcher.dart, у которого уже есть нормализованный fade (expressiveDecel/Accel) и слайд по Y, плюс dual-transition логика. Отличие только в знаке направления (_tabDirection), то есть в одном параметре, а не в новом классе: сейчас переключение табов About — единственное место в настройках со своим переходом, и оно не получит будущие правки M3SpringSwitcher (например reduce-motion внутрь блока).

Влияние: Табы About (Что нового / Правовое / Команда).

Правка: Свернуть в M3SpringSwitcher(type: fadeSlideY) или добавить в него параметр direction вместо локального _TabTravelTransition.

### MOTION-2 · low · `lib/widgets/chat/chat_empty_state.dart:131`

```dart
tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: context.reduceMotion
            ? Duration.zero
            : M3Durations.short4,
        curve: M3SpringCurves.expressiveDecel,
```

Появление пустого состояния (и переход пусто ↔ история) собрано вручную: TweenAnimationBuilder → Opacity + Transform.scale(0.98→1.0). Это ровно M3Entrance(scaleFrom: 0.98) из lib/widgets/motion/m3_entrance.dart: у него внутри FadeTransition (без saveLayer от Opacity) и reduce-motion обрабатывается в didChangeDependencies. Perf-аудит (n3) отметил Opacity; новая причина — дублирование готового блока и расхождение кривой/шкалы с остальным приложением.

Влияние: Один лишний слой и своя кривая на каждый показ пустого состояния чата.

Правка: Обернуть Padding в .entrance(scaleFrom: 0.98) (extension m3_entrance.dart:103).

### MOTION-4 · low · `lib/features/chats/presentation/create_group_members_screen.dart:93`

```dart
AnimatedSize(
          duration: M3Durations.medium1,
          curve: Curves.fastOutSlowIn,
```

Единственная анимация в полосе выбранных участников: (а) кривая не из M3SpringCurves, хотя протокол проекта требует только их, (б) не читается context.reduceMotion — при выключенных анимациях полоса всё равно 250 мс меняет высоту и сдвигает весь список кандидатов под пальцем, то есть ровно то, от чего reduced motion должен избавлять. Аналогично строка `color: isSelected ? scheme.primary : Colors.transparent` (409) меняет цвет без M3-перехода, только длительностью.

Влияние: Пользователь с отключёнными анимациями получает релэйаут списка на каждое добавление участника.

Правка: duration: context.reduceMotion ? Duration.zero : M3Durations.spatialFast, curve: M3SpringCurves.spatialFast.

### UI-2 · low · `lib/screens/legal_viewer_screen.dart:269`

```dart
leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Назад',
```

Проект заявляет M3E, но `StyleVariant.material3Expressive` не включён нигде: `iconButtonTheme` в `app_theme.dart:227` задаёт только `iconColor`, без `IconButtonTheme.variantOf`. Все `IconButton` зоны (навигация в `legal_viewer`, `native_file_viewer`, `chat_members`, `profile`, `post_comments`) наследуют базовый M3 — то есть единственный компонент, у которого в `material_ui` 1.11.1 опт-ин уже есть, остался не включённым. Это не дефект, а неиспользованная возможность темы.

Влияние: Кнопки-иконки выглядят как обычный M3 на фоне остальных expressive-поверхностей.

Правка: `iconButtonTheme: IconButtonTheme.variantOf(StyleVariant.material3Expressive, ...)` в `app_theme.dart` (проверить точную сигнатуру `IconButtonTheme.variantOf` перед правкой).

### UI-3 · low · `lib/widgets/media/m3_video_controls.dart:227`

```dart
child: InkWell(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
```

`Colors.*` в виджете запрещён правилами проекта (только colorScheme), а вместе с NoSplash это полностью убивает визуальный отклик на тап по поверхности видео — в остальном приложении отклик дают TouchContainer (state layer через foregroundDecoration) и M3PressScale. Пользователь не видит, что тап принят: единственный признак — исчезновение панели контролов.

Влияние: Нет press-feedback на главной интерактивной поверхности видеоплеера; обход темы.

Правка: overlayColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: 0.08)) или TouchContainer вместо InkWell.

### UI-6 · low · `lib/widgets/calls/call_control_dock.dart:155`

```dart
tooltip: data.isScreenSharing
                    ? 'Остановить демонстрацию'
                    : 'Демонстрация экрана',
```

Полоса звонков локализована наполовину: в соседних строках берётся context.l10n.callMute/callEnd, а здесь и ещё примерно в 15 местах — русские литералы: active_video_call_screen.dart:259,593,911, active_voice_call_screen.dart:216,418,455, outgoing_call_screen.dart:286, incoming_call_overlay.dart:365, active_group_call_banner.dart:88,93, screen_share_picker_dialog.dart:67,82,141, call_control_dock.dart:184,201,254. Для не-русской локали экран звонка останется русским, и tooltip-ы (единственная подпись для иконок) тоже.

Влияние: Смешанные языки в UI звонка для всех локалей, кроме ru; часть tooltip-ов не переводится.

Правка: Завести ключи в AppLocalizations для этих 15 строк и заменить литералы на context.l10n.*.


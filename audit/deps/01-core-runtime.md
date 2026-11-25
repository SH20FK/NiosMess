# 01. Core runtime и базовые утилиты

Охват: `pulse_flutter/lib` (564 файла), `pulse_flutter/test` (269), `pulse_flutter/integration_test` (2),
`packages/` (nios_sdk, nios_mls, nios_iroh, nios_lab — 65). Исключено: `*.g.dart`, `*.freezed.dart`,
`lib/l10n/secret/generated/**`, `build/`, `.dart_tool/`, `audit/`. Всего просмотрено 900 dart-файлов.
Версии не проверялись.

| пакет | файлов | обращений | где (топ-3) | вердикт |
|---|---|---|---|---|
| dart_webrtc | 2 (1 lib, 1 test) | 2 импорта, 1 вызов API | `lib/services/calls/microphone_meter_web.dart:5,35`, `test/web/browser_workspace_calls_test.dart:11` | нужен (точечно, web-only) |
| cupertino_icons | 0 | 0 | — | **мёртвый** |
| flutter_riverpod | 368 (238 lib, 130 test+it) | 370 импортов; `ref.watch` 346, `ref.read` 969, `.select(` 180 | `lib/main.dart:10` (ProviderScope на :73), `lib/providers/backend_chat_provider.dart`, `lib/screens/chat_detail_screen.dart` | нужен |
| go_router | 77 (60 lib, 17 test) | 77 импортов; 72 `GoRoute(`, 167 `context.push/go/pop` | `lib/router/app_router.dart:8` (866 строк, 72 маршрута), `lib/main.dart:20,348`, `lib/core/navigation/direct_chat_navigator.dart` | нужен |
| emoji_picker_flutter | 5 (3 lib, 2 test) | 5 импортов | `lib/widgets/chat/expression_picker_panel.dart:3,217`, `lib/widgets/chat/unicode_emoji_picker_view.dart:2`, `lib/widgets/chat/m3_emoji_search_view.dart:190` | нужен; внимание: поверх пакета своя M3-обёртка |
| characters | 3 (все lib) + 2 файла через реэкспорт Flutter | 3 импорта, 10 обращений `.characters` | `lib/core/utils/expression_editing.dart:1,16,27`, `lib/core/utils/noto_emoji.dart:1,23`, `lib/models/api/custom_emoji_model.dart:1,4` | нужен |
| shared_preferences | 76 (25 lib, 51 test) | 76 импортов; 101 `getInstance` (64 в lib) | `lib/core/storage/local_storage_service.dart:127`, `lib/core/utils/draft_storage.dart:71`, `lib/providers/auth_provider.dart` | нужен; внимание: legacy-API и 64 вызова без единой обёртки |
| http | 48 (23 lib, 25 test) + 5 файлов в `packages/` | 63 импорта/обращения | `lib/core/network/api_client.dart:14`, `lib/services/oauth_service.dart` (11× `http.Client`), `lib/repositories/chat_repository.dart` | нужен |
| intl | 16 lib (19 с учётом generated) | 19 импортов; `DateFormat(` 10, `NumberFormat(` 1, `Intl.` 22 | `lib/l10n/app_localizations.dart:6`, `lib/core/utils/app_time.dart:29` (`Intl.defaultLocale`), `lib/core/utils/datetime_helpers.dart:173` (`Intl.plural`) | нужен |
| google_fonts | 0 | 0 | — | **мёртвый** |

## Детали по спорным пунктам

**dart_webrtc** — объявлен ради единственной строки: в `microphone_meter_web.dart` нужен
`MediaStreamWeb` из `package:dart_webrtc`, чтобы получить `.jsStream` и отдать его в
`context.createMediaStreamSource(...)`. `flutter_webrtc` этот класс не реэкспортирует (он экспортирует
`webrtc_interface`), поэтому каст через `package:web` напрямую не обойти без ручного приведения JS-объекта.
Это не «отдельный WebRTC-движок»: весь остальной код (`webrtc_call_session.dart`, `call_devices.dart`,
`call_overlay.dart`, `active_video_call_screen.dart`) работает через `flutter_webrtc`. Версия `dart_webrtc`
обязана совпадать с транзитивной из `flutter_webrtc` — это единственная причина держать пин в pubspec.

**characters** — объявлен не «на всякий случай»: три реальных импорта, и API вызывается там, где важна
графемная нарезка (курсор/удаление эмодзи в `expression_editing.dart`, посимвольный разбор эмодзи в
`noto_emoji.dart`, подсчёт длины текста с кастомными эмодзи в `custom_emoji_model.dart` — иначе `length`
считает UTF-16-юниты и ломает лимит в 1 «эмодзи»). Ещё два файла (`core/identity/nios_mark.dart:85`,
`widgets/pulse_avatar.dart:163`) вызывают `.characters` вообще без импорта — расширение приезжает
реэкспортом из `package:flutter/widgets.dart`. Импорт в трёх файлах корректен и не лишний:
без явной зависимости это использование держалось бы на транзитивном реэкспорте SDK.

**intl** — тоже настоящий, а не формальный. Три файла локализации (`app_localizations*.dart` правится
руками, arb у них нет) держат `Intl.plural`/`Intl.message`, `app_time.dart` глобально ставит
`Intl.defaultLocale`, `datetime_helpers.dart` использует `Intl.plural`, а `DateFormat` живёт в 10
feature/widget-файлах (sessions, notification_center, chat_productivity, public_profile_screen,
working_hours_planner_dialog и т. д.). `NumberFormat` — один вызов в `widgets/profile/ai_usage_card.dart`.
Плюс `intl` всё равно приходит транзитивно через `flutter_localizations`, но здесь он задействован
напрямую, так что декларация оправдана.

**cupertino_icons** — ноль импортов во всём дереве и ноль `CupertinoIcons.` в коде. Проект грузит свои
шрифты (`MaterialSymbolsOutlined/Rounded/Sharp`, `NotoColorEmoji`) и `uses-material-design: true`.
Пакет не нужен ни для сборки, ни для рантайма.

**google_fonts** — ноль `GoogleFonts.` и ноль импортов. Все шесть гарнитур (BricolageGrotesque, Onest,
GolosText, PlusJakartaSans, Inter + NotoColorEmoji) объявлены ассетами в `pubspec.yaml` с локальными
variable-ttf. То есть загрузчик шрифтов из сети не используется вообще.

**flutter_riverpod — как пакет реально задействован.** 368 файлов с импортом (238 lib + 129 тестов + 1
`integration_test/performance_test.dart`). Провайдеры пишутся руками, без генератора (`@riverpod` /
`riverpod_generator` в проекте отсутствуют), набор такой: `Provider<…>` 89 объявлений (+13 `.family`),
`NotifierProvider` 62, `AsyncNotifierProvider` 18, `FutureProvider` 9, `StreamProvider` 7;
`StateProvider` в коде нет (четыре совпадения по маске — это имя `secretProtectionStateProvider`,
а не класс). Подписки: 139 файлов вызывают `ref.watch` (346 раз), 47 — `ref.listen`, 50 — `ref.invalidate`.
Гранулярность задействована активно: **`.select(` в 85 файлах, 180 вызовов**, лидеры —
`lib/screens/chat_detail_screen.dart` и `lib/screens/chat_list_screen.dart` (по 13),
`lib/screens/settings_appearance_screen.dart` (9), `lib/main.dart` (7). Обратная сторона:
**`ref.read` — 969 вызовов в 151 файле, из них 84 вызова в 37 файлах внутри `build()`** —
лидеры `lib/screens/main_shell_screen.dart` (8), `lib/screens/niosgram_screen.dart` (6),
`lib/widgets/chat/chat_filter_bar.dart` (6), `lib/widgets/post_card.dart` (5),
`lib/widgets/contacts/call_log_view.dart` (5). Само по себе это не ломает riverpod, но `ref.read`
в `build()` не подписывает виджет: значение не обновится, пока что-то другое не вызовет пересборку —
это же место обычно и стреляет при «залипшем» UI.

**emoji_picker_flutter** — используется всего в одном месте продукта (панель выражений в чате) и не как
готовый пикер: `Config`/`EmojiPicker` берутся как каркас (state, категории, скин-тоны, вставка в
контроллер), а сами категории и поиск нарисованы заново — `UnicodeEmojiPickerView` через
`customWidget`, поиск через `EmojiPickerUtils().searchEmoji` по собственному индексу `CategoryEmoji`
в `m3_emoji_search_view.dart`. То есть пакет задействован на 20–30 % своей поверхности,
остальное — своя реализация поверх.

**shared_preferences** — ядро настроек: `LocalStorageService` (4 `getInstance`), `DraftStorage`,
`ui_settings_provider`, `auth_provider` (9 `getInstance`), `push_notification_service` (6),
`chat_muted_provider` (5). Дублирования с `hive` нет: hive/`Hive.` (305 обращений в 38 файлах) держит
кэши сообщений и уведомлений (`cache_service.dart`, `encrypted_message_cache.dart`,
`notification_history_store.dart`), а prefs — ключи/флаги настроек. Замечание не к пакету, а к коду:
единой обёртки нет, 64 вызова `SharedPreferences.getInstance()` размазаны по 24 lib-файлам.

**http** — используется и в приложении (23 lib-файла), и в локальных пакетах: `packages/nios_mls/lib/src/client.dart:9`,
`packages/nios_iroh/lib/src/rendezvous.dart:6`, тесты `nios_sdk`. Часть кода идёт через общий
`ApiClient`, но сервисы (`oauth_service`, `password_reset_service`, `blob_store_service`,
`ws_media_fetcher`, `ota_update_provider`) создают собственные `http.Client` — 36 файлов ссылаются на
`http.Client`. Второго HTTP-клиента в проекте нет: `dio` отсутствует, `HttpClient` из `dart:io` встречается
только в двух e2e-тестах (`test/integration/e2e_auth_flow_test.dart`, `e2e_cold_start_and_logout_test.dart`).

**go_router** — единственный роутер. `lib/router/app_router.dart` — 866 строк, 72 `GoRoute`, redirect-логика
тоже там; в `main.dart` роутер поднимается как `ref.watch(appRouterProvider)` (строка 348). Из 60 lib-файлов
с импортом 58 используют `context.push/go/pop` (167 вызовов), 20 файлов (с тестами) трогают
core-API (`GoRouter(`, `GoRouterState`, `redirect:`). Обходов мимо роутера мало: 8 вызовов
`Navigator.push` на весь проект, из них `lib/router/app_navigation.dart` — легитимная обёртка,
`lib/screens/dev/extended_image_demo_screen.dart` — dev-экран.

## Что стоит удалить/заменить

1. **`cupertino_icons`** — удалить из `pubspec.yaml`. Иконки берутся из Material Symbols и своих ассетов,
   `CupertinoIcons.` в коде нет ни одного раза.
2. **`google_fonts`** — удалить. Шрифты лежат локальными variable-ttf в `assets/fonts/`, сетевой загрузчик
   не нужен (и он же тянет сетевой доступ, которого в проекте быть не должно).
3. **`dart_webrtc`** — оставить, но зафиксировать смысл комментарием в pubspec: пакет держится ради
   `MediaStreamWeb` в одном web-файле и обязан совпадать по версии с `flutter_webrtc`. Если появится
   желание убрать — сначала проверить, можно ли отдать в `createMediaStreamSource` JS-объект из
   `package:web` без каста.
4. **`shared_preferences`** — не удалять, а свести к одной точке: `LocalStorageService` уже есть, но 24
   lib-файла (включая `auth_provider` с 9 вызовами) зовут `getInstance()` напрямую. Плюс весь код на
   legacy `SharedPreferences.getInstance`; в 2.5+ для новых мест рекомендуется `SharedPreferencesAsync` /
   `SharedPreferencesWithCache`.
5. **`ref.read` в `build()` (37 файлов, 84 вызова)** — не про версии пакета, а про то, как riverpod
   задействован: в лидерах (`main_shell_screen.dart`, `niosgram_screen.dart`, `chat_filter_bar.dart`)
   стоит перевести на `ref.watch`/`select`, иначе подписки нет и обновление приходит «случайно».

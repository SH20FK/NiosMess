# Аудит производительности NiosMess по https://docs.flutter.dev/perf/best-practices

Дата: 2026-11-25. Шесть независимых агентов (`itsxiao/free/deepseek-flash`), каждый по своей зоне.
Код не изменялся. Детали — в `01-chat.md` … `06-motion-crosscut.md`.

## Счётчики (сырые, до дедупликации)

| Зона | blocker | major | minor | nit |
|---|---|---|---|---|
| 01 chat | 0 | 3 | 8 | 6 |
| 02 widgets | 1 | 6 | 10 | 5 |
| 03 screens + router | 2 | 7 | 4 | 4 |
| 04 core | 0 | 3 | 9 | 7 |
| 05 data layer | 2 | 10 | 8 | 6 |
| 06 motion + crosscut | 1 | 7 | 12 | 6 |
| **итого** | **6** | **36** | **51** | **34** |

После дедупликации (одни и те же места нашли 2–3 агента) — ~115 уникальных замечаний.

## P0 — блокеры, подтверждённые чтением кода

1. **Экраны звонков пересобираются 3 раза в секунду с полной палитрой.**
   `screens/calls/active_video_call_screen.dart:111` (`setState(() {})` в слушателе потока) и `:206-216` (`ColorScheme.fromSeed` + `ThemeData()` в `build()`). То же в `active_voice_call_screen.dart:93,126-131`.
   Проверено лично. Фикс: палитру — в `late final`/кэш, `setState` — убрать (таймер уже есть в `_timerNotifier`).
2. **E2EE-расшифровка целиком в UI-изоляте, последовательно, на каждое сообщение.**
   `services/ordinary_e2ee/ordinary_e2ee_codec.dart:297,317,322`, `ordinary_e2ee_service.dart:723`, `providers/backend_chat_provider.dart:2693-2706,2761-2861`.
   Причина: в pubspec только `cryptography: ^2.9.0`, `cryptography_flutter` нет → Ed25519/X25519/AES считаются на Dart.
   Фикс: `FlutterCryptography.enable()` + батч в `Isolate.run`.
3. **Догон истории без границы.** `backend_chat_provider.dart:2589-2615` (`while(true)` по страницам) + `:3239`; после долгого офлайна — тысячи расшифровок при видимом окне 300.
4. **Декод изображений в полном разрешении.** `widgets/message_bubble.dart:915,930` — `Image.memory`/`Image.file` без `cacheWidth` при `maxHeight: 320`; 12 МП фото = ~48 МБ RGBA, альбом из 4 — риск OOM. Проверено лично. Рядом `:673-677` сделано правильно.

## P1 — major с дешёвым фиксом

| # | Место | Что не так |
|---|---|---|
| 5 | `widgets/nav/m3_route_tab_switcher.dart:210-220` | `RepaintBoundary` снаружи `Opacity` (порядок перевёрнут) + `AnimatedBuilder` без `child` → saveLayer на весь экран каждую смену таба. Найдено тремя агентами, проверено |
| 6 | `widgets/profile_header_delegate.dart:40-43,84-87` | `Opacity` на всей шапке; delegate собирается на каждый пиксель скролла |
| 7 | `core/performance/adaptive_performance_provider.dart:122,273` | Телеметрия `capacity: 7200`: 3 `sort()` + snapshot раз в секунду из `addTimingsCallback`. **Плюс моя находка: `performanceTelemetryProvider` не читает ни один виджет во всём `lib/`** → работа впустую. Гейт по `PERF_TRACE` |
| 8 | `widgets/post_card.dart:368-383` | `MarkdownStyleSheet.fromTheme` + `inlineSyntaxes`/`builders` в `build()` каждой карточки ленты |
| 9 | `widgets/chat/chat_input_bar.dart:531` | `MediaQuery.of` в 1322-строчной панели ввода, рядом уже `.sizeOf`/`.viewInsetsOf` |
| 10 | `widgets/voice_message_player.dart:79` | `AudioPlayer` + скачивание + расшифровка файла в `initState` каждого голосового бабла; единственное медиа без `MediaPlaybackVisibility` |
| 11 | `models/interactive_message.dart:47,54` | `InteractiveMessage.parse` 2–3 раза на билд бабла, каждый раз новый `RegExp` + `jsonDecode` |
| 12 | `widgets/m3_file_picker_bottom_sheet.dart:1121,1275` | `FutureBuilder(future: thumbnailDataWithSize(...))` создаётся в `build()`; `setState` чекбокса перезагружает превью всех плиток |
| 13 | `create_chat_wizard_view.dart:917,1035`, `chat_members_screen.dart:124`, `chat_detail_screen.dart:1494-1517` | `shrinkWrap: true` / `Column(children: chats.map(...))` = неленивые списки |
| 14 | `widgets/settings/ordinary_e2ee_settings.dart:574` | `ref.watch(chatsProvider)` без `select` → любое сообщение пересобирает страницу |
| 15 | `services/secret_chat/secret_journal.dart:69-72,298-332`, `secret_chat_engine.dart:731` | fsync на каждое событие; чекпоинт сериализует весь аккаунт в UI-изоляте; `restore()` блокирует `build()` провайдера |
| 16 | `screens/chat_list_screen.dart:865,920` | O(n) `indexWhere`/`List.of`/filter на каждое входящее; `SliverList` без `itemExtent` при известной `rowHeight` |
| 17 | `screens/media_viewer_screen.dart:269-272` | `setState` на каждый 1 % свайпа ради `_dragProgress`, который нигде не читается |
| 18 | `screens/native_file_viewer_screen.dart:869,911` | `_content.split('\n')` в `build()`, переразбиение всего файла на каждое нажатие в поиске |
| 19 | `screens/legal_viewer_screen.dart:317-364,52-56` | Документ на 200–300 абзацев неленивым `Column` + пересборка на каждый символ поиска |
| 20 | `core/storage/encrypted_message_cache.dart:236-242` | `messages.map(toJson).toList()` для 2000 сообщений в UI-изоляте **до** `Isolate.run` |
| 21 | `core/media/media_playback_visibility.dart:50-80` | post-frame обход предков + `localToGlobal` на каждое `ScrollUpdateNotification` у каждого медиа-бабла |

## P2 — minor/nit, кратко

`core/motion/m3_spring_constants.dart:114` пересчёт константы `_rawResponse` каждый кадр; `core/utils/datetime_helpers.dart:55,200` `RegExp` литералами в `itemBuilder`; `core/utils/message_preview_text.dart:36` новый `md.Document` + `RegExp` на вызов; `core/motion/smooth_text_streamer.dart:69,108` `Timer.periodic(16ms)` вне vsync + `substring` (O(n²)); `core/modal/app_modal_content.dart:134` `TextPainter.layout()` в `LayoutBuilder`; `widgets/chat_tile.dart:587,726` два `LayoutBuilder` на строку; `chat_filter_bar.dart:295` `ShaderMask` на скроллящейся ленте; `message_bubble.dart:1036,1198,1353` `FileTypeDetector.detect` ×3 на бабл; `m3_reveal.dart:145` overshoot-кривая на `SizeTransition`; `m3_morphing_icon.dart:64-99` нет обновления кривой в `didUpdateWidget`; мёртвый `adaptive_glass.dart` с `BackdropFilter`.

## Что уже сделано правильно (проверено, менять не надо)

- **Список сообщений**: ленивые slivers, `findChildIndexCallback` через O(1) `_rowIndexes`, `addRepaintBoundaries: false` + свой `RepaintBoundary` на строку, стабильные ключи, `addAutomaticKeepAlives: false`.
- **Ввод изолирован от списка**: `RepaintBoundary` на композер и всю панель, `setState` только на переходе пусто↔непусто, черновик дебаунс 500 мс, typing троттл 3 с.
- **Ноль `MaskFilter.blur`** во всём `lib/`; **ноль `IntrinsicWidth`/`IntrinsicHeight`**; **ноль `AnimationController` в `build()`** (32 из 32 в `initState`); **ноль `operator ==` у `Widget`** (26 — только модели); **ноль неленивых `ListView(children:)`/`GridView.count`**; `indexWhere` в лейауте — 0 из 38.
- **Пружины** нормализованы (`f(0)=0`, `f(1)=1`), токены `const`, overshoot только на позиции/масштабе, не на opacity.
- **`TouchContainer`** по умолчанию `Clip.none`, state layer через `foregroundDecoration`.
- **Кэш темы** — LRU на 64 `ThemeData`, `fromSeed` только на промахе.
- **Тяжёлое вне UI-потока** там, где уже сделано: файловая крипта, стикеры (`compute`), обход storage (`compute`), архив/кеш сообщений (`Isolate.run`).
- **Роутер** в redirect не читает storage/JSON; `pageKey` фиксирован — табы не плодят страницы.

## Расхождения между агентами (калибровка, не спор по существу)

| Место | Оценки | Решение |
|---|---|---|
| `m3_route_tab_switcher` | blocker (02), major (03), major (06) | major: цена только в момент смены таба (~250 мс) |
| `message_bubble` images | blocker (06), major (02) | major, но фикс в одну строку и есть риск OOM |
| `smooth_text_streamer` | minor (04), major (06) | major: O(n²) растёт с длиной ответа AI |
| `chat_filter_bar` ShaderMask | major (06), minor (01) | minor: только при горизонтальном скролле ленты |
| дефект `RepaintBoundary`/`Opacity` | 3 агента нашли независимо | подтверждено чтением кода |

## Требует профилятора, а не чтения

Скролл чата с 20 голосовыми и GIF; смена таба и открытие чата (`AnimatedSwitcher`, 250 мс, два экрана); `circular_theme_reveal` (peak memory на dpr 2.75); длинный AI-стрим на 120 Гц; размер gap при catch-up после 1 ч / 1 дн / 1 нед офлайна; стоимость одной E2EE-операции pure-Dart на целевом Android; `DocxParser.parseBytes` в `initState` на 50–200 КБ.

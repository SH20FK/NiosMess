# Аудит NiosMess — итог

Дата: 2026-11-28. Приложение: `pulse_flutter` (Flutter 3.50.1 / Dart 3.14.0).

> **Внимание: ниже — версия до верификации.** Прогон скептиков идёт следом;
> расхождения с кодом собраны в разделе «Поправки после верификации» в начале
> файла. Плановые решения — в `audit/IMPLEMENTATION-PLAN.md`, он обновляется по
> мере вердиктов.

## Поправки после верификации (28.11)

| Что было в отчёте | Что показал код | Итог |
|---|---|---|
| `SEC-4`: «код сопряжения может сгенерировать кто угодно с публичным userId» | **неверно**: сервер связывает `request_id` с `OrdinaryPairing(user.id, request_id)`, сверяет `target_key` и проверяет Ed25519-подпись ключом жертвы (`ordinary_e2ee.py:199-208`). Чужой код → `E2E_PAIR_EXPIRED`, подмена target → `E2E_PAIR_MISMATCH` | остаётся **high**, но формулировка другая: эскалация «украденная сессия → keyring + recovery» без имени устройства, SAS и подтверждения в UI |
| `SEC-3`: «настройка врёт про защиту» | тумблеры **уже убраны** из UI осознанно (`settings_security_screen.dart:62-66`: «stay out of the UI until the behaviour lands»). Android `FLAG_SECURE` работает, iOS/десктоп канала не имеют, `MissingPluginException` глотается | **medium**: защиты на iOS нет, но UI её и не обещает |
| «Два мёртвых тумблера на экране» | экранный пункт **отклонён** (кода нет). Мёртвые поля в `ui_settings_provider` остались | low, чистка провайдера |
| `ARCH-3 backend_chat_provider` — god class | внутри **четыре независимых нотифаера**; довод «список чатов и E2EE в одном классе» ложный | **medium**: файл-склад, резать по нотифаерам |
| `ARCH-2 chat_detail_screen:74` — инверсия слоёв | UI→data — законное направление; «45 импортов» → 30 в 27 файлах | **medium**: проблема в локальном `setState` рядом с `chatMembersProvider` |
| Мёртвый код ≈2 200 строк | **≈12 360**: стек обоев 10 634 (`material_symbols_data` 8 563 — только тесты), `core/worker` 534 (используется тестом), звонки 572, экраны 273, `ApiClient` 165 | волна 5 переписана |
| `comment_thread.dart` мёртв | **живой**: `buildCommentThread` вызывается из `post_comments_screen.dart:322` | отклонено |
| `StyleVariant` — «одна строка, бесплатный выигрыш» | API подтверждён, но все 128 `IconButton` станут 40×40 + `StadiumBorder` вместо 48-круга | решение владельца, не механика. Утверждение «AGENTS.md этого прямо требует» — ложное: AGENTS.md:114 говорит обратное |
| MOTION: 4 предложения | блоки не подходят по API: у `M3SpringSwitcher` нет `direction`, `CallAudioRipple` требует `Animation`+`scheme` и 320 dp, у `M3AnimatedBadge` нет `child`, `M3SpringSwitcher` не анимирует высоту | отклонены, в плане заменены на `M3Reveal`/доработку блоков |
| «Правило 2 нарушено в 3 файлах (`elevation > 0`)» | **моя ошибка измерения**: `-match` в PowerShell регистронезависим, поэтому в счёт попали `scrolledUnderElevation: 2` и `highlightElevation: 1`. `ElevatedButton` в `lib/` — **0 вхождений** | правило 2 нарушать нечему. `inline_query_overlay.dart:44 elevation: 4` — не кнопка, проверить отдельно |
| MOTION второй партии: `sessions_screen:138`, `legal_viewer:242` | в `for-in` нет индекса, `AppBar.actions` — `List<Widget>` | отклонены; для `legal_viewer` нужна замена `actions` на `Row` |
| «Правило 9 нарушено: `StateProvider` ×4» | **ложное срабатывание grep**: совпала подстрока в `secretProtectionStateProvider`, а это `Provider.family` | правила 9 никто не нарушал — 0 `StateProvider` в `lib/` |
| `adaptive_glass.dart` — мёртвый | **живой**: 5 тестов в `adaptive_glass_test.dart` + allowlist в `anti_slop_guard`/`m3e_design_audit` | не удалять |
| `Colors.white/black` — 22 | 19 исправлено; 3 остались в `nios_mark.dart`/`nios_mark_badge.dart` — белая монограмма на градиенте бренда | осознанно |

---

## Исходная версия (до верификации)

14 агентов на `itsxiao/free/deepseek-flash`, партиционирование по каталогам.
Код не изменялся: только чтение и замеры.

Исходные данные: `audit/shortlist.json` (154 находки), `audit/report.md`
(полный текст с цитатами), `audit/perf-status.md` (сверка с прошлым
perf-аудитом), `audit/rust/` (Rust-разведка), `audit/findings/*.json` (сырые
результаты полос).

---

## Коротко

**154 находки: 19 high, 101 medium, 34 low, 0 blocker по формальной шкале.**

Блокеров нет только потому, что ни одна находка не срабатывает без действия
пользователя. По последствиям самая тяжёлая — `SEC-4` (сопряжение отдаёт весь
keyring).

Пять вещей, которые стоит знать, если читать дальше нечего:

1. **`SEC-4` — отдача ключей при ручном сопряжении.** `approvePairing` шифрует
   весь `_keyring` и `_recovery` в `target_key` из строки `niosmess-e2e:...`,
   в которой проверяются только самозаявленные `v` и `user_id`. Такой код может
   сгенерировать кто угодно: публичный userId виден в профиле и ссылках.
2. **Обои чата — заглушка, которая ухудшает чат.** `ChatWallpaperBackground`
   рисует плоский `ColoredBox` (в коде так и написано: «preferences stay stored,
   but no wallpaper is loaded or painted»), но наличие кастомных обоев
   выключает тональную палитру чата (`nios_chroma.dart:24`). Итог: 6 пресетов,
   8 слайдеров и «Применить» не рисуют ничего, зато отнимают expressive-окраску.
3. **Крипто на UI-изоляте, и обычный фикс не поможет.** Ed25519 + X25519 + 2×AES
   на каждое сообщение в главном изоляте. `cryptography_flutter` на Android
   ускоряет только AES/ChaCha/HMAC/PBKDF2 — Ed25519/X25519 там **нет** (только
   Apple). Значит выигрыш даёт батчинг в изоляте, а не `FlutterCryptography`.
4. **M3E включается одной строкой для 128 кнопок.** В `app_theme.dart:227`
   центральный `IconButtonThemeData` без `variant: StyleVariant.material3Expressive`,
   хотя в `material_ui` 1.11.1 это поддерживается. Сейчас `StyleVariant` в
   проекте не используется ни разу.
5. **Захламлённость измерима:** ≈2 200 строк мёртвого кода в 9 файлах, 5 файлов
   длиннее 1 400 строк, дебаг-экран в боевом роутере, 4 мёртвых тумблера,
   181 UI-строка мимо l10n.

**Rust: переписывать не надо.** Подробно — в конце.

---

## Как считали

- 11 полос по каталогам (`widgets/chat`, `widgets/chat/bubble`, `screens`,
  `services/calls`, крипто, `core`, дизайн-система, `providers`+`repositories`,
  `models`+`utils`, настройки, медиа) + 3 по Rust.
- Базой был существующий `audit/perf` (25.11, 6 агентов, ~115 замечаний):
  агенты не дублировали его, а искали то, чего там нет (M3E, движение,
  захламлённость), и отдельно проверяли, что из старого уже исправлено.
- Каждая находка требует дословную цитату кода (`evidence`); без неё слияние
  выбрасывает запись.
- Расхождения между полосами разбирались по коду, а не голосованием (пример:
  `FLAG_SECURE` — см. «Безопасность»).

---

## Топ по цене

| # | Находка | Место | Почему дорого |
|---|---|---|---|
| 1 | `SEC-4` | `services/ordinary_e2ee/ordinary_e2ee_service.dart:1080` | одно нажатие «сопрячь» отдаёт весь keyring + recovery |
| 2 | `MESS-1` | `widgets/wallpaper/chat_wallpaper_background.dart:11` | обои не рисуются, но гасят тональную палитру чата |
| 3 | `LAG-5` | `services/ordinary_e2ee/ordinary_e2ee_codec.dart:297` | N сообщений = N×(verify+DH+AES) в кадре |
| 4 | `LAG-2` | `screens/calls/active_video_call_screen.dart:459` | перестройка всего stage 2–3 раза в секунду |
| 5 | `LAG-1` | `widgets/settings/custom_color_picker_sheet.dart:75` | `ColorScheme.fromSeed` на каждый кадр перетаскивания |
| 6 | `ARCH-3` | `providers/backend_chat_provider.dart:4881` | 4 927 строк, 5 нотифаеров, push-роутинг в одном классе |
| 7 | `ARCH-3` | `screens/chat_detail_screen.dart:109` | 3 477 строк в одном `State`: AI, E2EE, загрузки, реакции |
| 8 | `ARCH-1` | `providers/auth_provider.dart:20` | хаб из 6 циклов; контракт `AuthState` тянет всё |
| 9 | `ARCH-2` | `repositories/auth_repository.dart:1` | слой данных импортирует providers: 11 репозиториев |
| 10 | `SEC-3` | `core/utils/screen_security_service.dart:6` | защита от скриншотов только на Android, на iOS канала нет |
| 11 | `LAG-1` | `core/utils/docx_parser.dart:95` | zip + 6 regex-проходов синхронно в `initState` |
| 12 | `LAG-1` | `models/interactive_message.dart:48` | `jsonDecode` дважды на бабл в одном кадре |

---

## M3E: что включить

Соблюдено: миграция на `material_ui` завершена (0 импортов SDK-Material в коде),
`dart:io` — 0, `withOpacity` — 0, `M3SpringCurves` используются, `m3_page_transitions`
подключены центрально.

Нарушено (проверено по всему `lib/`, 575 файлов):

| Правило | шт | Где |
|---|---|---|
| `Colors.white/black` | 22 в 5 файлах | `nios_mark`, `active_video_call_screen`, `login_screen`, `nios_mark_badge`, `extended_image_demo_screen` |
| `BoxShadow` | 11 в 4 | `create_chat_screen`, `group_profile_screen`, `native_file_viewer_screen`, `touch_container` |
| `StateProvider` (запрещён) | 4 в 3 | `e2ee_status_card`, `e2ee_verification_sheet`, `security_status_chip` |
| `shrinkWrap: true` | 10 в 9 | `create_group_details_screen`, `presets_tab`, `chat_members_screen`, `onboarding_screen`, `media_grid_picker` … |
| `elevation > 0` | 3 | `legal_viewer_screen`, `chat_detail_fab`, `inline_query_overlay` |
| `PopupMenuButton` | 1 | `call_control_dock.dart:215` |
| `BackdropFilter`/`blur` | 1 | `adaptive_glass.dart` (мёртвый файл) |

`CircularProgressIndicator` в `pulse_loading_indicator.dart` — разрешённое
исключение, это сам `AppLoadingIndicator`.

Пять правок с лучшим отношением «эффект / цена»:

1. **`app_theme.dart:227`** — добавить `variant: StyleVariant.material3Expressive`
   в `IconButtonThemeData`. Одна строка включает M3E всему иконочному слою
   (128 `IconButton`). Проверено: в `material_ui` 1.11.1 опт-ин есть только у
   `IconButtonThemeData` и `ElevatedButtonThemeData` — у остальных компонентов
   API пока нет, требовать его нельзя.
2. **`core/modal/m3_modal_surface.dart:118`** — единственная поверхность всех
   шитов и диалогов рисуется `RoundedRectangleBorder` с константой, а не
   сквирклом и не `AppRadiiTheme`. Одна правка меняет форму всех модалок и
   заодно начинает уважать настройку радиуса.
3. **`widgets/common/touch_container.dart:194`** — нет hover-состояния вовсе.
   `MouseRegion` + второй флаг в уже существующее условие даёт отклик на
   наведение 29 call-sites на Windows и Web.
4. **`settings_security_screen.dart:72`** — убрать или реализовать мёртвые
   тумблеры (см. «Безопасность»): сейчас они обещают управление защитой.
5. **`StateProvider` ×4** — перевести на `NotifierProvider` (правило 9);
   файлы маленькие, риск низкий.

Отдельно: **181 захардкоженная русская UI-строка** (`Text`, `label`, `hintText`,
`tooltip`) мимо `context.l10n`. Топ: `m3_file_picker_bottom_sheet.dart` (22),
`chat_creation_surfaces.dart`, `support_center_screen.dart`. Всего русских
литералов в коде 1 196, но большая часть — данные (поиск по эмодзи, каталог
обоев), а не UI.

---

## Движение: 21 возможность

Это не дефекты, а места, где анимации не хватает. Все — на существующих блоках
`lib/widgets/motion/`, новых классов не требуется.

| Место | Что происходит | Чем закрыть | Цена |
|---|---|---|---|
| `active_video_call_screen.dart:390` | смена раскладки stage (spotlight ↔ сетка) одним кадром | `M3SpringSwitcher(fade)` | только stage |
| `message_bubble.dart:421` | у бабла нет press-scale, хотя это главный жест | `M3PressScale` | один бабл |
| `touch_container.dart:194` | нет hover на Windows/Web | `MouseRegion` + state layer | 29 вызовов сразу |
| `media_viewer_screen.dart:392` | видео открывается без Hero (у картинок — есть) | `MediaHero` | push/pop |
| `bubble_upload_overlay.dart:159` | 5 состояний аплоада переключаются if/else | `M3SpringSwitcher` | оверлей |
| `outgoing_call_screen.dart:199` | «звоним» 10–20 с на статичном аватаре | `CallAudioRipple` | ринг-экран |
| `legal_viewer_screen.dart:242` | включение поиска меняет шапку одним кадром | `M3SpringSwitcher(fadeSlideY)` | шапка + тело |
| `sessions_screen.dart:138` | список устройств появляется без входа | `M3StaggeredItem` | строка |

Плюс 7 мест, где рукописная анимация дублирует готовый блок
(`chat_input_bar._iconSwapTransition`, `app_illustration._SubtleEntrance`,
`settings_about._TabTravelTransition`, `profile_screen._animatedDetail`,
`chat_empty_state`, док контролов звонка, `e2ee_settings`), и 2 места, где
анимация не уважает reduced motion (`SmoothTextStreamer`, полоса выбранных
участников группы).

`MOTION-3` (переходы экранов мимо темы) не найден: все переходы идут через
`M3SharedAxisPageTransitionsBuilder` / `M3ModalRoute`, кроме `PageRouteBuilder`
у дебаг-экрана.

---

## Лаги: статус прошлого аудита

`audit/perf-status.md`: **44 находки ещё в коде, 10 исправлено** из 54
проверенных.

Исправлено: P0-1 по звонкам (палитра мемоизирована, `setState` из слушателя
убран), `cacheWidth` у изображений бабла, догон истории ограничен
`maxCatchUpPages = 4`, `chat_input_bar` перешёл на `.sizeOf`, `profile_header_delegate`
(RepaintBoundary внутрь Opacity), `m3_spring_switcher` (утечка CurvedAnimation).

Осталось: крипто и журнал секретных чатов на UI-изоляте, телеметрия на 7 200
точек, `shrinkWrap`, `indexWhere` в чат-листе, `fromSeed` в пикере цвета и
пресетах, `FileTypeDetector` ×3 на бабл, `InteractiveMessage.parse` ×2 на бабл,
`Ref.watch(chatsProvider)` без `select` в E2EE-настройках.

Новое, чего в прошлом аудите не было: `CallSessionNotifier.notify()` →
`state = null; state = cur` перестраивает весь экран звонка 2–3 раза в секунду
даже после фикса палитры (`call_session_provider.dart:63-67`).

---

## Захламлённость

Мёртвый код (проверено grep'ом по `lib/` и `test/`), ≈2 200 строк:

| Объём | Что |
|---|---|
| 470 строк | весь `core/worker/` (изолят + SQLite + крипто) — ни одного потребителя; бонусом `dispose()` ставит `_closed = true` до `execute(shutdown)`, поэтому SQLite не закрывается |
| 269 | `services/calls/video_pipeline.dart` |
| 135 | `services/calls/e2ee_key_manager.dart` — параллельный стек E2EE звонков |
| 176 | `chat_redirect_screen.dart` + `direct_chat_resolver_screen.dart` (3 экрана без ссылок) |
| 112 | `widgets/chat/chat_state_surface.dart` |
| 94 | `widgets/adaptive/adaptive_glass.dart` (тот самый `BackdropFilter`) |
| 67 | `models/comment_thread.dart` |
| 55 | `LocalStorageHealth` / `checkIntegrity()` |
| 57 | `getIconForFileType` / `getIconColorForFileType` (импортируются 14 модулями, не вызываются) |

Плюс 586-строчный `extended_image_demo_screen.dart` — он **не мёртвый**, а хуже:
зарегистрирован в боевом роутере и доступен без авторизации.

Файлы-гиганты: `backend_chat_provider.dart` 4 927, `chat_detail_screen.dart`
3 477, `message_bubble.dart` 1 625, `profile_shared_media_tab_view.dart` 1 507,
`chat_input_bar.dart` 1 409 (лимит проекта — 1 000).

Дубли: три бутстрапа видеоплеера, два свайп-движка, две реализации «это бот»,
две полосы результата голосования, reply-превью дважды в одном `build`,
панели «редактирование» и «ответ» — копипаста на ~120 строк (и она уже
разошлась: «Обработка…» против «Обработка файла…»).

---

## Безопасность

**`SEC-4`** (`ordinary_e2ee_service.dart:1080`) — ручное сопряжение: код
`niosmess-e2e:...` принимается как есть, проверяются только самозаявленные поля,
и в выбранный из него `target_key` шифруется весь keyring со всеми эпохами плюс
recovery-код серверного бэкапа. В auto-enrollment (831–893) проверки есть; в
ручном пути — нет ни proof NiosID, ни привязки ключа к аккаунту.

**`SEC-3`** — расхождение двух агентов разрешено кодом:

- Android: `MainActivity.kt:43-48` ставит и снимает `FLAG_SECURE` — работает.
- iOS: обработчика канала нет вообще (grep по `ios/` пуст), исключение в
  `ScreenSecurityService` проглатывается. На Windows/macOS/web — так же.
- Оба тумблера на экране секретных чатов (`secureScreenshotsInSecretChats`,
  `linkPreviewsInSecretChats`) **не читает никто**: вызовы `setSecureFlag`
  зависят только от `isSecret`.

Что уже сделано правильно (проверено, не трогать): ключи и журнал в
`flutter_secure_storage`, копирование в секретном чате отключено, путь медиа
валидируется (`_safeId`, `p.isWithin`), креды не логируются.

---

## Rust: вердикт

**Не переписывать.** Три независимых взгляда (core/services, UI-слой, интернет)
сошлись: выигрыш не там, где ожидался, а цена высокая.

Замеры на Dart 3.14 AOT (реальные, не оценки): Ed25519 verify **2.12 мс**,
X25519 **0.61 мс**, AES-GCM 1 КБ **55 µs**, FFI-вызов **6.5–9.3 нс**,
`Isolate.run` **92 µs**. Изолят убирает jank, но не CPU — это и есть дешёвый
шаг, который закрывает большинство проблем.

Кандидаты, прошедшие фильтр:

| Место | Что | Вердикт |
|---|---|---|
| `services/bluetooth_mesh/mesh_packet.dart:222-245` | 2× Ed25519 verify + 2× SHA-256 на каждый BLE-пакет | `rust-candidate` (BLE нет на web) |
| `services/audio/voice_filter_processor.dart:168-189` | DSP 4–7 млн сэмплов синхронно | `rust-candidate` |
| `services/ordinary_e2ee/ordinary_e2ee_codec.dart:297` | крипто на сообщение | `isolate-first` + батч |
| `services/secret_chat/secret_journal.dart:298` | журнал: json+AES+flush | `isolate-first` |
| `models/api/message_model.dart:314` | `DateTime.tryParse` 32 µs × 2000 = 46–92 мс | `isolate-first` (веб — Rust→wasm) |
| `core/utils/docx_parser.dart:95` | zip + regex | `isolate-first` (`compute`) |
| `core/utils/message_preview_text.dart:36` | markdown→plain 40–473 µs на чат | `isolate-first` + кэш |

Ключевые факты против:

1. `nios_mls` — не «MLS на Dart», а обёртка над `openmls` (Rust). В
   `pulse_flutter` он вообще не подключён, а его цена — **5.7 МБ на ABI** и
   942 КБ wasm.
2. `cryptography_flutter` не закрывает Android: Ed25519/X25519 там только Apple.
3. Приложение собирается под **web**, где FFI нет: Rust возможен только как
   wasm-модуль, и это отдельная сборка с отдельными багами.
4. Уже есть дешёвые альтернативы: `Isolate.run` используется в 4 местах проекта,
   и именно там проблем нет.

Порядок действий, если хочется скорости: (1) батч-изолят для E2EE, (2) не
парсить даты строкой 2 000 раз, (3) кэш preview-текста, (4) `compute` для DOCX.
Rust — только если после этого BLE-mesh или аудио всё ещё будут упираться.

---

## План по волнам

**Волна 0 — безопасность и враньё в UI (полдня).**
`SEC-4` (описание и решение владельца), мёртвые тумблеры, iOS-заглушка честно
или реализована, дебаг-роут из прода.

**Волна 1 — M3E-мелочи с большим охватом (день).**
`StyleVariant` в `IconButtonThemeData`, сквиркл в `m3_modal_surface`, hover в
`TouchContainer`, `StateProvider` → `NotifierProvider`, `Colors.white` ×22,
`PopupMenuButton` в доке звонка.

**Волна 2 — движение (день-два).**
Восемь правок из таблицы + свести 7 рукописных анимаций на готовые блоки,
добавить reduced motion двум оставшимся.

**Волна 3 — лаги (2–3 дня).**
Батч-изолят для E2EE и журнала, `fromSeed` из пикера в кэш, `notify()` в
звонках, `select` в E2EE-настройках, `InteractiveMessage.parse` в кэш по строке.

**Волна 4 — захламлённость (день).**
Удалить 2 200 строк мёртвого кода, свести панели «ответ/редактирование», один
бутстрап плеера, два свайп-движка, две «это бот».

**Волна 5 — архитектура (недели, отдельным планом).**
Разрезать `backend_chat_provider` на 5 файлов, вынести `chat_detail_screen`,
развязать auth-хаб (token/сессия — в низком модуле без сокета и секретов),
убрать импорт providers из repositories.

**Волна 6 — l10n.**
181 строка в arb, начиная с `m3_file_picker_bottom_sheet.dart`.

---

## Что проверено и в порядке

Чтобы не переделывать зря:

- Список сообщений: ленивые slivers, O(1) `idToIndex`, свои `RepaintBoundary`,
  стабильные ключи, `addAutomaticKeepAlives: false`.
- Ввод изолирован от списка: `RepaintBoundary`, `setState` только на переходе
  пусто↔непусто, дебаунс черновика, троттлинг typing.
- Ноль `MaskFilter.blur`, ноль `IntrinsicWidth/Height`, ноль
  `AnimationController` в `build()`, ноль `operator ==` у `Widget`.
- Пружины нормализованы, overshoot не применяется к `Opacity`.
- `TouchContainer` по умолчанию `Clip.none`, state layer — через
  `foregroundDecoration`.
- Кэш темы — LRU на 64 `ThemeData`.
- Тяжёлое уже вынесено в 4 местах: файловая крипта, стикеры, обход storage,
  архив сообщений.
- Роутер в redirect не читает storage/JSON, `pageKey` фиксирован.
- Утечек контроллеров/подписок в звонках нет; `context` после `await` всегда
  под `mounted`.
- Модели immutable, внешних мутаций полей нет.

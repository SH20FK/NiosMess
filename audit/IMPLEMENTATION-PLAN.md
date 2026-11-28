# Рабочий план NiosMess

Дата: 2026-11-28. Версия плана: 2 (заменяет предыдущие редакции).
Основание: `audit/verified.json` (154 находки, из них 76 подтверждено,
29 понижено, 10 отклонено, 39 — мелочь UI/l10n вне фильтров скептиков),
`audit/RUST-AND-SIZE.md`, замеры из `audit/verify/*.json`.

---

## 0. Статус на сейчас

Версия: **3.154.0+4348** (изменения в рабочем дереве, не закоммичены).

| Сделано | Где | Проверка |
|---|---|---|
| Сжатие Material Symbols в Windows и Web | `.github/workflows/build.yml` | YAML валиден; ждёт первого прогона CI |
| Удалены 4 неиспользуемых фото | `assets/developers/` | `team.dart` ссылается только на 2 файла; тест поправлен |
| `StyleVariant.material3Expressive` глобально | `core/theme/app_theme.dart:227` | 83 теста M3E/модалок |
| Сквиркл поверхности модалок | `core/modal/m3_modal_surface.dart:118` | `m3e_design_audit` зелёный |
| Hover в `TouchContainer` | `widgets/common/touch_container.dart` | `touch_motion`, analyze |
| `Colors.white/black` 19 из 22 | 5 файлов | 3 остались как бренд-монограммы |
| `PopupMenuButton` → `MenuAnchor` | `widgets/calls/call_control_dock.dart` | тесты звонков |
| `statusDanger` удалена | `core/theme/app_colors.dart` | grep = 0 |
| Mesh: 3 → 2 верификации + батч-изолят | `mesh_packet`, `mesh_router`, `bluetooth_mesh_service`, `ordinary_e2ee_*` | новый тест, 39 тестов mesh/E2EE |
| Пикер цвета, тик звонков, слайдеры обоев | `custom_color_picker_sheet`, `call_session_provider`, `wallpaper_slider_field` | 2 новых теста |
| Мёртвый код ≈469 строк + 2 экрана | см. волну E | analyze по проекту = 0 issues |
| Дебаг-роут за `kDebugMode` | `router/app_router.dart` | в release маршрута нет |
| Мёртвая проводка настроек | `ui_settings_provider.dart` | grep = 0 |
| Волна C: 11 правок движения | 14 файлов (звонки, баблы, просмотрщик, документ, профиль, стример) | 210 тестов, новый `smooth_text_streamer_test` |
| Волна F: 88 строк → l10n | 5 файлов + три файла локализации | `gen-l10n` exit 0, кириллический grep пуст |
| D3: E2EE батчем в изолят | `ordinary_e2ee_service/codec`, `backend_chat_provider` | 50 сообщений: 0 тиков → 101, худший разрыв 4.6 мс; 50 тестов |
| D4: разбор кэша в изоляте | `core/storage/encrypted_message_cache.dart` | UI-блок 33–35 мс → 6–8 мс, `fromJson` на UI = 0 |
| D7: DOCX в `compute` | `core/utils/docx_parser.dart`, `native_file_viewer_screen` | 36–49 мс → 4 мс, скелетон вместо спиннера |
| D8/D10: `select` + Hive | `ordinary_e2ee_settings`, `contacts_cache_sync` | 0 уведомлений на чужое сообщение; 0 лишних записей |
| E1: стек обоев удалён | 25 файлов, 282 ассета, входы, l10n, prefs | **−12 978 строк**; `analyze` 0 issues, suite 1894 passed |
| D11: не выносится | `secret_chat_engine` | последовательный ratchet + AAD журнала; ограничение задокументировано |

Полный гейт после всех правок: `flutter analyze --fatal-infos` — **No issues found**,
`flutter test test/suite_test.dart` — **1916 тестов, все прошли**.

| Ждёт решения владельца | Почему |
|---|---|
| Удаление 4 фото команды (−5 МБ) | возможно, лежат на будущее |
| `StyleVariant` для `IconButton` | меняет все 128 кнопок: 48-круг → 40 + `StadiumBorder` |
| Сведение дублей с разошедшимся поведением | бот-детект, свайп-ответ, стикер-статус |
| Эмодзи: lazy-load (−10.1 МБ) или отказ от NotoColorEmoji (−10.2 МБ) | влияет на офлайн и на вид |

## 1. Правила процесса

1. Одна волна — одна ветка `fix/<волна>`, один PR, мёрж только на зелёном CI.
2. Внутри волны — отдельные коммиты по задачам; каждая задача самодостаточна и
   откатывается одним `git revert`.
3. Гейт перед каждым коммитом: `dart analyze --fatal-infos --fatal-warnings` +
   `dart test` (в проекте принято `dart test`, не `flutter test`).
4. Задачи с пометкой **решение** не начинаются без ответа владельца.
5. Версия и `assets/CHANGELOG.md` — по протоколу `AGENTS.md`, в конце волны,
   а не в каждом коммите.
6. Правки производительности принимаются только с замером до/после.
7. Правки M3E — со скриншотом до/после на трёх экранах: чат, настройки, звонок.

## 2. Порядок: почему именно такой

1. **Размер** — эффект мгновенный, риск нулевой, виден пользователю по размеру
   установки. Начинаем с того, что нельзя сломать.
2. **M3E-мелочи** — дешёвые правки с охватом на всё приложение (форма модалок,
   hover, мёртвые провайдеры). Готовят почву для движения.
3. **Движение** — то, что просил владелец («побольше анимаций»), но только на
   подтверждённых блоках и с гейтом reduced motion.
4. **Лаги** — самое дорогое по времени; начинается с mesh и E2EE, где замеры
   уже есть.
5. **Захламлённость** — удаление 12 тыс. строк. Идёт после правок, чтобы не
   тащить мёртвый код через конфликты.
6. **Локализация** — механическая, можно параллелить с волной 5.
7. **Архитектура** — отдельный срок, после того как быстрые волны закрыты.

---

## Волна A — размер (оценка 0.5 дня + решение по эмодзи)

| ID | Задача | Файлы | Проверка | Риск | Статус |
|---|---|---|---|---|---|
| A1 | Сжатие Material Symbols в Windows/Web | `.github/workflows/build.yml` | `--analyze-size` до/после; в артефакте шрифты 9.6 МБ вместо 33 | низкий | **сделано**, ждёт CI |
| A2 | Удалить 4 неиспользуемых фото | `assets/developers/` | `grep` по именам = 0; размер `assets/` −5.0 МБ | низкий | **решение** |
| A3 | Эмодзи: lazy-load или отказ от NotoColorEmoji | `assets/emoji/animated/`, `pubspec.yaml` | размер −10 МБ; офлайн-проверка | средний | **решение** |
| A4 | Baseline размеров | CI | таблица: Android AAB, Windows EXE, Web | — | вместе с A1 |

**Готово, когда:** `assets/` < 40 МБ, артефакты Windows/Web собраны, размеры
зафиксированы в PR.

---

## Волна B — M3E (оценка 1.5 дня)

| ID | Задача | Файл:строка | Проверка | Риск |
|---|---|---|---|---|
| B1 | `StyleVariant` для `IconButton` | `core/theme/app_theme.dart:227` | скриншоты до/после; все 128 кнопок одного вида | **решение** (меняет вид) |
| B2 | Сквиркл в поверхности модалок | `core/modal/m3_modal_surface.dart:118` | `RoundedSuperellipseBorder` + `AppRadiiTheme`; смена радиуса в настройках видна в шитах | низкий |
| B3 | Hover у `TouchContainer` | `widgets/common/touch_container.dart:194` | 25 call-sites реагируют на наведение на Windows/Web; вложенных `InkWell` нет | низкий |
| B4 | `StateProvider` → `NotifierProvider` | `e2ee_status_card`, `e2ee_verification_sheet`, `security_status_chip` | `grep StateProvider` = 0 | низкий |
| B5 | `Colors.white/black` → `colorScheme` | 5 файлов, 22 вхождения | `grep` = 0; проверка в тёмной теме | низкий |
| B6 | `PopupMenuButton` → `MenuAnchor` | `widgets/calls/call_control_dock.dart:215` | открывается, клавиатура работает | низкий |
| B7 | Мёртвая константа `statusDanger` | тема | `grep` = 0 | низкий |

**Готово, когда:** правила 4, 5, 7, 9 из `AGENTS.md` не нарушаются нигде
(`grep` = 0), скриншоты приложены.

---

## Волна C — движение (оценка 1 день)

Только подтверждённые верификатором пары «место → блок». Всё на существующих
блоках, новых классов не заводим.

| ID | Место | Блок | Что даёт |
|---|---|---|---|
| C1 | `active_video_call_screen.dart:390` | `M3SpringSwitcher(fade)` | смена раскладки звонка без прыжка |
| C2 | `message_bubble.dart:421` | `M3PressScale` | отклик на long-press (главный жест) |
| C3 | `media_viewer_screen.dart:392` | `MediaHero` | видео перелетает, как картинки |
| C4 | `bubble_upload_overlay.dart:159` | `M3SpringSwitcher` | 5 состояний аплоада без скачка |
| C5 | `legal_viewer_screen.dart:242` | `M3SpringSwitcher` + `Row` вместо `actions` | поиск появляется плавно |
| C6 | `chat_members_screen.dart:118` | `M3Reveal` | шит не дёргается при поиске |
| C7 | `chat_input_bar.dart:1326` | `M3SpringSwitcher` (1 место, не 4) | икона отправки/микрофона |
| C8 | `app_illustration.dart:113` | `M3Entrance` | убрать 65 строк ручной копии |
| C9 | `chat_empty_state.dart:131` | `M3Entrance` | единая кривая |
| C10 | `profile_screen.dart:657` | `M3SpringSwitcher` + вынести `layoutBuilder` в блок | одна политика переходов |
| C11 | `SmoothTextStreamer`, `create_group_members_screen:93` | гейт `reduceMotion` | reduced motion соблюдается везде |

**Не делать** (отклонено верификатором): `outgoing_call_screen:199`,
`settings_about:462`, `chat_detail_fab:40`, `sessions_screen:138` в текущем
виде — блоки не подходят по API. Для них нужны доработки блоков (`direction`,
`Animation`-параметр, `child`), это отдельная задача на полдня.

**Готово, когда:** при `MediaQuery.disableAnimations: true` ни одна из правок
не анимирует; в release нет новых пропущенных кадров на смене таба и открытии чата.

---

## Волна D — лаги (оценка 4 дня)

| ID | Задача | Файл:строка | Замер | Проверка |
|---|---|---|---|---|
| D1 | Mesh: убрать дубль Ed25519 (3→2) | `mesh_packet.dart` + `ordinary_e2ee_service.dart` | 2.4 мс/verify, ~8.3 мс/пакет | p95 parse+decrypt до/после; restore 384 пакетов |
| D2 | Mesh: батч в изолят (restore/outbox) | `bluetooth_mesh_service.dart` | restore ≈0.6 с | первый кадр не блокируется |
| D3 | E2EE: страница одним `Isolate.run` | `ordinary_e2ee_codec.dart:297` | 4.5 мс/сообщение → 360 мс на 80 | открытие чата 300 сообщений: нет кадров > 16 мс от крипто |
| D4 | Кэш: 2000 `fromJson` внутрь изолята | `encrypted_message_cache.dart:335` | подтверждено | загрузка кэша не блокирует кадр |
| D5 | Пикер цвета: `fromSeed` из `build` | `custom_color_picker_sheet.dart:75` | 0.78 мс/кадр | перетаскивание 60 fps |
| D6 | Звонки: `notify()` без смены identity | `call_session_provider.dart:63-67` | ~1.5 перестройки/с | 1/с максимум |
| D7 | DOCX: `compute` + один проход | `docx_parser.dart:95` | 23 мс/310 КБ, 73 мс/1 МБ | `initState` не блокирует кадр |
| D8 | E2EE-настройки: `select` | `ordinary_e2ee_settings.dart:581` | подтверждено | страница не перестраивается на сообщение |
| D9 | Обои: `setState` корня на каждое движение слайдера | `wallpaper_studio` | подтверждено | слайдер не перестраивает превью |
| D10 | Контакты: запись Hive на каждое сообщение | `contacts_screen.dart:303` | подтверждено | запись только при изменении |
| D11 | `secret_chat_engine:731` (100×1-2 мс) | секретные чаты | подтверждено | нет фризов при синке |
| D12 | `chat_list:1006` — O(1) индекс | инбокс | low | без `indexWhere` в кадре |

**Порядок внутри волны:** D1 → D2 (сразу видно), D3 → D4 (крипто), D5, D6, D9
(мелкие), затем D7, D8, D10–D12.

**Готово, когда:** по каждому пункту есть числа до/после; `perf-status.md`
показывает fixed, а не still.

---

## Волна E — захламлённость (оценка 2 дня)

| ID | Что | Строк | Особенность |
|---|---|---|---|
| E1 | Стек обоев: painter + `material_symbols_data` | 10 634 | `material_symbols_data` нужен **тестам** — перенести в `test/` |
| E2 | `core/worker/` | 534 | используется тестом — сначала тест |
| E3 | Мёртвый стек звонков | 572 | — |
| E4 | 3 экрана без ссылок | 273 | — |
| E5 | `chat_state_surface`, `adaptive_glass` | 207 | импорт в `chat_detail:84` вхолостой |
| E6 | `ApiClient`, `LocalStorageHealth`, 2 функции иконок, `isLink` | ~220 | `api_provider` нужен тесту |
| E7 | Мёртвая проводка настроек (2 поля) | 22 | UI их не показывает |
| E8 | Дебаг-демо из боевого роутера | 591 | **не удалять**, а спрятать за `kDebugMode` |
| E9 | 3 копии counted-stream в `_httpMultipartUploadOwned` | — | реальный дубль в загрузке |

**Отклонено:** `comment_thread.dart` (живой), `BotDetector` (6 вызовов).

**Готово, когда:** `grep` по именам пуст, `dart analyze` + `dart test` зелёные,
`lib/` потерял ~12 тыс. строк.

---

## Волна F — l10n (оценка 2 дня, параллелится)

181 UI-строка мимо `context.l10n`: начать с `m3_file_picker_bottom_sheet.dart`
(22), `chat_creation_surfaces.dart`, `support_center_screen.dart`.
Проверка: `flutter gen-l10n` + переключение на EN, русского в UI не остаётся.

---

## Волна G — архитектура (отдельный срок, 1–2 недели)

| ID | Задача | Критерий |
|---|---|---|
| G1 | `backend_chat_provider` (4927) → 5 файлов по нотифаерам | ни один файл > 1200 строк, тесты по нотифаерам |
| G2 | `chat_detail_screen` (3477, State 2496) → экран + контроллеры AI/загрузок/действий | State < 800 строк |
| G3 | Auth-хаб: token/сессия в низкий модуль | 0 циклов вокруг `auth_provider` |
| G4 | `repositories` без импорта `providers` | `grep` = 0 |
| G5 | UI без прямых импортов `repositories/` (30 в 27 файлах) | `grep` = 0 |

**Готово, когда:** циклы `auth_provider`/`app_router` отсутствуют, граф
зафиксирован в PR.

---

## Rust: гейт, а не вера

1. D1+D2 сначала. Замер после них: `verifies/s`, p95 `parse+decrypt`.
2. Rust только если **p95 > 50 мс** или **≥ 10 верификаций/с** после D1.
3. Спайк на одной функции `MeshPacket.verify` через `flutter_rust_bridge`,
   только Android + Windows.
4. Отказ: прирост < 20% времени кадра или APK +3 МБ.

Ожидание: при текущем трафике D1+D2 достаточно. Аудио (0.2–0.44 с на 60 с
записи) закрывается `Isolate.run`, Rust не нужен.

---

## Метрики

| Метрика | Сейчас | После волн A–E |
|---|---|---|
| `assets/` | 62.8 МБ | < 30 МБ |
| Мёртвый код | ≈11 933 строки | 0 |
| Файлы > 1000 строк | 5 | 5 (это волна G) |
| `StateProvider` / `Colors.white` / `PopupMenuButton` | 0 / 3 бренд-монограммы / 1 | 0 / 3 (осознанно) / 0 |
| Строки мимо l10n | 181 | 0 в UI |
| P0/P1 прошлого perf-аудита «still» | 44 | < 10 |
| Открытые high из аудита | 8 | 0 |

## Открытые вопросы (нужны до старта волн)

1. Фото команды: 4 файла на будущее или удаляем?
2. `StyleVariant`: включаем M3E-размеры кнопок глобально или только на новых экранах?
3. Эмодзи: lazy-load с офлайн-фолбэком или отказ от NotoColorEmoji?
4. Дубли с разошедшимся поведением (бот-детект, свайп, стикер-статус): какое
   поведение считаем правильным?
5. Начинаем с mesh (D1) или сначала закрываем A2/B2/B3 (полдня, видно сразу)?

# Инбокс и навигация NiosMess: доступность, адаптивность, локализация, тесты

Дата: 2026-11-22. Состояние кода: `HEAD = a0536c42` (`v3.137.1+4307`).
Область: оболочка (`main_shell_screen.dart`), нижний бар, web-rail, инбокс
(`chat_list_screen.dart`, `chat_tile.dart`, шапка, фильтры, FAB, свайп, пустые состояния,
модалка действий), экраны `features/chats/presentation/`, тесты по этим виджетам.

Правила чтения:
* **Факт** — то, что я прочитал в файле, путь:строка указан рядом.
* **Оценка** — расчёт по значениям токенов (контраст, ширины), формула названа.
* **Догадка** — помечено словом «догадка», в коде подтверждения нет.

Чего я **не** делал: **не запускал скринридер** (TalkBack/NVDA/VoiceOver) и **не проверял
жесты на живом устройстве**. Раздел «что слышит скринридер» — это вывод из дерева `Semantics`
в коде (`chat_tile.dart:195-225`), а не запись реального синтеза речи. Порядок обхода
фокуса тоже выведен из типов виджетов, а не из живого трекинга Tab. Контраст — расчёт по
WCAG-формуле на значениях из `app_surfaces.dart:20-61`, не замер пипеткой.

---

## 0. Краткие выводы

1. **Критично.** Глобальный `textScaler` перезаписывается настройкой приложения
   (`main.dart:414-416`), поэтому системный размер шрифта Android/Windows/браузера
   игнорируется: максимум — 1.3 (`ui_settings_provider.dart:11-19`). Пользователь,
   которому нужен 2.0, получить его не может.
2. **Критично.** Строка чата и пилюли фильтров **не фокусируются с клавиатуры**: внутри
   `GestureDetector` (`touch_container.dart:205`, `chat_filter_bar.dart:285`), `Focus`
   нигде нет. На Windows/web Tab ходит только по кнопкам шапки, FAB и таб-бару — список
   и фильтры недостижимы.
3. **Серьёзно.** `Semantics`-метка строки (`chat_tile.dart:195-211`) не содержит **превью
   последнего сообщения и времени**, а «печатает…» в инбоксе вообще не попадает в метку
   (`chat_list_screen.dart:466-470` передаёт текст в `subtitle`, `isTyping` не передаёт).
   Скринридер теряет два из четырёх информационных полей строки.
4. **Серьёзно.** Русские литералы в семантике и превью: «выбран», «закреплён», «без звука»,
   «Ключи не совпадают» (`chat_tile.dart:50-53`), плюс весь секретный пустой стейт
   (`chat_empty_state.dart:250-312`) и весь экран поиска (`inbox_search_screen.dart:106-484`).
   В английской локали скринридер читает «Secret chat, без звука».
5. **Серьёзно.** Горизонтальная полоса фильтров на 320–412 px не скроллится мышью:
   drag для мыши отключён (`main.dart:452-456`), колесо даёт `dy`, а горизонтальный
   `Scrollable` читает только `dx` (Flutter SDK `scrollable.dart:946`), скроллбара нет
   (`chat_filter_bar.dart:175-186`, `main.dart:488-497` — только при наличии controller).
   Пилюли при этом не фокусируются. Итог: «Боты» на узком окне недостижимы без тачскрина.
6. **Серьёзно.** Пилюля фильтра — 36 dp (32 в compact), `chat_filter_bar.dart:194,294`;
   тест это **закрепляет** (`neutral_inbox_test.dart:467`, `chat_list_m1_test.dart:194`).
7. **Серьёзно.** Две разные навигации для «десктопа»: web ≥840 получает rail
   (`main_shell_screen.dart:452,627-633`), нативный Windows на любой ширине — нижний бар
   (`:647-655`). Развилка зашита в тест (`web_workspace_test.dart:356-363`).
8. **Серьёзно.** Split-view включается только по ширине ≥840 (`:451`), без учёта высоты:
   телефон в ландшафте 844×390 получает список 360 + панель чата.
9. **Мелко, но заметно.** `Semantics(selected: true)` и литерал «выбран» в метке
   дублируют состояние (`chat_tile.dart:200,219`) — TalkBack скажет «выбран, выбран».
10. **Хорошо и надо сохранить:** `M3RouteTabSwitcher` исключает неактивные вкладки из
    семантики и фокуса (`m3_route_tab_switcher.dart:204-209`); скрытый FAB исчезает из
    дерева доступности (`inbox_compose_button.dart:32-35`); у строки одно merged-узло
    с `excludeSemantics` (`chat_tile.dart:217-225`); все анимации в области уважают
    `context.reduceMotion`.

---

## 1. Доступность

### 1.1 Семантика по интерактивным элементам

| Элемент | Роль / метка в коде | Что реально объявится | Проблема |
|---|---|---|---|
| Строка чата | `Semantics(button: true, selected:, label: <склейка>, excludeSemantics: true, onTap:, onLongPress:)` — `chat_tile.dart:217-225` | «Ирина, 2 непрочит., Прочитано, кнопка» | нет превью и времени; нет `customSemanticsActions` для «прочитать» |
| Пилюля фильтра | `Semantics(button: true, selected: true/false)` + `GestureDetector` — `chat_filter_bar.dart:281-289` | «Все, кнопка» / «Все, выбрано» | не фокусируется; нет `inMutuallyExclusiveGroup` (это не «кнопка», а сегмент набора) |
| Счётчик в пилюле папки | `Text` внутри `_PillBadge` — `:346-356` | «5» отдельным узлом после метки | число без смысла: «Работа 5» вместо «5 непрочитанных» |
| Кнопка поиска в шапке | `IconButton(tooltip:)` 48×48 — `chat_list_header.dart:126-135` | «Поиск сообщений, кнопка» | ок |
| Аватар-настройки в шапке | `IconButton(tooltip: tabSettings)` 48×48 — `:136-149` | «Настройки, кнопка» | по аватару ждут «Профиль»; метка не про аватар |
| Заголовок «Чаты» | обычный `Text` в `AppBar` — `:116-124` | просто текст | нет `Semantics(header: true)`, нельзя прыгнуть по заголовку |
| Нижний бар | `NavigationBar` — `app_bottom_nav.dart:112-150` | «Чаты, вкладка 1 из 3» + бейдж | бейдж скрыт на активной вкладке (`:146`), т.е. счётчик непрочитанных не звучит, когда пользователь как раз на «Чатах» |
| Web-rail | `NavigationRail(labelType: none)` — `web_workspace_navigation.dart:18-25` | метка есть (Flutter держит скрытый `Visibility.maintain` для семантики, SDK `navigation_rail.dart:776`) | визуально подписей нет и `Tooltip` нет → зрячий мышиный пользователь угадывает иконки |
| FAB | `FloatingActionButton(tooltip: inboxCreateMenu)` — `inbox_compose_button.dart:36-47` | «Создать, кнопка» | ок; при скрытии уходит из дерева (`:32-35`) |
| Пункт модалки действий | `Semantics(button: true, enabled:)` + `InkWell` 48 dp — `chat_actions_modal.dart:198-207` | «Отметить прочитанным, кнопка, недоступно» | ок |
| Разделитель панелей | `MouseRegion` + `GestureDetector`, 8 dp — `main_shell_screen.dart:866-891` | ничего | нет роли, нет клавиатуры |
| Пункт speed-dial | `GestureDetector` без `Semantics` — `m3_speed_dial_fab.dart:282-284` | текст + «нажать» (роль не «кнопка») | мёртвый код: в `lib/` не используется (см. §5.2) |

### 1.2 Что слышит скринридер для одной строки чата

Склейка по порядку (`chat_tile.dart:195-211`): `title, [Черновик: …], [N непрочит.],
[выбран], [закреплён], [без звука], [Секретный чат], [Ключи не совпадают], [печатает…],
[Прочитано|Отправлено], [статус отправки]`.

| Состояние строки | Метка (RU-локаль) | Замечания |
|---|---|---|
| Обычная, прочитана | «Ирина, Отправлено» | нет превью, нет времени |
| Непрочитанная (2) | «Ирина, 2 непрочит., Прочитано» | счётчик есть, превью нет; «2 непрочит.» — сокращение, озвучивается как «непрочит» |
| Без звука (muted) | «Ирина, 2 непрочит., без звука» | при английской локали: «Irina, 2 unread, **без звука**» — смешение языков |
| Закреплённая (pinned) | «Ирина, …, закреплён» | **недостижимо из инбокса**: `ChatTile.isPinned` не передаётся (`chat_list_screen.dart:456-539`), в модели нет поля pin (`chat_summary_model.dart:67-97`). Метка живёт только в тесте (`chat_tile_inbox_regressions_test.dart:695`) |
| Печатает | «Ирина» (и всё) | видимый текст «печатает…» приходит в `subtitle` (`chat_list_screen.dart:466-470`), а `subtitle` в метку не входит; `isTyping` в инбоксе не выставляется → и точки, и `chatTypingMultiple` не работают в реальном списке |
| Секретная | «Ирина, Секретный чат» | ок (ключ локализован, `app_ru.arb:10`) |
| Ошибка отправки | «Ирина, Не отправлено — повторите в чате» | ок, но фраза длинная для строки списка |
| Несовпадение ключей | «Ирина, Секретный чат, **Ключи не совпадают**» | русский литерал при любой локали |
| Черновик | «Ирина, Черновик: **Черновик:**» | дубль: `draftLabel` уже равен «Черновик:» (`app_ru.arb:68`), метка добавляет `inboxDraftSemantics` = «Черновик» (`:67`) |
| Выбранная (split) | «Ирина, выбран, …» + платформенное «выбрано» | дубль состояния |

### 1.3 Цели нажатия (реальные числа из кода)

| Элемент | Размер | Норма 48×48 | Источник |
|---|---|---|---|
| Строка чата | 76 dp (64 compact) × вся ширина | ок | `chat_tile.dart:92-93` |
| Кнопки шапки (поиск, аватар) | 48×48 | ок | `chat_list_header.dart:130-133,140-143` |
| Пилюля фильтра | **36 dp** (32 в compact) высотой | **нет** | `chat_filter_bar.dart:194,294`; тест закрепляет 36 (`neutral_inbox_test.dart:467`, `chat_list_m1_test.dart:194`) |
| Трек фильтров | 44 dp | нет (внутри 36) | `chat_filter_bar.dart:78-79` |
| FAB | 56×56 | ок | `main_shell_screen.dart:661`, тест `main_shell_inbox_pane_test.dart:147-148` |
| Пункт нижнего бара | 80 dp высотой, 1/3 ширины | ок | `app_bottom_nav.dart:91,114` |
| Web-rail | 88 dp + 1 dp разделитель | ок | `web_workspace_navigation.dart:24`, `main_shell_screen.dart:632` |
| Пункт модалки действий | 48 dp | ок | `chat_actions_modal.dart:205-206` |
| Крестик «убрать участника» | **≈18×18** (иконка 14 + padding 2) | **нет, критично** | `create_group_members_screen.dart:341-356` |
| Ручка изменения ширины панели | **8 dp** шириной | нет | `main_shell_screen.dart:880` |
| Точка присутствия | 14 dp (декоративная) | — | `chat_tile.dart:330-345` |

### 1.4 Клавиатура и фокус (Windows/web)

Факты:
* Единственный `Focus` в инбоксе — обёртка без `autofocus` (`chat_list_screen.dart:173`),
  внутри неё нет ни одного фокусируемого узла списка.
* `ChatTile` → `Semantics` → `TouchContainer` → `GestureDetector`
  (`touch_container.dart:205-238`). `Semantics(onTap:)` даёт активацию скринридеру, но
  **не** делает узел фокусируемым: Tab строку не увидит, Enter не откроет чат.
* Пилюли фильтров — то же (`chat_filter_bar.dart:285-288`): Tab их не видит,
  Enter/Space не переключают. Клавиатурный пользователь физически не может сменить фильтр.
* Горячие клавиши есть только на поиск и вкладки: `Ctrl/Cmd+K` (`chat_list_screen.dart:167-172`),
  `Ctrl/Cmd+Alt+1..3` и `Ctrl/Cmd+Alt+N` (`main_shell_screen.dart:418-446`). Стрелок,
  Home/End, PageUp/Down по списку, «прочитать» с клавиатуры — нет (grep по
  `arrowDown|arrowUp|LogicalKeyboardKey.enter` в области — 0 совпадений).
* Видимого фокус-кольца у кастомных элементов нет (нет `Focus` → нет и состояния
  `WidgetState.focused`); у Material-кнопок кольцо даёт тема по умолчанию
  (`app_theme.dart` не переопределяет `focusColor`).
* Порядок Tab на десктопе: `Ctrl+K`-подсказки нет, а Tab идёт «шапка → FAB → таб-бар»,
  список пропускается целиком.
* `Ctrl+K` в Chrome на web — системный шорткат («поиск в адресной строке»). Перехватывает
  ли его Flutter до браузера — **догадка**, нужна ручная проверка в Chrome/Edge.

### 1.5 Жесты без нежестровой альтернативы

| Жест | Что делает | Альтернатива | Итог |
|---|---|---|---|
| Свайп вправо по строке | «прочитано» (`chat_list_screen.dart:414-430`, `swipe_action_row.dart:64-80`) | долгое нажатие → пункт «Отметить прочитанным» (`chat_actions_modal.dart:112-118`) | для тача есть, **для клавиатуры нет** |
| Свайп отключён у прочитанных | `enabled: chat.unreadCount > 0` (`:416`) | — | жест зависит от данных (и это же отмечал UX-аудит 03) |
| Долгое нажатие по строке | меню действий (`:536`) | ПКМ (`:537-538`), скринридер ( `onLongPress` в `Semantics`) | для клавиатуры нет (нет `Menu`-клавиши/шортката) |
| Долгое нажатие по пилюле/«Все» | управление папками (`chat_filter_bar.dart:90,112`) | только через Настройки → «Чаты» (`settings_chats_screen.dart:40`) | из инбокса клавиатурой недостижимо |
| Горизонтальный скролл фильтров | показывает скрытые пилюли | нет (см. §0 п.5) | на узком окне мышью недостижимо |
| Драг разделителя панелей | ширина списка 260–640 (`main_shell_screen.dart:486-501`) | двойной клик — сброс (`:872`) | с клавиатуры нельзя |

### 1.6 Цвет как единственный сигнал

| Сигнал | Чем ещё продублирован | Оценка |
|---|---|---|
| Непрочитанность | жирность 700 vs 600 (`chat_tile.dart:497,502`) + пилюля с числом | ок |
| Выбранная строка | фон + индикатор 3×20 dp (`:376-397`) + `Semantics(selected)` | ок |
| Выбранная пилюля фильтра | только заливка `secondaryContainer` (`chat_filter_bar.dart:302`); вес намеренно фиксирован w600 (`:241-242`) | **цвет единственный визуальный сигнал**; для семантики — `selected` |
| «Онлайн» | только зелёная точка 14 dp (`chat_tile.dart:326-345`), в семантику не входит | цвет + нет текста → провал |
| Muted-бейдж | фон + рамка `outlineVariant` (`:732-759`), рамка 1.1:1 — практически невидима | де-факто цвет; но в заголовке есть иконка `notifications_off` (`:541-547`) — ок |
| Доставлено/прочитано | разные глифы `done` / `done_all` (`:475-486`) | ок |
| Несовпадение ключей | рамка + иконка + текст ошибки (`:264-269,532-540,632-640`) | ок |

### 1.7 Контраст (оценка по токенам, светлая тема)

Токены: `app_surfaces.dart:20-61` (`#F2F2F2` surface, `#505050` onSurfaceVariant,
`#C7C7C7` outlineVariant, `#DCDCDC` surfaceContainerHigh, `#EFEFEF` surfaceContainerLow).

| Пара | Значение | Норма | Итог |
|---|---|---|---|
| Время/превью: `onSurfaceVariant` на `surface` | ≈7.2:1 | 4.5 | ок |
| Текст непрочитанного: `onSurface` на `surface` | ≈15.2:1 | 4.5 | ок |
| Примечание E2EE под заглушкой: `onSurfaceVariant@0.7`, 12 px (`main_shell_screen.dart:745-751`) | ≈3.5:1 | 4.5 | **провал** |
| Строки безопасности секретного стейта: `onSurfaceVariant@0.85`, 11 px (`chat_empty_state.dart:369-376`) | ≈4.9:1 | 4.5 | на грани |
| Рамка трека фильтров: `outlineVariant@0.28` (`chat_filter_bar.dart:153-155`) | ≈1.1:1 | 3 (граница контрола) | **провал** |
| Заливка трека: `surfaceContainerLow` на `surface` | ≈1.03:1 | 3 | **провал** (границу задаёт только рамка выше) |
| Точка «онлайн» `#22C55E` на `surface` (`app_colors.dart:8`) | ≈2.0:1 | 3 | **провал** |
| Текст muted-бейджа на `surfaceContainerHigh` | ≈5.9:1 | 4.5 | ок |
| Рамка muted-бейджа `outlineVariant` | ≈1.1:1 | 3 | провал (не критично, есть иконка) |
| Разделитель rail/рабочая область (`main_shell_screen.dart:632`) | ≈1.3:1 | 3 | провал (слабая граница региона) |
| Тёмная тема: `onSurfaceVariant` на `#1A1A1A` | ≈9.3:1 (5.2:1 при @0.7) | 4.5 | ок |

Бейдж непрочитанных (`primary`/`onPrimary`) не считаю: контраст задаёт M3-схема и
пользовательский `contrastLevel` (`main.dart:400,406`).

### 1.8 Масштаб текста 1.3 и 2.0

* **Глобально 2.0 недостижим**: `main.dart:410-441` подменяет `textScaler` на
  `TextScaler.linear(fontScale.scale)`, где шкала — 0.85/1.0/1.15/1.3
  (`ui_settings_provider.dart:11-19`). Системные 1.3/1.5/2.0 (Android «Крупный шрифт»,
  Windows «Размер текста», зум текста в браузере) отбрасываются. Это главный
  a11y-дефект: остальные пункты ниже описывают, что будет, если это починить.
* **Строка чата**: жёсткой высоты нет, `Column` внутри `Row` растёт — при 2.0 строка
  станет ≈120 dp вместо 76. Побочно: `ChatTile.rowHeight` (76), `AppHeights.row`
  (`expressive_tokens.dart:234`) и скелетон (`pulse_skeleton.dart` фиксированные метрики)
  перестают совпадать с реальной строкой → прыжок layout при загрузке.
* **Слот времени**: `min(scale(72), ширина*0.42)` (`chat_tile.dart:425-430`), статус — 0.5
  строки. При 2.0 «12.11.2025» обрезается троеточием (тест `chat_tile_inbox_regressions_test.dart:347`
  проверяет формулу, а не читаемость).
* **Шапка**: высота считается как `max(64, scaledTitle + 32)` (`chat_list_header.dart:51-60`) —
  при 2.0 это ≈96 dp, ок. Но в compact-режиме возвращается **фиксированные 56** (`:52`) →
  при 2.0 заголовок 24/1.33 в 56 dp обрезается. Тест `chat_list_header_and_performance_test.dart:112`
  ждёт 64, а compact-высоту не проверяет вообще.
* **Пилюли фильтров**: `max(36, scale(18)+6)` (`chat_filter_bar.dart:193-197`) —
  растут, ок.
* **Нижний бар**: `height: 80` фиксирован (`app_bottom_nav.dart:91,114`), подпись 11 px
  (`:100`); при 2.0 (22 px) иконка 24 + подпись 22 в 80 dp — риск вертикального переполнения.
  Проверено только «без исключений» при 1.8 (`neutral_inbox_test.dart:312-419`).
* **Пустые состояния**: `ChatEmptyState` (не-секретная ветка) — `Center` + `Column`
  без скролла (`chat_empty_state.dart:129-209`) → при 2.0 на низком окне переполнение;
  `EmptyStateWidget` в инбоксе скроллится (`empty_state_widget.dart:40-42`) — ок.
* **Дата/время**: `DateFormat('HH:mm')`, `'dd.MM'`, `'dd.MM.yyyy'` без локали
  (`datetime_helpers.dart:4-7`) → 24-часовой формат и точки для всех локалей.

### 1.9 Reduce motion

Покрыто: скрим шапки (`chat_list_header.dart:90-93`), FAB (`inbox_compose_button.dart:19-31`),
строка/бейдж/точки печати (`chat_tile.dart:183-186,740-742,807-820`), свайп
(`swipe_action_row.dart:82-88`), `ReorderSlide` (`reorder_slide.dart:56`), таб-свитчер
(`m3_route_tab_switcher.dart:63-64,112-115`), нижний бар (`app_bottom_nav.dart:53-57`),
карточка `ChatEmptyState` (`:132-135`), speed-dial (`m3_speed_dial_fab.dart:97-117`).

Не покрыто:
* Переход на экран чата `push('/chat/id')` (`chat_list_screen.dart:533`) — обычный
  `MaterialPage` (`app_router.dart:68-70`), `reduceMotion` не проверяется. В приложении
  есть места, где проверяется (`app_router.dart:83,420`) — значит это пропуск, а не решение.
* `OfflineBanner`: `AnimatedSize`/`AnimatedOpacity` с фиксированными длительностями
  (`offline_banner.dart:16-21`).
* `create_group_members_screen.dart:92-94` — `AnimatedSize` с `Curves.fastOutSlowIn`;
  `:403-405` — `AnimatedContainer` с `M3Durations.short4` без проверки reduced motion.

---

## 2. Адаптивность

### 2.1 Что происходит на разных ширинах

Формулы: `isWide = w >= 840`; `webRail = isWeb && isWide`;
`workspace = w - (webRail ? 89 : 0)`; `maxList = clamp(workspace-340, 260, 640)`;
`listWidth = clamp(360, 260, maxList)` — `main_shell_screen.dart:451-463`.
Список центрируется в `kInboxContentMaxWidth = 640` (`:49,783-789`).

| Ширина | Нативная (Windows) | Web |
|---|---|---|
| 320 | 1 колонка, список 320, шапка 64, нижний бар 80, FAB 56 | то же (rail только с 840) |
| 360 | 1 колонка, список 360 | то же |
| 412 | 1 колонка, список 412 | то же |
| 600 | 1 колонка, список 600 (cap 640 не достигнут) | то же |
| 840 | **split**: список 360 + ручка 8 + панель 472, нижний бар остаётся | **split + rail 88+1**, список 360, панель 383, нижнего бара нет |
| 1200 | split: 360 + панель 832, нижний бар | rail, 360 + панель 743 |
| 1600 | split: 360 + панель 1232, нижний бар | rail, 360 + панель 1143; список можно растянуть до 640 |

Замечания:
* `Breakpoints.expanded (1200)` и `large (1600)` объявлены (`expressive_tokens.dart:192-196`),
  но оболочка их не использует — grep по `Breakpoints.` в `main_shell_screen.dart` даёт
  только `medium` (`:451`). Значит: нет «permanent drawer» на 1600, нет расширенного rail.
* Doc-комментарий `Breakpoints.medium` обещает rail на 600–839 (`expressive_tokens.dart:189-190`) —
  в коде на 600–839 ни rail, ни split, только центрированный список.
* Скачок на 840: было 640-по-центру, стало 360 + панель. Между 640 и 839 список стоит
  по центру с большими полями — приемлемо, но 840 — единственная точка переключения,
  промежуточного состояния (rail без панели) нет.
* Панель чата в split на 840 web — 383 dp шириной (`1150` нет), это уже узко для бабблов
  и медиа (**догадка** в части комфорта, ширина — факт).

### 2.2 Safe area и системные инсеты

* Оболочка: `PulseScaffoldBody(expand: true, topSafe: false, bottomSafe: false)`
  (`main_shell_screen.dart:635-640`) — горизонтальные SafeArea остаются включёнными
  (`pulse_scaffold_body.dart:32-34`), верх даёт вложенный `AppBar` (`chat_list_header.dart:107`),
  низ — `NavigationBar(maintainBottomViewPadding: true)` (`app_bottom_nav.dart:118`).
* **Web-rail стоит вне SafeArea**: `Row[WebWorkspaceNavigation, Divider, Expanded(PulseScaffoldBody)]`
  (`main_shell_screen.dart:625-643`) → в ландшафте с боковым вырезом rail окажется под ним.
* **Двойной учёт нижнего инсета**: `extendBody: false` (`:620`), тело уже заканчивается над
  баром, но список добавляет ещё `viewPadding.bottom` (`chat_list_screen.dart:213-221`).
  `Scaffold` при `extendBody: false` не обнуляет `MediaQuery.padding` для body
  (SDK `scaffold.dart:960-962`) → на жестовой навигации Android внизу списка ~34 dp пустоты
  сверх нужного.
* FAB в split: `bottom: 16 + viewPadding.bottom` только когда есть rail (`:470-472,798-802`) —
  логика верная, комментарий на `:468-469` это объясняет.
* Клавиатура: инбокс не содержит поля ввода, `viewInsets` не учитывается нигде в области —
  ок.

### 2.3 Складные и ландшафт

* `MediaQuery.displayFeatures` не читается нигде в `lib/` (grep — 0 совпадений). Петля
  складного устройства пересечёт список/панель на 840+ без всякой обработки.
* Ландшафтный телефон: 844×390 → `isWide = true` (`:451`) → список 360 + панель 484 при
  высоте 390 (шапка 64 + фильтры 44 + строка 76 → видно ~2.5 строки). Признака «это телефон»
  в условии нет (нет проверки `shortestSide`, `platform`, `capabilities`).
* При 320×800 (тест `chat_list_m1_test.dart:227-262`) проблем нет по исключениям.

### 2.4 RTL

Поддержка языков — только `en` и `ru` (`app_localizations.dart:96-99`), RTL-локали нет.
Тем не менее миграция в RTL сломается в конкретных местах:

| Место | Код | Что будет в RTL |
|---|---|---|
| Градиент затухания фильтров | `main_shell_screen` → `chat_filter_bar.dart:163-173` `centerLeft → centerRight` | затухание останется справа, т.е. на «начале» строки: первая пилюля будет бледной |
| Индикатор выбранной строки | `chat_tile.dart:376-397` `Positioned(left: 8)` | останется слева, хотя строка начинается справа |
| Точка «онлайн» | `chat_tile.dart:327-329` `Positioned(right: -1)` | уедет на внешний край аватара, а не к тексту |
| FAB в панели инбокса | `main_shell_screen.dart:798-801` `Positioned(right:)` | останется справа (в RTL «право» — это start) |
| FAB в телефоне | `Scaffold.floatingActionButton` | ок (Scaffold учитывает Directionality) |
| Свайп | `swipe_action_row.dart:41-43,109,126` `Directionality` + `PositionedDirectional` | **правильно** |
| Rail | `Row` уважает Directionality | **правильно** (rail справа) |
| Панель действий | `chat_actions_modal.dart` — `Row`/`EdgeInsets.symmetric` | ок |

---

## 3. Локализация

### 3.1 Пайплайн (важно для редизайна)

* Рабочая цепочка одна: `l10n.yaml` → `arb-dir: lib/l10n/secret`, вывод в
  `lib/l10n/secret/generated/secret_chat_localizations*.dart`, класс `SecretChatLocalizations`.
  Файлы-источники: `lib/l10n/secret/app_en.arb`, `app_ru.arb`.
* `lib/l10n/app_localizations*.dart` (класс `AppLocalizations`) — **сирота без .arb**:
  генератор настроен только на `secret/`, а исходников для `AppLocalizations` в репозитории нет.
  `context.l10n` — это `AppLocalizations` (`core/localization/l10n.dart:8-11`), к которому
  `SecretChatL10n` (`core/localization/secret_chat_l10n.dart:5-729`) добавляет геттеры из
  `SecretChatLocalizations`.
* Следствие: **новую строку для инбокса нельзя добавить «по правилам»** (AGENTS запрещает
  править сгенерированные `app_localizations*.dart`), её надо класть в
  `lib/l10n/secret/app_*.arb` — то есть в файл с именем «secret», хотя строка про инбокс.
  Это архитектурный долг, который редизайн обязан либо принять, либо починить
  (перевести все ключи в один `arb` и перегенерировать `AppLocalizations`).
* Комментарий-оправдание в `chat_tile.dart:46-49` («the repo ships only generated
  `app_localizations*.dart`, the source .arb files are absent») **неверен**: `arb` есть,
  просто другой. Это не блокер, а незакрытая задача.

### 3.2 Хардкоды в области (русские литералы в виджетах)

| Файл:строка | Литерал | Когда виден |
|---|---|---|
| `chat_tile.dart:50` | `'Ключи не совпадают'` | превью + семантика, во всех локалях |
| `chat_tile.dart:51-53` | `'выбран'`, `'закреплён'`, `'без звука'` | только семантика, во всех локалях |
| `chat_empty_state.dart:250` | `'Секретный чат'` | fallback заголовка |
| `chat_empty_state.dart:261` | `'Здесь используется сквозное шифрование'` | fallback описания |
| `chat_empty_state.dart:278-312` | 5 пар «заголовок/подзаголовок» про шифрование | секретный пустой стейт целиком |
| `main_shell_screen.dart:685` | `'NiosMess Web'` | заглушка правой панели на web |
| `inbox_search_screen.dart:106` | `'Ошибка при поиске: $e'` | ошибка поиска (в т.ч. текст исключения) |
| `inbox_search_screen.dart:171-177` | `'Все'`, `'Чаты'`, `'Сообщения'`, `'Люди'` | скрипки области поиска |
| `inbox_search_screen.dart:243` | `'Поиск по чатам, сообщениям и людям...'` | хинт поля |
| `inbox_search_screen.dart:299-330` | `'Быстрый поиск'`, `'Непрочитанные'`, `'Группы'`, `'Каналы'`, `'непрочитан'` | подсказки пустого запроса |
| `inbox_search_screen.dart:386,396,424,477` | `'Ничего не найдено'`, `'Люди'`, `'Чаты'`, `'Сообщения'` | результаты |
| `inbox_search_screen.dart:461-464,484` | `'Канал'`, `'Группа'`, `'Личный чат'`, `'Сообщение'` | подписи строк |
| `inbox_search_launcher.dart:44` | `'Me'` | имя по умолчанию (мёртвый виджет, см. §5.2) |
| `inbox_search_launcher.dart:113-114` | `'⌘ K'`, `'Ctrl K'` | подсказка шортката |
| `web_workspace_navigation.dart:29` | `'NiosMess'` (tooltip) | tooltip логотипа |
| `people_picker_screen.dart:70,87-90,150,211-212,223-224,237,250-251,287-288,294,301-302` | «Не удалось открыть диалог», «Новый секретный чат», «Имя или @username», «Недавние собеседники» и т.д. | весь экран |
| `create_group_members_screen.dart:66,182,185-186,203,216,234-235,291-292` | «Поиск по имени...», «Новая группа», «Выбрано: N», «Далее (N)», «Ничего не найдено» | весь экран |
| `create_group_details_screen.dart:55,58,64,112-113,125,141-142,167,177,182,195-196,211,219,277,301,338` | «Параметры группы», «Тип группы», «Публичная/Частная», «Создать группу» | весь экран |
| `create_channel_screen.dart:63,69,75,118-119,131,150-151,166,169,184-185,210,220,225,238-239,256,259-260,288,325` | «Новый канал», «Название канала *», «Публичный/Частный», «Создать канал» | весь экран |

Итого: 4 экрана в `features/chats/presentation/` (поиск, выбор людей, создание группы/канала)
не локализованы **вообще** (нет импорта `l10n` в `create_*` вовсе), а `chat_tile` и
`chat_empty_state` — частично.

### 3.3 Форматы

* `formatRelativeTime` (`datetime_helpers.dart:53-91`) — «сейчас/вчера/7 мин/3 д» из
  ручного словаря только для `ru`, fallback `now/yesterday/7m/3d` (`:152-169`);
  `Intl.plural` вызывается, но все ветки возвращают одно и то же (`:171-193`) — для
  русского «мин/д» это неважно, для других языков (польский, украинский) — сломается.
* `DateFormat` без `locale` (`:4-7`): 24 часа и `dd.MM.yyyy` жёстко. Для `en-US`
  ожидается AM/PM и `M/d/yyyy`. Тест фиксирует именно `ru`/`en`-единицы
  (`web_workspace_test.dart:226-253`).
* Счётчик непрочитанных: `chatListUnreadCount` в ru — `'$count непрочит.'` без форм
  множественного числа (сокращение спасает, но «1 непрочит.» — не по-русски).
* В `create_group_members_screen.dart:186,203,216` число подставляется конкатенацией
  («Выбрано: 3», «Далее (3)») — без плюрализации вообще.

### 3.4 Строки, которые не влезут

* `inboxSendFailed` = «Не отправлено — повторите в чате» (31 символ, `app_ru.arb:66`) в
  слот статуса, ограниченный 50 % ширины строки (`chat_tile.dart:425-430`) → на 320 dp
  обрежется до «Не отправлено — по…».
* `chatListNoChats` / `inboxNoUnread` / `inboxCategoryEmpty` — в `EmptyStateWidget`
  центрированы, ок.
* `inboxFilterResetHint` («Выберите «Все», чтобы вернуться ко всем чатам») — 49 символов
  в подзаголовке пустого состояния; ок (обёртка), но кнопка рядом подписана
  `preferencesResetConfirm` = «Сбросить» — слово из раздела настроек, не про фильтры
  (`chat_list_screen.dart:389-395`). Смысловое расхождение.
* Английские строки короче русских везде, кроме `preferencesResetConfirm` — риска
  «не влезет» в EN нет; риск обратный: русские длиннее на 10–20 % в пилюлях фильтров
  (`chatListFilterUnread` = «Непрочитанные») — именно поэтому полоса и скроллится.

---

## 4. Тесты

### 4.1 Что покрыто

`✓` — файл импортирован в `test/suite_test.dart` (значит, гоняется в CI
`flutter test test/suite_test.dart`, `.github/workflows/build.yml:114`).
`—` — файл существует, но в suite не импортирован (в CI не запускается).

| Поведение | Тест | CI |
|---|---|---|
| Строка чата: заголовок/превью/время/аватар | `chat_list_m1_test.dart` «renders title, subtitle, formatted time and avatar» (:60) | ✓ |
| Счётчик > 99 → «99+» | `chat_list_m1_test.dart` «renders 99+ for large unread count» (:109) | ✓ |
| Онлайн-точка (cutout) | `chat_list_m1_test.dart` «renders online status indicator cutout…» (:130) | ✓ |
| Одна семантическая нода + русские подписи состояний | `chat_tile_inbox_regressions_test.dart` «tile exposes a single labelled semantics node» (:695) | **—** |
| Key mismatch озвучивается | там же «key mismatch is announced to screen readers» (:740) | **—** |
| Черновик на 200 % не переполняет | там же «long draft label survives a 200% text scale…» (:128) | **—** |
| Высота 76 при статусе отправки | там же «sending status lives in the time slot and keeps the row at 76» (:273) | **—** |
| Высота 64 в compact | там же «compact tiles keep their 64dp height…» (:323) | **—** |
| Слот времени ограничен масштабом | там же «time slot caps by text scale, not by screen width» (:347) | **—** |
| Печать: цвет + 3 точки | там же «typing preview is primary-tinted with three dots» (:447) | **—** (и это не путь инбокса: `isTyping` не передаётся) |
| Точки статичны при reduced motion | там же (:476) | **—** |
| Muted-бейдж тональный | там же (:517) | **—** |
| Нажатие → 8 % onSurface | там же «pressed tile paints the M3 8% onSurface state layer» (:764) | **—** |
| ПКМ не срабатывает как long press | там же (:804) | **—** |
| Шапка растёт с масштабом текста | там же (:839 — только `heightFor`, без реальной шапки в слоте) | **—** |
| Шапка: 64 dp, 16 dp колонка, аватар 48/32 | `chat_list_header_and_performance_test.dart` (:112) | ✓ |
| Шапка: 320 dp при 200 % — иконки hit-testable | там же (:46) | ✓ |
| Скрим шапки | там же (:142) | ✓ |
| Пилюля 36 dp, одна строка, без overflow-меню | `chat_list_m1_test.dart` (:173) — пиннит 36 | ✓ |
| Пилюля: reduced motion + 320 dp + 2.0 | там же (:227) — только «нет исключения» | ✓ |
| Папки заменяют типы; ПНМ по папке | `chat_filter_bar_folders_test.dart` (:85,:105) | **—** |
| Долгое нажатие по папке/«Все» → управление | там же (:143,:154) | **—** |
| Скрытый FAB вне дерева доступности | `neutral_inbox_test.dart` (:190) | ✓ |
| Реальный инбокс: 2 темы × 2 локали × 1.0/1.8 | там же (:312), внутри — высота бара 80, `viewPadding 34 → 114` (:419,:622), высота пилюли 36 (:467) | ✓ |
| Плитки фильтров переключают список | там же (:448-577) | ✓ |
| Долгое нажатие → модалка → удаление с диалогом | там же (:578-594) | ✓ |
| Таб-бар: 80 dp, индикатор, бейдж 99+, скрыт на активном | `app_bottom_nav_badge_test.dart` (:61,:87,:105,:112) | **—** |
| Таб-бар: reduced motion выключает анимацию | `nav_power_saver_test.dart` (:19) | ✓ |
| Шелл: split на 900, центр 640 на 700, полная ширина на 390 | `main_shell_inbox_pane_test.dart` (:113,:125,:134) | **—** |
| Шелл: FAB 56 и зазор до бара | там же (:140,:153) | **—** |
| Web: rail ≥840, бар <840, ресайз | `web_workspace_test.dart` «actual shell adapts navigation on resize» (:256) | ✓ |
| Web: `Ctrl+Alt+N` из инбокса | там же (:397-404) | ✓ |
| Web: выбранная строка = `chat` в URL | там же (:386-394) | ✓ |
| Модалка действий: 48 dp, отключённый «прочитать» | `chat_actions_modal_test.dart` (:59,:85) | **—** |
| Модалка действий: заголовок, разделитель, форма | там же (:45,:122,:160) | **—** |
| Мёртвый speed-dial: 6 тестов | `m3_speed_dial_fab_test.dart` (:24-153) | ✓ |
| Мёртвый `ChatSearchBar` (3-й неиспользуемый виджет) | `chat_list_m1_test.dart` «ChatSearchBar Tests» (:326) | ✓ |
| Поиск сохранённых: гонки, оффлайн, алиасы | `inbox_saved_search_test.dart` (:134,:192,:244,:277) | ✓ |
| Скелетон 76 dp = строка | `wave_a_visual_tokens_test.dart` (:96) | **—** |
| Провайдеры инбокса: merge/refresh/read | `providers/inbox_refresh_merge_test.dart`, `providers/inbox_reliability_test.dart` | ✓ |

### 4.2 Что закреплено так, что редизайн его сломает

| Тест | Закрепляет | Почему хрупко |
|---|---|---|
| `neutral_inbox_test.dart:467` + `chat_list_m1_test.dart:194` | высота пилюли фильтра **ровно 36** | любое исправление a11y (≥48) падает |
| `neutral_inbox_test.dart:419,622` | нижний бар **80**, с инсетом 34 → **114** | M3E-бар переменной высоты не влезет |
| `neutral_inbox_test.dart:448-458` | ключи `chat-filter-*`, отсутствие `chat-filter-more`, отсутствие `FilterChip` | переименование/`SegmentedButton` ломает |
| `main_shell_inbox_pane_test.dart:129-131` | `list.width == 640`, `left == 30` на 700 | любая новая ширина панели |
| `main_shell_inbox_pane_test.dart:118-121` | `list.width < 540` на 900 → фактически 360 | ресайз панели по умолчанию |
| `main_shell_inbox_pane_test.dart:147-148` | FAB **56×56** + `FloatingActionButton` как тип | M3E-FAB другой формы/размера |
| `web_workspace_test.dart:356-363` | `NavigationRail` есть ⇔ web, `NavigationBar` иначе | единая навигация для web+Windows ломает |
| `chat_tile_inbox_regressions_test.dart:724-729` | семантика содержит **русские** «выбран/закреплён/без звука» и «Прочитано» | локализация метки ломает тест (это правильный тест с неправильным ожиданием) |
| `chat_tile_inbox_regressions_test.dart:273,323` | `rowHeight 76`, `compactRowHeight 64` | любая адаптивная высота строки |
| `chat_tile_inbox_regressions_test.dart:158,190,688` | точные цвета (`Colors.transparent`, `secondaryContainer`, `primary`) | смена тональности |
| `app_bottom_nav_badge_test.dart:100-102` | бейдж не ниже `iconRect.top + 4` и не левее `icon.left - 24` | другой бейдж/размер иконки |
| `chat_actions_modal_test.dart:72,104` | строки меню ровно 48 | ок для a11y, но меню на `MenuAnchor` падает |
| `wave_a_visual_tokens_test.dart:96` | скелетон 76 dp | связано с `ChatTile.rowHeight` |
| `chat_list_header_and_performance_test.dart:131,138` | цель 48×48, круг 32×32, отступ 16 | другая шапка |

* `InboxSearchLauncher` / `ChatSearchField` не покрыты вообще: ни одного теста, виджет
  не используется в `lib/` (только `chat_search_field.dart:16` ссылается на него), при
  этом в нём есть хардкод `'Me'` (`inbox_search_launcher.dart:44`).

### 4.3 Поведения без тестов вообще

* Фокус и клавиатура: ни одного теста с `sendKeyEvent(Tab)` по инбоксу; нет теста, что
  строка/пилюля фокусируемы.
* Локализация в `en`: `chat_tile`-семантика в EN не проверяется ни разу; `create_*`
  и `inbox_search` не проверяются на отсутствие хардкодов (нет теста-«нет русских букв
  без l10n»).
* RTL: ни одного теста с `Directionality(TextDirection.rtl)`.
* Масштаб 2.0 для **шапки внутри скринa** (не `heightFor`) и для **нижнего бара** —
  только «нет исключения» при 1.8.
* `compactMode` + крупный шрифт: не тестируется (`ChatListHeader.heightFor(compact: true)`
  → 56, `chat_list_header.dart:52`).
* Ландшафтный телефон (844×390): split не проверяется.
* Свайп по строке: нет ни одного теста `SwipeActionRow` → «прочитано» (тестов на сам
  виджет нет вообще).
* Долгое нажатие по строке в инбоксе → `ChatActionsModal` покрыто только в
  `neutral_inbox_test.dart:578` (через `find.text('Ирина')`).
* `Outlined`-состояние «нет результатов» после смены фильтра: проверяется текст, но не
  озвучивание (`liveRegion`).
* Контраст: ни одного автоматического теста (это нормально, но и ручного lockdown нет).

---

## 5. Findings

Severity: **P0** — блокирует доступность, **P1** — серьёзно, **P2** — мелко.

### P0

| # | Где | Проблема | Фикс |
|---|---|---|---|
| A1 | `main.dart:414-416`, `ui_settings_provider.dart:11-19` | Системный масштаб шрифта отбрасывается, максимум 1.3 | `textScaler: TextScaler.linear(fontScale.scale)` → комбинировать: `platformScaler.clamp(maxScaleFactor: …)` или `TextScaler.linear(fontScale.scale * systemScale)`; шкалу приложения оставить как множитель |
| A2 | `chat_tile.dart:217-238` (`TouchContainer` → `touch_container.dart:205`), `chat_filter_bar.dart:285-288` | Строки и пилюли недостижимы с клавиатуры (нет `Focus`/`InkWell`/`FocusableActionDetector`) | Обернуть строку и пилюлю в `FocusableActionDetector` (Enter/Space → onTap, `Menu`/`Shift+F10` → меню) + видимое фокус-кольцо (`WidgetState.focused`), + тест с `sendKeyEvent(Tab)` |
| A3 | `chat_tile.dart:195-211` | В метке нет превью и времени; «печатает…» не звучит | Добавить `subtitle` (сжато) и `formattedTime` в `semanticsLabel`; для typing — отдельный `Semantics(liveRegion: true)` или `hint`; тест на EN-локаль |
| A4 | `chat_empty_state.dart:250-312`, `chat_tile.dart:50-53`, `inbox_search_screen.dart` (см. §3.2) | Русские литералы в UI и семантике | Ключи в `lib/l10n/secret/app_en.arb` + `app_ru.arb`, `flutter gen-l10n`; в `chat_tile` — `l10n.inboxKeyMismatch/inboxPinned/inboxMuted`; удалить `TODO(l10n)` с неверным обоснованием |

### P1

| # | Где | Проблема | Фикс |
|---|---|---|---|
| B1 | `chat_filter_bar.dart:175-186` + `main.dart:452-456` + `main.dart:488-497` | Полоса фильтров не скроллится мышью и не фокусируется; пилюли за краем недостижимы | Дать `ScrollController` (появится `RawScrollbar`), добавить `PointerDeviceKind.mouse` в `dragDevices` или `ScrollConfiguration` для этой полосы, либо заменить скролл на `Wrap`/`MenuAnchor` «ещё» при узкой ширине |
| B2 | `chat_list_screen.dart:456-539` | `isTyping`, `isPinned`, `typingNames` в `ChatTile` не передаются → состояние «печатает» и «закреплён» не существуют в приложении, хотя виджет и тесты их поддерживают | Передавать `isTyping: isTyping` (и убрать подмену `subtitle`), добавить `isPinned` в модель, либо удалить мёртвые параметры |
| B3 | `chat_tile.dart:200,219` | Двойное озвучивание «выбран» | Убрать литерал из метки, оставить `Semantics(selected: true)` |
| B4 | `chat_tile.dart:198` + `app_ru.arb:67-68` | «Черновик: Черновик:» | Не добавлять префикс, `draftLabel` уже содержит двоеточие; либо `inboxDraftSemantics` без «:» |
| B5 | `chat_filter_bar.dart:194,294` | Цель 36/32 dp | Поднять до 48 (трек 56) или оставить визуально 36 и добавить невидимый хит-паддинг до 48 (`MaterialTapTargetSize`), обновив тесты |
| B6 | `create_group_members_screen.dart:341-356` | Кнопка «убрать участника» ≈18×18, без метки | 48×48 тач-таргет, `Semantics(label: 'Убрать <имя>', button: true)` |
| B7 | `create_group_members_screen.dart:403-422` | Выбор участника только цветом + галочка без семантики; `ListTile` без `selected:` | `ListTile(selected: isSelected)` + `Semantics(checked/selected)` + `Checkbox`-семантика |
| B8 | `main_shell_screen.dart:647-655` vs `:627-633` | Windows получает нижний бар, web — rail; одна платформа-«десктоп» выглядит по-разному | Rail при `isWide` независимо от `isWeb` (или флаг в `ClientCapabilities`), тест `web_workspace_test.dart:356` переписать на «rail на широком, бар на узком» |
| B9 | `main_shell_screen.dart:451` | Split только по ширине: ландшафт 844×390 даёт две панели | Условие `isWide = w >= 840 && h >= 600` (или `shortestSide`), плюс тест на 844×390 |
| B10 | `chat_tile.dart:326-345`, `app_colors.dart:8` | «Онлайн» — только цвет (2.0:1) и не в семантике | Добавить в метку «в сети» и/или форму (кольцо), поднять контраст точки до ≥3:1 |
| B11 | `main_shell_screen.dart:745-751` | Текст 12 px `onSurfaceVariant@0.7` ≈3.5:1 | Убрать alpha, оставить `onSurfaceVariant` (7.2:1) |
| B12 | `chat_filter_bar.dart:146-157` | Граница трека ≈1.1:1 | `outlineVariant` без alpha (≈1.3:1) + заливка `surfaceContainer` (1.12:1) — всё ещё мало; нужен `outline` (3.0:1) или тональный контейнер с большим шагом |
| B13 | `web_workspace_navigation.dart:23-25` | `labelType: none`, `Tooltip` нет | `labelType: all` (или `selected`) либо `Tooltip(message: label)` на каждом destination |
| B14 | `inbox_search_screen.dart:106` | Текст исключения попадает в UI | Общее сообщение из l10n, детали — в `debugPrint` |
| B15 | `chat_list_screen.dart:389-395` | Кнопка сброса подписана `preferencesResetConfirm` («Сбросить настройки»-неймспейс) | Новый ключ `inboxResetFilters` = «Показать все» |

### P2

| # | Где | Проблема | Фикс |
|---|---|---|---|
| C1 | `chat_list_header.dart:52` | compact-шапка 56 dp фиксирована при любом масштабе | `math.max(AppHeights.lg, scaledTitle + room)` как в некомпактной ветке |
| C2 | `chat_list_screen.dart:213-221` | Лишний `viewPadding.bottom` (тело уже над баром) | Убрать, оставить `24 + (fab ? 72 : 0)` |
| C3 | `main_shell_screen.dart:625-643` | Rail вне SafeArea (боковой вырез в ландшафте) | Обернуть весь `Row` в `SafeArea(left/right)` или перенести rail внутрь |
| C4 | `main_shell_screen.dart:880` | Ручка панели 8 dp, без семантики и клавиатуры | 16–24 dp хит-зона + `Semantics(slider/label)` + стрелки ←/→ |
| C5 | `offline_banner.dart:16-21` | Нет `reduceMotion`, нет `liveRegion` | `context.motionDuration(...)`, `Semantics(liveRegion: true)` |
| C6 | `chat_list_header.dart:116-124` | Заголовок не `header` | `Semantics(header: true)` вокруг `Text` |
| C7 | `app_bottom_nav.dart:146` | Бейдж скрыт на активной вкладке → счётчик не звучит | В семантику destination добавлять `label: '${item.label}, $count'` (или `Semantics(value:)`), независимо от пилюли |
| C8 | `chat_empty_state.dart:129-209` | Не-секретная ветка без скролла | Обернуть в `SingleChildScrollView` как в `EmptyStateWidget` |
| C9 | `main_shell_screen.dart:798-801`, `chat_tile.dart:376-397,327-329`, `chat_filter_bar.dart:163-173` | LTR-геометрия (`Positioned left/right`, LTR-градиент) | `PositionedDirectional` + `AlignmentDirectional` для градиента |
| C10 | `datetime_helpers.dart:4-7` | Жёсткие `HH:mm` / `dd.MM.yyyy` | `DateFormat.jm(locale)` / `DateFormat.yMd(locale)` |
| C11 | `m3_speed_dial_fab.dart:282-284,339-341` | Пункт меню без роли «кнопка», без фокуса; виджет не используется | Удалить виджет+тест или починить (если он вернётся в редизайн) |

---

## 6. Чеклист для редизайна (чтобы не откатиться)

Навигация:
1. Rail и бар взаимоисключающие по **ширине**, а не по платформе; точка переключения
   одна и та же для Windows и web; на ≥1200 rail расширенный, на ≥1600 — с подписями.
2. Нижний бар: высота = `80 + системный инсет` (тест на 34 dp остаётся), подпись
   ≥11 px и масштабируется; бейдж не скрывается от семантики.
3. Каждый destination: `Semantics(selected)` + подпись + счётчик в семантике; rail — с
   `Tooltip` или видимыми подписями.
4. Переключение вкладки объявляется (`SemanticsService.announce` с именем страницы).
5. Неактивные вкладки остаются вне фокуса и семантики (как сейчас в
   `m3_route_tab_switcher.dart:204-209`) — это не ломать.
6. `Ctrl+Alt+1..3` продолжает работать; добавить `Ctrl+1..3` и документировать в UI.

Инбокс:
7. Строка чата: одна семантическая нода, метка = имя + превью + время + счётчик +
   флаги, все флаги из l10n; `onTap`/`onLongPress` в `Semantics`; `customSemanticsActions`
   «Отметить прочитанным».
8. Строка фокусируема (Tab), Enter открывает, `Menu`-клавиша/Shift+F10 открывает меню,
   фокус-кольцо видимо и не меньше 2 dp контрастом ≥3:1.
9. Свайп остаётся, но у него всегда есть не-жестовая копия: пункт меню (есть) **и**
   клавиша (нет).
10. Все тач-цели ≥48 (пилюли фильтров, крестики участников, ручка панели).
11. Пилюли фильтров: либо `Wrap`/перенос, либо скролл с `ScrollController` (скроллбар),
    либо `MenuAnchor` «Ещё» — но не «горизонтальный скролл без мыши и клавиатуры».
12. Фильтры доступны с клавиатуры как группа (`inMutuallyExclusiveGroup`, стрелки ←/→).
13. Смена фильтра/поиска объявляется (`liveRegion` с количеством результатов).
14. Текст: превью 14 px `onSurfaceVariant` без alpha; статус — тот же контраст;
    никаких `@0.7` на тексте.
15. Масштаб: системный `textScaler` уважается, шапка/строка/бар считают высоту от
    масштаба, ни одной фиксированной высоты с текстом внутри.
16. Safe area: rail и бар внутри SafeArea по горизонтали; внизу ровно один учёт инсета.
17. RTL: `PositionedDirectional`, `AlignmentDirectional`, никаких `left:`/`right:` в
    новых виджетах; свайп и rail уже корректны — не сломать.
18. Все новые строки — только через `l10n`; `.arb`-файл `lib/l10n/secret/app_*.arb`
    (или починить пайплайн, чтобы `AppLocalizations` тоже имел источник).
19. Каждая анимация — через `context.reduceMotion`/`M3Durations`; никаких
    `Curves.fastOutSlowIn` и фиксированных `Duration(milliseconds: …)`.

Тесты:
20. Ни один новый тест не должен пиннить 36 dp, ровно 640/360, `Colors.transparent`
    или русский литерал семантики; вместо этого — «≥48», «≤640», «цвет = токен темы»,
    «метка = l10n-ключ в текущей локали».

---

## 7. Что уже хорошо (не ломать)

1. **Один узел на строку.** `Semantics(excludeSemantics: true)` + `onTap`/`onLongPress`
   (`chat_tile.dart:217-225`), тест `chat_tile_inbox_regressions_test.dart:695-738`
   проверяет отсутствие дубля (`find.bySemanticsLabel` ровно один).
2. **Скрытые вкладки не читаются и не фокусируются.** `ExcludeFocus` +
   `ExcludeSemantics` + `IgnorePointer` в `m3_route_tab_switcher.dart:204-209` —
   редкость даже в зрелых приложениях.
3. **Скрытый FAB уходит из дерева доступности** (`inbox_compose_button.dart:32-35`),
   и это закреплено тестом (`neutral_inbox_test.dart:190-243`).
4. **Состояние не только цветом**: непрочитанность = вес + пилюля; выбранная строка =
   фон + полоса-индикатор + `Semantics(selected)`; ошибка доставки = глиф + цвет +
   текст (`chat_tile.dart:475-486,648-661`).
5. **Reduce motion покрыт** в области почти везде, включая статичные точки печати
   (`chat_tile.dart:807-820`) и таб-свитчер (`m3_route_tab_switcher.dart:63-64`).
6. **Клавиатурные шорткаты платформы**: `Ctrl/Cmd+K`, `Ctrl+Alt+1..3`, `Ctrl+Alt+N`
   (`chat_list_screen.dart:167-172`, `main_shell_screen.dart:418-446`), с тестом на
   `Ctrl+Alt+N` (`web_workspace_test.dart:397-404`).
7. **Список ограничен по ширине и центрируется** (`kInboxContentMaxWidth = 640`) —
   длинные строки не растягиваются на 4K.
8. **O(1) индекс списка** (`chat_list_screen.dart:402-404,564-568`) + охранный тест
   `perf/ui_smoothness_regression_guard_test.dart:86-106` — важно, чтобы редизайн не
   вернул `indexWhere`.
9. **Тач-цели шапки 48×48** с комментарием-обоснованием (`chat_list_header.dart:150-152`).
10. **Свайп корректен в RTL** (`swipe_action_row.dart:41-43,109`).
11. **Модалка действий** полностью на l10n, строки 48 dp, отключённый пункт остаётся
    (не прыгает высота) — `chat_actions_modal.dart:109-118`.

---

## 8. Что я не проверял

* **Скринридер живьём.** Не запускал TalkBack/NVDA/VoiceOver: порядок, паузы, фактическое
  произношение смешанных строк («Irina, 2 unread, без звука») — по коду, не по слуху.
* **Реальный Tab-трекинг** на Windows/web — вывод из типов виджетов, не из запуска.
* **Жесты на устройстве**: свайп, долгое нажатие, drag ручки панели, колесо мыши по
  фильтрам (в т.ч. поведение `Shift+wheel` в Chrome) — не проверял руками.
* **Контраст замером** (пипетка/скриншот): только расчёт по токенам светлой/тёмной схемы
  `AppSurfaces.neutralize`. Для динамических цветов (`DynamicColorBuilder`, `main.dart`)
  значения другие — расчёт не переносится.
* **Реальные высоты на устройствах** при 1.3/2.0 (нет запуска `flutter run`); выводы о
  росте строки — из отсутствия жёсткой высоты, не из скриншота.
* **Fold/posture** на реальном складном устройстве (и нет уверенности, что Flutter на
  Windows отдаёт `displayFeatures` — **догадка**).
* **Сетевые/данные-состояния** инбокса (loading/error/пусто) на предмет a11y-объявлений:
  `EmptyStateWidget` прочитал, но как он звучит при смене состояния — не проверял.
* **Тесты не запускал** (`flutter test --no-pub`) — только читал их код и состав
  `test/suite_test.dart`; «в CI / не в CI» — по импортам в `suite_test.dart` и шагу
  `flutter test test/suite_test.dart` в `.github/workflows/build.yml:114`. Отдельные
  файлы могли попасть в другие шаги CI, которые я не читал целиком.

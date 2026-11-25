# Аудит навигации NiosMess (2026-11-22)

**Приложение:** `F:\Niosmess V2\pulse_flutter`. Все пути ниже, кроме отдельно помеченных, относительны ему.
**Что читал целиком:** `lib/widgets/app_bottom_nav.dart`, `lib/screens/main_shell_screen.dart`, `lib/widgets/nav/web_workspace_navigation.dart`, `lib/widgets/nav/m3_route_tab_switcher.dart`, `lib/core/theme/expressive_tokens.dart`, `lib/core/motion/m3_spring_constants.dart`, `lib/core/motion/m3_motion.dart`, `lib/widgets/pulse_scaffold_body.dart`, `lib/widgets/chat/inbox_compose_button.dart`, `lib/core/platform/client_capabilities.dart`, `lib/providers/ui_settings_provider.dart` (фрагменты), `lib/core/utils/haptic_service.dart`, файлы тестов из §1.9, `tool/check_ui_architecture.dart` (проверки 8–9).
**Фоновый документ:** `docs/motion-audit-2026-11-21/02-transitions-navigation.md`. Моушен табов и индикатора там уже разобран (M3–M5, M11–M13), здесь я это не повторяю — только фиксирую текущее состояние и то, что не покрыто.
**Факты против догадок:** каждое утверждение о коде имеет `файл:строка`. Всё, что я не мог проверить запуском, помечено «(не проверено)». Числа из спек M3 — только те, что я реально прочитал (см. §2.1, там указано, откуда именно).

---

## 1. Инвентарь

### 1.1 Нижняя панель — `AppBottomNav`

Файл: `lib/widgets/app_bottom_nav.dart`.

Дерево:

```
DecoratedBox(surfaceContainer + верхняя линия 0.7dp)      :76-85
└── Theme(navigationBarTheme: height 80, indicator, label) :86-111
    └── NavigationBar (key 'main-bottom-navigation')       :112-151
        └── NavigationDestination × 3                      :122-149
            └── _destinationIcon(Badge?)                   :136-148, 162-185
                └── TabMorphIcon (outline/filled)          :125-135, 197-313
```

| Параметр | Значение | Где |
|---|---|---|
| Высота | **80** (и в `NavigationBarThemeData.height`, и в `NavigationBar.height`) | `app_bottom_nav.dart:91`, `:114` |
| Фон контейнера | `scheme.surfaceContainer` | `:78`, `:93` |
| Верхняя граница | `outlineVariant` @ 0.35, ширина **0.7** | `:79-84` |
| Elevation | 0, `surfaceTintColor: Colors.transparent` | `:92`, `:115-116` |
| Индикатор | `secondaryContainer`, `StadiumBorder()`, размер не задан → SDK-дефолт **64×32** | `:96-97`; SDK `navigation_bar.dart:29-30` |
| Иконка | 24dp, морф outline↔filled, цвет `onSecondaryContainer` / `onSurfaceVariant` | `:125-135` |
| Лейбл | всегда видим (`alwaysShow`), `AppFonts.ui`, **11sp**, w700 выбран / w500 нет, `onSurface` / `onSurfaceVariant` | `:98-109`, `:121` |
| Нижний инсет | `maintainBottomViewPadding: true` | `:118` |
| Табы | `chats` / `niosgram` / `settings`, подписи «Чаты» / «Лента» / «Настройки» | `:58-75`; `lib/l10n/app_localizations_ru.dart:15, 27, 2702` |
| Длительность анимации | `context.reduceMotion ? 0 : (tierC ? short4 200мс : medium2 300мс)` | `:52-57`, `:117` |
| Haptic | `HapticService.tap()` (selectionClick) только если индекс **другой** | `:43-45`; `core/utils/haptic_service.dart:12-14` |
| Sound | `playUiTick()` на каждый принятый тап, при `soundEffects` | `:40-42` |
| Дебаунс фидбэка | 120 мс | `:33`, `:37` |

**Дополнительная анимация иконки** (`TabMorphIcon`, `:197-313`), поверх индикатора:

* контроллер `duration` = та же длительность панели (`:231`), кривые `expressiveDecel` / reverse `expressiveAccel` (`:234-238`), но гонится `Curves.linear` (`:253-257`);
* кросс-фейд opacity outline/filled по `_animation` (`:289-303`);
* «пульс» по линейному значению контроллера: `sin(pi·t)` → scale `1 + 0.16·pulse`, подъём `−3.5dp` (`:277-283`).

**Бейдж** (`_destinationIcon`, `:162-185`):

| Параметр | Значение | Где |
|---|---|---|
| Цвет | `scheme.primary` / текст `onPrimary` | `:170-171` |
| Форма | дефолт `Badge` → `StadiumBorder` | SDK `badge.dart:186` |
| Позиция | `AlignmentDirectional.topEnd`, `offset: (2, −9)` — подобрано «на глаз» под 24dp иконку | `:172-173` |
| Паддинг | `h 4 / v 1.5`, шрифт 10sp w800 | `:174-181` |
| Значение | `totalUnreadCountProvider`, `>99 → '99+'` | `:51`, `:182` |
| Видимость | **скрыт на выбранном табе** | `:146`, `:168` |

Источник счётчика: `lib/providers/backend_chat_provider.dart:1136-1143` — простая сумма `unreadCount` по всем чатам. Настройки `badgeCountMessages` / `badgeIncludeMuted` тут **не участвуют** (см. M9).

### 1.2 Переключатель контента табов — `M3RouteTabSwitcher`

Файл: `lib/widgets/nav/m3_route_tab_switcher.dart`. Это вторая половина «навигации»: тап по табу запускает и панель, и этот свитчер.

| Параметр | Значение | Где |
|---|---|---|
| Длительность | та же, что у панели: 200 / 300 мс, при reduce motion — переход мгновенный | `main_shell_screen.dart:599-601`, `m3_route_tab_switcher.dart:63-66`, `:112-115` |
| Разбивка | fade-out 35 % времени, fade-in 65 % | `:148-149` |
| Кривые | `expressiveAccel` на выход, `expressiveDecel` на вход | `:154-158` |
| Движение | сдвиг 32dp + scale 0.96 (вход) / 0.985 (выход) | `:56`, `:170-171` |
| Состояние | вкладки живут в `Offstage` + `TickerMode`, не пересоздаются | `:198-227` |
| Что важно для навигации | `onTransitionStateChanged` → `_syncInteraction()` → тир производительности | `main_shell_screen.dart:594`, `:568-571` |

### 1.3 Web-рельс — `WebWorkspaceNavigation`

Файл: `lib/widgets/nav/web_workspace_navigation.dart` (62 строки, весь файл).

| Параметр | Значение | Где |
|---|---|---|
| Фон | `scheme.surfaceContainerLow` | `:22` |
| Ширина | `minWidth: 88` | `:24` |
| Лейблы | **`NavigationRailLabelType.none`** — подписи не показываются | `:23` |
| Выравнивание группы | `groupAlignment: -0.65` | `:25` |
| Логотип (leading) | 48dp, `primaryContainer`, `BorderRadius.circular(18)`, `Tooltip('NiosMess')`, padding 20 по вертикали | `:26-42` |
| Пункты | те же 3 таба, иконки дублируют панель, лейблы есть в дескрипторах (только для семантики) | `:43-59` |
| Бейджи | **нет** | `:43-59` |
| FAB/меню/expanded | **нет** | `:16-60` |
| Haptic / звук | **нет**, `onSelect` уходит прямо в `_onTapTab` | `main_shell_screen.dart:628-631` |
| Разделитель | `VerticalDivider(width: 1)` рядом с рельсом | `main_shell_screen.dart:632` |

Факт из SDK: при `labelType: none` индикатор рельса — **круг 56×56** (`navigation_rail.dart:24`, `:304-306`, `:1057-1066`), а не «таблетка» 64×32, как в панели. То есть в одном продукте два разных индикатора.

### 1.4 Шелл — `MainShellScreen`

Файл: `lib/screens/main_shell_screen.dart`.

| Что | Значение | Где |
|---|---|---|
| Табы | `const ['chats','niosgram','settings']` | `:78` |
| Маппинг tab→index | `settings`/`profile` → 2, `niosgram` → 1, иначе 0 | `:333-337` |
| Переключение | `context.go('/main/$targetTab')`; при том же табе — **ранний return** | `:353-376`, особенно `:359-361` |
| «Широко» | `maxWidth >= Breakpoints.medium` = **840** | `:451` |
| Рельс | `webRail = capabilities.browserWorkspace && isWide` (browserWorkspace == `kIsWeb`, `client_capabilities.dart:20`) | `:452` |
| Ширина рабочей области | `maxWidth − (webRail ? 89 : 0)` — 89 = 88 рельса + 1 разделитель, захардкожено | `:453` |
| Панель на широком | `bottomNavigationBar: webRail ? null : AppBottomNav(...)` | `:647-655` |
| Панель в RepaintBoundary | да | `:649` |
| FAB | только `!isWide && tab == 0`; на широком — FAB внутри инбокс-панели | `:656-662`, `:797-802` |
| FAB-отступы | `kInboxComposerClearance = 88` (16+56+16), `kInboxComposerMargin = 16` | `:51-57` |
| Скролл-скрытие FAB | по `ScrollEndNotification` при `extentAfter <= 0` | `:573-592` |
| Инсет под FAB для рельса | `MediaQuery.viewPaddingOf(context).bottom` | `:470-472` |
| PopScope | `canPop: browserWorkspace`; с не-главного таба → `go('/main/chats')` без анимации; с главного — «нажмите ещё раз» | `:394-417` |
| Горячие клавиши | `Ctrl+Alt+1/2/3`, `Ctrl+Alt+N` — только web | `:418-446` |
| Прогрев табов | `Timer(400мс)` активирует неактивированные вкладки | `:172-188` |

### 1.5 Compose FAB

`lib/widgets/chat/inbox_compose_button.dart`: `FloatingActionButton` 56×56 (пин в тесте `main_shell_inbox_pane_test.dart:147-148`), `primaryContainer`, radius 18, `heroTag: 'compose_chat_fab'`, elevation 0/hover 1, появление `AnimatedSlide(0.35)` + `AnimatedOpacity`, 200 мс, `spatialFast` / `expressiveDecel` (`:24-31`).

### 1.6 Поведение по брейкпоинтам (как есть в коде)

| Окно | Панель | Контент | FAB | Рельс |
|---|---|---|---|---|
| < 600 (compact) | `NavigationBar` 80dp, вертикальные пункты, индикатор-таблетка | одна панель | Scaffold FAB, правый нижний, над панелью | — |
| 600–839 (medium) | **та же панель 80dp, вертикальные пункты** | одна панель, инбокс по центру ≤ 640 (`:786`) | Scaffold FAB | — |
| 840–1199 (expanded), web | **нет панели** | список + деталь | внутри инбокс-панели | рельс 88dp, только иконки, без бейджа |
| 840+ , Android/iOS/Windows/Linux | **панель 80dp** | список + деталь | внутри инбокс-панели | — |
| ≥ 1200, ≥ 1600 | без изменений: `Breakpoints.expanded` / `.large` в навигации **не используются** | | | |

`Breakpoints.compact (600)` и `Breakpoints.expanded (1200)` объявлены в `lib/core/theme/expressive_tokens.dart:187-196`, но в навигации не читаются — grep по `Breakpoints.` даёт только `medium` (13 мест).

### 1.7 Настройки, относящиеся к навигации

`lib/providers/ui_settings_provider.dart`:

* `navBarFloating` — объявлена (`:84`, `:188`), дефолт `false` (`:141`), `copyWith` (`:238`, `:287`), ключ `ui.navBarFloating` (`:357`), чтение из prefs (`:436`), сеттер `setNavBarFloating` (`:677-679`), очистка (`:846`). **Читателей нет ни одного** — grep по всему `pulse_flutter` даёт только эти строки и два теста, которые передают `navBarFloating: true` (`test/widgets/neutral_inbox_test.dart:38`, `test/visual/inbox_screenshot_dump_test.dart:443`).
* `badgeCountMessages` (`:109`, `:213`, сеттер `:791`), `badgeIncludeMuted` (`:110`, `:214`, сеттер `:796`) — то же: сеттеры никто не вызывает, значения никто не читает.

### 1.8 Тема навигации (второй источник правды)

`lib/core/theme/app_theme.dart`:

* `navigationBarTheme` (`:142-165`): `height: 66`, фон `surfaceContainerLow @ 0.96`, индикатор `secondaryContainer`, лейбл `labelMedium` с `onSecondaryContainer` и **w700** (`:143-156`), `iconTheme` 24 (`:157-164`).
* `navigationRailTheme` (`:166-179`): фон `surface`, индикатор `secondaryContainer`, `selectedLabelTextStyle` `onSurface` w700.

Панель перекрывает это локальным `Theme` (`app_bottom_nav.dart:86-111`) — работают только `iconTheme`; рельс перекрывает фон (`web_workspace_navigation.dart:22`), лейблы не видны вообще. То есть в репозитории три разных числа высоты (66 / 80 / «64 по спеке») и два разных фона панели.

### 1.9 Тесты, которые пиннят поведение

| Тест | Что закрепляет |
|---|---|
| `test/widgets/app_bottom_nav_badge_test.dart:61-85` | высота **ровно 80**, `alwaysShow`, индикатор `secondaryContainer`, иконки 24 |
| то же `:87-103` | `99+`, бейдж не залезает на глиф, не уезжает к соседу |
| то же `:105-110` | бейдж **скрыт** на выбранном табе (`findsNothing` для `Badge`) |
| `test/widgets/neutral_inbox_test.dart:416-421` | ширина 390, высота **80**, панель прижата к низу окна |
| `test/widgets/main_shell_inbox_pane_test.dart:122,131` | при 900 и 700 ширины есть `NavigationBar` (то есть рельса на 900 нет) |
| то же `:140-151` | FAB 56×56, `fab.bottom <= nav.top − 16` |
| `test/widgets/web_workspace_test.dart:356-363` | web → рельс и нет панели; не-web → панель и нет рельса |
| то же `:379-383` | 390 ширины → панель, рельса нет |
| `test/widgets/nav_power_saver_test.dart:78-99` | tier C всё ещё анимирует; reduce motion → `animationDuration == 0` |
| `test/widgets/tab_shared_axis_switcher_test.dart:206-214` | тапы подряд, `animationDuration == Duration.zero` при reduce motion |
| `tool/check_ui_architecture.dart:170-190` | в тексте `AppBottomNav` должны быть литералы `child: NavigationBar(`, `context.reduceMotion`, `animationDuration: duration`, `Duration.zero` |

---

## 2. Сверка с Material 3 Expressive

### 2.1 Источники и что из них реально удалось прочитать

| Источник | Как получен | Что дал |
|---|---|---|
| `https://m3.material.io/components/navigation-bar/specs` | открыт в браузере, снят текст страницы | варианты (flexible вместо baseline), конфигурации (vertical/horizontal), цветовые роли, анатомия |
| `https://m3.material.io/components/navigation-bar/guidelines` | то же | 3–5 пунктов, обязательные лейблы, поведение при повторном тапе, скролл, размещение FAB, запрет панели на десктопе, адаптивность |
| `https://m3.material.io/components/navigation-rail/specs` | то же | collapsed/expanded, standard/modal, «hide when collapsed», анатомия (menu, FAB, бейджи), цветовые роли |
| `https://m3.material.io/components/navigation-rail/guidelines` | то же | 3–7 пунктов, leading edge, FAB сверху с elevation 0, бейджи, лейблы, «рельс — единственный навигационный элемент» |
| `https://m3.material.io/components/badges/specs` | то же | цветовые роли error/on-error, large badge 8dp радиус / 16dp высота / 16×34dp / отступ 14×12dp, конфигурации «active with badge» |
| `material-components-android/docs/components/BottomNavigation.md` (репозиторий Google) | raw-файл | числа M3E: высота 80→**64dp**, паддинги 12→6 / 16→6, индикатор 64→**56dp**, горизонтальные пункты при ≥600dp, лейбл больше не жирный, активный лейбл `on-surface-variant`→`secondary`, фон `surfaceContainer`, elevation 3dp |
| `material-components-android/docs/components/NavigationRail.md` | raw-файл | числа M3E: ширина 80→**96dp**, пункт 60→64dp, шаг 0→4dp, elevation 0→3dp, верхний паддинг 4→6, нижний 12→4, верхний отступ контента 8→44dp |
| Flutter SDK на диске `F:\Flutter\flutter` (3.44.6) | чтение исходников | фактические дефолты Flutter: индикатор панели 64×32, индикатор рельса 56×56 при `labelType: none`, `Badge` = `StadiumBorder` + `largeSize 16`, рельс анимируется `kThemeAnimationDuration` без возможности переопределить |

**Чего я не смог прочитать:** собственные таблицы измерений на `m3.material.io` (Measurements — это картинки, а таблицы токенов рендерятся JS-компонентом, текстом они не отдаются). Поэтому все **числа** в §2.2 взяты из документации Google для Android-реализации, а не с самой страницы спеки. Формулировки «короче», «горизонтальные пункты в medium», «expanded заменяет navigation drawer» — со страницы спеки дословно.

### 2.2 Спека против кода

| Элемент | M3 Expressive | В приложении | Вердикт |
|---|---|---|---|
| Высота панели | **64dp** (было 80) | 80 (`app_bottom_nav.dart:91,114`) | расхождение, 16dp лишней высоты на каждом экране телефона |
| Верхний/нижний паддинг пункта | 6 / 6dp | не задаётся, дефолт Flutter (12 / 16) | следует из высоты 80 |
| Индикатор | **56dp** шириной | 64×32 (`StadiumBorder`, дефолт SDK) | расхождение |
| Лейбл выбранного | `secondary`, **не жирный** | `onSurface`, **w700** (`:102-107`) | расхождение |
| Размер лейбла | label-medium (12sp) | 11sp (`:101`) | на 1sp меньше |
| Фон контейнера | `surfaceContainer` | `surfaceContainer` (`:78`,`:93`) | совпадает |
| Elevation контейнера | 3dp (Android-дефолт) | 0 + hairline-бордер (`:79-84`) | осознанное отклонение (правило AGENTS «без теней»), ок |
| Пункты в medium (600–839) | **горизонтальные** | вертикальные, панель 80dp | расхождение |
| Где можно панель | compact + medium; **на десктопе нельзя** | панель на всех платформах до 840 включительно, и на Windows/Linux — на любой ширине (`:452`) | расхождение |
| Бейдж: цвет | `error` / `on error` | `primary` / `onPrimary` (`:170-171`) | расхождение |
| Бейдж: форма и размер | радиус 8dp, высота 16dp, 14×12dp от угла иконки | `StadiumBorder`, ~13dp, offset (2,−9) (`:173-181`) | расхождение |
| Бейдж на активном пункте | предусмотрен спекой («Active with label — large badge») | скрывается (`:146`) | расхождение |
| Повторный тап по активному табу | прокрутить в начало | ничего (`:359-361`) | не реализовано |
| Скрытие панели при скролле | допускается | нет (скрывается только FAB) | не реализовано, не обязательно |
| Рельс: ширина collapsed | **96dp** | 88 (`:24`) | расхождение |
| Рельс: варианты | collapsed и **expanded** (standard/modal, меню) | только один фиксированный, без меню | расхождение |
| Рельс: лейблы | «все пункты требуют лейбл в одно слово» | `labelType: none`, тултипов нет (`:23`) | расхождение |
| Рельс: FAB в слоте | опционально, сверху, elevation 0 | нет | не реализовано |
| Рельс: бейдж | справа сверху иконки (collapsed) / у лейбла (expanded) | нет | расхождение |
| Рельс: выравнивание | top или center | `-0.65` (`:25`) — ни то, ни другое | самодеятельность |
| Рельс: разделитель | опционально, на границе с контентом | `VerticalDivider(width: 1)` (`main_shell_screen.dart:632`) | совпадает |
| Рельс + панель одновременно | запрещено | соблюдено (`:647-655`) | совпадает |

---

## 3. Находки

### CRITICAL

**K1. На web-раскладке (≥840) счётчик непрочитанных исчезает полностью.**
`lib/widgets/nav/web_workspace_navigation.dart:43-59` — у пунктов рельса нет `Badge`; `lib/screens/main_shell_screen.dart:647-655` — панель, которая единственная умеет бейдж, в этом режиме не строится. Итог: пользователь в основной веб-раскладке не видит ни числа непрочитанных, ни даже точки. Единственный признак — бейджи на строках чатов в левой панели, но они уходят за скролл и не видны, когда открыт чат.
*Исправление:* обернуть `icon`/`selectedIcon` рельса тем же `_destinationIcon` (вынести бейдж в общий виджет `NavUnreadBadge`), плюс счётчик у лейбла, когда появится expanded-режим. Это ~30 строк и правка одного теста.

### MAJOR

**M1. Панель на 80dp вместо 64dp — самая заметная «устаревшесть».**
`lib/widgets/app_bottom_nav.dart:91`, `:114`; дополнительно `app_theme.dart:143` держит третье значение `66`. M3E прямо укоротила панель (80→64, см. §2.1). 16dp на телефоне — это примерно высота строки текста, которую съедает док.
*Исправление:* `height: 64`, паддинги пункта 6/6; удалить `height: 66` из темы; обновить `app_bottom_nav_badge_test.dart:68`, `neutral_inbox_test.dart:419`. Индикатор 56 см. M7 — в 3.44.6 это уже не «правка числа», а свой индикатор.

**M2. В medium-окне (600–839) нет горизонтальных пунктов.**
`lib/screens/main_shell_screen.dart:451` — единственный порог 840; между 600 и 840 телефонная панель с вертикальными пунктами на всю ширину планшета. Спека: «In medium windows, navigation bars should use horizontal items» (bar, Configurations) и «≥600dp» в Android-доке. Планшет 800dp получает растянутую мобильную панель и однопанельный инбокс.
*Исправление:* при `600 ≤ width < 840` — горизонтальная конфигурация пунктов (иконка слева от лейбла, ширина по контенту с максимумом, центрирование), высота 64. В текущем `NavigationBar` Flutter этого нет — нужен свой виджет пункта поверх `NavigationBar` или собственный бар.

**M3. Рельс — урезанная копия панели: без лейблов, без тултипов, уже спеки.**
`lib/widgets/nav/web_workspace_navigation.dart:23-25`. `labelType: none` + `minWidth: 88` (спека: 96) + `groupAlignment: -0.65`. Flutter в режиме `none` не добавляет `Tooltip` (проверил: в `navigation_rail.dart` тултипов нет, только `Semantics` — `:775`, `:1104-1106`). На десктопе пользователь видит три безымянные иконки и должен угадывать. При этом спека требует лейбл у каждого пункта.
*Исправление:* `labelType: selected` (или `all` для 3 пунктов), `minWidth: 96`, `groupAlignment: -1` (top) либо `0` (center); ширину вынести в токен.

**M4. Нет collapsed/expanded рельса и меню — то есть нет M3E-замены navigation drawer.**
`web_workspace_navigation.dart:16-60` — статичный рельс, `NavigationRail` без `extended`/меню. M3E объявила drawer устаревшим и предлагает expanded-рельс; в приложении на ≥1200 ничего не меняется (порог `Breakpoints.expanded` в навигации не используется). Для 3 разделов expanded не обязателен, но тогда это нужно зафиксировать решением, а не молчанием: сейчас в `expressive_tokens.dart:189-190` написано «medium: compact navigation rail», чего в коде нет.
*Исправление:* либо честно ограничиться collapsed-рельсом и поправить комментарий-токен, либо добавить expanded с меню-иконкой (стандарт: меню сверху, лейблы, FAB в слоте).

**M5. Бейдж не по спеке и скрыт там, где он нужнее всего.**
`app_bottom_nav.dart:170-182` — `primary` вместо `error`, `StadiumBorder` вместо радиуса 8dp, высота ~13dp вместо 16dp, offset подобран вручную. `:146` — на выбранном табе бейдж скрывается; спека бейджей содержит конфигурации «Active with label — large badge», то есть активный пункт с бейджем — норма.
Продуктовое следствие: находясь на «Чатах» (где и происходит чтение), пользователь не видит суммарный счётчик вообще.
*Исправление:* вынести бейдж в общий компонент: `error`/`onError` (или осознанно `primary` с записью в доке), радиус 8, высота 16, отступ 14×12 от угла иконки, показывать всегда при `count > 0`.

**M6. Активный лейбл и его вес противоречат M3E.**
`app_bottom_nav.dart:98-109`: `onSurface` + w700 для выбранного; спека: `secondary`, «label text is no longer bolded when selected». Плюс 11sp вместо `labelMedium` (12sp) и локальный `TextStyle` вместо `textTheme.labelMedium`, из-за чего типографика панели живёт отдельно от темы.
*Исправление:* `color: scheme.secondary`, `fontWeight: w500` для обоих состояний, `fontSize` из `labelMedium` темы.

**M7. Два разных индикатора в одном продукте.**
Панель: `StadiumBorder`, 64×32 (`:97` + SDK `navigation_bar.dart:29-30`). Рельс: круг 56×56 (SDK `navigation_rail.dart:24`, `:304-306`). Спека M3E даёт 56dp для панели; рельс уже почти совпал, панель — нет. Переход между раскладками (например, ресайз окна web) меняет форму выделения.
*Исправление:* для рельса достаточно **показать лейблы**: при `labelType: selected/all` индикатор перестаёт быть круглым и рисуется как `StadiumBorder` шириной 56dp (`navigation_rail.dart:304-306`, `:1050-1067`), то есть почти совпадёт с M3E-панелью. Для панели хуже: в Flutter 3.44.6 ширина индикатора **не параметризована** (`navigation_bar.dart:29-30` — константы 64/32, `:795-796` — дефолты `NavigationIndicator`, в `NavigationBarThemeData` есть только `indicatorShape`/`indicatorColor`, `:469-471`), поэтому честные 56dp требуют своего индикатора/своего бара. Проверить, появился ли параметр в 3.47.6 (CI), я не мог.

**M8. Рельс игнорирует reduce motion и тир производительности, и не даёт haptic/звука.**
`web_workspace_navigation.dart:18-21` — нет ни `context.reduceMotion`, ни тира. В SDK длительность анимации рельса жёстко `kThemeAnimationDuration` (`navigation_rail.dart:591`), параметра нет. Панель в это же время умеет `Duration.zero` (`app_bottom_nav.dart:55-57`) и тир C. Плюс тап по рельсу не зовёт `HapticService.tap()`/`playUiTick()`, а тап по панели зовёт (`:40-45`).
Это нарушение §Motion AGENTS («Always use M3SpringCurves… expressive components whenever they exist») и расхождение между двумя реализациями одной функции.
*Исправление:* общий обработчик выбора таба (`_selectTab(index, source)`), который делает фидбэк, дебаунс и `context.go`; для рельса — либо `NavigationRail` заменить на свой (тогда контролируем длительность), либо при reduce motion подменять `NavigationRail` статичной колонкой.

**M9. Мёртвые настройки: `navBarFloating`, `badgeCountMessages`, `badgeIncludeMuted`.**
`lib/providers/ui_settings_provider.dart:84,141,188,238,287,357,436,677-679,846` — у `navBarFloating` есть всё, кроме читателя. Сеттеры `setBadgeCountMessages`/`setBadgeIncludeMuted` (`:791`, `:796`) никто не вызывает, значения нигде не читаются — значит бейдж в навигации считает и замьюченные чаты, и «сообщения», хотя пользователю обещали настройку (её нет в UI вообще).
Отдельно неприятно, что тесты передают `navBarFloating: true` (`test/widgets/neutral_inbox_test.dart:38`, `test/visual/inbox_screenshot_dump_test.dart:443`) — они выглядят как проверка поведения, которого нет.
*Исправление:* либо удалить `navBarFloating` целиком (поле, ключ, сеттер, миграцию, из тестов), либо реализовать и добавить тумблер; `badgeCountMessages`/`badgeIncludeMuted` — подключить к `totalUnreadCountProvider` (`backend_chat_provider.dart:1136-1143`) и вывести в настройки уведомлений.

**M10. Тап по активному табу не делает ничего, хотя спека требует скролла в начало.**
`main_shell_screen.dart:359-361` — ранний `return`, до `_revealComposer()` и `context.go`. При этом звук тика проигрывается (`app_bottom_nav.dart:40-42`), а haptic — нет (`:43`), то есть обратная связь есть, действия нет. То же на рельсе.
*Исправление:* при `targetTab == widget.tab` — вызвать скролл-в-начало активного списка (у `ChatListScreen`/`NiosgramScreen` нужен `ScrollController` или `PrimaryScrollController`) и выйти.

**M11. Дубли конфигурации: три высоты, два фона, два источника пунктов.**
`app_theme.dart:142-179` задаёт `height: 66`, фон `surfaceContainerLow@0.96`, активный лейбл `onSecondaryContainer` — всё это перекрыто в `app_bottom_nav.dart:86-111` (`80`, `surfaceContainer`, `onSurface`). Для рельса тема даёт фон `surface`, а виджет — `surfaceContainerLow`. Пункты описаны дважды: `_NavItem` (`app_bottom_nav.dart:58-75`, `188-195`) и `NavigationRailDestination` (`web_workspace_navigation.dart:43-59`), плюс `_tabs` (`main_shell_screen.dart:78`) и `_tabIndex` (`:333-337`). Один новый таб = правки в четырёх местах.
*Исправление:* один список дескрипторов (`NavDestination(index, label, icon, selectedIcon, tab)`) в одном файле, по нему строятся и панель, и рельс; из `app_theme.dart` убрать nav-темы или оставить только то, что реально не перекрывается.

**M12. Любое изменение счётчика перестраивает всю панель.**
`app_bottom_nav.dart:51` — `ref.watch(totalUnreadCountProvider)` в корне `build`, поэтому каждый апдейт непрочитанных (socket-события) пересобирает `NavigationBar` и три `TabMorphIcon` (stateful, со своими контроллерами). Это ровно тот класс проблем, против которого §Motion & Performance AGENTS.
*Исправление:* вынести бейдж в отдельный `ConsumerWidget`, который watch-ит счётчик, а `AppBottomNav` оставить на неизменяемых данных.

### MINOR

| # | Файл:строка | Проблема | Исправление |
|---|---|---|---|
| m1 | `app_bottom_nav.dart:79-84` | hairline-бордер 0.7dp / alpha 0.35 вне токенов; спека разделитель в панели не предусматривает (разделение даёт заливка) | либо убрать, либо `Divider`-токен 1dp/`outlineVariant` |
| m2 | `main_shell_screen.dart:453` vs `web_workspace_navigation.dart:24` | `89` в шелле и `88` в рельсе — связаны арифметикой, но не константой | один токен `kNavRailWidth = 88` + `+1` на разделитель |
| m3 | `app_bottom_nav.dart:33-47` | дебаунс 120 мс только у панели; рельс не дебаунсится и не даёт фидбэка | общий обработчик (см. M8) |
| m4 | `main_shell_screen.dart:400` | комментарий «Secondary tab (Contacts, NiosGram, Profile)» — Contacts давно не таб, табов три | поправить комментарий |
| m5 | `web_workspace_navigation.dart:32`, `:35` | радиус 18 и размер 48 у логотипа — не из `AppRadiiTheme`/`AppShape`; правило AGENTS про скругления соблюдено «на глаз» | `AppRadii.of(context).lg` / `AppShape.card` |
| m6 | `app_bottom_nav.dart:175-182` | шрифт бейджа 10sp/w800 и паддинги заданы вручную, `'99+'` — магическая строка; в теме `BadgeTheme` нет | `BadgeThemeData` в теме + токен текста |
| m7 | `app_bottom_nav.dart:116` | `surfaceTintColor: Colors.transparent` при `elevation: 0` — мёртвый параметр | удалить |
| m8 | `main_shell_screen.dart:649` vs `:627-633` | панель в `RepaintBoundary`, рельс — нет | обернуть рельс так же |
| m9 | `tool/check_ui_architecture.dart:181-186` | проверка 9 ищет литералы `child: NavigationBar(` — рефакторинг вида `NavigationBar(` или вынос в переменную уронит «архитектурный» тест, ничего не сломав в продукте | проверять по AST/типу виджета или сузить до `NavigationBar(` |
| m10 | `app_bottom_nav.dart:146` | скрытие бейджа на активном табе закреплено тестом `app_bottom_nav_badge_test.dart:105-110` — при исправлении M5 тест надо переписать, а не удалять | переписать ожидание на «бейдж виден» |
| m11 | `app_bottom_nav.dart:277-283` | пульс иконки (scale 1.16, подъём 3.5dp) поверх индикатора — третья независимая анимация в одном тапе; спеке неизвестна | убрать или оставить только кросс-фейд outline↔filled |
| m12 | `main_shell_screen.dart:78` + `:333-337` | `_tabs` и `_tabIndex` — две ручные таблицы одного маппинга; `profile` маппится в 2, хотя `_tabs` такого значения не знает | один enum/дескриптор |

---

## 4. Три направления редизайна

### (a) Spec-true flexible navigation bar

64dp, паддинги 6/6, индикатор 56, лейбл `secondary` без жирности, горизонтальные пункты на 600–839, бейдж `error`/8dp/16dp и всегда видим, панель остаётся докнутой (`extendBody: false`).

* Плюсы: минимальные правки в двух файлах, снимает M1, M2, M5, M6, M7; визуально это и есть «M3E»; риск регрессий низкий.
* Минусы: не решает web/десктоп (K1, M3, M4); горизонтальная конфигурация в Flutter отсутствует, её придётся рисовать самим (свой пункт поверх `NavigationBar` или свой бар) — это уже не «одна правка числа».
* **Compose FAB:** остаётся FAB Scaffold, прижатым к правому нижнему углу над панелью. Панель ниже на 16dp → FAB опускается на 16dp; `kInboxComposerClearance = 88` (`main_shell_screen.dart:54`) — это внутренний отступ списка, его менять не нужно, но `_InboxComposerScrim` (`:812-844`) стоит перепроверить глазами. Тест `main_shell_inbox_pane_test.dart:146` продолжит проходить (он про зазор ≥16dp).
* **Бейдж:** переезжает в правый верхний угол иконки по спеке, виден и на активном табе; `99+` остаётся, но ширина вырастет с ~13 до 16dp — надо проверить, что на 24dp иконке он не задевает соседний пункт (сейчас это гарантирует тест `:100-102`).
* **Труд:** ~1,5–2 дня с тестами и снапшотами.

### (b) Floating pill / dock

Пилюля с отступом 16dp от краёв, `surfaceContainerHigh`, радиус 28/full, три пункта icon+label, контент скроллится под ней (`extendBody: true`), панель может прятаться при скролле вниз (это разрешено guidelines).

* Плюсы: сильный «экспрессивный» жест, сразу видно, что приложение не «стандартное»; штатное место для `navBarFloating`-флага (сейчас мёртвого).
* Минусы: придётся переписать нижние отступы у всех скроллящихся экранов, иначе последняя строка чата/поста уедет под пилюлю; `_InboxComposerScrim` и `kInboxComposerClearance` рассчитаны на докнутую панель и станут неверными; FAB и пилюля начинают конкурировать за один и тот же угол; снапшот-тесты (`web_workspace_test.dart`, `neutral_inbox_test.dart`) придётся перегенерировать.
* **Compose FAB:** надо поднимать на `16 (зазор) + 64 (пилюля) + 16`, то есть ~96dp от низа; либо переносить в саму пилюлю как четвёртый «пункт-действие» (тогда он перестаёт быть FAB по семантике); либо прятать его при скролле вместе с пилюлей. Сейчас FAB уже прячется на конце списка (`main_shell_screen.dart:580-588`), и с плавающей панелью эта логика станет заметнее и рискованнее.
* **Бейдж:** на пилюле лучше точкой или числом на иконке; при 3 пунктах и ширине ~360dp место есть, `99+` влезает.
* **Труд:** 3–5 дней + ревизия отступов по всему приложению.

### (c) Adaptive bar → rail с collapsed/expanded рельсом

<600 — панель 64dp; 600–839 — горизонтальная панель (из (a)); ≥840 — collapsed-рельс 96dp **на всех платформах**, не только web; ≥1200 — expanded-рельс (standard) с меню-иконкой, лейблами и бейджем у лейбла.

* Плюсы: закрывает K1, M1–M4, M7; совпадает и со спекой, и с собственными токенами проекта (`expressive_tokens.dart:189-196`); один код навигации для web и десктопа.
* Минусы: expanded-рельс на 840–1199 отнимает 220–360dp у и без того тесного сплита (список 260–640 + деталь); для трёх разделов expanded — избыточен, поэтому разумный минимум: collapsed везде ≥840, expanded только ≥1200 и по кнопке. Нужен свой виджет рельса, чтобы управлять длительностью/бейджами/лейблами (штатный `NavigationRail` не даёт ни длительности, ни бейджей в пункте).
* **Compose FAB:** на ≥840 переезжает в FAB-слот рельса сверху (спека: top-aligned, elevation 0, в expanded превращается в extended FAB). Это меняет привычное место главного действия на десктопе — но именно так спека и предписывает; в сплит-режиме FAB остаётся в инбокс-панели (как сейчас, `:797-802`). `heroTag: 'compose_chat_fab'` (`inbox_compose_button.dart:37`) придётся оставлять уникальным: два FAB одновременно (в рельсе и в панели) нельзя.
* **Бейдж:** collapsed — справа сверху иконки; expanded — рядом с лейблом; счётчик наконец виден на web (K1 закрыт). Нужен общий `NavUnreadBadge`.
* **Труд:** 5–8 дней в полном виде; 3–4 дня в минимальном (bar до 840 + collapsed-рельс 96dp без expanded).

**Рекомендация:** (a) + минимальная (c). Сначала панель до спеки (64/56/лейбл/бейдж/горизонталь в medium), затем collapsed-рельс 96dp с лейблами и бейджем на всех платформах ≥840. Это закрывает K1 и M1–M7 при умеренном риске; expanded-рельс оставить на потом и записать это решение в токены/доки, чтобы `expressive_tokens.dart:189-190` перестал обещать несуществующее.

---

## 5. Что хорошо и надо сохранить

1. **Reduce motion и тиры производительности в панели.** `app_bottom_nav.dart:52-57` + `:117` — `Duration.zero` и `short4` для tier C; это редкость и это правильно. Закреплено тестами `nav_power_saver_test.dart:78-99`, `tab_shared_axis_switcher_test.dart:212`.
2. **Тональная глубина без теней.** `app_bottom_nav.dart:76-85` — заливка `surfaceContainer` + hairline вместо elevation/boxShadow. Ровно то, что требует AGENTS. При переходе на 64dp это надо сохранить.
3. **Лейблы всегда видимы + filled-иконка активного пункта.** `:121`, `:125-135` — совпадает со спекой («Don't remove the labels», «use filled icons for active»). Это же лечит доступность на телефоне.
4. **Бейдж с ограничением `99+` и подгонкой, чтобы не залезать на глиф.** `:162-185` + тесты `app_bottom_nav_badge_test.dart:87-103`. Логику оставить, поменять только цвет/форму/размер.
5. **URL как источник состояния таба.** `main_shell_screen.dart:375` + `app_router.dart:255-266` — таб живёт в `/main/:tab`, работают deep link, browser back, `Ctrl+Alt+1/2/3` (`:418-446`). Не ломать при редизайне.
6. **Рельс вне панелей + разделитель.** `main_shell_screen.dart:627-633` — по спеке («placed outside any panes, always along the leading edge», разделитель опционален). Оставить.
7. **Панель и рельс никогда не показываются одновременно.** `:647-655` — прямое требование спеки, выполнено.
8. **Согласованные константы зазора под FAB** (`kInboxComposerClearance`, `kInboxComposerMargin`, `:51-57`) и тест, который держит зазор `fab.bottom <= nav.top − 16` (`main_shell_inbox_pane_test.dart:140-151`). При смене высоты панели эти константы остаются валидными — это удачная развязка.
9. **`maintainBottomViewPadding: true`** (`app_bottom_nav.dart:118`) — жестовый инсет не «съедает» пункты на Android.
10. **Переключение контента не пересоздаёт вкладки** (`m3_route_tab_switcher.dart:198-227`, `TickerMode`/`Offstage`) и прогревается заранее (`main_shell_screen.dart:172-188`) — состояние и скролл сохраняются, как спека и советует («Preserve state»).
11. **Тестовое покрытие навигации** — 5 файлов + проверка 9 в `tool/check_ui_architecture.dart`. Даже с оговоркой m9 это редкая для проекта дисциплина; при редизайне тесты нужно переписывать, а не удалять.

---

## 6. Что я не проверял

* **Не запускал приложение и тесты**, не собирал APK/web — всё выше статический анализ кода и чтение SDK. Реальные пиксели, FPS, поведение на устройстве — не проверены.
* **Таблицы измерений на `m3.material.io`** не читаются текстом (Measurements — картинки, токен-таблицы — JS-виджет). Числа взяты из документации Google для Android-реализации (§2.1); если у дизайна есть Figma-токены с другими значениями, сверять надо по ним.
* **Собственный токен-набор M3E в проекте** (`m3e_design`) не смотрел — возможно, там уже есть nav-токены, которые стоило бы использовать вместо чисел из этой спеки.
* **Версии Flutter.** SDK, который я читал, — 3.44.6 (`F:\Flutter\flutter\bin\cache\flutter.version.json`); CI собирает на 3.47.6. Поведение `NavigationBar`/`NavigationRail`/`Badge` в 3.47.6 не сверял, возможны отличия (например, дефолтная форма бейджа).
* **Семантика для скринридеров** (TalkBack/VoiceOver): читается ли бейдж как «99+» отдельным узлом, хватает ли лейблов рельса без тултипов — не проверял на устройстве.
* **Клавиатурный фокус** рельса и панели (Tab-порядок, focus ring) — не проверял.
* **Predicitive back** и жесты — удалены осознанно, в этом аудите не рассматривались; фон — `docs/motion-audit-2026-11-21/02-transitions-navigation.md` (C3, M11).
* **Как реально обновляются переводы.** `l10n.yaml` генерирует только `SecretChatLocalizations` из `lib/l10n/secret/*.arb`, а `AppLocalizations` (откуда берутся `tabChats`/`tabNiosgram`/`tabSettings`) лежит готовым в `lib/l10n/app_localizations_ru.dart`, и ключа `tabChats` в ARB нет. Каким пайплайном он обновляется — не выяснял.
* **Другие платформы и раскладки**: планшет Android в ландшафте, складные, iOS — код ведёт себя одинаково (панель до 840), но визуально не проверял.
* **Мьюты и счётчик.** Правда ли `chatsProvider` отдаёт `unreadCount` уже без мьютов — не проверял; из кода видно только, что `totalUnreadCountProvider` складывает всё подряд (`backend_chat_provider.dart:1136-1143`).
* **Поведение `context.go` при смене таба на web** (пересоздание страницы и потеря состояния свитчера) — известно по прошлому аудиту (M12), здесь не перепроверял.

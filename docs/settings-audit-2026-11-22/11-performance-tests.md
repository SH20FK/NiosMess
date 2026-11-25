# 11. Настройки: производительность по коду и карта тестов

Аналитик: производительность и тесты. Только чтение кода, ничего не запускалось
(`flutter`, `dart`, `git` запрещены в этой волне). Все утверждения о поведении
рантайма помечены «по коду»: это статический разбор, не замеры кадров.

Пути настроек, которые реально существуют в репозитории:

- хаб: `lib/screens/settings/settings_hub_screen.dart` — 14 строк, делегирует в
  `lib/screens/profile_screen.dart:15` (`SettingsHubScreen` → `ProfileScreen`);
  файла `lib/screens/settings_hub_screen.dart` нет.
- экраны: `lib/screens/settings_*.dart`, `lib/screens/e2ee_settings_screen.dart`
- каркас: `lib/widgets/settings_ui.dart`, `lib/widgets/settings/*.dart`,
  `lib/features/settings/**`, `lib/widgets/notifications/notification_settings_section.dart`
- состояние: `lib/providers/ui_settings_provider.dart`,
  `lib/providers/settings_navigation_provider.dart`

---

## 1. Главные выводы

1. **Хаб настроек — это `ProfileScreen`, и он слушает состояние настроек целиком**
   (`profile_screen.dart:764`). Любой переключатель в любой встроенной панели
   перестраивает мастер-панель: ~9 навигационных строк, 4 секции, header профиля и
   поиск. Для бейджа нужен только `themeMode` (`profile_screen.dart:265-270`).
2. **`settings_chats_screen.dart:30`, `settings_energy_saving_screen.dart:21`,
   `settings_language_region_screen.dart:20`, `settings_preferences_screen.dart:72`
   тоже делают `ref.watch(uiSettingsProvider)` целиком** — это 4 экрана
   «ConsumerWidget размером с экран», где курсор ползунка громкости перестраивает
   весь экран уведомлений.
3. **Самый дорогой побочный эффект — подсчёт размера хранилища в главном изоляте.**
   `storageSnapshotProvider` (`local_storage_service.dart:396-400`) при первом чтении
   обходит `documents/support/temp` рекурсивно и вызывает `entity.length()` на каждый
   файл (`local_storage_service.dart:317-345`). Этот провайдер слушает сам хаб
   (`profile_screen.dart:775`) и health-баннер (`settings_health_controller.dart:16`),
   то есть **открытие настроек запускает обход файловой системы**, а не только
   экран «Хранилище». TTL кеша 5 минут (`local_storage_service.dart:119`).
4. **Смена акцентного цвета стоит 9 × `ColorScheme.fromSeed`** — каждый превью-сватч
   пересобирает схему в `initState`/`didUpdateWidget`
   (`settings_appearance_screen.dart:518-524`, 8 палитр + кастомный, строки 34-43,
   303-327). Плюс собственный `AnimatedTheme` поверх уже анимируемой темы приложения
   (`settings_appearance_screen.dart:99-121` + `main.dart:381-390`).
5. **`uiCornerRadius` лежит внутри `VisualThemeSettings`** (`ui_settings_provider.dart:113-119`),
   поэтому любой сдвиг радиуса пересоздаёт тему всего приложения
   (`main.dart:347-408`) и запускает 600-мс анимацию темы — хотя меняется только скругление.
6. **Запись в SharedPreferences уже разведена по времени для ползунков**
   (`ui_settings_provider.dart:507-517`: 250 мс debounce; используется в
   `setMessageBubbleRadius`, `setUiCornerRadius`, `setSoundVolume` —
   строки 534, 539, 583). Но ползунок громкости всё равно пишет state на каждый тик
   (`settings_preferences_screen.dart:121-123`), а переключатели пишут сразу.
7. **В настройках нет ни одного `BackdropFilter`, `MaskFilter.blur`, `ImageFiltered`
   или `BoxShadow`** — проверено grep по 14 файлам экранов и 14 файлам
   `lib/widgets/settings/*`. Это соответствует «Motion & Performance Protocol».
   Осталось два слабых места: `Opacity` + `Clip.hardEdge` в сворачивающемся header на
   каждом кадре прокрутки (`settings_profile_header.dart:151-154, 173-188, 247-263, 272-309`)
   и `AnimatedSwitcher`, который держит **две** полноценные панели настроек
   одновременно во время переключения секции (`profile_screen.dart:571-600`).
8. **Тест `test/widgets/settings_performance_phase4_test.dart` мёртвый**: он не
   импортирован в `test/suite_test.dart` (импорты `settings_*` — строки 1-14, 44-78,
   216-226), а CI запускает ровно `flutter test test/suite_test.dart`
   (`.github/workflows/build.yml:114`). Значит три его проверки дебаунса/гидратации/resetAll
   в CI не выполняются.
9. **`settings_scroll_smoothness_test.dart` проверяет не производительность, а
   отсутствие ложных нажатий и `AnimatedScale.scale == 1.0`**
   (`settings_scroll_smoothness_test.dart:54-74`). Реальных бюджетных проверок
   (нет `saveLayer`, нет перестройки всего экрана, число перестроек на тик) в настройках нет.
10. **Тестов настроек много (~110 проверок в 20 файлах), но они в основном
    «прибитые пиксели и типы виджетов»**: `maxWidth == 860` , `PulseAvatar.radius == 52`,
    `find.byType(ExpansionTile)`, `find.byType(SettingsChoiceButtons<AppFontScale>)`,
    точные русские строки. При редизайне это основной источник красных тестов,
    а поведенческое ядро (права/приватность, кеш-очистка, гонки аккаунтов,
    device hardware) — наоборот, хорошо покрыто и его надо сохранить.

---

## 2. Часть 1. Производительность по коду

### 2.1 Область перестроения

| Где | Строка | Что не так |
|---|---|---|
| `profile_screen.dart` (хаб) | `764` | `final UiSettingsState settings = ref.watch(uiSettingsProvider);` — полное состояние. Используется только в `_getSectionBadgeValue` (`260-288`, читает `settings.themeMode`) и передаётся в `_sectionGroups`/`_buildMobileProfile`. Любой `setHaptics`, `setAnimateStickers`, `setAutoDownload*` перестраивает мастер-панель целиком. |
| `profile_screen.dart` | `556-563` | `SliverChildListDelegate.fixed([...])` собирает все секции хаба заново на каждый такой rebuild (builder-делегата нет, но и ленивости нет — для 4 секций это ок, дорого именно то, что они пересобираются от чужого состояния). |
| `profile_screen.dart` | `775-777` | `ref.watch(storageSnapshotProvider)` в хабе: любое обновление снапшота (в т.ч. после `refresh(forceRefresh: true)` из экрана «Хранилище») перестраивает хаб. |
| `profile_screen.dart` | `438-447` | `_healthIssues()` вызывает `ref.watch(settingsHealthProvider)` **внутри метода, вызываемого из `build`** — скрытый watch: хаб перестраивается на `authProvider`/`storageSnapshotProvider`/`otaUpdateProvider` (`settings_health_controller.dart:11-21`). |
| `settings_chats_screen.dart` | `30` | полный `watch` на корне экрана; нужны `sendOnEnter` и `doubleTapReactionEmoji`. |
| `settings_energy_saving_screen.dart` | `21` | полный `watch`; нужны 3 bool + `backgroundMode`. |
| `settings_language_region_screen.dart` | `20` | полный `watch`; нужны `localeCode`, `timeZoneMode`, `timeZoneId`. |
| `settings_preferences_screen.dart` | `72` | полный `watch`; экран целиком (включая `NotificationSettingsSection`) перестраивается на каждый тик ползунка громкости (`117-130`). |
| `settings_appearance_screen.dart` | `60-80` | 7 отдельных `select` — лучше, чем полный watch, но `_AppearanceScreen` это ConsumerWidget на весь экран: смена `compactMode` пересобирает и палитру, и 9 превью, и ползунок. |
| Хорошая практика для образца | `settings_storage_screen.dart:350-352`, `settings_row.dart:168-191` | В `SettingsRow`/`SettingsRow`-ветках состояние читается точечно `select` — так и надо делать везде. |

Оценка: один переключатель в панели «Оформление» на десктопе даёт rebuild
`ProfileScreen` → мастер-список (~20 строк, каждая = `SettingsSection` →
`Builder` → `Material` → `SettingsListItem` → `PressableSurface` → `AnimatedContainer`
→ `M3PressScale` → `GestureDetector`, `settings_ui.dart:214-239`,
`settings_list_item.dart:230-317`, `pressable_surface.dart:82-141`) + header + поиск.
Мастер-строка `ListView(children: [...])` (`profile_screen.dart:633`) не ленива, но
строк мало — это не проблема сама по себе, проблема в триггере.

### 2.2 Списки и ленивая сборка

| Где | Строка | Наблюдение |
|---|---|---|
| `settings_shell.dart` | `74-79` | Все настройки — `SliverToBoxAdapter(child: Column(children: children))`. Ленивой сборки нет **ни на одном** экране настроек. Для коротких форм приемлемо; для «Хранилища» (`settings_storage_screen.dart:191-383`, 9 категорий + секции) и «О системе» (`settings_about_screen.dart:116-262`) — заметный единый layout-пакет. |
| `profile_screen.dart` | `633` | `ListView(children: [...])` в мастер-панели — eager, но ~25 элементов. |
| `settings_parent` | `273` (language screen) | Единственный `ListView.builder` — выбор часового пояса, ленивый. ОК. |
| `profile_screen.dart` | `350-370` | `SearchAnchor.suggestionsBuilder` дергает `SettingsRegistry.search` на каждый символ и строит `SettingsListItem` для всех результатов без ленивости (`.map(...).toList()`). Реестр статический (`settings_registry.dart:40, 322, 700-714`), поэтому дорогая часть — не поиск, а ~N×`SettingsListItem`. |
| `profile_screen.dart` | `93-119` | `SliverAppBar.large` в каркасе: ок. |
| `settings_about_screen.dart` | `167-183` | `AnimatedSize` + `AnimatedSwitcher` на содержимом вкладки: layout каждый кадр анимации. Только по нажатию на вкладку. |

`shrinkWrap: true` внутри другого скролла в настройках **не найден** (grep по всем
файлам настроек: совпадений нет).

### 2.3 Отрисовка: blur, тени, клипы, saveLayer, RepaintBoundary

Grep по `lib/screens/settings_*`, `e2ee_settings_screen.dart`, `profile_screen.dart`,
`lib/widgets/settings/*`:

- `BackdropFilter` — 0 совпадений.
- `MaskFilter` — 0.
- `ImageFiltered` — 0.
- `BoxShadow` — 0.
- `ClipRRect` — `settings_storage_screen.dart:432` (полоска занятого места, статичная),
  `custom_color_picker_sheet.dart:217`, `about_identity_widgets.dart:46` (аватар/логотип).
- `ClipOval` — `settings_appearance_screen.dart:576` (превью-сватч, 9 штук).
- `Clip.antiAlias` — 0 в настройках; в `SettingsSection` явно `Clip.none`
  (`settings_ui.dart:233`) — соответствует правилу 2 протокола.

Отдельно:

| Место | Строки | Что по коду | Серьёзность |
|---|---|---|---|
| `settings_profile_header.dart` | `151-154` | `Material(clipBehavior: Clip.hardEdge)` вокруг `Stack` в `SliverPersistentHeader`: клип пересчитывается на каждом кадре прокрутки (delegate.build зовётся по `shrinkOffset`). | P3 |
| `settings_profile_header.dart` | `173-188`, `247-263`, `272-309` | Три `Opacity` с дробной непрозрачностью вокруг текстовых блоков — каждый даёт `saveLayer` на кадр, пока идёт сворачивание. Поддеревья маленькие (имя, `@username`, кнопка), поэтому цена ограничена. | P3 |
| `profile_screen.dart` | `571-600` | `AnimatedSwitcher(layoutBuilder: Stack(fit: expand))` держит **старую и новую** панель одновременно; при переключении на «Оформление» это означает, что во время 300-мс перехода живут два полноценных экрана, включая 9 превью-сваччей с `ColorScheme.fromSeed` (`settings_appearance_screen.dart:510-540`). | P2 |
| `system_resource_meter.dart` | `61-93` | Положительный пример: анимируемый `TweenAnimationBuilder` обёрнут в `RepaintBoundary`. | — |
| `settings_profile_header.dart` | `216-229` | Аватар в `RepaintBoundary` — ок. |
| `about_update_tile.dart` | `76` | `RepaintBoundary` вокруг прогресса — ок. |
| `settings_storage_screen.dart` | `402-458` | `_SegmentedProgressBar` — статичная, без анимации: `RepaintBoundary` не нужен. |
| `settings_appearance_screen.dart` | `340-462` | `PageView` с превью палитр: каждый поинт рисует 4 `ColoredBox` в `ClipOval`; при свайпе перерисовывается, но `RepaintBoundary` нет. Дешёво, но при редизайне стоит учесть. | P3 |

Что с «постоянно анимируемыми частями»: в настройках таких нет, кроме
`AppLoadingIndicator` (спиннер в «Хранилище»/«Системе», `settings_storage_screen.dart:149-152`,
`settings_system_device_screen.dart:34-37`) и `MorphingBrandMark` в «О системе»
(`settings_about_screen.dart:121-127`) — у последнего `AnimationController` по нажатию,
не по таймеру, и `RepaintBoundary` внутри (`morphing_brand_mark.dart:117-120, 165`).

### 2.4 Побочные эффекты в `build` и тяжёлые вычисления

| Где | Строки | Что по коду | Оценка |
|---|---|---|---|
| `local_storage_service.dart` | `317-345` | `directory.list(recursive: true)` + `await entity.length()` для **каждого** файла, в главном изоляте (нет `compute`/`Isolate`). Асинхронные `await` дают кадры, но цикл может длиться секунды на большом кеше, и каждый `length()` — платформенный вызов. | P1 |
| `local_storage_service.dart` | `136-205` | Снапшот также читает все ключи SharedPreferences черновиков и их длины (`147-158`). | P2 |
| `profile_screen.dart` + `settings_health_controller.dart` | `775`, `16` | Хаб подписан на этот снапшот ⇒ обход ФС стартует при открытии настроек, **даже если пользователь не открывал «Хранилище»**. Кеш 5 мин (`local_storage_service.dart:119`). | P1 |
| `settings_storage_screen.dart` | `28-33, 60-78` | `refresh(forceRefresh: true)` и каждый «очистить» заново запускают полный обход. | P2 |
| `settings_appearance_screen.dart` | `518-524` | `ColorScheme.fromSeed` в `initState`/`didUpdateWidget` каждого превью; при смене seed/стиля/яркости — 9 пересчётов за кадр. | P2 |
| `settings_appearance_screen.dart` | `45-51` | `_appearanceThemeProvider` (`Provider.autoDispose.family`) пересчитывает `AppTheme.themed` при любом изменении `visualTheme`, включая `uiCornerRadius`. | P2 |
| `main.dart` | `347-408` | `visualTheme` (с `uiCornerRadius`) → два `AppTheme.themed` (внутри — `ColorScheme.fromSeed`, `app_theme.dart:18-26, 53-62`) на **каждый** сдвиг радиуса; плюс `themeAnimationDuration: M3Durations.long2` (`main.dart:381-389`) — интерполяция темы всего приложения. | P2 |
| `custom_color_picker_sheet.dart` | `72-79` | `ColorScheme.fromSeed` **в `build`** — на каждый тик hue-ползунка (`331-334`) и на каждый символ hex (`399-407`). Плюс `fromSeed` для галочки выбранного пресета (`365-371`). | P2 |
| `settings_about_screen.dart` | `46-65` | `PackageInfo.fromPlatform()` и `rootBundle.loadString('assets/CHANGELOG.md')` — в `initState`, не в `build`. Хорошо. | — |
| `settings_system_device_screen.dart` | `23, 27-30` | `ref.watch(deviceHardwareProvider)` — проба железа не в build; `onRefresh` инвалидирует провайдер. Хорошо. | — |
| `e2ee_settings_screen.dart` | `190` | `ObjectKey(ref.watch(ordinaryE2eeProvider))`: при смене объекта сервиса дочерний `OrdinaryE2eeSettings` пересоздаётся с нуля (сброс локального состояния). Не про кадры — про стабильность. | P3 |
| `ordinary_e2ee_settings.dart` | `573` | `ref.watch(chatsProvider).value` внутри секции: экран E2EE перестраивается на любое обновление списка чатов. | P3 |
| `profile_screen.dart` | `64, 612, 784` | `ref.read(clientCapabilitiesProvider)` в getter, вызываемом из `build`, и отдельный `watch` того же провайдера — смешение `read`/`watch`, риск не поймать изменение в одном из путей. | P3 |
| `settings_language_region_screen.dart` | `153-195` | `Timer` на следующую минуту, `setState` раз в минуту — ок; отменяется по `TickerMode` (`176-181`). | — |

### 2.5 Запись настроек: debounce

- Инфраструктура есть: `_persistKeyDebounced` + `_pendingKeyWrites` + `_flushPendingWrites`
  (`ui_settings_provider.dart:507-530`), `flushPersist()` вызывается при уходе в фон
  (`main.dart:159, 172`).
- Задебаунсены ровно три непрерывных значения: `messageBubbleRadius` (534),
  `uiCornerRadius` (539), `soundVolume` (583).
- **Слайдер радиуса не пишет на каждое движение вообще**: он коммитит значение только
  в `onChangeEnd` (`settings_appearance_screen.dart:786-789`), а во время драга держит
  `_localValue` в локальном state (`750-791`). Это лучший паттерн в наборе.
- Ползунок громкости пишет state на каждый тик (`settings_preferences_screen.dart:121-123`),
  debounce спасает только SharedPreferences, но не кадры: `setSoundVolume` →
  новый `UiSettingsState` → rebuild всего экрана «Уведомления» (`72`) и `M3Reveal`.
- Переключатели (`setHaptics`, `setAnimateStickers`, …) пишут key сразу
  (`ui_settings_provider.dart:565-568, 714-722` и т.д.) — это нормально, они дискретные.
- `resetAll()` (772-820) делает `Future.wait` из 40 `prefs.remove` — атомарно по смыслу,
  но 40 платформенных операций; вызывается редко (кнопка «Сбросить» в
  `settings_about_screen.dart:85-105`).

### 2.6 Что реально ловят два «производительных» теста

`test/widgets/settings_scroll_smoothness_test.dart` (4 теста, 11 `expect`):

- `27-75`: после drag по строке `tappedCount == 0` и все `AnimatedScale.scale == 1.0`
  до и после скролла (проверка `PressableSurface`/`M3PressScale`,
  `pressable_surface.dart:56-69, 139`).
- `77-107`: тап вызывает callback.
- `109-145`: `SettingsSwitchTile` переключает значение.
- `147-181`: `SettingsInfoTile` показывает subtitle/value и ловит long press.

То есть это **тест отсутствия ложных срабатываний**, а не FPS. Ни `saveLayer`,
ни число rebuilds, ни время layout он не проверяет.

`test/widgets/settings_performance_phase4_test.dart` (5 тестов, 16 `expect`) — **не в CI**:

- `4.1` синхронная гидратация из `cachedPrefs` (`28-42`);
- `4.2` дебаунс ползунка: 10 тиков → одно значение в prefs (`44-64`);
- `4.3` `resetAll` чистит state и ключи (`66-85`);
- `4.4` `SettingsScaffold` рендерится (комментарий в имени обещает
  `SliverChildBuilderDelegate`, хотя `settings_shell.dart:74` использует
  `SliverToBoxAdapter`+`Column`) — проверяет только `findsOneWidget`;
- `4.5` экран «Система и устройство» рендерится.

Отсюда: единственные проверки дебаунса и `resetAll` в репозитории **не выполняются
в CI** (`.github/workflows/build.yml:114` — только `test/suite_test.dart`).

---

## 3. Таблица находок по производительности

| # | Серьёзность | Место | Что не так (по коду) | Предлагаю |
|---|---|---|---|---|
| 1 | **P1** | `profile_screen.dart:764` | Полный `watch(uiSettingsProvider)` в хабе: любое изменение любой настройки перестраивает мастер-панель, header, поиск и все секции. | `ref.watch(uiSettingsProvider.select((s) => s.themeMode))` только для бейджа «Оформление»; остальное убрать из этого экрана. |
| 2 | **P1** | `local_storage_service.dart:317-345` + `profile_screen.dart:775` + `settings_health_controller.dart:16` | Открытие настроек запускает рекурсивный обход ФС и `length()` на каждый файл в главном изоляте. | Гнать снапшот через `Isolate.run`/`compute`; не подписывать хаб на полный снапшот (нужен только признак «> 1 ГБ» — вынести в отдельный дешёвый провайдер); увеличить TTL или сделать ленивый триггер только на экране «Хранилище». |
| 3 | **P2** | `settings_appearance_screen.dart:518-524` | 9 × `ColorScheme.fromSeed` при смене seed/paletteStyle/brightness. | Считать превью лениво (только видимая страница `PageView`) или заменить на 4 тональных `ColoredBox` из уже известной схемы без `fromSeed`. |
| 4 | **P2** | `main.dart:347-408` + `ui_settings_provider.dart:113-119` | Радиус скругления входит в `visualTheme` ⇒ сдвиг ползунка пересчитывает тему всего приложения и запускает 600-мс анимацию темы. | Вынести `uiCornerRadius` (и, возможно, `fontScale`) из `VisualThemeSettings`, читать их точечно через `ThemeExtension`/`select`, не пересоздавая `ThemeData`. |
| 5 | **P2** | `settings_preferences_screen.dart:72, 117-130` | Тик ползунка громкости перестраивает весь экран «Уведомления» (включая `NotificationSettingsSection` и `M3Reveal`). | Локальный state в `_VolumeSlider`, коммит в провайдер по `onChangeEnd` (как в `settings_appearance_screen.dart:786-789`). |
| 6 | **P2** | `custom_color_picker_sheet.dart:74-78` | `ColorScheme.fromSeed` в `build` листа — на каждый тик hue-слайдера и символ hex. | Мемоизировать схему по `_selected` (пересчёт только при изменении цвета, с debounce 50-80 мс). |
| 7 | **P2** | `profile_screen.dart:571-600` | `AnimatedSwitcher` держит две панели настроек одновременно; на «Оформление» это два экрана с превью. | Короткий fade/`AnimatedSwitcher` с `SizeTransition` без второй полноценной панели или переключение без кроссфейда (уже есть reduced-motion ветка). |
| 8 | **P2** | `settings_appearance_screen.dart:99-121` | Собственный `AnimatedTheme` внутри `MaterialApp`, который уже анимирует тему (`main.dart:381-390`) — двойная интерполяция `ThemeData` на смену цвета. | Оставить один уровень: снять `AnimatedTheme` в настройках и дать это делать приложению, либо наоборот — отключить анимацию темы приложения на время нахождения в настройках. |
| 9 | **P2** | `settings_chats_screen.dart:30`, `settings_energy_saving_screen.dart:21`, `settings_language_region_screen.dart:20` | Полный `watch` на корне экрана при 2-4 реально нужных полях. | `select` на каждое поле. |
| 10 | **P3** | `settings_shell.dart:74-79` | Все дети любой панели настроек собираются и укладываются сразу (`Column` в `SliverToBoxAdapter`). | Для длинных экранов («Хранилище», «О системе») дать `SliverList.builder`-вариант каркаса. |
| 11 | **P3** | `settings_profile_header.dart:151-154, 173-188, 247-263, 272-309` | `Clip.hardEdge` + три `Opacity` с дробным значением в `SliverPersistentHeader` — `saveLayer` на кадр прокрутки. | Заменить `Opacity` на `FadeTransition`-подобную подмену через `AnimatedOpacity` вне скролл-зависимого слоя или на смену цвета текста (`withValues(alpha:)`) без `saveLayer`. |
| 12 | **P3** | `profile_screen.dart:350-370` | `SearchAnchor` строит все результаты `SettingsRegistry.search` на каждый символ. | Строить лениво (`ListView.builder`) и/или ограничить топ-N. |
| 13 | **P3** | `profile_screen.dart:438-447` | Скрытый `ref.watch` внутри метода, вызываемого из `build`. | Вернуть в `build` явным именованным `watch`, чтобы было видно зависимости. |
| 14 | **P3** | `e2ee_settings_screen.dart:190`, `ordinary_e2ee_settings.dart:573` | `ObjectKey` по объекту сервиса пересоздаёт дочернее дерево; watch списка чатов в секции. | Ключ по `userId`; `select` на нужный срез чатов. |
| 15 | **P3** | `settings_screens_m3_test.dart:87-116` (тест) | Единственный «performance»-тест в CI — `settings_scroll_smoothness`, проверяет только отсутствие ложных тапов. | Добавить бюджетные тесты (см. §6). |

---

## 4. Часть 2. Карта тестов

### 4.1 Что есть

Все файлы — `test/…` внутри `pulse_flutter`. «В suite» = импортирован и вызван в
`test/suite_test.dart` (единственная команда CI: `flutter test test/suite_test.dart`,
`.github/workflows/build.yml:114`).

| Файл | Что проверяет (по именам тестов) | В suite | Тестов | `expect` | Тип |
|---|---|---|---|---|---|
| `widgets/settings_screens_m3_test.dart` | 1.1-1.2 каркас (embedded/standalone), 1.3 тональная секция и радиус ≥ 24, 1.4 `isSelected`, 1.5 `Switch`, 1.6 value/subtitle, 1.7-1.15 инстанцирование 9 экранов, 2.1-2.2 пять вьюпортов 360→3840 без overflow, 3.1-3.3 реестр (уникальные id/route, поиск ru/en, ≥ 20 узлов) | да (`222`, `498`) | 17w + 3u | 45 | **пиксели+типы**: `group.color == surfaceContainerLow` (`213-221`), `radius >= 24` (`222`), `find.byType(SettingsChoiceButtons<AppFontScale>)` (`348`), `find.byType(Slider)` (`404`), `find.byType(AppBar) == nothing` (`111`, `168`) |
| `widgets/settings_refresh_test.dart` | браузерные security-настройки не поднимают биометрию (`115-141`), клавиатурная активация строки (`143-159`), одна семантика-переключатель и один tap = одно изменение (`174-225`), нейтральные иконки/парные тона (`227-263`), appearance+language на 360dp/200% (4 комбинации × 8 drag, `265-301`), поиск раскрывает `ExpansionTile` и сохраняет legacy-значения (`303-353`), реестр в двух языках (`355-380`), пауза видео-контроллера по настройке (`382-424`) | да (`44`, `492`) | 7w + 1u | 33 | смешанный: поведение (семантика, клавиатура, видео) + **типы** `ExpansionTile` (`322-346`) + **цвета** (`254-261`) + геометрия `getRect(...).top < 844` (`338`) |
| `widgets/settings_redesign_test.dart` | хаб держит identity при скролле, `PulseAvatar.radius == 52` (`160-179`), `M3Reveal` при reduced motion без тикеров (`181-218`), 320dp/200% ru/en × light/dark без исключений (`220-243`) | да (`4`, `448`) | 3w | 12 | **пиксели**: `radius, 52` (`165`, `173`), ширина hit-зоны ≥ 48 (`177`) |
| `widgets/settings_redesign_personalization_test.dart` | 320dp/200% читаемость appearance/chats/language/energy (4 экрана × 4 комбинации, `121-162`), AI-квота (`164-221`), быстрые реакции `ChoiceChip` (`223-236`), отмена выбора TZ и поиск (`238-272`), лист TZ с клавиатурой (`274-305`), звуковое превью (`307-374`), Plus trial coalescing (`376-448`), late Plus status (`450-472`) | да (`5`, `450`) | 9w | 41 | в основном поведение; лимиты пикселей — только «нет исключения»/overflow |
| `widgets/settings_redesign_security_test.dart` | 12 unit-тестов: очистка кеша не трогает Temp/документы/outbox (`192-470`), симлинки не удаляют внешний файл, гонки device-list/revoke/privacy по аккаунтам (`471-703`); 2 widget: pending recovery key после смены аккаунта (`706-765`), session detail 320dp/200% (4 комбинации, `767-` ) | да (`9`, `459`) | 2w + 12u | 54 | **логика/поведение** — самое ценное и наименее хрупкое |
| `widgets/settings_redesign_profile_editor_test.dart` | редактор профиля: 320dp/200%+клавиатура (4 комбинации), черновик A не сохраняется в B, coalescing сохранения, ошибка сохраняет черновик, disposed callbacks | да (`7`, `454`) | 5w | 29 | поведение + доступность, минимум пикселей |
| `widgets/settings_redesign_system_test.dart` | юниты провайдера железа (кеш, дедуп in-flight, отсутствие выдуманных характеристик, невалидные измерения), resource labels 320dp/200% | да (`11`, `462`) | 2w + 5u | 35 | логика + «нет overflow» |
| `widgets/settings_redesign_system_dialogs_test.dart` | support-write без автореплея, failed acknowledgement сохраняет текст, About documents/team 320dp/200%, report dialog с клавиатуры, alpha-информация | да (`13`, `464`) | 4w + 1u | 21 | поведение + доступность |
| `widgets/settings_redesign_system_profile_dialogs_test.dart` | рабочие часы, лимит бейджей ≤ 2 и одно сохранение, late badge data после смены аккаунта | да (`1`, `469`) | 3w | 13 | поведение |
| `widgets/settings_master_detail_test.dart` | провайдер выбранной секции (`158-184`), 2-панельный layout на 1024dp с ключом `settings-master-pane` (`189-230`), переключение панели (`232-268`), `isSelected` (`270-306`), мобильный fallback (`309-338`), 6 вьюпортов (`340-414`) | да (`220`, `497`) | 5w + 2u | 32 | **пиксели/структура**: `find.byKey('settings-master-pane')`, `master.width >= 300`, `master.right ≈ detail.left`, `CustomScrollView` |
| `widgets/settings_desktop_restructure_test.dart` | `Align(topCenter)` + `ConstrainedBox.maxWidth == 860` и `== 1120` | да (`218`, `496`) | 2w | 9 | **чистые пиксели** |
| `widgets/settings_about_screen_test.dart` | reduced motion открывает вкладку сразу, 3 «pill»-таба, документы (4 пункта), команда (`sanlsan`, `SH20FK`) | да (`216`, `495`) | 4w | 13 | **тексты ru + структура вкладок** |
| `widgets/settings_system_device_test.dart` | все секции характеристик с точными строками (`Система и устройство`, `Дисплей и графика`, `1080 × 2412 px`, `120 Гц`, `391 ppi`), отсутствие `AppBar` в embedded, unit-мапперы SoC/маркетингового имени | да (`225`, `500`) | 2w + 3u | 24 | **пиксели/тексты** (widget) + логика (unit) |
| `widgets/settings_scroll_smoothness_test.dart` | отсутствие ложных тапов и `AnimatedScale.scale == 1.0`, тап/toggle/long-press работают | да (`223`, `499`) | 4w | 11 | поведение + **тип `AnimatedScale`** |
| `widgets/settings_performance_phase4_test.dart` | гидратация из кеша, дебаунс ползунка, `resetAll`, рендер каркаса, рендер «Системы» | **нет** | 2w + 3u | 16 | логика + smoke |
| `widgets/ordinary_e2ee_settings_test.dart` | theme/recovery-контролы влезают в 320px/200% (2 яркости) | да (`73`, `293`) | 1w (×2) | 8 | пиксели/overflow |
| `widgets/web_settings_paste_test.dart` | веб-настройки сохраняют секцию при ресайзе и дают один заголовок в compact web (`55-150`), вставленная картинка не теряется при ошибке (`152-` ) | да (`53`, `479`) | 2w | 20 | поведение (веб) |
| `unit/settings_registry_test.dart` | `getTopLevelSections` = 9 без `account`/`system_device` (`12-27`), поиск «скругление»/«corner» (`29-48`), отключённые контролы не рекламируются (`50-68`), blacklist (`70-76`), пустой запрос (`78-81`) | да (`46`, `493`) | 5u | 27 | логика реестра |
| `settings_plus_navigation_test.dart` | back из Plus выходит из прямого и pushed-маршрута даже после скролла | да (`78`, `410`) | 1w (×2) | 4 | поведение |
| `e2e/niosgram_and_settings_e2e_test.dart` | 3.1 ресайз ленты при скролле, 3.2 переключение темы в master-detail, 3.3 навигация Feed↔Settings, 4.1 сценарий ленты, **4.2 полный сценарий настроек** (переключение секций, выбор размера шрифта через `SettingsChoiceButtons<AppFontScale>`, ползунок громкости, `Icons.notifications_active_rounded`), 4.3 мобильный стек | да (`169`, `541`) | 6w (3 про настройки) | 33 | **пиксели+типы+иконки**: `find.widgetWithText(SettingsListItem, 'Оформление')`, `find.byIcon(Icons.notifications_active_rounded)` (`520`) |

Итого по настройкам: ~20 файлов, ~120 тестов, ~520 `expect`.

### 4.2 Поведение vs прибитые пиксели

**Поведение (страховка, переживёт редизайн почти без правок):**

- `settings_redesign_security_test.dart` (12 unit) — права/приватность, кеш-очистка,
  гонки аккаунтов. Тестирует сервисы, не виджеты.
- `settings_redesign_system_test.dart` (5 unit) и unit-часть `settings_system_device_test.dart`
  (мапперы SoC/имен) — железо.
- `unit/settings_registry_test.dart` — реестр/поиск (но зависит от id узлов и ru-строк).
- `settings_redesign_profile_editor_test.dart`, `settings_redesign_system_dialogs_test.dart`,
  `settings_redesign_system_profile_dialogs_test.dart`, часть
  `settings_redesign_personalization_test.dart` — сценарии с клавиатурой, черновиками,
  ошибками, сменой аккаунта.
- `web_settings_paste_test.dart` — веб-навигация и вставка.
- `settings_plus_navigation_test.dart` — back-навигация.
- `settings_scroll_smoothness_test.dart` — семантика нажатий (но завязан на `AnimatedScale`).
- `settings_refresh_test.dart` частично: семантика одного переключателя (`174-225`),
  клавиатура (`143-159`), пауза видео (`382-424`).

**Прибитые пиксели/типы (сломаются от редизайна):**

| Файл | Степень | Что именно прибито |
|---|---|---|
| `settings_desktop_restructure_test.dart` | **переписать целиком** | `Align(topCenter)` + `ConstrainedBox.maxWidth 860/1120` (`81-91`, `127-137`) — это проверка реализации `SettingsShell`, а не поведения. |
| `settings_screens_m3_test.dart` | **частично, ~60 %** | 1.3 цвет секции и радиус (`213-222`), 1.8/1.11/1.12 типы контролов (`348`, `385`, `404`), 1.1/1.2 наличие `AppBar` (`168`, `188`). Инстанцирование 1.7-1.15 и вьюпорты 2.x — полезны, их оставить. |
| `settings_master_detail_test.dart` | **переписать целиком** | Ключ `settings-master-pane`, `master.width >= 300`, `master.right ≈ detail.left`, наличие `CustomScrollView` — вся геометрия двухпанельного лэйаута. |
| `settings_about_screen_test.dart` | **частично** | Тексты вкладок и 4 документа — оставить как контент-проверку; «3 Pill tabs» и порядок — прибито. |
| `settings_system_device_test.dart` (widget-часть) | **частично** | Точные ru-строки секций (`72-97`); при переименовании секций — править. |
| `settings_redesign_test.dart` | **частично** | `PulseAvatar.radius == 52` (`165`, `173`), `InkWell` вокруг аватара (`174-176`). |
| `settings_refresh_test.dart` | **частично** | `find.byType(ExpansionTile)` + `controller.isExpanded` (`322-346`), цвета `onSecondaryContainer/onSurfaceVariant` (`254-261`), координата `top < 844` (`338`). |
| `e2e/niosgram_and_settings_e2e_test.dart` | **частично (сценарий 4.2)** | Иконка `Icons.notifications_active_rounded` для входа в «Уведомления» (`520`) и `SettingsChoiceButtons<AppFontScale>` (`510-517`) — заменить на семантические/по ключам локаторы. |
| `settings_scroll_smoothness_test.dart` | **частично** | `find.byType(AnimatedScale)` и `scale == 1.0` (`54-74`) — прибито к `M3PressScale`. |
| `widgets/appearance_palette_test.dart` (не в моём списке, но про настройки) | **частично** | `find.byType(NiosColorField)` и `scheme.primary` в промежуточном кадре (`46-60`), `find.byType(ChoiceChip)` внутри поля (`348`). |

Оценка трудозатрат: полностью переписать 2 файла (desktop_restructure,
master_detail), существенно — `settings_screens_m3` (~60 %), остальные — точечно.

---

## 5. Пробелы покрытия

Экраны и сценарии, где тестов настроек нет вообще либо есть только «не упало»:

1. **`SettingsEnergySavingScreen`**: покрыт только smoke-рендером на 320dp
   (`settings_redesign_personalization_test.dart:134`). Нет проверок:
   выбор `backgroundMode` дергает `BackgroundService.requestDisableBatteryOptimization`
   / `SystemUtils.requestIgnoreBatteryOptimizations`
   (`settings_energy_saving_screen.dart:109-119`), появление кнопки
   «игнорировать оптимизацию» только при `reliable` (`142-168`), поведение на iOS
   (ветка `else` с `SettingsRow`, `172-182`).
2. **`SettingsChatsScreen`**: `sendOnEnter` нигде не проверяется (только рендер и
   быстрые реакции, `settings_redesign_personalization_test.dart:223-236`);
   диалог «Папки чатов» — `chat_productivity_test.dart:456`, но не через сам экран
   настроек.
3. **`SettingsWallpaperScreen` → `WallpaperStudioScreen`**: widget-тестов студии нет
   (есть только `ChatWallpaperPainter`, `NiosWeave` encode/decode и URL-резолв).
   Для настроек это значит: маршрут `/settings/wallpaper` и `initialCode` не покрыты.
4. **`NotificationSettingsSection`** (`lib/widgets/notifications/notification_settings_section.dart`)
   и весь экран «Уведомления» (`SettingsPreferencesScreen`): нет ни одного теста на
   переключение 6 тумблеров, на `_permission`-ветки (`118-132`), на
   `_change`/ошибку (`43-55`). Есть только «экран инстанцируется и есть `Slider`»
   (`settings_screens_m3_test.dart:389-406`).
5. **`SettingsAccountScreen`**: только инстанцирование. Копирование в буфер
   (`settings_account_screen.dart:100-105`) не проверяется.
6. **`SettingsStorageScreen` UI**: сервис покрыт (`settings_redesign_security_test.dart`),
   но UI-поток «нажать Очистить → подтвердить → прогресс/тост/refresh», ветка `kIsWeb`
   (`settings_storage_screen.dart:100-140`) и ошибка снапшота (`153-175`) — нет.
7. **Хаб-поиск `SearchAnchor`** (`profile_screen.dart:290-373`): логика поиска покрыта,
   сам UI (открытие вью, переход по результату с anchor, `_selectSection`) — нет.
8. **`resetAll()` (кнопка «Сбросить настройки»)**: в CI не покрыт, потому что
   единственный тест живёт в невидимом `settings_performance_phase4_test.dart`.
9. **Персистентность `UiSettingsNotifier`**: в CI нет тестов на `readFromPrefs`
   по каждому ключу, на debounce, на `flushPersist`. Только косвенно через UI.
10. **Все остальные `SettingsAnchor`-точки** (реестр знает ~40 узлов,
    `settings_registry.dart:322-697`), кроме `ui_corner_radius`
    (`settings_refresh_test.dart:327-337`) и `chats.callDevices`/`auto_download_wifi`
    (в юнит-тестах реестра), не проверены на «поиск → раскрылось → проскроллилось».
11. **Пустая директория `test/features/settings/`** — существует, но пустая:
    место под слоевые тесты фичи `lib/features/settings/**` не используется.
12. **Нет ни одного бюджетного теста**: число rebuild на тик, отсутствие `saveLayer`,
    стоимость обхода ФС. `unit/list_virtualization_memory_test.dart` и
    `unit/performance_lifecycle_regression_test.dart` в suite есть, но к настройкам
    не относятся.

---

## 6. `tool/check_ui_architecture.dart`

Скрипт (`204` строки) — grep-и по `lib/`, 10 проверок; **в CI не вызывается**
(в `.github/workflows/*.yml` нет упоминания, только `tool/…py` и
`tool/chrome_synthetic_media.sh`).

Правила, которые касаются настроек:

| # | Правило | Строки | Отношение к настройкам |
|---|---|---|---|
| 1 | `showModalBottomSheet(` запрещён вне `core/modal/` | `41-57` | Настройки используют `AppModal.showSheet` (`settings_language_region_screen.dart:123`, `settings_appearance_screen.dart:237`) — проходит. |
| 2 | `showGeneralDialog(` запрещён вне `core/modal/` | `59-75` | В настройках нет. |
| 3 | `AlertDialog(` запрещён в фичах | `77-93` | Настройки используют `showAppConfirmDialog` (`settings_storage_screen.dart:81`, `e2ee_settings_screen.dart:125`). |
| 4 | `showDialog(` запрещён вне `core/modal/` и `app_dialogs.dart` | `95-112` | `settings_about_screen.dart:195` использует `showAppDialog` — проходит. |
| 5 | **`BackdropFilter(` запрещён в `widgets/`, кроме `adaptive_glass.dart`** | `114-132` | Единственное правило скрипта, которое напрямую про производительность: размытий в `lib/widgets/settings/*` нет. `lib/screens/**` этим правилом **не** покрыт. |
| 6 | Модели `AiAction`/`AiQuota`, `sessionAccessTokenProvider` | `134-157` | К настройкам относится косвенно (AI-квота выводится в Plus/AI-карточке). |
| 7 | `AnimatedSwitcher` + `expressiveDecel` в `main_shell_screen.dart` | `159-168` | Не про настройки. |
| 8 | Нижний бар/рейл на `AppNavItem` с reduced-motion | `170-197` | Не про настройки. |
| 9 | Чат-маршрут использует `M3SharedAxisPageTransitionsBuilder` | `199-211` | Не про настройки. |

Чего скрипт **не** проверяет и что стоит добавить под редизайн (это дешевле, чем
визуальные тесты): запрет `watch(uiSettingsProvider)` без `select` в
`lib/screens/settings*`/`profile_screen.dart`; запрет `ColorScheme.fromSeed` в
`build`; запрет `Opacity(` внутри `SliverPersistentHeader`; запрет блокирующих
обходов ФС в UI-провайдерах.

---

## 7. Стратегия тестов под редизайн

### 7.1 Оставить как есть (не трогать, это страховка)

- `settings_redesign_security_test.dart` (12 unit) — приватность, очистка кеша, аккаунт-гонки.
- `settings_redesign_system_test.dart` (5 unit) + unit-часть `settings_system_device_test.dart`.
- `settings_redesign_profile_editor_test.dart`, `settings_redesign_system_dialogs_test.dart`,
  `settings_redesign_system_profile_dialogs_test.dart`.
- `web_settings_paste_test.dart`, `settings_plus_navigation_test.dart`,
  `unit/settings_registry_test.dart`.
- Вьюпорт-матрицы (`320dp/200%`, `360→3840`) из `settings_screens_m3_test.dart:442-497`,
  `settings_refresh_test.dart:265-301`, `settings_redesign_personalization_test.dart:121-162` —
  перенести в один параметризованный helper и расширить на все панели.

### 7.2 Написать ДО начала редизайна (сейчас этих тестов нет)

1. **Контракт состояния, не вида**: тест `uiSettingsProvider` — для каждого сеттера
   «вызвал → state изменился → ключ в prefs (с учётом debounce) → гидратация обратно».
   Это переезд `settings_performance_phase4_test.dart` в `unit/` + `suite_test.dart`.
   Убирает зависимость от UI при проверке persist-логики.
2. **Контракт `SettingsRegistry` ↔ экраны**: для каждого узла из
   `SettingsRegistry.getAllNodes()` (≥ 20, проверено `settings_screens_m3_test.dart:558-567`)
   проверка «anchor существует в дереве соответствующего экрана». Это единственный
   тест, который переживёт любую переверстку и поймает «поиск ведёт в пустоту».
3. **Бюджетные проверки вместо кадров**:
   - число rebuild `ProfileScreen` на один `setHaptics` (счётчик в `MaterialApp.builder`
     или `find`-хук) — цель: 0 перестроек мастер-панели;
   - `ColorScheme.fromSeed` не вызывается в `build` (статический аудит-тест по AST/строкам);
   - `LocalStorageService.snapshot` не вызывается при открытии хаба (fake-сервис со
     счётчиком в оверрайде);
   - число записей в `SharedPreferences` за 20 тиков ползунка == 1
     (уже есть в мёртвом 4.2 — вернуть в CI).
4. **Смоук всех 13 `SettingsSectionId`** (`settings_navigation_provider.dart:5-18`):
   для каждой секции `ProfileScreen` в десктопе рендерится без исключения и содержит
   хотя бы один `SettingsListItem`/`SettingsRow`. Сейчас покрыты не все
   (energySaving/plus/chats — частично).
5. **Golden-free скриншоты**: капчур-механизм уже есть
   (`settings_redesign_test.dart:83-158`, `NIOS_SETTINGS_CAPTURE_DIR`) — использовать
   для ручного визуального сравнения до/после, не в CI.

### 7.3 Удалить вместе со старым кодом

- `settings_desktop_restructure_test.dart` — целиком (проверяет `Align`/`maxWidth`
  конкретного каркаса).
- `settings_master_detail_test.dart` — переписать, старую версию удалить
  (ключ `settings-master-pane`, геометрия `master.right ≈ detail.left`).
- Пиксельные части `settings_screens_m3_test.dart:193-259, 321-440` (тональная
  поверхность, радиус 24, типы контролов) — заменить на семантические проверки
  («секция объявлена header-семантикой», «контрол доступен по роли»).
- `find.byType(ExpansionTile)`-проверки (`settings_refresh_test.dart:322-346`) —
  заменить на «после поиска anchor-элемент виден в вьюпорте».
- `PulseAvatar.radius == 52` (`settings_redesign_test.dart:165, 173`).
- `find.byType(AnimatedScale)` (`settings_scroll_smoothness_test.dart:54-74`) —
  на «tap во время drag не срабатывает», без привязки к классу.
- Иконки/точные ru-строки как единственный локатор в e2e
  (`niosgram_and_settings_e2e_test.dart:501, 520`) — на `ValueKey` секций
  (`settings-destination-*` уже существуют, `profile_screen.dart:418`).

### 7.4 Порядок работ

1. Сначала: перенос persist-тестов в `unit/settings_persistence_test.dart` и подключение
   в `suite_test.dart` (закрывает мёртвый `phase4`).
2. Затем: тест «anchor существует на экране» + смоук всех 13 секций.
3. Потом бюджетные проверки (rebuild scope, fromSeed, обход ФС).
4. Только после этого — редизайн, при котором удаляются пиксельные проверки из §7.3.

---

## 8. Не проверено

- **Ничего не запускалось**: `flutter test`, `flutter analyze`, `dart test`,
  `tool/check_ui_architecture.dart` не выполнялись (запрет волны). Пройдут ли текущие
  тесты — не знаю; в частности строки в `settings_system_device_test.dart:72-97`
  (`Дисплей и графика`, `Оптика и камеры`) выглядят как возможное расхождение с
  текущими l10n-ключами (`settingsDeviceDisplay`, `settingsDeviceCameras`), но это
  не проверено.
- **Кадры/время кадра не измерялись.** Все оценки («дорого», «P1/P2») — вывод из
  количества работы в коде и области перестроения, не из профайлера.
- **`LibWallpaperStudioScreen`** (`lib/features/wallpaper/presentation/wallpaper_studio_screen.dart`)
  и его Canvas-рендер по производительности не разбирал.
- Подэкраны-диалоги (bade-селектор, `EditProfileSheet`, sheet сессий) не аудировал
  по производительности — только по тестам, которые их касаются.
- **Веб-специфика** (`kIsWeb`-ветки `profile_screen.dart:788-812`,
  `settings_storage_screen.dart:100-140`) не проверялась на chrome-платформе
  (`build.yml:118-124` запускает другие файлы).
- Не проверял, есть ли `test/features/settings` в `.gitignore`/истории — директория
  пустая, содержимое не установлено.
- Не оценивал стоимость `AppTheme.themed` численно (`app_theme.dart:31-67`) — только
  факт вызова `ColorScheme.fromSeed` внутри и количество вызовов на rebuild.

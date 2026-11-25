# 03. Настройки глазами фаната Material 3 Expressive

**Роль:** убеждённый сторонник M3E. Позиция: настройки NiosMess должны выглядеть и двигаться как эталонное expressive-приложение, а не как аккуратный M3-baseline.
**Дата:** 2026-11-22. **Код:** `F:/Niosmess V2/pulse_flutter`.
**Метод:** только чтение кода и сверка со спецификацией m3.material.io. `flutter`/`dart`/`git` не запускались (12 параллельных агентов). Всё, что не подтверждено кодом или источником, помечено «по памяти» / «не проверено».

Коротко о главном: **настройки NiosMess — это уже очень хороший M3 baseline и местами M3E, но expressive-слой включён наполовину.** Есть настоящие пружины, тональные группы, 40×40-слоты иконок и M3E-индикатор загрузки — и при этом нет shape-morph у выбранной строки, нет state layer, группы игнорируют пользовательский радиус скругления, а «expressive»-кривые в токенах — это переименованные baseline-кривые. P0 нет, но P1 набирается на полноценный редизайн-спринт.

---

## 1. Главные выводы

1. **Каркас правильный, expressive-детали — нет.** `SettingsSection` уже собирает связную группу: внешний радиус + 4 dp у внутренних строк (`lib/widgets/settings_ui.dart:218-226`), тональная поверхность `surfaceContainerLow` (`:224-226`), 2 dp зазор (`:215`). Это ровно логика expressive-списков — но реализована «вручную» и с отклонениями (см. п. 3 и 5).
2. **Пользовательский радиус скругления сломан именно в настройках.** `outer = AppRadii.of(context).lg.clamp(24.0, 32.0)` (`lib/widgets/settings_ui.dart:179`) при настройке `uiCornerRadius` 8…28 dp: `AppRadiiTheme.fromCornerRadius` кладёт `lg = cornerRadius` (`lib/core/theme/expressive_tokens.dart:113-123`), значит любой радиус 8–23 dp молча превращается в 24. Пользователь крутит ползунок «Скругление интерфейса» (`lib/screens/settings_appearance_screen.dart:204-215`) и не видит эффекта на самом частом экране. Это P1.
3. **Выбранная строка не делает shape morph.** По спеке expressive-списка выбранный элемент получает радиус 16 dp со всех сторон, невыбранный — 4 dp изнутри и 16 dp снаружи (m3 lists/specs). У нас выбранная строка сохраняет радиус группы (`lib/widgets/settings/settings_list_item.dart:310-311`), то есть 4 dp на внутренних строках, и только заливается `secondaryContainer` (`:311`). Классическая «заливка без морфа» — самый заметный дешёвый промах.
4. **Нет state layer и hover.** `PressableSurface` рисует `AnimatedContainer` с цветом и focus-рамкой 2 dp (`lib/widgets/settings/pressable_surface.dart:87-109`) и `M3PressScale(0.98)` (`:139`), но не использует `InkWell`/`InkResponse`, поэтому нет ни ripple, ни hover-слоя. На десктопе настройки живут в master-detail (`lib/screens/profile_screen.dart:603-674`), и там hover — базовая обратная связь, а её нет.
5. **Hub не показывает заголовки групп.** `_sectionGroups` строит `SettingsSection(children: …)` без `title` (`lib/screens/profile_screen.dart:412-433`), название группы уходит только в `Semantics.label` (`:409-411`). M3E прямо просит группировать похожее в «informative groupings» (m3 blog/building-with-m3-expressive), а Android 16 Settings показывает разделы явно. Сейчас четыре группы визуально — четыре безымянных стопки.
6. **Все иконки разделов одного цвета.** `isSection` даёт 40×40 `primaryContainer` с радиусом 14 (`lib/widgets/settings/settings_list_item.dart:239-249`), цвет иконки — `onPrimaryContainer` (`:163-164`). В редизайне системных настроек Android 16 каждый раздел получает свою пастельную иконку в круге, и это главный механизм wayfinding (androidpolice; YouTube-обзоры). У нас 13 разделов выглядят одинаково.
7. **Компонентный класс выбора не тот.** Все выборы «из вариантов» — это `ChoiceChip` в `Wrap` (`lib/widgets/settings/settings_choice_buttons.dart:17-38`): тема, масштаб шрифта, палитра, язык, часовой пояс, фоновая работа, табы «Что нового». По M3 это `segmented button` (40 dp, full radius, 2–5 сегментов), а с мая 2025 сам segmented button «no longer recommended — use the connected button group» (m3 segmented-buttons/overview). Мы используем третий по рекомендации компонент.
8. **App bar — baseline, и он не отделяется от контента при скролле.** `SliverAppBar.large` (`lib/widgets/settings/settings_shell.dart:85-96`) с `backgroundColor: surface` и `scrolledUnderElevation: 0` (`:99-100`). Спека: baseline medium/large больше не рекомендуются, вместо них medium/large flexible (m3 app-bars/specs), а на скролле должен появляться **fill**, а не тень (m3 app-bars/overview). У нас на скролле не появляется ничего.
9. **Движение: физика верная, а «expressive»-кривые — нет.** Пружины `spatial/effects` с числами 800/0.6, 380/0.8, 200/0.8 и 3800/1.0, 1600/1.0, 800/1.0 (`lib/core/motion/m3_spring_constants.dart:12-53`) и settle-time 350/500/650 / 150/200/300 (`:206-211`) совпадают с официальной таблицей m3 motion/specs. Но `expressiveDecel = Cubic(0.05,0.7,0.1,1.0)`, `expressiveStandard = Cubic(0.2,0,0,1)`, `expressiveAccel = Cubic(0.3,0,0.8,0.15)` (`:177-183`) — это baseline-кривые `emphasized*` (по памяти) под expressive-именами; официальные expressive-кривые имеют контрольные точки вида `0.42, 1.67, 0.21, 0.90` (m3 motion/specs) и овершутят. Названия в коде врут, и часть анимаций настроек ездит на effects-кривой там, где меняется геометрия (например `AnimatedSize` в `lib/screens/settings_about_screen.dart:170-183`).
10. **Запреты AGENTS.md почти соблюдены — кроме обоев.** В самих экранах настроек нет `BoxShadow`, нет `elevation > 0`, нет прямых `CircularProgressIndicator`/`LinearProgressIndicator` (единственный `LinearProgressIndicator` — внутри разрешённого `AppLoadingIndicator` для детерминированного прогресса, `lib/widgets/pulse_loading_indicator.dart:34-48`), `Switch`/`Checkbox` идут через тему. Но `settings_wallpaper_screen.dart` — это обёртка над `WallpaperStudioScreen` (`lib/screens/settings_wallpaper_screen.dart:20-25`), а там `PopupMenuButton` (`lib/features/wallpaper/presentation/wallpaper_studio_screen.dart:224`) и обычный `AppBar` (`:221`), то есть запрет №4 AGENTS.md нарушен внутри настроечного маршрута.

---

## 2. Эталон M3E: числа и правила с источниками

| Что | Значение | Источник |
|---|---|---|
| Expressive list, невыбранный элемент | 4 dp внутренний радиус, 16 dp внешний | [m3 lists/specs](https://m3.material.io/components/lists/specs) |
| Expressive list, выбранный элемент | 16 dp со всех сторон (shape morph) | там же |
| Высоты элементов списка | 56 / 72 / 88 dp; ≥88 dp или 3+ строки — выравнивание по верху | [m3 lists/overview](https://m3.material.io/components/lists/overview) |
| Разделитель списка | inset слева 16 dp, справа 24 dp; padding над/под 0 | m3 lists/specs |
| Trailing-элемент | padding слева 16 dp, справа 24 dp; touch target 48 dp | m3 lists/specs |
| Baseline-списки | «Not recommended. Use expressive lists instead» | m3 lists/specs (таблица вариантов) |
| Switch: track | 32 dp высота × 52 dp ширина, outline 2 dp, `corner.full` | [m3 switch/specs](https://m3.material.io/components/switch/specs) |
| Switch: handle | 16 dp (off) / 24 dp (on) / 28 dp (pressed), иконка в handle 24 dp, state layer 40 dp | там же |
| Slider XS | track 16 dp, handle 44 dp × 4 dp, радиус трека 8 dp, label 44×48 dp | [m3 sliders/specs](https://m3.material.io/components/sliders/specs) |
| Slider, форма | handle меняет ширину при выборе, трек меняет форму у края | [m3 sliders/overview](https://m3.material.io/components/sliders/overview) |
| Segmented button | высота 40 dp, full radius, 2–5 сегментов, sentence case | [m3 segmented-buttons/overview](https://m3.material.io/components/segmented-buttons/overview) |
| Segmented button, статус | «no longer recommended. Use the connected button group instead» (May 2025) | там же |
| Connected button group | новый компонент M3E; объединяет переключаемый набор, встроенный shape morph | [m3 button-groups/specs](https://m3.material.io/components/button-groups/specs), доклад Google «Build next-level UX with M3 Expressive» ([YouTube](https://www.youtube.com/watch?v=6IsFP3gD28E)) |
| Кнопки, радиусы | round = full; square: XS/S 12 dp, M 16 dp, L/XL 28 dp; pressed square: 8/12/16 dp | [m3 buttons/specs](https://m3.material.io/components/buttons/specs) |
| Кнопки, padding | small button: 16 dp (24 dp — «not recommended») | m3 buttons/specs |
| App bars | baseline medium/large не рекомендуются → medium flexible / large flexible | [m3 app-bars/specs](https://m3.material.io/components/app-bars/specs) |
| App bars, скролл | без тени; разделение с контентом — заливкой цвета | [m3 app-bars/overview](https://m3.material.io/components/app-bars/overview) |
| Шкала радиусов M3E | large 16, large increased 20, XL 28, XL increased 32, XXL 48, full | [m3 shape/overview-principles](https://m3.material.io/styles/shape/overview-principles) |
| Цвет групп | `surfaceContainerLow` — карточки/элементы списка; container-роли — для компонентов | [m3 color/roles](https://m3.material.io/styles/color/roles) |
| Motion, expressive fast spatial | `cubic-bezier(0.42, 1.67, 0.21, 0.90)`, 350 ms | [m3 motion/specs](https://m3.material.io/styles/motion/overview/specs) |
| Motion, expressive default spatial | `0.38, 1.21, 0.22, 1.00`, 500 ms | там же |
| Motion, expressive slow spatial | `0.39, 1.29, 0.35, 0.98`, 650 ms | там же |
| Motion, expressive fast/default/slow effects | `0.31,0.94,0.34,1.00` 150 ms / `0.34,0.80,0.34,1.00` 200 ms / `0.34,0.88,0.34,1.00` 300 ms | там же |
| Motion, правило | spatial — позиция/размер/форма, effects — цвет/прозрачность | [m3 motion/how-it-works](https://m3.material.io/styles/motion/overview/how-it-works) |
| Touch targets | 48×48 dp для касания, 44×44 dp для мыши | [m3 designing/structure](https://m3.material.io/foundations/designing/structure) |
| Android 16 Settings | общие контейнеры для похожих настроек, контрастные фоны разделов, новые цветные иконки, крупнее переключатели | [androidpolice](https://www.androidpolice.com/android-16-material-3-settings-redesign), [9to5google](https://9to5google.com/2025/05/13/android-16-material-3-expressive-redesign) |
| Android 16 Settings, детали | пастельные иконки в кругах у каждого раздела; свитчи с галочкой/крестиком; настройки разбиты на секции | обзоры Android 16 QPR1 ([YouTube](https://www.youtube.com/watch?v=MGTXY_1Yjzw), [YouTube](https://www.youtube.com/watch?v=sMLBdtmTd1Q)) |
| Gmail settings M3E | цветные иконки, скруглённые карточки, крупные контролы, разделы вместо простыни | [androidauthority](https://www.androidauthority.com/gmail-material-3-expressive-settings-redesign-rollout-3734964) |

Пять правил M3E, которые я применяю дальше как чек-лист:
- **Группируй в контейнер** — «organize content into logical groupings or containers» (m3 blog).
- **Форма сообщает состояние** — выбор = морф радиуса, не только цвет (lists/specs).
- **Пружины вместо длительностей**, spatial ≠ effects (motion/specs, how-it-works).
- **Цвет — роль, не декор**: `surfaceContainerLow` для групп, `secondaryContainer` для выбранного, `error` только для деструктива.
- **Движение на жест, не на декор**: 350/500/650 ms для геометрии, 150/200/300 ms для цвета.

---

## 3. Таблица находок

P0 — блокирует редизайн; P1 — нарушает спеку/настройку пользователя и видно глазом; P2 — заметное расхождение с M3E; P3 — полировка.

| № | P | Место | Что не так | Что предлагаю |
|---|---|---|---|---|
| 1 | **P1** | `lib/widgets/settings_ui.dart:179` | `AppRadii.of(context).lg.clamp(24.0, 32.0)` перебивает `uiCornerRadius` 8–23 dp: настройка внешне «не работает» | `outer = AppRadii.of(context).lg` без нижнего клампа; максимум — `clamp(0, 32)`, либо отдельный токен `settingsGroupRadius`, производный от `uiCornerRadius` |
| 2 | **P1** | `lib/widgets/settings/settings_list_item.dart:300-313` | Выбранная строка не меняет форму: остаётся радиус группы (4 dp внутри) | Анимировать `BorderRadius` к 16 dp со всех сторон на `M3SpringCurves.spatialFast` (350 ms), невыбранные — 4/16. Это и есть expressive shape morph |
| 3 | **P1** | `lib/widgets/settings/pressable_surface.dart:87-140` | Нет state layer: ни ripple, ни hover. `AnimatedContainer` + scale — единственная обратная связь | `InkWell`/`InkResponse` внутри `Material` строки (8 % onSurface hover, 10 % pressed), либо ручной `AnimatedContainer`-слой цвета; `M3PressScale` оставить как второй слой |
| 4 | **P1** | `lib/screens/settings/settings_hub_screen.dart:14-16` → `lib/screens/profile_screen.dart:412-433` | Группы хаба без видимых заголовков; название только в `Semantics` | Вернуть видимый `title` в `SettingsSection` (`labelLarge` 14/20, w600, `onSurfaceVariant`, отступ 16/10), как в Android 16 Settings |
| 5 | **P1** | `lib/features/wallpaper/presentation/wallpaper_studio_screen.dart:221-241` | `PopupMenuButton` + обычный `AppBar` внутри настроечного маршрута — прямое нарушение AGENTS.md (п. 4) | `MenuAnchor` или inline-sheet; шапку — на `SettingsShell`/`SettingsResponsiveShell` |
| 6 | **P2** | `lib/widgets/settings/settings_shell.dart:85-100` | `SliverAppBar.large` (baseline, не рекомендуется) + при скролле нет заливки (`scrolledUnderElevation: 0`, цвет = surface) | Medium flexible app bar: `expandedHeight ≈ 112`, collapsed 64, при `overlapsContent` — `surfaceContainer`/`surfaceContainerLow` фон без тени |
| 7 | **P2** | `lib/widgets/settings/settings_list_item.dart:159-164, 239-249` | Все `isSection`-иконки — один `primaryContainer`; нет цветового кодирования разделов | Палитра на раздел: `primary/secondary/tertiary` + их container-роли (13 разделов → 4–5 оттенков), 40×40 superellipse |
| 8 | **P2** | `lib/widgets/settings/settings_choice_buttons.dart:17-38` | `ChoiceChip` в `Wrap` вместо segmented button / connected button group | Для 2–5 текстовых опций — connected group (40 dp, full radius, selected `secondaryContainer`, морф 350 ms); chips оставить эмодзи и фильтрам |
| 9 | **P2** | `lib/core/motion/m3_spring_constants.dart:177-183` | `expressiveDecel/Standard/Accel` не совпадают с официальными expressive-кривыми; имена врут | Либо переименовать в `emphasized*` (честный baseline), либо добавить реальные `0.42,1.67,0.21,0.90` и др. и использовать их только для spatial-свойств |
| 10 | **P2** | `lib/screens/settings_about_screen.dart:170-183` | `AnimatedSize` (геометрия) на effects-кривой `expressiveDecel` | `M3SpringCurves.spatialDefault` для размера, effects — только для `AnimatedSwitcher`-прозрачности |
| 11 | **P2** | `lib/screens/settings_appearance_screen.dart:283-297` | `SwitchListTile` в обход `SettingsListItem`: другое выравнивание, нет 40×40-слота, другой межстрочный ритм | Перевести на `SettingsListItem.toggle` (с `isSection`-слотом), как остальные строки |
| 12 | **P2** | `lib/screens/settings_storage_screen.dart:194-201` | Сводная карточка объёма — `Container` с радиусом 26 dp (магия), вне тональной системы групп | `SettingsSection`-совместимая карточка: `surfaceContainer` , `AppShape.card`/`uiCornerRadius`, superellipse |
| 13 | **P2** | `lib/widgets/settings/ordinary_e2ee_settings.dart:586` | `DropdownButtonFormField<int>` для выбора из вариантов — не expressive-паттерн | Segmented/connected group при 2–5 опциях; `MenuAnchor` при большем числе |
| 14 | **P2** | `lib/screens/profile_screen.dart:620-632` | Master-pane отделён только 1 px бордером, обе панели `surface` | Навигационная панель — `surfaceContainerLow`, бордер убрать/оставить 0.2 alpha; вложенный список — без тональной заливки |
| 15 | **P3** | `lib/features/settings/presentation/settings_row.dart:65-75` | `ExpansionTile` внутри группы: своя геометрия строки, baseline-шеврон, нет 40-слота | Строка-аккордеон на базе `SettingsListItem` + `M3MorphingIcon` (chevron ↓/↑), контент — `M3Reveal(expandY)` |
| 16 | **P3** | `lib/widgets/settings_ui.dart:102-115` | Плашка баннера — `Container` 48×48, `BorderRadius.circular(16)`, а весь остальной проект использует `RoundedSuperellipseBorder` | `AppRadii.superellipse(14/16)` либо `flutter_m3shapes` (AGENTS.md п. 5) |
| 17 | **P3** | `lib/widgets/settings_ui.dart:74-156` | `SettingsNavBanner` + `SettingsHeaderIllustration` не используются нигде (только определения) | Использовать иллюстрации в пустых/пояснительных состояниях подэкранов (сейчас пустое состояние — строка текста) |
| 18 | **P3** | `lib/screens/profile_screen.dart:332-346` | Пустой поиск — центрированный текст без иллюстрации и действия | Иллюстрация 96 dp + `titleSmall` + `bodyMedium`, при пустом запросе — подсказки-чипы популярных разделов |
| 19 | **P3** | `lib/screens/settings_storage_screen.dart:419-451` | Ручная полоса из `Container` с радиусом 6 dp (вне шкалы радиусов) | 4/8 dp сегментная полоса на токенах: `surfaceContainerHighest` + `primary`/`tertiary`/`secondary` |
| 20 | **P3** | `lib/widgets/settings/system_resource_meter.dart:69-92` | Самодельный 8 dp бар вместо M3 progress (для ёмкости это оправдано, но геометрия не токенизирована) | Оставить кастом, но вынести высоту/радиус в токены; добавить `Semantics.value` уже есть (`:39-42`) — сохранить |
| 21 | **P3** | `lib/screens/settings_system_device_screen.dart:75-84` | `DecoratedBox` с радиусом 24 dp (магия), нет superellipse | `AppRadii.xlRadius` / `AppShape.cardBorder()` |
| 22 | **P3** | `lib/features/settings/presentation/settings_issue_card.dart:42-51` | `Container` 20 dp + 1 px бордер + внешний `margin` 16 при parent-padding 16 → двойной инсет 32 dp | Вписать в групповой контейнер, бордер убрать (тон-контраст достаточно), margin 0 |
| 23 | **P3** | `lib/widgets/settings/custom_color_picker_sheet.dart:82,120,141,178,218,304,396,416` | Восемь разных радиусов (28/24/20/16/12) в одном листе | Свести к 3: sheet 28, карточка 20, контрол 12 |
| 24 | **P3** | `lib/screens/settings_appearance_screen.dart:765-795` | Ползунок: `trackHeight: 16` (совпадает с XS), но значение дублируется в строке-заголовке и в `label` слайдера | Один источник значения: `label` внутри handle (44×48 контейнер) + stop indicators, как в спеке |
| 25 | **P3** | `lib/widgets/settings/settings_profile_header.dart:149,154,174,247,272` | `Clip.hardEdge` + три `Opacity` на скролле: потенциальные saveLayer-кадры | Оставить геометрию, но прозрачности — через `FadeTransition`/`AnimatedOpacity` с `RepaintBoundary`; `Clip.none` где возможно (AGENTS motion-протокол) |
| 26 | **P3** | `lib/widgets/notifications/notification_settings_section.dart:83-117` | Мини-хедер уведомлений — просто `Icon` 24 dp без контейнера, в отличие от иконок строк | Иконка в 40×40 тональном контейнере (`primaryContainer`/`tertiaryContainer` по статусу разрешения) |
| 27 | **P3** | `lib/screens/settings_privacy_screen.dart:66-104` | Все `leading`-иконки вручную покрашены в `scheme.primary` | Отдать цвет `SettingsListItem` (он сам берёт `onSurfaceVariant`/`onPrimaryContainer`), либо кодировать категории палитрой |
| 28 | **P3** | `lib/core/theme/app_theme.dart:281` | Checkbox: радиус 4 dp, контейнер не 18 dp | M3: чекбокс 18 dp, радиус 2 dp — по памяти, требует сверки |

Что **не** является находкой (и это надо защищать при редизайне): `surfaceContainerLow` для групп (`settings_ui.dart:224`), 4 dp внутренний радиус (`:218-223`), 48 dp min target (строка ≥64 dp, `settings_list_item.dart:231`), `MergeSemantics` для switch-строки (`:317`), `AppLoadingIndicator` вместо спиннеров (`lib/widgets/pulse_loading_indicator.dart:50-58`), `elevation: 0` во всей теме, `reduced motion` в пружинах/переходах, search bar как `SearchBar` (`lib/screens/profile_screen.dart:299-324`).

---

## 4. Целевой вид по M3E

### 4.1 Хаб настроек (мобильный)

Сверху вниз:
1. **App bar (medium flexible).** Expanded 112 dp: заголовок «Настройки» `headlineMedium` 28/36 w700 (сейчас `settings_shell.dart:90-96` — так и есть, оставить), collapsed 64 dp с `titleLarge` 22/28. При скролле — фон `surfaceContainer` без тени (m3 app-bars/overview). Кнопка QR — `IconButton` 48 dp справа.
2. **Карточка профиля = hero-контейнер (сейчас её нет как контейнера).** `surfaceContainerLow`, радиус `AppShape.card` 20–28, padding 20, аватар 80 dp, имя `titleLarge` 22/28 w700, `@username` `bodyMedium` `onSurfaceVariant`, ниже connected group из двух кнопок: «Изменить» (filled tonal, 40 dp, full radius) + QR (icon button 40 dp). Обоснование: «give the most important content visual prominence through … the brightest surface mapping» (m3 blog).
3. **Search bar.** Оставить `SearchBar`: `surfaceContainerHigh`, full radius, elevation 0, высота 56, padding 16 (совпадает с `app_theme.dart:142-164`).
4. **Заголовки групп — видимые.** `labelLarge` 14/20 w600 `onSurfaceVariant`, отступ 16 слева, 10 снизу (сейчас в `SettingsSection` это уже есть — `settings_ui.dart:187-201` — но хаб их не передаёт).
5. **Группа.** Контейнер `surfaceContainerLow`, внешний радиус = `uiCornerRadius` (без клампа), внутренние строки 4 dp, **без 2 dp зазоров** между строками (зазор ломает «connected»-метафору; допустим разделитель 1 dp `outlineVariant` с инсетом 16/24 по спеке). Строки: 64 dp одно-строчные / 72 dp двустрочные.
6. **Строка раздела.** 40×40 superellipse-контейнер (радиус 12–14) с **разным** тоном по секции: Чаты/Уведомления — `primaryContainer`, Персонализация — `secondaryContainer`, Безопасность — `tertiaryContainer`, Приложение — `surfaceContainerHighest`; иконка 24 dp внутри. Текст с 72 dp (16 + 40 + 16). Шеврон 24 dp `onSurfaceVariant`.
7. **Опасное действие.** Отдельная группа из одной строки, текст `error`, без иконки-контейнера (сейчас `SettingsListItem.danger` — правильно, `settings_list_item.dart:109-122`), отступ 24 dp сверху.
8. **Вход групп.** `M3Entrance` уже есть (`lib/widgets/motion/m3_entrance.dart:34-69`) — 3–4 группы с задержкой 40 ms, `reduceMotion` выключает (там уже учтено `:66-68`). Больше 4 — не анимировать: визуальный шум.

### 4.2 Типовой подэкран

- Тот же shell, заголовок раздела `headlineMedium`; контент 16 dp по краям, max-width 860 (как сейчас).
- Группы: заголовок (`labelLarge` `onSurfaceVariant`) + контейнер; между группами 20 dp (сейчас `settings_ui.dart:181`).
- Продвинутые настройки — не `ExpansionTile`, а строка-аккордеон на `SettingsListItem` с `M3MorphingIcon` и `M3Reveal(expandY)`.
- Одиночные ползунки и выборы — внутри своей группы, а не «голым» `Padding` (сейчас `settings_appearance_screen.dart:691-722`, `settings_chats_screen.dart:58-85`).

### 4.3 Строка каждого типа

| Тип | Разметка | Цвет/форма |
|---|---|---|
| Nav | 64/72 dp, слот 40×40, title `bodyLarge` 16/24 w500, subtitle `bodyMedium` 14/20, chevron 24 | фон `surfaceContainerLow` (группа), hover 8 % `onSurface`, pressed 10 %, focus — 2 dp `primary` |
| Value | как nav, но trailing — `labelLarge` `onSurfaceVariant` одного цвета с subtitle-логикой | значение не жирнее заголовка (сейчас `w600`, `:288`) |
| Toggle | вся строка — цель нажатия, `MergeSemantics`; Switch 52×32, handle 24 dp, при желании `thumbIcon` check/close | track `primary` / `surfaceContainerHighest`, outline 2 dp `outline`; анимация handle — `spatialFast` |
| Выбранный | заливка `secondaryContainer`, текст `onSecondaryContainer`, **радиус 16 dp со всех сторон** | морф радиуса 350 ms `spatialFast` |
| Danger | title `error`, без контейнера иконки; подтверждение — диалог с `error`-filled кнопкой | `error` / `errorContainer` |
| Слайдер | строка-заголовок 64 dp + сам слайдер с padding 16, track 16 dp, handle 4×44, stop indicators при `divisions` | active `primary`, inactive `surfaceContainerHighest`, label 44×48 |
| Выбор 2–5 | connected button group 40 dp, full radius, icons 18, label `labelLarge` | selected `secondaryContainer`/`onSecondaryContainer`; морф 350 ms |
| Выбор >5 | chips в `Wrap`, spacing 8 (как сейчас `settings_choice_buttons.dart:19-21`) | `surfaceContainerLow`, selected `secondaryContainer` |
| Info-строка (значение без действия) | как value, но без chevron, `bodySmall` `onSurfaceVariant` | тон группы |

### 4.4 Кнопки действий

`FilledButton`/`FilledButton.tonal`: высота 40 dp, full radius (`AppRadii.full`), горизонтальный padding 16 dp (24 dp M3E не рекомендует), icon 18 dp, label `labelLarge`; pressed — shape morph к square 12 dp (по спеке buttons/specs), 150 ms effects для цвета + 350 ms spatial для формы. Сейчас `app_theme.dart:74-121` даёт pill, но без padding/морфа — проверить и добавить.

### 4.5 Опасные действия

Одна строка в собственной группе, `error`; диалог — `AppModal.showConfirmation` (`lib/widgets/app_dialogs.dart:153-161`), кнопка подтверждения `FilledButton` с `error`/`onError`, отмена — `TextButton`. Время подтверждения не анимировать «весело»: `effectsFast` 150 ms, без overshoot (правило «effects не овершутят» — m3 motion/how-it-works).

### 4.6 Диалоги и листы

- Диалог: 24 dp радиус (`AppShape.dialogBorder()` уже в `app_theme.dart:191-195`), `surfaceContainerHigh`, elevation 0 — оставить.
- Bottom sheet: 28 dp сверху, drag handle 32×4 `onSurfaceVariant` 38 % (уже `app_theme.dart:206-215`). Внутри листов — те же `SettingsSection`, не `ListTile` (сейчас в `profile_screen.dart:135-153` это сделано правильно, а в `lib/widgets/contacts/call_log_view.dart:28-135` — `ListTile`; другой агент, но паттерн стоит унифицировать).

### 4.7 Пустые и загрузочные состояния

- Загрузка: `AppLoadingIndicator` (M3E morphing) — уже так (`lib/screens/settings_privacy_screen.dart:45-49`, `settings_storage_screen.dart:149-152`, `settings_system_device_screen.dart:34-37`). Не заменять на `CircularProgressIndicator` никогда.
- Ошибка: тональная карточка `errorContainer` 20 % + `error`-иконка + `FilledButton.tonal` «Повторить» (сейчас это строка-строка в группе, `settings_storage_screen.dart:153-174`).
- Пусто: иллюстрация 96 dp (`SettingsHeaderIllustration` уже существует, `lib/widgets/vector_illustrations.dart:253-290`) + `titleSmall` + `bodyMedium` `onSurfaceVariant` + одно действие.

---

## 5. M3E-компоненты в проекте, которыми настройки не пользуются

| Что есть | Где живёт | Где в настройках могло бы быть |
|---|---|---|
| `M3Entrance` (пружинное появление) | `lib/widgets/motion/m3_entrance.dart` | вход групп хаба (сейчас нет; в `profile_screen.dart` не встречается) |
| `M3StaggeredList` | `lib/widgets/motion/m3_staggered_list.dart` | каскад строк в длинных подэкранах (privacy, about) — **нигде не используется**, даже вне настроек |
| `M3MorphingIcon` | `lib/widgets/motion/m3_morphing_icon.dart` | шеврон аккордеона (`settings_row.dart:67`), иконка «уведомления вкл/выкл» в строке |
| `M3SpringSwitcher` | `lib/widgets/motion/m3_spring_switcher.dart` | смена значения строки (сейчас только `settings_energy_saving_screen.dart:122`) |
| `M3AnimatedBadge` | `lib/widgets/motion/m3_animated_badge.dart` | бейджи «N новых» в хабе вместо простого `value` |
| `flutter_m3shapes` | `onboarding_screen.dart:6`, `app_logo_mark.dart:3`, `core/identity/nios_mark.dart:4` | 40×40 слоты иконок и 48×48 плашка баннера (сейчас `BorderRadius.circular`) |
| `AppRadii.superellipse` / `AppShape` | `lib/core/theme/expressive_tokens.dart:38-99` | используется темой (карточки, диалоги, меню), но **не** строками настроек |
| `AppLoadingIndicator` (loading_indicator_m3e) | `lib/widgets/pulse_loading_indicator.dart` | уже используется — эталон для остальных |
| `SettingsHeaderIllustration` | `lib/widgets/vector_illustrations.dart:253` | пустые состояния, шапки подэкранов; сегодня не вызывается |

Вывод по роли: expressive-инструментарий в проекте **богаче, чем его применение в настройках**. Редизайн — это не «добавить M3E», а «подключить уже написанное».

---

## 6. Где M3E плохо подходит мессенджеру (честные уступки)

1. **Высоты 72/88 dp.** Настройки NiosMess — это 40+ строк; 88 dp строки сделают экран «прайс-листом». Уступаю: 64/72 dp, но с обязательным 48 dp target.
2. **Large flexible app bar.** На утилитарном экране настройки expanded 152 dp — потеря вертикали. Уступаю: medium flexible 112 dp + заливка на скролле.
3. **Shape morph на каждом тапе.** Постоянные морфы утомляют и стоят кадров на слабых Android. Уступаю: морф только у выбранной строки, у кнопок и у аккордеона; обычные тапы — state layer + scale 0.98.
4. **Connected button group для эмодзи.** В `settings_chats_screen.dart:60-84` восемь эмодзи-чипов: группа из 8 противоречит «2–5 сегментов» (m3 segmented-buttons/guidelines). Уступаю: чипы остаются, но с `M3SelectionMotion` (уже есть, `:65`).
5. **Многоцветные иконки везде.** В privacy/danger цвет должен нести смысл, а не декор. Уступаю: палитра — только у 13 разделов хаба и статусов; строки внутри — нейтральные.
6. **Wavy progress.** M3E-волна для «занято 4.2 из 8 ГБ» читается как «идёт процесс». Уступаю: плоский сегментный бар для ёмкости, волна — только для загрузки/синхронизации.
7. **Третьи стороны.** `material_3_expressive` 1.2.3 (button groups, FAB menu) тянет `material_ui`, `motor`, `cupertino_ui` — по AGENTS.md издатель не верифицирован. Уступаю: свои минимальные реализации (button group = `Wrap` + `AnimatedContainer` радиусов; flexible app bar = `SliverPersistentHeader`), без нового пакета, пока не будет аудита кода.
8. **Flutter-ограничение.** В SDK нет `ButtonGroup` и flexible app bars (по памяти), M3E slider handle 4×44 и «растущий» switch handle тоже не реализованы — понадобится кастом. Это аргумент делать выборочно, а не «всё M3E».

---

## 7. Не проверено

- **Flutter-рендеринг слайдера.** `SliderThemeData(year2023: false)` (`lib/core/theme/app_theme.dart:244-251`) — что именно он включает (stop indicators, вертикальный handle) — **по памяти**, без запуска.
- **M3E switch handle** (рост 16→24→28 dp, icon в handle) в текущей версии Flutter — **по памяти**; в коде используется обычный `Switch` (`settings_list_item.dart:203`) без `thumbIcon`.
- **Точные dp редизайна Android 16 Settings** — источники (androidpolice, 9to5google, видеообзоры) описывают «скруглённые контейнеры, цветные иконки в кругах, крупные свитчи» без чисел; конкретные размеры я не подтверждал.
- **Контраст** `onSecondaryContainer` на `secondaryContainer` при выбранной строке и `w700`-заголовке — не измерял (WCAG-калькулятор не запускал).
- **Динамические цвета.** Насколько `primaryContainer`/`secondaryContainer` реально различимы при `DynamicColorBuilder` и при пользовательской палитре — не проверял (нужен запуск).
- **Производительность.** `Clip.hardEdge` + три `Opacity` в `settings_profile_header.dart` — оценка статическая, профилирования не было.
- **`SettingsNavBanner` действительно мёртвый код** — проверено grep по `lib/`; тесты (`test/`, `integration_test/`) не проверял.
- **Wallpaper studio** прочитан фрагментами (205–249); полный набор нарушений (в т.ч. хардкод русских строк `:215, :232, :236`) — зона другого аналитика.
- **`uiCornerRadius` вне настроек.** Утверждение «кламп ломает настройку только в настройках» основано на том, что остальные потребители берут `AppRadii.of(context).lgRadius` без клампа (`chat_tile.dart:235`, `chat_list_screen.dart:247`, `inbox_search_results.dart:401`); все места не перепроверял.

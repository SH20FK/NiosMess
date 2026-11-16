# Визуальный аудит инбокса NiosMess — 2026-11-16

Источники: 2 агента по коду (экран/шапка/фильтры; тайл/состояния), референсы
лидеров (36 ссылок), официальные токены M3 Expressive, реальные рендеры экрана
(light/dark × телефон/планшет, PNG в `C:/Hermes/cache/scratch/inbox_shots/`).
Скриншоты я смотрел глазами — замечания ниже помечены «[скриншот]».

---

## Вердикт по скриншотам (что видно без кода)

1. **[скриншот, P0] FAB перекрывает список.** На телефоне зелёный карандаш
   накрывает строку «Марья Ковалёва» и часть бейджа «7» у Тимура; на планшете —
   строки «NiosPlus» и «Секретный диалог». FAB полупрозрачный, сидит над
   контентом без нижнего отступа. Нужен `bottom: 16 + 56 + 16 + viewPadding`
   либо скрытие при скролле вниз.
2. **[скриншот, P0] Бейдж «99+» на нижнем навбаре накрывает иконку «Чаты»**
   и выходит за пределы destination — визуально сломанный Badge (нужен
   `Badge(offset: Offset(0,-2))` / `label` с ограничением, не поверх иконки).
3. **[скриншот, P0] Планшет 900dp: список растянут от края до края.**
   Превью короткие слева, время и бейджи прибиты к правому краю, между ними
   ~500dp пустоты. Нет max-width контента (≤640dp) и нет двухпанельного режима
   list-detail. Без этого планшет/desktop выглядят как растянутый телефон.
4. **[скриншот, P1] Непрочитанные почти не отличаются.** Заливка
   `surfaceContainerHigh@0.65` = CR 1.09 (light) и 1.15 (dark); в тёмной теме
   разница видна только по жирности. Три сигнала (вес, заливка, пилюля)
   деградируют до двух.
5. **[скриншот, P1] Два ряда фильтров в разных визуальных языках:** текстовые
   чипы-стадиумы («Все/Непрочитанные/Группы/Тип чата») vs пилюли папок из
   chipTheme; индикатор «Все» — короткий штрих 30dp по центру, не по ширине
   чипа; «Тип чата» без иконки читается как обычный текст.
6. **[скриншот, P1] Сбитая левая колонка:** заголовок «Чаты» x=16, текст
   фильтра x=33, аватар x=22, текст строки x=82. Три разные левые линии в
   верхней части экрана.
7. **[скриншот, P1] «Избранное» без подложки:** иконка закладки 28dp без круга
   — в левой колонке дырка, строка оптически легче остальных.
8. **[скриншот, P1] Строки слипаются:** у unread-плиток нулевой зазор,
   соседние «Ирина» и «Наша группа» читаются как один блок с защемлёнными
   углами.
9. **[скриншот, P2] Черновик не читается:** метка «Черновик:» и текст одного
   цвета tertiary, без иконки и курсива — выглядит как обычное сообщение.
10. **[скриншот, P2] Typing серый:** «печатает...» тем же цветом, что превью,
    без анимации и без акцента; в группе нет «Несколько человек печатают».

---

## P0 — ломает систему

### 1. Выбранный чат визуально не отличается от невыбранного (desktop/web)
`chat_tile.dart:140-146`: selected = `primaryContainer@0.45` → CR 1.063 к фону
и 1.030 к unread-строке (порог для состояний — 3:1). В двухпанельном режиме
это единственный индикатор открытого чата. Плюс `isSelected` стоит первым в
тернарнике — hover на выбранной строке не работает.
→ `secondaryContainer` без альфы + ведущий индикатор `3×20dp` radius 2
`primary` с inset 8 + `w700` в заголовке; hover — `Color.alphaBlend(0.05
onSurface, secondaryContainer)`.

### 2. `keyMismatch` не имеет визуала в списке
`chat_list_screen.dart:453-535` не передаёт `keyMismatch` в `ChatTile`; поле
есть в модели. Секретный чат со сломанным ключом выглядит как здоровый.
→ при `true`: замок → `gpp_maybe_rounded 16dp scheme.error`, превью «Ключи не
совпадают» в error, рамка строки `error@0.35` 1dp.

### 3. Лейбл свайпа не может отрисоваться целиком
`chat_list_screen.dart:410-427, 676-717`: порог 40% ширины (≈136dp на строке
340), а композиция «иконка 24 + 8 + текст ~157dp + паддинги 36» ≈ 225dp.
Действие срабатывает, когда видно «Отметить проч…».
→ `dismissThresholds: 0.35` + лейбл «Прочитано» (≈68dp) **или** проявлять
лейбл по прогрессу (`t=((p−0.25)/0.5).clamp(0,1)`, scale 0.9→1).

### 4. Тональная лестница уничтожена
`app_surfaces.dart:22-33`: все `surfaceContainer*` зажаты в `#EDEDED…#DCDCDC`
(Δ 4–6%), unread ещё умножен на alpha 0.65. При запрете теней/blur (AGENTS.md)
глубина не выражается ничем.
→ развести ступени минимум по 3 L*: `low #EFEFEF` (1.02), `container #E6E6E6`
(1.09), `high #DCDCDC` (1.25), `highest #CFCFCF` (1.42); убрать alpha у
тональных поверхностей.

### 5. Четыре левые колонки вместо одной
Заголовок 16 / контейнер чипа 20 / аватар 22 / текст чипа 33; разница
заголовок↔лейбл = 17dp. Ритм шапки в layout 4/0/12 при визуальных 12/8/12/20.
→ колонка контейнеров 16; `SliverPadding(horizontal: 8)` + внутренний 12 →
аватар 20; ввести `AppSpacing {xs:4, sm:8, md:12, lg:16, xl:24}` и собрать
блок шапки как 8 → контрол 40 → 8 → контрол 40 → 12.

---

## P1 — заметно и системно

| # | Где | Проблема | Предложение |
|---|---|---|---|
| 1 | `chat_tile.dart:144-145` | unread CR 1.09/1.15 | либо `surfaceContainerHighest` в полную силу (1.22/1.38), либо оставить только пилюлю+вес |
| 2 | `chat_tile.dart:142-145` | hover на unread CR 1.057, на selected отсутствует | явные уровни: resting transparent → hover high → selected secondaryContainer |
| 3 | `chat_tile.dart:292-306` | статус отправки добавляет третью строку: высота 76→88.5 | статус в слот времени, высота всегда 76 |
| 4 | `chat_tile.dart:110` | `timeMaxWidth = ширинаЭкрана*0.32` без textScaler → «12.11.2025» обрезается при 2.0 | `min(textScaler.scale(72), maxWidth*0.42)` + `Flexible` |
| 5 | `chat_tile.dart:325-333` | typing — обычный серый, без анимации, группы → одно число | primary w500 + 3 точки (stagger 160ms), `chatTypingMultiple` |
| 6 | `touch_container.dart:174-215` | нет state layer (M3: 8% pressed) | `InkWell(overlayColor: onSurface@0.08, borderRadius: 16)` |
| 7 | `chat_tile.dart:226-232, 359-366` | 15sp/12sp вместо titleMedium 16 / bodyMedium 14 | 16/24 w600 (unread w700), 14/20, letterSpacing 0.25 |
| 8 | `chat_tile.dart:419-424` | muted-пилюля CR 1.119, строка тонирована как unread | muted: без заливки, пилюля high+рамка, текст onSurfaceVariant |
| 9 | `chat_tile.dart:147-162 vs :228-230` | фон анимируется 150ms, вес — скачком | `AnimatedDefaultTextStyle` 150ms gentle |
| 10 | `chat_tile.dart:280-287, 438-445` | двойной акцент: время primary + пилюля primary | время всегда onSurfaceVariant, tabular |
| 11 | `chat_tile.dart:378-387` | delivered/read неразличимы (оба primary), семантика молчит | delivered onSurfaceVariant, read primary; в label «доставлено/прочитано» |
| 12 | `chat_list_screen.dart:767-780` | ПКМ на desktop → центрированный диалог со скримом | `MenuAnchor` у курсора (240dp, radius 20, пункты 40dp) |
| 13 | `chat_list_header.dart:78-79` | прозрачный AppBar без границы: строка режется по кромке | scrim `surface`+1dp `outlineVariant@0.22` при scroll>8 (200ms gentle) |
| 14 | `chat_list_header.dart:57` vs `app_theme.dart:83-85` | заголовок w600 при общем w700 | `headlineSmall.copyWith(w700)` или без style |
| 15 | `chat_list_header.dart:14,27` | `_titleVerticalPadding=8` даёт 12dp; высота 56 при headline 24 | 64dp (`AppHeights.xl`), отступ 16; textScale → max(64, scaled+32) |
| 16 | `chat_productivity.dart:96-97,111-145` | ряд папок схлопывается в 0 при загрузке → список прыгает | плейсхолдер той же высоты / AnimatedSize 200ms |
| 17 | `chat_list_screen.dart:145-147` | compact меняет только строку, шапка 115dp остаётся | прокинуть compact в шапку и контролы (56/36) |
| 18 | `chat_list_screen.dart:184-187` | RefreshIndicator CR 1.157, «висит в воздухе» | `surfaceContainerHighest` + рамка 40dp, displacement 24 |
| 19 | `chat_list_screen.dart:216-220` | нижний отступ 88 магический; в split даёт 122dp пустоты | `24 + (hasFAB ? 72 : 0) + viewPadding.bottom` |
| 20 | `chat_filter_bar.dart:76,126` | смена веса 500↔700 меняет ширину → ряд дёргается | вес фиксирован w600, состояние — заливкой |

---

## P2 — полировка (сжато)

- Заголовочные иконки разного размера (14/16) → все 16, gap 4; lock+pin оба
  primary → pin/mute onSurfaceVariant; бейдж сырым Icon вместо `BadgeChip`;
  в semanticsLabel нет mute/pin/secret/selected.
- Аватар: точка 13dp внутри 48dp с рамкой чужого цвета → `right:-1,bottom:-1`,
  14dp, рамка = фактический фон строки; «Избранное» → круг 48
  `primaryContainer` + иконка 24; инициалы `radius*0.66`; меню radius 22→24.
- Превью: тип медиа дублируется иконкой и словом → только иконка; драфт —
  метка + италик + `edit_note_rounded`; секретные — без типа медиа.
- Свайп: `margin vertical 1` при нулевом зазоре → 0/2; подложка однородная
  `primary@0.14` → `secondaryContainer` + иконка в круге 40; лейбл без fontSize
  → labelLarge; `Alignment.centerLeft` → directional.
- Меню: `markRead` выфильтровывается → disabled-пункт (меню не прыгает);
  header padding даёт аватар x=30 и текст x=86 против лейблов x=72 → 0/12;
  `RoundedRectangleBorder(12)` → `AppShape.controlBorder()`; деструктив
  залит+обведён дважды → только error-текст + pressed-layer; две гарнитуры
  в одном меню → labelLarge.
- Скелетон: инсет 28 vs реальные 22 → те же 22; `separator 10` vs реальные 0
  → 2; статичные блоки → pulse 1200ms (при disableAnimations — статика);
  заглушка времени по центру → topRight.
- Пустые состояния: иконка ошибки рисуется primary → параметр iconColor;
  `80×80` круг → супереллипс 28; три разных пустых состояния с одной иконкой →
  done_all / filter_alt_off / chat_bubble; CTA `preferencesResetConfirm` →
  `inboxResetFilters`; busy сжимает кнопку → фиксированная ширина.
- E2EE-плашка: голая строка на full-bleed → контейнер `surfaceContainerLow`,
  radius 16, padding 12/8, иконка lock 16, AnimatedSize.
- Токены: radius 16 захардкожен вместо `AppRadii.of(context).lgRadius`;
  `chipTheme.shape` 12 против `AppShape.pill` («reserved for chips»);
  `dialogTheme` 28 против `AppShape.dialog` 24; мёртвый `ChatListFilterBar`
  и неиспользуемый `PulseSkeleton`.
- Стрип фильтров обрезается за 16dp до края → padding внутри скролла + фейд
  12dp + Scrollbar; `M3SelectionMotion` 0.97 у всех невыбранных → убрать.

---

## Токены M3 Expressive (что применять)

- **Списки:** высоты 56/72/88; радиусы 4 inner + 16 outer (selected 16, hover
  12, pressed 16); label/leading 16; trailing 16/24; divider 1dp inset 16/24;
  зазоры группы 10/12; leading icon 20 (expressive), avatar 40, image 56;
  target ≥48; selected `secondaryContainer`.
- **App bar:** small 64 (`titleLarge` + `labelMedium`); medium flexible 112
  (collapse 64); large 120–152; при скролле — тон `surfaceContainer`, не тень.
- **Search bar:** 56, full radius 28, `surfaceContainerHigh`, elevation 0.
- **Chips:** 32dp, radius 8 (M3E-morph 12→full→4), icon 18, padding 16/8,
  gap 8; selected `secondaryContainer`, unselected 1dp `outlineVariant`.
- **Badges:** small 6, large 16 (min width 16, height 16), padding 4,
  `labelSmall`, `maxCount: 99`, offset 6×6 / 14×12; скрывать на активном табе.
- **FAB:** 56/16/icon 24, extended 56 padding 16/20 gap 8; тон
  `primaryContainer`, elevation 3; large 96 — icon 32.
- **Segmented:** 40dp, outline 1, padding min 12, gap 2–8; в M3E официально
  deprecated → connected button group (в Flutter нет, делать руками).
- **Tabs:** 48 (текст) / 64 (иконка+текст), indicator 3, shape 3/3/0/0.
- **Motion:** spring default spatial ζ0.8/k380 ≈212ms, fast ≈98ms, slow ≈293ms;
  effects ζ1.0: 150/231/327ms; длительности 50…1000.
- **Глубина:** elevation 0/1/3/6/8/12; M3E — без тени и surfaceTint, только
  `surfaceContainerLowest…Highest` (100/96/94/92/90).

## Что есть во Flutter 3.44/3.47

Списки 56/72/88 и padding 16/24 — есть, shape-morph — руками. App bar small 64
— есть, flexible и subtitle — руками. Search bar 56/stadium — есть, elevation 0
— руками. Chips radius 8 — есть, height 32/morph — руками. Badges 6/16 — есть,
maxCount 99 — параметр. FAB 56/40/96 — есть, icon 32 — руками. Segmented 40 —
есть (M3E не рекомендует). Spring-токенов нет → `SpringSimulation` с нашими
`M3SpringCurves`.

---

## План внедрения

**Волна A (P0, 1–2 дня):** FAB-отступ и скрытие при скролле; бейдж навбара;
max-width 640 + двухпанельный режим для ≥840; selected-строка; keyMismatch;
свайп-лейбл; тональная лестница; единая колонка 16 и `AppSpacing`.

**Волна B (P1, 2–3 дня):** контрасты unread/hover/muted; высота строки без
прыжка; время при textScale; state layer; типографика 16/14; typing-точки;
пилюля muted; галочки + семантика; десктопное меню `MenuAnchor`; scrim шапки;
ритм 8/8/12; папки-плейсхолдер; compact целиком.

**Волна C (P2, 2–3 дня):** иконки/бейджи/аватар; свайп-подложка; меню;
скелетон; пустые состояния; E2EE-плашка; токены радиусов; чистка мёртвого.

**После каждой волны:** скриншот-тест `test/visual/inbox_screenshot_dump_test.dart`
уже есть — прогонять и сравнивать глазами; `flutter analyze --no-pub` и
`flutter test` (baseline 7 падений).

---

## Файлы, которые будут затронуты

`chat_list_screen.dart`, `chat_tile.dart`, `chat_list_header.dart`,
`chat_filter_bar.dart`, `chat_list_filter_bar.dart` (удалить),
`chat_productivity.dart`, `pulse_skeleton.dart`, `empty_state_widget.dart`,
`ordinary_e2ee_notice.dart`, `touch_container.dart`, `chat_actions_modal.dart`,
`app_surfaces.dart`, `app_theme.dart`, `expressive_tokens.dart`,
`m3_selection_motion.dart`, `main_shell_screen.dart` (FAB/навбар/адаптив).

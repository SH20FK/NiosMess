# NiosMess — дизайн-аудит по канонам Material 3 Expressive

<aside>
📌

Прочитано на HEAD `d7c739bf` (v3.60.7+143): `core/theme/app_theme.dart`, `app_typography.dart`, `app_colors.dart`, `expressive_tokens.dart`, `pubspec.yaml`, `widgets/pulse_button.dart`, `pulse_loading_indicator.dart`, `pulse_page_header.dart`, `pulse_skeleton.dart`, `gooey_segment.dart`, `empty_state_widget.dart`, `m3_badge.dart`, листинги `widgets/` и `core/theme/`.

**Переходы между табами в этот аудит не входят** — они уже в работе отдельной задачей.

</aside>

## 1. Главный вывод

В проекте есть **инфраструктура** M3 Expressive: пружины `M3SpringCurves`, длительности `M3Durations`, `flutter_m3shapes`, `loading_indicator_m3e`, три вариативных шрифта, тональные поверхности, тиры производительности. Но **сам дизайн-язык всё ещё baseline Material 3 образца 2021 года**, поверх которого навешаны локальные украшения.

Пять строк кода отвечают за то, что приложение не выглядит как M3 Expressive:

| Где | Что стоит | Что должно быть по канону |
| --- | --- | --- |
| `app_theme.dart` | `DynamicSchemeVariant.tonalSpot` | `expressive` / `vibrant` |
| `app_typography.dart` | `displayLarge: 36` | `57`, вся шкала сжата на 1–2 ступени |
| весь UI | `BorderRadius.circular` | superellipse-скругления |
| `app_theme.dart` | нет `year2023: false` | обязательный opt-in в M3E-отрисовку |
| иконки | `Icons.*` | Material Symbols с осью `FILL` |

Всё остальное в отчёте — следствия и детали.

## 2. Цвет

### 2.1 Палитра генерируется в самом консервативном варианте (P0)

```dart
ColorScheme.fromSeed(
  seedColor: settings.seedColor,
  brightness: brightness,
  dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot, // ← 2021 baseline
)
```

`tonalSpot` — это **дефолтный вариант первой версии Material You**. Он намеренно занижает хрому и держит хью близко к сиду, чтобы палитра была «безопасной». M3 Expressive построен на противоположном: сдвинутые хью, высокая хрома в контейнерах, заметный контраст между `primaryContainer` и `secondaryContainer`.

При `tonalSpot` любой сид, который пользователь выберет, превращается в приглушённую пастель. Отсюда ощущение «стоковый флаттер», даже когда все компоненты на месте.

Фикс и одновременно новая фича в настройках внешнего вида:

```dart
/// User-facing palette styles. Maps onto Material's scheme variants.
enum PaletteStyle {
  expressive(DynamicSchemeVariant.expressive),  // default
  vibrant(DynamicSchemeVariant.vibrant),
  content(DynamicSchemeVariant.content),
  calm(DynamicSchemeVariant.tonalSpot),
  mono(DynamicSchemeVariant.monochrome);

  const PaletteStyle(this.variant);
  final DynamicSchemeVariant variant;
}

static ColorScheme _scheme(
  VisualThemeSettings settings,
  Brightness brightness,
  double contrastLevel,
) {
  return ColorScheme.fromSeed(
    seedColor: settings.seedColor,
    brightness: brightness,
    dynamicSchemeVariant: settings.paletteStyle.variant,
    // -1.0 .. 1.0. Mirrors the Android 14+ system contrast slider.
    contrastLevel: contrastLevel,
  );
}
```

Один enum в `ui_settings_provider` плюс сегмент в настройках — и у пользователя появляется выбор «характера» темы, которого нет ни в Telegram, ни в WhatsApp. Ключ кэша тем уже считается через XOR, туда надо добавить `paletteStyle.index`, иначе смена стиля не перерисует тему.

### 2.2 Системный контраст игнорируется (P1)

`contrastLevel` не передаётся вообще. Android 14+ и iOS имеют системный регулятор контраста, `MediaQuery.highContrast` доступен. По канону доступности M3 схема обязана реагировать: `0.0` обычная, `0.5` средняя, `1.0` максимальная. Сейчас пользователь с включённым системным контрастом получает ту же пастель.

### 2.3 `app_colors.dart` — мёртвая захардкоженная палитра (P1)

Файл целиком состоит из константных хексов, причём это **ровно дефолтная baseline-палитра Material 3**: `0xFF6750A4`, `0xFFE8DEF8`, `0xFF625C71`. То есть параллельно динамической схеме в проекте лежит статическая копия стокового фиолетового Material.

Прямое нарушение правила репозитория о запрете хардкода цветов. Любое использование `AppColors.*` — это место, которое **не реагирует ни на сид, ни на тёмную тему, ни на OLED, ни на системную динамику**.

Отдельно `AppColors.avatarPalette` — восемь подобранных руками цветов для аватаров. Они не связаны со схемой, поэтому при любом сиде аватары конфликтуют с темой. По канону это делается через HCT: берём хью из хеша идентификатора, хрому и тон — из текущей схемы.

```dart
/// Scheme-aware avatar color: hue from the identity hash, chroma and tone
/// from the active scheme, so avatars always agree with the theme.
Color avatarColorFor(String id, ColorScheme scheme) {
  final double hue = (id.hashCode.abs() % 360).toDouble();
  final bool isDark = scheme.brightness == Brightness.dark;
  return Color(Hct.from(hue, 48.0, isDark ? 70.0 : 48.0).toInt());
}
```

`Hct` доступен из `material_color_utilities`, который уже тянется транзитивно через Flutter.

### 2.4 OLED-оверрайд неполный (P2)

`copyWith` переопределяет шесть surface-ролей, но **не трогает** `surfaceDim`, `surfaceBright`, `inverseSurface`, `onInverseSurface`, `scrim`. В OLED-режиме снекбары (`inverseSurface`) и скримы под шитами остаются от обычной тёмной темы, то есть светлее, чем должны быть на чёрном фоне.

## 3. Типографика

### 3.1 Шкала сжата — это убивает выразительность сильнее всего (P0)

Главная визуальная идея M3 Expressive — **экстремальный контраст размеров**. Крупный заголовок и мелкий бодик, соотношение примерно 3.5 к 1. Текущая шкала:

| Роль | Сейчас | M3-спека | Комментарий |
| --- | --- | --- | --- |
| displayLarge | 36 | 57 | сейчас это размер спекового displaySmall |
| displayMedium | 30 | 45 | −15 |
| displaySmall | 24 | 36 | −12 |
| headlineLarge | 28 | 32 | −4 |
| headlineMedium | 22 | 28 | −6 |
| headlineSmall | 20 | 24 | −4 |
| titleLarge | 18 | 22 | −4 |
| titleMedium | 16 | 16 | ок |
| labelLarge | 15 | 14 | нестандартный размер |
| body * | 16 / 14 / 12 | 16 / 14 / 12 | ок |

Соотношение `displayLarge / bodyLarge` сейчас **2.25**, по спеке **3.56**. Вся иерархия сплющена в узкий диапазон 16–36, поэтому крупные экраны читаются как «много текста примерно одного веса».

Второе следствие: `PulsePageHeader` рисует заголовок страницы через `titleLarge` (18 sp). Заголовок экрана по канону — `headlineMedium` и выше. То есть даже правильный по спеке `titleLarge` здесь применён не по назначению, а он ещё и занижен.

Поднимать шкалу надо не механически: 57 sp уместен для hero-моментов (splash, профиль, пустые состояния), а не для каждого экрана. Правильный ход — **выправить шкалу до спеки** и отдельно пройти по экранам, заменив `titleLarge` на `headlineMedium`/`headlineLarge` там, где это заголовок страницы.

### 3.2 Не задан line-height у 12 из 15 ролей (P1)

`height` проставлен только у `bodyLarge` и `bodyMedium` (1.45). У всех display, headline, title, label и у `bodySmall` его нет, поэтому межстрочное расстояние берётся из метрик конкретного шрифта. Три разных шрифта дают три разных ритма, и вертикальные отступы между блоками перестают быть предсказуемыми. В спеке line-height задан для каждой роли.

### 3.3 Вариативные оси шрифтов не используются (P1)

В `pubspec.yaml` каждое семейство зарегистрировано как **пять записей с разным `weight`, указывающих на один и тот же variable-файл**. Формально работает, но это эмуляция статических весов: Flutter не интерполирует ось, а выбирает ближайшую запись.

Bricolage Grotesque — вариативный шрифт с осями `wght`, `wdth` и `opsz`. M3 Expressive прямо строится на этом: «emphasized» состояния — это **сдвиг по оси веса**, а не подмена шрифта.

```dart
TextStyle(
  fontFamily: AppFonts.headline,
  fontSize: 32,
  height: 40 / 32,
  fontVariations: const <FontVariation>[
    FontVariation('wght', 700),
    FontVariation('wdth', 105), // slight expansion reads as "expressive"
    FontVariation('opsz', 32),  // optical size matched to font size
  ],
)
```

Побочный выигрыш: вес становится анимируемым. Подсветка выбранного таба, выделение активного чата, акцент на непрочитанном — всё это перестаёт «щёлкать» между w500 и w700 и начинает плавно доезжать.

### 3.4 Цвет впечён в текстовые стили (P2)

Почти у каждой роли задан `color: scheme.onSurface` или `onSurfaceVariant`. Из-за этого любой текст на цветном контейнере (`primaryContainer`, `inverseSurface`, `error`) наследует неправильный цвет, и его приходится вручную перекрывать. Отсюда массовые `copyWith(color:)` по всему коду — они лечат симптом.

По канону цвет текста определяет компонент или `DefaultTextStyle` родительской поверхности, а не типошкала. Особенно опасны `labelMedium` и `labelSmall` с вшитым `onSurfaceVariant`: на `primary` они почти не читаются.

### 3.5 Сырые `TextStyle` без `fontFamily` — утечка Roboto (P1)

```dart
// m3_badge.dart
style: TextStyle(color: ..., fontSize: 12, fontWeight: FontWeight.w600)
```

Ни одного `fontFamily`, ни `copyWith` от темы. Значит бейдж рисуется **системным Roboto**, а не Onest. То же в `app_bottom_nav.dart` у счётчика непрочитанных (`TextStyle(fontSize: 10)`). Цифры в бейджах — самый заметный мелкий элемент интерфейса, и он набран другим шрифтом.

Гейт:

```bash
rg -n "TextStyle\(" lib | rg -v "fontFamily|copyWith|textTheme"
```

## 4. Шейпы

### 4.1 Скругления — круговые дуги вместо superellipse (P0 по восприятию)

M3 Expressive перешёл на **гладкие суперэллипсы** («squircle»): кривизна нарастает плавно, без видимого стыка дуги и прямой. Именно это отличает современные карточки от «закруглённых прямоугольников 2019 года». На радиусах 20–28, которые используются в проекте, разница видна невооружённым глазом.

Во Flutter это доступно как `RoundedSuperellipseBorder` и `ClipRSuperellipse`.

```dart
// было
shape: RoundedRectangleBorder(borderRadius: AppRadii.lgRadius)
ClipRRect(borderRadius: AppRadii.lgRadius, child: ...)

// M3 Expressive
shape: RoundedSuperellipseBorder(borderRadius: AppRadii.lgRadius)
ClipRSuperellipse(borderRadius: AppRadii.lgRadius, child: ...)
```

Менять надо не везде: карточки, диалоги, шиты, пузыри сообщений, аватары-квадраты, большие контейнеры. Круглые элементы (`StadiumBorder`, `BoxShape.circle`) не трогаем — там суперэллипс не имеет смысла.

<aside>
⚠️

Перед массовой заменой проверить доступность API на закреплённой версии Flutter и замерить один экран со списком: суперэллипс считается дороже дуги. Клип применять только там, где он и так был, новых `Clip` не добавлять — правило 2 моторного протокола.

</aside>

### 4.2 Shape-шкала обрезана до четырёх ступеней (P1)

```dart
AppRadii: sm 12, md 20, lg 28, full 999
```

В каноне семь ступеней: none 0, XS 4, S 8, M 12, L 16, XL 28, full. Не хватает мелких (4, 8) и средней 16 — поэтому в коде появляются литералы `circular(16)`, `circular(18)`, `circular(24)`, `circular(6)`, `circular(5.5)`, `circular(6.5)`. Только в трёх прочитанных файлах встретилось **девять** разных радиусов вне токенов.

### 4.3 Пользовательская настройка радиуса работает на треть (P1)

`settings.uiCornerRadius` попадает всего в три места: `cardTheme`, `dialogTheme`, `bottomSheetTheme`. Остальные компоненты темы захардкожены:

| Компонент | Радиус в теме |
| --- | --- |
| searchBar / searchView | 28 |
| listTile | 20 |
| popupMenu | 20 |
| segmentedButton | 18 |
| snackBar | 16 |
| inputDecoration | `AppRadii.mdRadius` (20) |

Пользователь двигает ползунок, карточки меняются, а поля ввода, списки и меню остаются. Либо провести `AppRadii.of(context)` через все компоненты (расширение `AppRadiiTheme` для этого и сделано), либо убрать настройку. Сейчас она читается как баг.

### 4.4 `flutter_m3shapes` почти не используется (P2)

Пакет подключён, но по предыдущим аудитам встречается только в splash, OTP-полях и about-экране. В каноне M3E шейпы — это **система**: индикатор навигации, бейджи, аватары групп, акцентные иконки, пустые состояния, индикаторы загрузки. Сейчас это разовые украшения на трёх экранах из сорока семи.

## 5. Компоненты: чего нет в теме

В `ThemeData` настроены 15 блоков. Отсутствуют:

| Отсутствует | Последствие |
| --- | --- |
| `filledButtonTheme` | **основная кнопка приложения не стилизована вообще** |
| `outlinedButtonTheme`, `textButtonTheme` | второстепенные кнопки на дефолтах Flutter |
| `filledButtonTheme` высоты | `AppHeights.lg = 56` не применяется, кнопки разной высоты |
| `floatingActionButtonTheme` | FAB — единственный компонент, которому разрешена elevation, но она не задана |
| `chipTheme` | чипы на дефолтах, хотя `badge_chip.dart` 14 КБ рисует свои |
| `menuTheme`, `menuButtonTheme` | `MenuAnchor` обязателен по правилам репозитория и при этом не затемирован |
| `navigationRailTheme` | десктопный рейл на дефолтах, индикатор `primaryContainer` задан вручную в шелле |
| `switchTheme`, `checkboxTheme`, `radioTheme` | переключатели в настройках на дефолтах |
| `sliderTheme` | слайдеры (громкость, радиус, шрифт) на дефолтах 2023 |
| `dividerTheme` | в коде вручную `outlineVariant` с альфой 0.20 / 0.22 / 0.28 |
| `tooltipTheme` | подсказки в стоковом стиле |
| `tabBarTheme`, `drawerTheme`, `expansionTileTheme` | дефолты |
| `datePickerTheme`, `timePickerTheme` | пикеры выпадают из языка приложения целиком |

### 5.1 Тема стилизует запрещённую кнопку и не стилизует используемую (P0)

```dart
elevatedButtonTheme: ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(56),
    shape: const StadiumBorder(),
    ...
```

`ElevatedButton` в этом проекте запрещён правилами. А `PulseButton`, который и есть главная кнопка приложения, построен на `FilledButton` — и **не получает ни высоты 56, ни StadiumBorder, ни стиля текста**. Отсюда разъезд: в `login_screen` высота 56 и радиус 28 прописаны руками, в остальных местах кнопка ~40.

### 5.2 `PulseButton` собран не по канону (P1)

```dart
child: Column(              // ← иконка НАД текстом
  children: [
    if (isLoading) AppLoadingIndicator(size: 16)
    else if (icon != null) Icon(icon, size: 20),
    if (icon != null || isLoading) SizedBox(height: 4),
    Text(label, overflow: TextOverflow.ellipsis),
  ],
)
```

Кнопка M3 — это **строка**: иконка слева, 8 dp, метка. Здесь `Column`, то есть иконка сверху. Плюс:

- `Listener` + `setState` вместо `InkWell` → **нет state-layer**: ни hover, ни focus, ни ripple. По канону M3 состояние обязательно для каждого интерактивного элемента, и это же ломает навигацию с клавиатуры на десктопе.
- Масштаб нажатия `0.94`, длительность `100 ms`, кривая `Curves.easeOutCubic` — при том что в проекте есть свои токены `AppMotion.scalePressed = 0.975`, `durationPress = 140` и обязательные `M3SpringCurves`. Двойной стандарт в самом переиспользуемом компоненте.
- Скачок 0.94 — это 6% сжатия, ощутимо резче, чем 2.5% в токене.

### 5.3 Не выставлен opt-in в M3E-отрисовку (P0)

У ряда компонентов Flutter держит старую геометрию за флагом. Без явного отказа от неё вы получаете вид 2023 года даже на новом Material.

```dart
progressIndicatorTheme: ProgressIndicatorThemeData(
  year2023: false,        // wavy track + stop indicator
  color: scheme.primary,
  linearTrackColor: scheme.surfaceContainerHighest,
  circularTrackColor: scheme.surfaceContainerHighest,
),
sliderTheme: const SliderThemeData(
  year2023: false,        // M3E handle, gap, track shape
),
```

Волнистый трек и стоп-индикатор у линейного прогресса — это **визитная карточка** M3 Expressive. Сейчас в проекте ради этого написан свой `Md3SquiggleProgress`, хотя платформа умеет сама.

### 5.4 Компоненты M3E, которых нет вообще (P2, возможности)

| Компонент | Где пригодился бы в NiosMess |
| --- | --- |
| Button group (связанная группа) | фильтры чат-листа, выбор качества медиа |
| Split button | «Отправить» с выбором режима, отправка без звука |
| FAB menu | уже есть кастомный `M3SpeedDialFab`, можно свести к канону |
| Docked / floating toolbar | панель действий при выделении сообщений вместо кастомного бара |
| Loading indicator | **есть**, через `loading_indicator_m3e` |
| Wavy progress | через `year2023: false` вместо своего сквиггла |

## 6. Иконки

### 6.1 Три шрифта Material Symbols лежат мёртвым весом (P1)

В `pubspec.yaml` зарегистрированы `MaterialSymbolsOutlined`, `MaterialSymbolsRounded`, `MaterialSymbolsSharp`. При этом весь код использует `Icons.*`, то есть **legacy Material Icons**. Три вариативных шрифта попадают в сборку и, судя по коду, не используются.

Надо выбрать одно из двух:

1. **Перейти на Symbols** — тогда открывается ось `FILL`, о которой ниже, но нужен свой map кодпоинтов.
2. **Выкинуть три шрифта из ассетов** и унифицировать `Icons.*` на одном варианте.

Второе дешевле, первое каноничнее.

### 6.2 Ось `FILL` не используется — иконки переключаются подменой (P1)

В `app_bottom_nav.dart` для каждого таба заданы `icon` и `selectedIcon`. Это **подмена глифа**: контурная иконка мгновенно заменяется на залитую. В каноне M3E выбор состояния — это **анимация по оси `FILL` от 0 к 1**, контур наливается цветом непрерывно.

```dart
// Material Symbols variable axes: FILL 0 -> 1 turns outline into filled,
// so selection becomes a continuous transition instead of a glyph swap.
AnimatedBuilder(
  animation: fill, // 0.0 .. 1.0, driven by the nav controller
  builder: (BuildContext context, Widget? _) => Text(
    glyph, // codepoint from a generated symbols map
    style: TextStyle(
      fontFamily: 'MaterialSymbolsRounded',
      fontSize: 24,
      color: color,
      fontVariations: <FontVariation>[
        FontVariation('FILL', fill.value),
        FontVariation('wght', 400 + 100 * fill.value),
        FontVariation('opsz', 24),
      ],
    ),
  ),
)
```

### 6.3 В одном ряду навигации смешаны два стиля иконок (P1, видно глазом)

```dart
chat_bubble_outline_rounded   // rounded
group_outlined                // НЕ rounded
grid_view_outlined            // НЕ rounded
person_outline_rounded        // rounded
```

Четыре таба, **два разных семейства иконок**. У двух скругления мягкие, у двух — прямые. Это самое заметное место в приложении, и там прямо сейчас видна несогласованность.

## 7. Состояния, фидбек, app bar

### 7.1 У AppBar нет scroll-under состояния (P1)

```dart
appBarTheme: AppBarTheme(
  elevation: 0,
  backgroundColor: Colors.transparent,
  ...
```

Нет `scrolledUnderElevation`, нет тонального перехода, нет `surfaceTintColor`. По канону M3 верхняя панель обязана **сменить поверхность на `surfaceContainer`, когда контент уезжает под неё**. Сейчас панель прозрачная всегда, поэтому текст списка проезжает под заголовком и под статус-баром без какой-либо разделительной поверхности.

Также нет `systemOverlayStyle`: цвет иконок статус-бара не привязан к яркости темы, на светлой теме с тёмным фоном они могут стать нечитаемыми.

Прозрачная панель нужна на hero-экранах поверх мешевого фона — это осознанное решение. Правильный компромисс: оставить прозрачность как вариант, но добавить обёртку, переключающую поверхность при скролле на `M3SpringCurves.expressiveStandard`, и применить её на всех списочных экранах.

### 7.2 Поле ввода меняет язык формы между состояниями (P1)

```dart
enabledBorder: OutlineInputBorder(borderSide: BorderSide.none)   // без границы
focusedBorder: OutlineInputBorder(borderSide: BorderSide(width: 1.5))  // полная обводка
```

В покое это **filled**-поле без индикатора, в фокусе — **outlined**-поле с полной рамкой. В каноне это два разных компонента, и смешивать их состояния нельзя: filled-поле показывает фокус **подчёркиванием снизу**, outlined — рамкой по контуру. Сейчас при фокусе поле визуально «превращается» в другой компонент.

Попутно: `contentPadding` 18/14 даёт высоту около 46 px при минимуме 48 для тач-таргета; не заданы `labelStyle`, `floatingLabelStyle`, `errorStyle`, `helperStyle`, `prefixIconColor`, `suffixIconColor`.

### 7.3 Нет state-layer у кастомных интерактивных элементов (P1)

- `PulseButton` — `Listener`, без ink и без фокуса.
- `GooeySegment` — `GestureDetector` с `HitTestBehavior.opaque`, без ink, без фокуса, не фокусируется с клавиатуры.
- `PulsePageHeader` — статический `Container`.

В каноне у каждого интерактивного элемента **пять состояний**: enabled, hover, focus, pressed, disabled. На десктопе (а он поддерживается, есть рейл и master-detail) отсутствие hover и focus ощущается как «не нажимается».

### 7.4 Нарушения запрета на тени (P2)

Правило репозитория — тональные поверхности вместо теней, elevation только у FAB. Известные нарушения: `Material(elevation: 8)` в `m3_organic_background.dart`, `boxShadow` в десктопной заглушке чата, `elevation: 6` у ручного снекбара в `main_shell_screen.dart`. Плюс этот снекбар вызывается напрямую через `ScaffoldMessenger`, минуя обязательный `AppToast`.

## 8. Загрузочные состояния

### 8.1 Скелетоны невидимы без шиммера (P0, это баг)

```dart
// ChatListSkeleton
decoration: BoxDecoration(color: scheme.surface, ...)   // карточка
  ...
  decoration: BoxDecoration(color: scheme.surface, ...) // плейсхолдер внутри
```

Плейсхолдеры залиты **тем же цветом**, что и их контейнер. Контраст нулевой. Скелетон видно **только** в момент прохода шиммер-градиента. То есть на медленном соединении пользователь видит пустые прямоугольники, а не структуру контента. То же в `MessageListSkeleton`. В `PostCardSkeleton` сделано правильно — `surfaceContainerHighest` на `surfaceContainerLow`.

### 8.2 Шиммер — это saveLayer на весь список каждый кадр (P0 по производительности)

```dart
Shimmer.fromColors(
  ...
  child: ListView.separated(...),  // ← маска накрывает ВЕСЬ список
)
```

`Shimmer` работает через `ShaderMask` с бегущим градиентом, то есть **полноэкранный `saveLayer` на каждом кадре**, и происходит это в самый чувствительный момент — при первой отрисовке и холодном старте. Это прямо противоречит правилам 1 и 2 моторного протокола, который вы только что закрыли по всему остальному коду.

Дополнительно `highlightColor: scheme.primaryContainer.withValues(alpha: 0.6)` — цветной блик. В каноне плейсхолдер нейтральный, он не должен притягивать внимание сильнее реального контента.

Правильный путь по M3E: **статичные тональные плейсхолдеры** на `surfaceContainerHighest` без бегущего блика, а если ожидание длинное — один `AppLoadingIndicator`. Если движение всё же нужно, это одна дешёвая пульсация прозрачности на листовом узле внутри `RepaintBoundary`, а не маска поверх списка.

### 8.3 Три системы индикации загрузки (P2)

`AppLoadingIndicator` (канон), `Md3SquiggleProgress` (своя реализация того, что умеет платформа), голые `CircularProgressIndicator` и `LinearProgressIndicator` в `message_bubble.dart` (запрещены правилами). Плюс `typedef PulseLoadingIndicator = AppLoadingIndicator` — два имени одного виджета.

## 9. Адаптивность

### 9.1 Брейкпоинты вразнобой (P1)

Найденные значения: `760` (переключение на рейл в шелле), `840` (`m3_organic_background`), максимальные ширины контента `780`, `820`, `860`, `520`. Канонические окна Material — **600 / 840 / 1200 / 1600**.

Последствия:

- Планшет или раскладушка в диапазоне 600–760 получает **телефонный bottom nav**, хотя по канону там уже должен быть рейл.
- Нет окна «expanded» и «large»: приложение прыгает из телефонного лэйаута сразу в рейл на 760 и больше не меняется, тогда как на 1200+ канон предполагает **расширенный рейл с метками и постоянную панель**.

```dart
abstract final class Breakpoints {
  static const double compact = 600.0;   // phone: bottom nav
  static const double medium = 840.0;    // foldable, small tablet: rail
  static const double expanded = 1200.0; // tablet landscape: rail + list-detail
  static const double large = 1600.0;    // desktop: expanded rail
}
```

### 9.2 Масштабирование шрифта ОС не учтено (P1)

По коду разбросаны фиксированные высоты: 56 (кнопка), 72 (nav bar), 44 (сегмент), 38 (иконка хедера), 80 (пустое состояние), 52 (аватар в скелетоне), 36 (капсула сегмента), 24/12 (бейдж). При системном масштабе 150–200% содержимое в них обрезается.

Своя настройка `AppFontScale` (0.85–1.3) это **не решает**: она масштабирует текст внутри приложения, но не защищает фиксированные контейнеры и не читает системное значение. По канону контейнеры под текст должны быть `min`-ограничены, а не фиксированы, либо считаться через `MediaQuery.textScalerOf(context).scale(...)`.

### 9.3 Не обрабатываются системные флаги доступности (P2)

В теме и компонентах нет реакции на `MediaQuery.highContrast`, `MediaQuery.boldText`, `MediaQuery.disableAnimations`, `MediaQuery.invertColors`. Первые два прямо влияют на дизайн-токены (контраст схемы и вес шрифта), третий — на всю моторику.

## 10. Дубликаты компонентов

Одна из главных причин «разъезжающегося» вида: на каждую задачу есть по три реализации, и каждая со своими радиусами, цветами и мотором.

| Задача | Реализации |
| --- | --- |
| Бейдж со счётчиком | `m3_badge.dart`, `badge_chip.dart` (14.7 КБ), нативный `Badge` в `app_bottom_nav` |
| Сегмент-контрол | `gooey_segment.dart`, `segmentedButtonTheme`, свой селектор в about-экране |
| Заголовок экрана | `pulse_page_header.dart`, `SettingsScaffold`, обычный `AppBar` |
| Пустое состояние | `empty_state_widget.dart`, `empty_feed_widget.dart`, `centered_note.dart` |
| Индикатор загрузки | `AppLoadingIndicator`, `Md3SquiggleProgress`, голые прогрессы |
| Кнопка | `PulseButton`, `FilledButton` напрямую, `FilledButton.icon` с ручными размерами |
| Фон | `animated_mesh_background`, `animated_background_blobs`, `m3_organic_background`, `heroGradient` |

По каждой строке нужно выбрать **один** канонический компонент, остальные удалить, а не оставлять «на всякий случай».

## 11. Моторика вне переходов табов

### 11.1 `GooeySegment` — пружина, написанная руками и рассинхронизированная (P1)

```dart
_stretchAnim = TweenSequence<double>([...5 отрезков...])
    .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
// 500 ms
```

Пять ручных отрезков 1.0 → 1.25 → 0.85 → 1.1 → 0.95 → 1.0 — это попытка воспроизвести затухающую пружину, при наличии готовой `M3SpringCurves.bouncy`. Плюс:

- **Ширина и позиция едут по разным кривым.** Позиция считается через `_controller.value` напрямую, то есть **линейно**, а растяжение — по `TweenSequence` с `easeInOut`. Капсула доезжает до места не тогда, когда перестаёт пульсировать.
- 500 ms — вдвое дольше канонического `medium2` для такого элемента.
- `AnimatedContainer(duration: 200)` обёрнут вокруг `Text`, но **не анимирует ни одного своего свойства** — меняются только `style` ребёнка. То есть вес и цвет метки переключаются мгновенно, а `AnimatedContainer` стоит зря. И у него не задана `curve`, а дефолт — `Curves.linear`.
- Высота 44 px — ниже минимума 48 для тач-таргета.

### 11.2 Дефолтная `Curves.linear` у implicit-анимаций (P1)

У `AnimatedContainer`, `AnimatedScale`, `AnimatedOpacity` и родственных **дефолтная кривая — линейная**. Любой такой виджет без явной `curve` двигается механически. Гейт:

```bash
rg -n -U "Animated[A-Za-z]+\((?:[^)]*\n)*?[^)]*\)" lib | rg -v "curve:"
```

### 11.3 Ноль моторики там, где канон её требует (P2)

`EmptyStateWidget`, `PulsePageHeader`, `M3Badge`, `PulseSkeleton` → появление контента не анимировано. По канону M3E появление пустого состояния и смена счётчика — это `bouncy`-вход, а не мгновенная подстановка.

## 12. План для агента

<aside>
🤖

**Фаза 1. Палитра и контраст.** `PaletteStyle` enum, `dynamicSchemeVariant` из настроек, дефолт `expressive`, `contrastLevel` из `MediaQuery.highContrast`, добавить `paletteStyle` и `contrastLevel` в ключ кэша тем. Сегмент выбора стиля палитры в настройках внешнего вида.

**Фаза 2. Типографика.** Выправить шкалу до спеки, задать `height` всем пятнадцати ролям, убрать `color` из типошкалы (и вычистить появившиеся регрессии контраста), перевести display и headline на `fontVariations`. Отдельным проходом заменить `titleLarge` на `headlineMedium` в заголовках экранов.

**Фаза 3. Шейпы.** Расширить `AppRadii` до семи ступеней, провести `AppRadii.of(context)` через все блоки темы, заменить круговые скругления на `RoundedSuperellipseBorder` и `ClipRSuperellipse` на карточках, диалогах, шитах и пузырях. Замерить один длинный список до и после.

**Фаза 4. Тема компонентов.** Добавить отсутствующие блоки из раздела 5, начиная с `filledButtonTheme`. Удалить `elevatedButtonTheme`. Выставить `year2023: false` у прогрессов и слайдеров, после чего удалить `Md3SquiggleProgress`. Починить рассинхрон цвета индикатора навигации: `secondaryContainer` в теме, в `app_bottom_nav` и в рейле.

**Фаза 5. `PulseButton` и state-layer.** Перевести на `InkWell` внутри `FilledButton`, иконка слева в `Row`, масштаб и длительность из `AppMotion`, кривая из `M3SpringCurves`. То же для `GooeySegment`: `InkResponse`, высота 48, одна пружина на позицию и растяжение, `AnimatedDefaultTextStyle` для метки.

**Фаза 6. Загрузочные состояния.** Убрать `shimmer` целиком, починить контраст плейсхолдеров, оставить статичные тональные скелетоны. Вынести `shimmer` из `pubspec.yaml`.

**Фаза 7. Иконки.** Решить вопрос Material Symbols: либо генерируемый map кодпоинтов и анимация оси `FILL`, либо удаление трёх шрифтов из ассетов. В любом случае унифицировать семейство иконок в навигации.

**Фаза 8. Адаптивность.** Ввести `Breakpoints`, перевести шелл и все `maxWidth` на них, добавить окно 600–840 с рейлом и расширенный рейл на 1200+. Заменить фиксированные высоты на минимальные ограничения.

**Фаза 9. Дедупликация.** По каждой строке таблицы из раздела 10 выбрать канонический компонент, переключить вызовы, удалить остальные.

**Фаза 10. Чистка.** `app_colors.dart` — удалить или свести к HCT-генератору аватаров. Убрать `typedef PulseLoadingIndicator`. Вынести тени из трёх известных мест. Ручной `ScaffoldMessenger` → `AppToast`.

</aside>

Фазы 1–4 независимы и дают почти весь визуальный эффект. Фазы 5–11 можно вести параллельно. Фазу 9 делать последней, когда каноны уже зафиксированы.

## 13. Гейты и критерии приёмки

```bash
# захардкоженные цвета
rg -n "Color\(0x|Colors\.(white|black)" lib --glob '!**/l10n/**'

# TextStyle без семейства и без наследования от темы
rg -n "TextStyle\(" lib | rg -v "fontFamily|copyWith|textTheme"

# радиусы вне токенов
rg -n "circular\((?!AppRadii)" lib -P | rg -v "core/theme"

# implicit-анимации без кривой
rg -n "Animated(Container|Scale|Opacity|Align|Padding|Positioned)\(" lib -A6 | rg -v "curve:"

# запрещённые компоненты и тени
rg -n "ElevatedButton|BoxShadow|elevation: [1-9]" lib
rg -n "CircularProgressIndicator|LinearProgressIndicator" lib --glob '!**/pulse_loading_indicator.dart'

# shimmer должен исчезнуть
rg -n "shimmer" lib pubspec.yaml

# брейкпоинты вне констант
rg -n "maxWidth >= [0-9]|maxWidth > [0-9]" lib
```

Критерии приёмки:

1. Переключение `PaletteStyle` меняет палитру мгновенно и на всех экранах, включая OLED и системную динамику.
2. При системном контрасте «максимальный» схема пересчитывается, тема не берётся из кэша.
3. Соотношение `displayLarge / bodyLarge` не меньше 3.0.
4. Ни одного `TextStyle` без семейства шрифта.
5. Все блоки темы из раздела 5 присутствуют; `elevatedButtonTheme` удалён.
6. Линейный прогресс отрисован волнистым треком со стоп-индикатором средствами платформы.
7. Скелетон читается на статичном скриншоте без анимации.
8. Профиль кадров при показе скелетона чат-листа: ноль `saveLayer`, p99 raster в бюджете тира.
9. На ширине 700 px показан рейл, а не bottom nav.
10. При системном масштабе текста 200% ни один экран не обрезает контент.
11. `flutter analyze` — ноль новых замечаний.

<aside>
📦

**Версия.** Это редизайн дизайн-системы, значит следующий minor после того, который уйдёт на переходы табов. По протоколу репозитория строку в `CHANGELOG.md` пишет владелец своими словами — агент версию бампает, а формулировку спрашивает.

</aside>
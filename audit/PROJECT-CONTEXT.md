# Контекст аудита NiosMess (общий бриф для всех агентов-полос)

Читать целиком перед работой. Это факты, проверенные по коду и по исходникам
пакетов — не пересказ README.

## Проект

- Корень репозитория: `F:\Niosmess V2`
- Приложение: `F:\Niosmess V2\pulse_flutter` (Flutter, 862 .dart в `lib/`)
- Flutter **3.50.1**, Dart **3.14.0**
- Состояние: riverpod 3 (`NotifierProvider`/`AsyncNotifierProvider`), go_router 17
- UI: **`package:material_ui` 1.11.1** — миграция уже сделана в 101 файле,
  осталось 5 импортов `package:flutter/material.dart`:
  `lib/main.dart`, `lib/core/theme/markdown_theme.dart`,
  `lib/l10n/app_localizations.dart`, `lib/screens/settings_appearance_accent_screen.dart`,
  `lib/screens/settings_appearance_screen.dart`
- M3E-пакеты в проекте: `motor` 1.1.0, `m3e_design` 0.2.1, `flutter_m3shapes`,
  `loading_indicator_m3e` 0.1.1
- Цели сборки: Android, Windows, **Web** (важно: web в CI собирается)

## Проверенные факты про M3E (не выдумывать сверх этого)

1. В `material_ui` 1.11.1 компонентный опт-ин M3E (`StyleVariant`) есть
   **только у двух** тем: `ElevatedButtonThemeData` и `IconButtonThemeData`
   (`IconButtonTheme.variantOf`). Глобального `ThemeData`-варианта Expressive
   **нет**. Требовать `StyleVariant` у других компонентов — ошибка.
2. `StyleVariant` в проекте не используется ни разу (0 вхождений) — это
   возможность, а не дефект.
3. M3E в Flutter катится по компонентам; «полного M3E» в SDK нет и не будет в
   ближайшее время. Проект это знает (см. `AGENTS.md`, раздел M3E Protocol).
4. Новые M3E-пакеты предлагать нельзя без проверки издателя, лицензии и кода
   (правило проекта). Если предлагаешь пакет — укажи pub.dev-ссылку и почему
   существующих `m3e_design`/`flutter_m3shapes`/`motor` недостаточно.

## Дизайн-система проекта (использовать её, а не изобретать)

- `lib/core/theme/`: `app_theme.dart` (19 КБ, `AppTheme.themed(...)`),
  `expressive_tokens.dart` (12 КБ), `app_surfaces.dart` (тональные поверхности),
  `app_typography.dart`, `app_colors.dart`, `nios_chroma.dart`
- `lib/core/motion/`: `m3_spring_constants.dart` (`M3SpringCurves`),
  `m3_motion.dart`, `m3_page_transitions.dart`, `nios_dismissible.dart`,
  `smooth_text_streamer.dart`
- `lib/widgets/motion/` (готовые блоки, использовать ДО написания своих):
  `M3PressScale`, `M3Entrance`, `M3MorphingIcon`, `M3StaggeredList`,
  `M3SpringSwitcher`, `M3Reveal`, `M3ReactionBurst`, `M3AnimatedBadge`,
  `M3SelectionMotion`
- `lib/core/modal/app_modal.dart` — единственный API для шитов
- `AppToast` — тосты, `showAppConfirmDialog` — диалоги, `AppLoadingIndicator` — прогресс

## Обязательные правила проекта (нарушение = находка)

Из `AGENTS.md` (не пересказывай их агенту как советы — это требования):

1. Никаких прямых `CircularProgressIndicator`/`LinearProgressIndicator` —
   только `AppLoadingIndicator` (исключение: `AppLoadingIndicator(value:)` для
   детерминированного прогресса).
2. `ElevatedButton` с `elevation > 0` запрещён.
3. `Card`/`Container` с резкими `BoxShadow` запрещены: глубина — тональными
   поверхностями (`surfaceContainer*`).
4. `PopupMenuButton` запрещён — `MenuAnchor` или свой expressive-шит.
5. Плоские прямоугольные `Container` для акцентных иконок/бейджей запрещены —
   `flutter_m3shapes`/сквирклы.
6. `Switch`/`Checkbox` без M3-стиля запрещены.
7. `Colors.white`/`Colors.black` запрещены — только `colorScheme.*`.
8. `withOpacity()` запрещён — только `withValues(alpha:)`.
9. `StateProvider` запрещён — только `NotifierProvider`.
10. `dart:io` запрещён — только `package:universal_io/io.dart`.

Анти-jank правила (тоже требования):

- Никакого `MaskFilter.blur`/`BackdropFilter` в повторяющихся циклах и тайлах
  списков; статический блюр — пре-рендер в `ui.Image`.
- Тайлы по умолчанию `clipBehavior: Clip.none`.
- Никакого `messages.indexWhere(...)` в `findChildIndexCallback`/layout — только O(1) `idToIndex`.
- Поле ввода и индикатор записи — в `RepaintBoundary`, отдельно от списка.
- Пружины — только `M3SpringCurves`; никаких overshoot-кривых на `Opacity`/`FadeTransition`.
- Никаких `AnimationController` в `build()`.
- Никакого неограниченного `shrinkWrap: true` внутри скролла.
- Холодный старт: независимые инициализации параллельно (`Future.wait`).

## Что нельзя трогать (даже читать как находку)

- `*.g.dart`, `*.freezed.dart`, `lib/l10n/secret/generated/**`, `pubspec.lock`
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`
- `assets/`, `server_core/`, `mock_quic/`, `graphify-out/`, `.opencode/`

## Что искать (четыре группы правил аудита)

Кроме общих правил из рубрики (`ARCH/LEAK/LIST/NET/DATA/SEC/UI/CODE`), в этом
аудите используются четыре группы под цели владельца.

### M3E — соответствие Material 3 Expressive
- `M3E-1`: `ElevatedButton`/`IconButton` без `StyleVariant.material3Expressive`,
  когда M3E-стиль уместен (только эти два компонента — см. факт 1).
- `M3E-2`: нарушение любого из 10 обязательных правил выше.
- `M3E-3`: хардкод цвета/тени/радиуса/типографики там, где есть
  `ColorScheme`, `AppSurfaces`, `ExpressiveTokens`, `AppTypography`.
- `M3E-4`: оставшийся импорт `package:flutter/material.dart`.

### MOTION — «побольше анимаций» (возможности, не дефекты)
- `MOTION-1`: мгновенное изменение состояния, где уместна M3-пружина/переход.
  Указать: где, какое состояние меняется, какой существующий блок из
  `widgets/motion/` подходит (или «нужен новый блок» + почему существующие не
  годятся), какова цена (сколько виджетов перестраивается).
- `MOTION-2`: рукописная анимация, дублирующая готовый блок из `widgets/motion/`.
- `MOTION-3`: переход экрана не через `core/motion/m3_page_transitions.dart`.
- `MOTION-4`: анимация, которая сломает anti-jank правила или не учитывает
  `MediaQuery.disableAnimations` (reduced motion).

Каждая MOTION-находка обязана назвать **точный существующий API**. Выдумывать
классы запрещено.

### LAG — «поменьше лагов»
- `LAG-1`: дорогая работа в `build()` (сортировка, парсинг, regex, форматирование,
  декодирование, запрос к БД/диску).
- `LAG-2`: слишком широкий rebuild (подписка на весь провайдер в корне, `setState`
  высоко в дереве, отсутствие `select`).
- `LAG-3`: проблемы виртуализации списка (`shrinkWrap`, нет `itemExtent`,
  `indexWhere` в layout, отсутствие ключей).
- `LAG-4`: saveLayer/дорогая растеризация (`Clip.antiAlias` на тайлах,
  `BackdropFilter`, `MaskFilter.blur`, `Opacity` на больших поддеревьях).
- `LAG-5`: синхронная работа на UI-изоляте (крипто, файлы, сеть, БД, большие JSON).
- `LAG-6`: изображения без `cacheWidth`/`cacheHeight` для превью; полноразмерный
  декод для миниатюр.

Нужен механизм («почему тормозит»), а не «может тормозить».

### MESS — «поменьше захламлённости»
- `MESS-1`: мёртвый код (класс/функция без ссылок — подтвердить grep'ом).
- `MESS-2`: дубли виджетов (два видеоплеера, два просмотрщика, два диалога).
- `MESS-3`: параллельные реализации одного паттерна (сырой
  `showModalBottomSheet` вместо `AppModal`, `ScaffoldMessenger` вместо `AppToast`).
- `MESS-4`: файл > 1000 строк.
- `MESS-5`: каталог > 15 прямых файлов.
- `MESS-6`: закомментированный код/`TODO`-кладбище большими блоками (> 15 строк).

## ВАЖНО: уже есть аудит производительности (не дублировать)

`audit/perf/00-summary.md` + `01-chat.md` … `06-motion-crosscut.md` — аудит от
2026-11-25, 6 агентов, ~115 уникальных замечаний с точными строками. Его тема —
**тормоза**, а не M3E и не захламлённость.

Поэтому:

1. **Прочитай `audit/perf/00-summary.md`** и файл своей зоны (указан в задании).
2. Не пересказывай его находки заново. Если находка из твоего списка уже есть
   там — пропускай, кроме случая «она всё ещё в коде И ты добавляешь новую
   причину/новый масштаб».
3. В твоём JSON может быть поле `perf_status`: для каждой проверенной P0/P1
   находки твоей зоны — `still` (всё ещё в коде) или `fixed` (уже исправлено),
   с текущей строкой. Это отдельная ценность: показать, что починилось за 3 дня.
4. Основная твоя работа — то, чего в perf-аудите нет: **M3E**, **MOTION**,
   **MESS**. Не трать попытку на повторный поиск `shrinkWrap` и `setState`.

## Формат результата

1. Записать JSON в указанный тебе файл `F:\Niosmess V2\audit\findings\<lane>.json`
   по схеме `C:\Users\Александр\Desktop\dart-audit-kit\review\findings.schema.json`.
2. `rule` — из перечисленных групп (например `LAG-3`, `MOTION-1`, `MESS-2`).
3. `severity`: `blocker` только для утечки данных/потери сообщений/краша;
   `high` — заметный jank, нарушение архитектуры, сломанный сценарий;
   `medium` — лишние rebuild, обход темы, дублирование; `low` — мелочи.
4. `evidence` — **дословная цитата кода** 1–5 строк. Без цитаты находка
   выбрасывается автоматически.
5. `why` — чем это вредит **этому** приложению, с механизмом.
6. `patch_sketch` — одна фраза: куда и что. Не полный патч.
7. Не больше 15 находок. Худшие по влиянию отбросить, указать `truncated`.
8. **Код не менять.** Ни одного edit, ни `dart fix`, ни форматирования.

Дополнительно в JSON можно добавить:

```json
"perf_status": [
  {"from": "audit/perf/00-summary.md#5", "status": "still", "file": "...", "line": 123},
  {"from": "audit/perf/00-summary.md#9", "status": "fixed", "note": "теперь .sizeOf"}
]
```

В ответ вернуть не больше 12 строк: сколько прочитано файлов, сколько находок по
группам, 3 самые дорогие (rule + file:line + одна фраза).

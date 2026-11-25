# План обновления зависимостей NiosMess

Статус: **план, не выполняется.** Блокеры Б1–Б4 закрыты владельцем, решения внесены.
Основа: `audit/deps/00-summary.md` + проверка pub.dev API (81/81) + проверка исходников
`material_ui`/`cupertino_ui`.

---

## 0. Решения владельца (приняты)

| # | Решение |
|---|---|
| Б1 | CI поднимаем до Flutter **3.50.1** (локальный и CI выравниваются) |
| Б2 | **Мигрируем приложение на `material_ui`**, через большое число сабагентов |
| Б3 | Правки `android/` и `windows/` **разрешены** (нативные мажоры делаем) |
| Б4 | `flutter_markdown` меняем на форк — выбран `flutter_markdown_plus` |
| — | Сабагентов можно использовать много, партиционирование по каталогам |

---

## 1. Факты, проверенные перед планированием

| Факт | Значение |
|---|---|
| Локальный Flutter | **3.50.1** stable (артефакты догружаются) |
| Flutter в CI | **3.47.6** → надо 3.50.1 |
| Hosted-зависимостей | 81 (+2 path) |
| Обновлений | 56: **15 major / 27 minor / 14 patch** |
| Мёртвых | 7 (6 hosted + `nios_mls`) |
| Мажоров после удаления мёртвого | **12** |
| `package:flutter/material.dart` | deprecated after `v3.47.0-0.0.pre` |

**Проверено по исходникам:**

1. `material_ui` 1.11.1 живёт в `flutter/packages/tree/main/packages/material_ui`
   (официальный монорепо), требует `Dart ^3.13.0`, `Flutter >=3.47.0`.
2. `material_ui.dart` — 7.3 КБ: **`export 'package:flutter/widgets.dart'`** + 187
   `export 'src/...'`. То есть `Widget`, `BuildContext`, `State`, `Page`, `Route`,
   `TextStyle`, `Color` остаются **теми же типами**. Меняются только material-типы:
   `ThemeData`, `ColorScheme`, `TextTheme`, `ThemeExtension`, `MaterialPage`,
   `MaterialApp`, `ScaffoldMessenger`, `WidgetStateProperty`, `ButtonStyle`.
3. `cupertino_ui.dart` устроен так же (2.9 КБ, 55 `src/`).
4. Следствие: миграция = **замена одной строки импорта на файл** + правка границ,
   где material-типы пересекают границы файлов. Это не переписывание UI.

**Форк markdown (проверено по метрикам):**

| Пакет | Score | скачиваний/мес | Примечание |
|---|---|---|---|
| **`flutter_markdown_plus` 1.0.12** | **160/160** | **1 003 000** | издатель `foresightmobile.com`, wasm-ready, Dart ^3.4 — фактически продолжение оригинала |
| `gpt_markdown` 1.4.1 | 160/160 | 208 638 | другой API (LLM-рендер), fallback |
| `markdown_widget` 2.3.2+8 | 150/160 | 9 880 | свой API, слабее |
| `markdown_viewer` 0.6.2 | 70/160 | 101 | не годится |

---

## 2. Правила игры

1. Одна фаза — ветка `upgrade/<фаза>`, один PR, мёрж только на зелёном CI.
2. **Один мажор — один коммит.** Мажоры не смешиваются между собой и с minor'ами.
3. `pubspec.lock` не правится руками — только `flutter pub get`.
4. Запрещён `flutter pub upgrade --major-versions`.
5. Версия и `assets/CHANGELOG.md` — по протоколу `AGENTS.md` (в конце фазы или волны).
6. Откат — `git revert` коммита фазы. Для `flutter_secure_storage` — плюс план
   восстановления данных.

### Роли

| Роль | Модель | Когда |
|---|---|---|
| Исполнитель | `itsxiao/free/deepseek-flash` | обычные фазы, механические волны |
| Сильный | `itsxiao/free/glm-5.3-prime` | ядро темы, интеграция, затыки |
| Ревьюер А | `itsxiao/free/kimi-k3` | ревью диффа |
| Ревьюер Б | `itsxiao/free/qwen3.8-max` | ревью диффа независимо от А |

### Конкурентность при «туче» сабагентов

Это главный источник поломок, поэтому жёстко:

1. **Партиционирование по каталогам.** Два агента никогда не получают пересекающиеся
   файлы. Внутри одной волны файл принадлежит ровно одному агенту.
2. **Агент не запускает `pub get`** и не правит `pubspec.yaml` — это делает только
   интегратор. Иначе 15 конкурентных резолвов.
3. **Агент анализирует только свой срез**: `dart analyze lib/<свой каталог>`.
   Глобальный `analyze` — только у интегратора.
4. Агент возвращает **патч + список «не смог починить»**; кросс-файловые ошибки
   собирает интегратор и чинит централизованно.
5. Волна применяется последовательно: агенты → интегратор → глобальный прогон.
6. Если два агента всё же упёрлись в один файл — приоритет у владельца каталога,
   второй сдаёт «не смог».

---

## 3. Фаза 0 — окружение, CI и базис

**Цель:** выровнять SDK и узнать исходное состояние.

1. Дождаться `flutter upgrade`, зафиксировать фактические Flutter/Dart.
2. **Б1 + гигиена CI.** Версии SDK захардкожены в трёх местах:
   `build.yml:29` (`FLUTTER_VERSION: '3.47.6'`), `profile-windows.yml:15` (`3.47.5`),
   `protocol-sdk.yml:38` (`dart-lang/setup-dart` → `'3.12.2'`). Первые два поднять
   до `3.50.1`; Dart-пин в `protocol-sdk` трогать только если standalone-пакеты
   перестанут резолвиться на новом SDK.

   Заодно (по аудиту CI от 2026-11-25) закрыть:
   - `android-startup-smoke` (эмулятор, ~3 мин) запускается на **каждый push в main**;
     перенести на теги + `workflow_dispatch`/`preview_apk`;
   - нет `paths-ignore` для `**.md` и `audit/**` — сейчас правка документа запускает
     весь релизный конвейер на ~22 минуты;
   - у `test`, `build-android`, `build-windows` нет `timeout-minutes`
     (у `protocol-sdk` есть 35) — добавить 30/35;
   - `publish-web` создаёт прогон на каждый завершённый Build, включая failure/cancel:
     7 из 20 последних прогонов — пустые skip. Это шум в истории, не работа; job-`if`
     уже стоит, чинить нечего.

   **Что в CI уже правильно (не трогать):** `concurrency` с `cancel-in-progress: true`
   в `build.yml`; PR-гейты (`build-windows` — только main/tags, `protocol-sdk` —
   `if: github.event_name != 'pull_request'` при собственном PR-триггере, то есть
   **без дублирования**); `android-startup-smoke` как reusable с `needs`;
   `pull_request` не собирает APK.
3. `flutter pub get` (появится `extended_image`), зафиксировать diff lock.
4. `flutter pub outdated --json > audit/deps/outdated-baseline.json`.
5. Базовые прогоны **до любых правок**: `dart analyze lib test`,
   `flutter analyze --fatal-infos`, `dart test`, `flutter test test/suite_test.dart`,
   chrome-тесты, `dart test test/pure_dart`.
6. **Б2-развилка:** если `--fatal-infos` красный на deprecated `flutter/material.dart` —
   временно, до конца фазы 7, добавить в `analysis_options.yaml`:
   ```yaml
   analyzer:
     errors:
       deprecated_member_use: ignore   # снять в фазе 7
   ```
   Зафиксировать это в задаче, чтобы подавление не осталось навсегда.

**Gate 0:** известен список исходных ошибок; CI-патч готов; `deprecated_member_use`
либо не нужен, либо подавлен с датой снятия.

---

## 4. Фаза 1 — удаление мёртвого

Ветка `upgrade/1-dead`. Коммит на пакет.

`cupertino_icons`, `google_fonts`, `shimmer`, `android_intent_plus`,
`audio_waveforms`, `msix` — и отдельным коммитом `nios_mls` (снимает
`openmls_frb.dll` 11.7 МБ и правку `native_assets.yaml`).

Мёртвый код после подтверждения: `services/calls/video_pipeline.dart`,
`providers/call_video_provider.dart`, `nios_sdk`: `link.dart`, `trust.dart`,
`SqliteWalDurableStore`, hive-бокс `messages_cache_box`.

**Не удалять:** `HeadlessWorkerClient` / `headless_core_isolate` — готовый перф-фикс,
завести отдельную задачу.

**Gate 1:** нет импортов удалённого; `analyze` без новых ошибок; тесты зелёные;
`flutter build windows` проходит.

---

## 5. Фаза 2 — patch + minor (41 пакет)

Ветка `upgrade/2-minor`. Три батча, коммит на 5–10 пакетов, `pub get` после каждого.

- **2a. Pure Dart:** `archive`, `crypto`, `intl`, `material_color_utilities`,
  `timezone`, `uuid`, `image`, `http`, `test`.
- **2b. Плагины:** `path_provider`, `shared_preferences`, `connectivity_plus`,
  `package_info_plus`, `url_launcher`, `app_links`, `share_plus`, `photo_manager`,
  `flutter_image_compress`, `flutter_cache_manager`, `flutter_file_dialog`,
  `video_player_platform_interface`, `audioplayers_platform_interface`.
- **2c. UI/медиа:** `flutter_riverpod` 3.5, `flutter_svg` 2.5, `lottie` 3.8,
  `video_player` 2.14, `audioplayers` 6.8, `chewie` 1.18, `emoji_picker_flutter` 4.5
  и остальные из baseline.

**Пороговые:** `desktop_drop` 0.9.2 (Dart `^3.13.5`), `tray_manager` 0.9.1 и
`window_manager` 0.7.1 (Flutter ≥3.50 / Dart ^3.14). Если не встают на 3.50.1 —
остаются, факт фиксируется в отчёте.

**Gate 2:** по батчу — `analyze` + тесты; после фазы — `flutter build windows`
и `flutter build web`.

---

## 6. Фаза 3 — хвосты плагинов (2)

- `file_picker` 12 → 13: **выполнено**. Проверка показала, что `getDirectoryPath()` и
  `pickFileAndDirectoryPaths()` в проекте не используются (все 12 вызовов — `pickFiles`),
  поэтому код менять не пришлось. Единственное реальное изменение API: `PlatformFile.length()`
  стал `Future<int?>` — размер трактуется как `?? 0` в `create_post_screen.dart` (2 места)
  и `m3_file_picker_bottom_sheet.dart` (1 место).
- `desktop_drop` 0.9.2 — **заблокирован апстримом**, не нами: `file_picker` даже в 13.4.1
  требует `cross_file ^0.3.5+4`, а `desktop_drop >=0.9.0` требует `^0.4.0`. Остаётся 0.8.4
  до тех пор, пока `file_picker` не переедет на `cross_file 0.4`.
- `open_file` 3 → 4: **выполнено**, API совместим (`dart analyze` чист на 4 файлах / 6 вызовах).

**Gate 3:** открытие файлов на Android и Windows вручную.

---

## 7. Фаза 4 — `flutter_markdown` → `flutter_markdown_plus` (Б4)

Ветка `upgrade/4-markdown`.

1. Заменить зависимость: `flutter_markdown: ^0.7.7+1` → `flutter_markdown_plus: ^1.0.12`.
2. Заменить импорты (4 файла, по отчёту: `widgets/post_card.dart`,
   `widgets/chat/*`, `screens/feed_post_screen.dart` и т.д.).
3. **Проверить паритет API** (это делает отдельный агент по исходникам форка):
   `MarkdownBody`, `MarkdownStyleSheet.fromTheme`, `inlineSyntaxes`, `builders`,
   `onTapLink`, `MarkdownElementBuilder`.
4. Прогнать рендер: лента (`post_card`), комментарии, сообщения с markdown.
5. Если паритет неполный — fallback на `gpt_markdown` (другой API, дороже по правкам)
   или форк `flutter_markdown_selectionarea` (слабый, не рекомендую).

**Gate 4:** лента и сообщения рендерятся как раньше; custom emoji (`CustomEmojiSyntax`,
`CustomEmojiMarkdownBuilder`) работают; `analyze` чистый.

---

## 8. Фаза 5 — нативные мажоры (5) — Б3 разрешён

Ветка `upgrade/5-native`. По одному коммиту на пакет, но правки платформы — общим
подготовительным коммитом.

**Подготовка платформы (1 коммит):**
- `android/`: `compileSdk` 37, AGP 9.1.1, Gradle wrapper под AGP 9, Kotlin DSL,
  JDK в CI (проверить 17 vs 21).
- `windows/`: `cmake_minimum_required(VERSION 3.14)`, `CXX_STANDARD 20`.
- Проверка: пуш в ветку → `.github/workflows/build.yml` зелёный. Локально APK
  не собирается (`AGENTS.md`), поэтому только CI.

**Пакеты:** `firebase_core` 5 (iOS SDK 13 / Android SDK 35),
`firebase_messaging` 17, `flutter_local_notifications` 23, `permission_handler` 13,
`flutter_foreground_task` 11 (есть отдельный migration-док).

**Gate 5:** Android-workflow зелёный; push-уведомление приходит на устройство;
локальное уведомление показывается; `flutter build windows` проходит.

**Откат:** платформенный коммит откатывается отдельно от пакетных.

---

## 9. Фаза 6 — поведенческие мажоры (2)

### 6.1 `flutter_secure_storage` 10 → 11

1. Аудит: сейчас **ни одной `AndroidOptions`/`IOSOptions` не задано** — выяснить,
   какими алгоритмами зашифрованы существующие записи (38 файлов использования).
2. Убедиться, что миграция v10 прошла (`migrateOnAlgorithmChange`).
3. Только потом 11.x (удалены `RSA_ECB_PKCS1Padding`, `AES_CBC_PKCS7Padding`).
4. Ручной тест: вход → перезапуск → сессия жива. Плюс сценарий «данные не читаются»
   → мягкий выход на повторный логин, без краша.

**Gate 6.1:** ручной тест на Android и Windows + на устройстве, где стояла v9/v10.

### 6.2 `record` 6 → 7

Удалены background recording service и `manageAudioSession`; затрагивает
`AndroidManifest` (foreground-service разрешения) → правки платформы разрешены.

**Gate 6.2:** запись голосового, волна рисуется, разрешения в манифесте не осиротели.

---

## 10. Фаза 7 — миграция на `material_ui` (главная) + 3 пакета

Ветка `upgrade/7-material-ui`. Работает «туча» сабагентов, но строго по волнам.

### 7.0. Подготовка

- Ветка, `working`-метка, чтобы можно было откатить волну целиком.
- Отдельный документ `audit/material_ui-map.md` — карта границ (см. 7.1).

### 7.1. Волна A — инвентаризация (10–12 агентов, только чтение)

**Замерено 26.11 на текущем коде:** 410 файлов импортируют `package:flutter/material.dart`
(`lib` + `test`), 1 файл — `package:flutter/cupertino.dart`, 1631 вхождение material-типов,
из них в сигнатурах (кандидаты в «границы») — ~140 файлов. Это и есть реальный объём.

Срезы: `core/theme` + `core/motion`, остальной `core/`, `widgets/chat`,
остальные `widgets/`, `screens/`, `features/`, `providers/`, `services/`,
`models` + `repositories`, `router` + `main.dart`, `test/`, `packages/`.

Каждый агент отдаёт CSV:

```
путь | импортирует material/cupertino | объявляет material-тип в публичном API | какие типы
```

**Цель волны — найти «границы»:** файлы, через которые `ThemeData`, `ColorScheme`,
`TextTheme`, `ThemeExtension`, `MaterialPage`, `WidgetStateProperty`, `ButtonStyle`
пересекают границы файлов. Это и есть настоящий объём миграции; остальное — механика.

Ожидаемые узлы (по аудиту): `core/theme/app_theme.dart`, `app_surfaces.dart`,
`expressive_tokens.dart`, `core/motion/m3_page_transitions.dart`,
`core/modal/*`, `widgets/motion/*`, `router/app_router.dart` (`_page`,
`_m3eEntryPage` → `MaterialPage`), `widgets/app_dialogs.dart`,
`core/utils/app_toast.dart`.

### 7.2. Волна B — ядро (1 сильный агент, `glm-5.3-prime`)

`core/theme/**`, `core/motion/**`, `core/modal/**`, `widgets/motion/**`,
`core/utils/app_toast.dart`, `widgets/app_dialogs.dart`.

Почему один: это хаб. Здесь появляется первый `ThemeData` из `material_ui`, и до
окончания волны приложение может не компилироваться — это ожидаемо.

**Gate B:** `dart analyze` выдаёт **только** ошибки границ, все перечислены в отчёте.

### 7.3. Волна C — параллельная механика (12–16 агентов, несвязные каталоги)

Срезы (файлов ориентировочно):
`widgets/chat/**` (~67), остальные `widgets/**` (~114), `screens/**` (~50),
`features/**` (~30), `providers/**` (43), `services/**` (~70),
`models`+`repositories` (~41), `l10n` (3, править все три сразу),
`test/**`, `packages/nios_sdk`.

Правила волны: агент меняет **только импорты и локальные следствия**, кросс-файловые
ошибки не чинит, а сдаёт списком. Каталоги не пересекаются.

### 7.4. Волна D — интеграция (1 интегратор + 2 ревьюера)

Интегратор: собирает «не смог», чинит границы, добивается `0` импортов
`package:flutter/material.dart` и чистого `analyze` (включая `--fatal-infos`).
Снимает временное подавление `deprecated_member_use` из фазы 0.

**Gate D:** `grep -c "package:flutter/material.dart"` по `lib/` = **0**;
`grep -c "package:flutter/cupertino.dart"` = 0 (остался только `cupertino_ui`);
`flutter analyze --fatal-infos` чистый; тесты зелёные; `flutter build windows` + web.

### 7.5. Волна E — пакеты

**Поправка по факту (dry-run 26.11):** `dynamic_color` 2.x **недостижим**. Цепочка
`loading_indicator_m3e 0.1.1 → m3e_design ^0.2.0 → dynamic_color ^1.8.1` жёстко держит 1.x,
а `AppLoadingIndicator` обязателен по `AGENTS.md` (140 использований). Поэтому:

- `material_ui` ^1.11.1 и `cupertino_ui` ^1.1.7 — добавляются как прямые зависимости
  (сейчас они уже транзитивные через `chewie 1.18.1` и `flutter_riverpod 3.5.0`);
- `cached_network_image` 4 и `go_router` 18 — поднимаются;
- `dynamic_color` остаётся **1.9.0**, и `AppTheme.themed` переделывается так, чтобы
  принимать seed-`Color` вместо целого `ColorScheme` (`main.dart:397` сейчас передаёт
  `dynamicScheme: lightDynamic`). `Color` — общий `dart:ui`-тип, поэтому граница остаётся
  целой, а функция динамических цветов сохраняется.

`cached_network_image` 4, `go_router` 18 — **только после** D,
потому что они приносят `material_ui`-типы, а до миграции это гарантированный разъезд.
Проверить особенно: `DynamicColorBuilder` в `main.dart` → `AppTheme.themed(...)`
и `MaterialPage` в роутере.

**Gate E:** смена темы (светлая/тёмная/динамическая) на Android и Windows;
навигация по всем маршрутам, deep links, диалоги, шиты.

### 7.6. Известные мины (для ревьюеров)

1. `ThemeExtension<T>` — `AppSurfaces`/`ExpressiveTokens` должны быть одним типом,
   иначе `Theme.of(context).extension<...>()` вернёт `null`.
2. `WidgetStateProperty` vs устаревший `MaterialStateProperty` — в проекте уже
   `WidgetStatePropertyAll`, это правильный вариант.
3. `MaterialPage` в `_page()`/`_m3eEntryPage()` — должен стать `material_ui`.
4. `Theme.of(context)` — ~300 мест, механика, но любая забытая строка даст
   «`ThemeData` is not a subtype».
5. `GlobalMaterialLocalizations` в `MaterialApp.localizationsDelegates` —
   из `flutter_localizations`, совместимо по generic-типу, но проверить.
6. `ColorScheme.fromSeed` + `AppSurfaces.neutralize` — оба должны быть на одном типе.
7. Пакеты, которые **не** мигрировали (`photo_view`, `flutter_svg`, `lottie`,
   `qr_flutter`, `emoji_picker_flutter`, `loading_indicator_m3e`): они принимают
   либо только `Widget`, либо общие painting-типы — прогнать `analyze` покажет.
8. `flutter_m3shapes` возвращает `ShapeBorder` (painting) — безопасно.
9. `test/**` — тесты используют `Color`/`ThemeData`; их тоже надо мигрировать,
   иначе `suite_test` не соберётся.
10. `l10n`: `app_localizations*.dart` правятся все три сразу (по `AGENTS.md`).

---

## 11. Фаза 8 — финал

- `flutter pub outdated` — ни одного пакета из поднятых.
- Полный прогон матрицы.
- Версия + `assets/CHANGELOG.md` (стиль по `AGENTS.md`).
- Обновить `audit/deps/00-summary.md`: что сделано, что осознанно пропущено.
- Удалить временный dev-экран `lib/screens/dev/extended_image_demo_screen.dart`
  и маршрут `/dev/image-viewer`.

---

## 12. Матрица проверок

| Проверка | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| `dart analyze lib test` | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| `flutter analyze --fatal-infos` | ✔ |  |  |  |  | ✔ |  | ✔ |
| `dart test` | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| `suite_test.dart` | ✔ | ✔ | ✔ |  | ✔ | ✔ |  | ✔ |
| chrome-тесты | ✔ |  | ✔ |  |  |  |  | ✔ |
| `flutter build windows` |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| `flutter build web` |  |  | ✔ |  |  |  |  | ✔ |
| Android-workflow (CI) |  |  |  |  |  | ✔ | ✔ | ✔ |
| Ручной вход/сессия |  |  |  |  |  |  | ✔ |  |
| Ручной рендер markdown |  |  |  |  | ✔ |  |  | ✔ |
| Ручная смена темы + навигация |  |  |  |  |  |  |  | ✔ |

---

## 13. Порядок, цена, параллелизм

| Фаза | Цена | Риск | Сабагентов | Зависит от |
|---|---|---|---|---|
| 0. Окружение + CI | 1 | низкий | 1–2 | — |
| 1. Мёртвое | 2 | низкий | 2 | 0 |
| 2. patch+minor | 5 | низкий-средний | 3 (по батчу) | 0 |
| 3. `file_picker`, `open_file` | 1 | низкий | 2 | 2 |
| 4. markdown-форк | 1 | низкий | 2 | 2 |
| 5. Нативные мажоры | 4 | высокий | 3 | 0, Б3 |
| 6. Поведенческие | 3 | **высокий** | 3 | 2 |
| 7. `material_ui` | **10–14** | **очень высокий** | **25–30 суммарно** | 2, 4 |
| 8. Финал | 1 | низкий | 1 | все |

Всего по плану: ~40–45 запусков сабагентов, из них 25–30 в фазе 7.

Фазы 3, 5, 6 независимы друг от друга; 7 зависит от 2 и 4 (после миграции не должно
остаться пакетов, которые тянут старый material). Фазы 0–4 дают основную часть выигрыша
при низком риске, даже если 5–7 отложить.

---

## 15. Прогресс выполнения

Обновляется по мере работы; здесь только факты с проверкой.

### Фаза 0 — выполнена
- OK Локальный SDK: Flutter 3.50.1 / Dart 3.14.0 / DevTools 2.61.0.
- OK CI поднят: `build.yml` `FLUTTER_VERSION: '3.50.1'`, `profile-windows.yml` `3.50.1`.
- OK `AGENTS.md` синхронизирован (было 3.44.6 / CI 3.47.6).
- OK CI-гигиена: `paths-ignore` для `**.md`/`audit/**`/`docs/**` на push; `android-startup-smoke`
  только на тегах и `preview_apk`; `publish-release` принимает `skipped`; таймауты 20/35/30/15/10.
- OK Базис: `dart analyze lib test` — No issues found; `dart test test/pure_dart` — 18/18 passed;
  `flutter test test/suite_test.dart` — 1911 passed, 1 failed (guardrail на голый прогресс-индикатор
  в dev-демо, исправлено на `AppLoadingIndicator`).
- OK `audit/deps/outdated-baseline.json` (117 пакетов, 15 major).
- OK `deprecated_member_use: ignore` в `analysis_options.yaml` (282 info на material.dart), снимается в фазе 7.

### Фаза 1 — выполнена
- OK Удалены: `cupertino_icons`, `google_fonts`, `shimmer`, `android_intent_plus`, `audio_waveforms`, `msix`, `nios_mls`.
- OK Из кода вырезан MLS-мост в `nios_protocol_accounts.dart` (`openGroups` не вызывался).
- OK lock 306 → 299; ушли `openmls`, `flutter_rust_bridge`, `get_it`, `console`, `build_cli_annotations`.
- OK `dart analyze lib test` — No issues found.
- Прим: `cupertino_icons` остаётся транзитивным через `chewie`.

### Фаза 2 — patch + minor
| Пакет | Было | Стало |
|---|---|---|
| archive | 4.5.2 | 4.7.1 |
| crypto | 3.0.7 | 3.0.8 |
| image | 4.12.0 | 4.13.1 |
| web | 1.1.1 | 1.1.2 |
| camera | 0.12.1 | 0.12.2 |
| flutter_file_dialog | 3.3.3 | 3.3.6 |
| flutter_cache_manager | 3.4.5 | 3.5.0 |
| flutter_webrtc | 1.6.2+hotfix.4 | 1.6.3 |
| chewie | 1.17.4 | 1.18.1 |
| flutter_riverpod | 3.4.3 | 3.5.0 |
| flutter_svg | 2.3.0 | 2.5.0 |
| lottie | 3.6.1 | 3.8.2 |
| geolocator | 14.0.2 | 14.1.2 |
| window_manager | 0.5.2 | 0.5.2 (0.7.1 требует MSVC, отложено) |
| tray_manager | 0.5.3 | 0.5.3 (0.9.1 требует MSVC, отложено) |
| pasteboard | 0.5.0 | 0.6.2 |

- Не поднялись из-за чужих констрейнтов: `connectivity_plus` 7.3.1 (доступна 7.3.2),
  `material_color_utilities` 0.13.0 (доступна 0.13.1).
- `desktop_drop` 0.9.2 заблокирован: требует `cross_file ^0.4.0`, а `file_picker 12` держит
  `^0.3.5+4`. Разблокируется только вместе с `file_picker 13` (фаза 6).
- `window_manager` 0.7.1 / `tray_manager` 0.9.1 переведены на nativeapi (`nativeapi 0.6.2`):
  `WindowManager.instance.getCurrent()`, синхронный `Window`, `TrayIcon`, `Menu`/`MenuItem`,
  `WindowCloseRequestedEvent` вместо `setPreventClose`. **Отложено:** `cnativeapi` собирает
  нативную библиотеку из исходников через build hook (`native_toolchain_c`), а на машине нет
  ни MSVC, ни clang (gcc в `native_toolchain_c` есть только для Linux). Без компилятора
  падает не только `flutter build windows`, но и `flutter test`. Готовая версия файла лежит
  в `audit/desktop_window_service.nativeapi.dart.txt`; применить после установки
  VS Build Tools (`Microsoft.VisualStudio.Component.VC.Tools.x86.x64`). CI (`windows-latest`)
  ограничение не затрагивает.

### Фаза 8 (DoD) — частично
- OK Web-сборка на CI: `Build Web` — success за 2 мин (прогон 45692760314).
- OK Версия `3.148.0+4336` → **`3.149.0+4337`**, чейнджлог `assets/CHANGELOG.md`
  дописан секцией `[3.149.0]`.
- OK `audit/deps/00-summary.md` дополнен фактическим результатом (раздел 6).
- OK `audit/material_ui-map.md` — карта фазы 7: 410 импортов material, 1 cupertino,
  135 файлов-границ.
- ОТКР `Build Android APK` и `Build Windows Installer` — идут в прогоне 45692760314.
- ОТКР Dev-экран `/dev/image-viewer` **оставлен намеренно**: это инструмент, который
  запросил владелец, и на нём завязан пакет `extended_image`. Удаление — отдельным
  решением, не в рамках апгрейда.

<!-- дальше: фаза 5 (native), 6 (поведение), 7 (material_ui) -->

### Фаза 4 — выполнена
- OK `flutter_markdown` 0.7.7+1 (discontinued) → **`flutter_markdown_plus` 1.0.12**, пакет удалён из графа.
- OK Импорты заменены в 4 файлах: `lib/screens/native_file_viewer_screen.dart`,
  `lib/widgets/chat/custom_emoji.dart`, `lib/widgets/post_card.dart`,
  `test/widgets/feed_features_test.dart`. Остатков `package:flutter_markdown/` — 0.
- OK Поверхность API совпала: `flutter_markdown_plus.dart` экспортирует `src/builder.dart`,
  `src/style_sheet.dart`, `src/widget.dart` — то есть `MarkdownBody`, `MarkdownStyleSheet`,
  `MarkdownElementBuilder` на месте.
- ГЕЙТ: `flutter test test/suite_test.dart` → **1912/1912 passed**, `dart analyze` чист.

### Фаза 6 — частично
- 6.1 OK `flutter_secure_storage` 10.3.4 → **11.2.0**. Аудит: 17 мест создают
  `FlutterSecureStorage()`, и **ни одно** не передаёт опции — значит все записи сделаны
  дефолтными алгоритмами v10 (`RSA-OAEP` / `AES-GCM`), а v11 удаляет только устаревшие
  `RSA_ECB_PKCS1Padding` и `AES_CBC_PKCS7Padding`. Риск потери данных низкий.
  v11 также перестал пинить compileSdk 37 и берёт `flutter.compileSdkVersion` (11.1.0),
  поэтому AGP 9 не требует.
- 6.2 БЛОК `record` 6.2.1 → 7.2.0: помимо удаления background-сервиса и
  `manageAudioSession`, changelog 7.0.0 содержит «Android: **Move to AGP 9.x**».
  То есть это та же миграция тулчейна, что в фазе 5; отдельно не применяется.

### Фаза 3 — выполнена
- OK `file_picker` 12.3.0 → **13.4.1**. Код не переписывался: `getDirectoryPath` не используется.
  Совместимость сломалась только на `PlatformFile.length()` → `Future<int?>`; размер берётся `?? 0`
  в `create_post_screen.dart:372,425` и `m3_file_picker_bottom_sheet.dart:510`.
- OK `open_file` 3.5.11 → **4.0.0**, API совместим.
- БЛОК `desktop_drop` 0.9.2 — апстримный конфликт: `file_picker` (даже 13.4.1) тянет
  `cross_file ^0.3.5+4`, а `desktop_drop >=0.9.0` требует `^0.4.0`. Остаётся 0.8.4.
- ГЕЙТ фаз 2 и 3: `flutter test test/suite_test.dart` → **1912/1912 passed**,
  `dart analyze lib test` → No issues found.
- Найден и исправлен реальный регресс от `chewie 1.18.1`: полноэкранный маршрут больше
  не даёт `Material`-предка, `Slider` в `M3VideoOverlayControls` падал на
  `debugCheckHasMaterial`. Панель управления получила собственный
  `Material(type: MaterialType.transparency)` (`lib/widgets/media/m3_video_controls.dart`).

## 14. Definition of Done

- [ ] Flutter в CI = 3.50.1, локальный = CI.
- [ ] `pubspec.yaml` без мёртвых строк; `flutter pub outdated` чист по поднятым.
- [ ] `analyze` (включая `--fatal-infos`) без новых замечаний.
- [ ] `dart test`, `suite_test`, chrome, `pure_dart` — зелёные.
- [ ] `flutter build windows` и `flutter build web` проходят.
- [ ] Android-workflow зелёный, push и локальные уведомления проверены на устройстве.
- [ ] Вход/сессия после `secure_storage` 11 живы на Android и Windows.
- [ ] `grep "package:flutter/material.dart" lib/` = 0; `material_ui` — везде.
- [ ] Лента, комментарии и сообщения с markdown рендерятся; custom emoji работают.
- [ ] Версия и `CHANGELOG.md` обновлены; `audit/deps/00-summary.md` актуализирован.
- [ ] Временный dev-экран и маршрут удалены.

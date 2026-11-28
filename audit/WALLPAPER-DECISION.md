# Обои чата: дошить (A) или удалить (B)

Дата: 2026-11-28. Репозиторий: `F:\Niosmess V2\pulse_flutter`. Код не менялся — только чтение, `git log/show`, подсчёт строк.

## 0. Что реально в коде (важнее постановки)

1. **Фича не «забыта», она намеренно выключена 23.10.2026** коммитом `8f728063 "Redesign inbox with neutral surfaces and unified M3 navigation"`: из `chat_wallpaper_background.dart` удалено 239 строк, из `wallpaper_preview_pane.dart` — 129. Тот же коммит оставил в файлах комментарии «preferences stay stored, but no wallpaper is loaded or painted».
2. **Пауза закреплена тестами-стражами**, а не только комментариями:
   - `test/widgets/neutral_inbox_test.dart:167-188` — «page and chat backdrop never create painters or read wallpaper storage»: `CustomPaint` и `Image` под `ChatWallpaperBackground` должны отсутствовать;
   - `test/widgets/appearance_palette_test.dart:341-379` — «palette changes preserve controls **without restoring decorative backgrounds**», проверяет отсутствие `RawImage`;
   - `test/unit/settings_registry_test.dart:134-152` — «search does not advertise disabled backgrounds», `wallpaper_generator` не должен находиться поиском.
3. **Логика Chroma уже готова к обоям**: `nios_chroma.dart:20-26` (`shouldApply` → `false` при кастомных обоях), вызов в `chat_detail_screen.dart:2380-2396`. Условие `cw != s.global || cw.imagePath != null` — то есть Chroma отключается только для чата с override, а не для всех.
4. **Полная рабочая реализация лежит в git** (`8f728063^`): `ChatWallpaperBackground` — `ConsumerStatefulWidget` на 239 строк с `WallpaperImageCache`, `RawImage`, фото-слоем и заглушкой-градиентом; `WallpaperPreviewPane` — `CustomPaint(ChatWallpaperPainter)`. То есть «дошить» = во многом «достать из git».
5. **Ключевая ловушка A:** `ChatWallpaperState.global` по умолчанию `ChatWallpaperConfig.defaultPattern` (`chat_wallpaper_provider.dart:13`, `chat_wallpaper_config.dart:124`), а `forChat()` никогда не возвращает `null` (`:24-27`). Старая реализация рисовала конфиг **безусловно** → простое восстановление из git включит узорные обои **во всех чатах у всех пользователей** сразу после апдейта, что прямо противоречит «neutral surfaces» и трём тестам выше. Состояния «обоев нет» в модели не существует.
6. **Студия сейчас живая и обещает больше, чем делает**: `settings_wallpaper_screen.dart` → `WallpaperStudioScreen`, входы `app_router.dart:683-686` и `profile_screen.dart:746`; превью при этом показывает «Фоны временно отключены» (`wallpaper_preview_pane.dart:34`, l10n `backgroundsPaused`), а «Применить» всё равно пишет конфиг в prefs (`wallpaper_studio_screen.dart:72-86`). Это и есть текущий продукт-дефект: настройка сохраняется и ничего не меняет.
7. Мелочь по постановке: провайдер лежит в `lib/providers/chat_wallpaper_provider.dart`, а не в `lib/widgets/wallpaper/`.
8. `WallpaperImageCache.clear()` вызывается из провайдера 4 раза (`:128, :141, :174, :183`) — это единственная связь кэша с провайдером.
9. `NiosWeave` (`lib/core/identity/nios_weave.dart`, 267 строк) в `lib/` используется **только** painter'ом (`chat_wallpaper_painter.dart:5, 264-491`), но на нём же висят `test/unit/nios_weave_test.dart`, `test/perf/weave_size_test.dart`, `test/unit/moments_test.dart` (share-URL обоев).
10. Ассеты: `assets/svg/pattern_icons/` — 290 файлов, 142 КБ; объявлены в `pubspec.yaml` (lucide, tabler).

## 1. Инвентарь стека (измерено `Get-Content | Measure-Object -Line`)

| Файл | Строк | Кто использует |
|---|---:|---|
| `lib/widgets/wallpaper/chat_wallpaper_painter.dart` | 727 | preview (сейчас нет), тест |
| `lib/widgets/wallpaper/material_symbols_data.dart` | 8559 | только painter |
| `lib/widgets/wallpaper/icon_sources_catalog.dart` | 352 | painter, image_cache |
| `lib/widgets/wallpaper/curated_wallpaper_catalog.dart` | 213 | только painter |
| `lib/widgets/wallpaper/cupertino_icons_data.dart` | 206 | icon_sources_catalog, painter |
| `lib/widgets/wallpaper/wallpaper_image_cache.dart` | 313 | провайдер (4× `clear()`), старый background |
| `lib/widgets/wallpaper/wallpaper_color_resolver.dart` | 109 | painter, cache, старый background/preview |
| `lib/widgets/wallpaper/chat_wallpaper_background.dart` | 10 | `chat_detail_screen.dart:2487` |
| `lib/features/wallpaper/**` (5 файлов) | 1024 | `settings_wallpaper_screen`, router, profile |
| `lib/models/chat_wallpaper_config.dart` | 489 | провайдер, студия, painter, тесты |
| `lib/providers/chat_wallpaper_provider.dart` | 170 | студия, chat_detail (Chroma), background |
| `lib/core/identity/nios_weave.dart` | 267 | только painter + 3 теста |
| `test/widgets/chat_wallpaper_painter_test.dart` | 185 | painter |
| `test/models/chat_wallpaper_config_test.dart` | 138 | config |
| `test/widgets/wallpaper_slider_field_test.dart` | 45 | студия |
| `test/unit/nios_weave_test.dart`, `test/perf/weave_size_test.dart`, `test/unit/moments_test.dart` | 87 / 60 / 48 | NiosWeave |

Итого под ножом в B: ~10.5 тыс. строк `lib/widgets/wallpaper` + ~1 тыс. студии + ~0.9 тыс. моделей/провайдера/weave + ~0.6 тыс. тестов ≈ **13 тыс. строк и 290 ассетов**.

## 2. Вариант A — «дошить фичу»

### 2.1 Кто рисует
`ChatWallpaperNotifier`/`chatWallpaperProvider` уже отдаёт `ChatWallpaperState.forChat(chatId)`; `chat_detail_screen.dart:2487` передаёт `chatId` в `ChatWallpaperBackground`, дальше `ChatViewport.wallpaper` (`chat_viewport.dart:61,72-73,150-152`) кладёт виджет под список сообщений. Не хватает только тела `ChatWallpaperBackground` (сейчас 13 строк → `ColoredBox`).

### 2.2 Правки

| # | Файл | Что делать | ч |
|---|---|---|---:|
| A1 | `lib/widgets/wallpaper/chat_wallpaper_background.dart` | Вернуть версию из `git show 8f728063^:./lib/widgets/wallpaper/chat_wallpaper_background.dart`, заменить `flutter/material.dart` → `material_ui`, сохранить `RepaintBoundary` + `RawImage` | 3 |
| A2 | `lib/widgets/wallpaper/wallpaper_preview_pane.dart` | Вернуть `CustomPaint(ChatWallpaperPainter)` + демо-бабблы из того же коммита (учесть, что старый текст был с emoji — правило «no emoji» из `9f4fe4db`) | 2 |
| A3 | `lib/models/chat_wallpaper_config.dart` + `chat_wallpaper_provider.dart` | Ввести явное «обоев нет» (флаг `enabled`/`WallpaperBackgroundStyle.none`), сделать дефолт **off**, миграция старых записей: у сохранённых конфигов без флага — off, чтобы апдейт не включал узор всем | 5 |
| A4 | `lib/screens/chat_detail_screen.dart:2380-2396` | Пересчитать `hasCustomWallpaper`: сейчас `cw != s.global` → при глобальном узоре Chroma остаётся включённой и конфликтует по контрасту; отключать Chroma при любом активном узоре | 2 |
| A5 | `lib/features/wallpaper/**` | Тумблер «Фон: выкл/узор/фото» в студии, превью по `config`, «Применить» пишет только при включении; l10n-ключи, `settings_registry` (`appearance.wallpaper`) | 4 |
| A6 | Перф/тема QA | Профилировка на телефоне и Windows: cache budget, DPR, resize, смена темы; `ImageFiltered` для фото (Windows уже без блюра) | 5 |
| A7 | Тесты | Инвертировать 3 стража, добавить widget-тест `ChatWallpaperBackground` (off → `ColoredBox`, on → `CustomPaint`/`RawImage`), обновить реестр/навигацию | 4 |

**Оценка A: 15–21 ч (2–3 рабочих дня).** «Наивное» восстановление двух файлов из git — 4–6 ч, но оно включает узор во всех чатах, ломает 3 стража и противоречит текущему дизайн-направлению; это не готовый вариант, а регресс.

### 2.3 Риски A

- **Дефолт.** Без A3 фича выкатывается «всем и сразу». Это главный риск, а не производительность.
- **Память/кадры.** `WallpaperImageCache` (`:42-48`) держит 32 МБ (моб/web) / 64 МБ (desktop) и максимум **3** записи (`:217`). При logical 1080×2400 и `pixelRatio` до 2.0 одна картинка ≈ 2160×4800×4 ≈ **41 МБ**, т.е. уже больше мобильного бюджета → запись вытесняется немедленно, кэш превращается в анти-кэш, а `_doRender` (полный пересчёт узора + SVG-пулов) запускается на каждое открытие чата/резкое изменение размера. Лечится понижением DPR/квоты, но это отдельная работа (входит в A6).
- **Правило про блюр.** `tool/check_ui_architecture.dart:114-131` и `test/unit/anti_slop_guard_test.dart:80-98` запрещают `BackdropFilter` вне `AdaptiveGlass`; `test/m3e_design_audit_test.dart:215` ловит `MaskFilter.blur`. Painter сам по себе чист (`saveLayer` ограничен 24×24, `chat_wallpaper_painter.dart:519`), но фото-слой — полноэкранный `ImageFiltered(ui.ImageFilter.blur)`, который формально проходит, а по смыслу нарушает «zero blur passes»; на Windows старый код глушил блюр и добавлял скрим. Любая новая «стеклянная» подача бабблов поверх обоев упрётся в страж.
- **Отсутствие обоев.** Сейчас тон обеспечивает `AppSurfaces.of(context)`; при A надо гарантировать, что при off остаётся ровно `ColoredBox(AppSurfaces)` и Chroma работает — это и есть смысл A3/A4, но именно тут ломается контраст в dark/light.
- **Тесты.** Падают `neutral_inbox_test` (ищет отсутствие `CustomPaint`), `appearance_palette_test` (запрещает возврат декоративных фонов), `settings_registry_test` (запрещает `wallpaper_generator` в поиске), `settings_master_detail_test` (ожидает `SettingsWallpaperScreen`). Это не «поправить ожидания», а осознанная отмена решения от 23.10 — нужно согласие владельца продукта, иначе любой зелёный прогон достигается правкой стражей.

## 3. Вариант B — «удалить стек»

### 3.1 Точный список

Удалить целиком:
- `lib/widgets/wallpaper/chat_wallpaper_painter.dart` (727)
- `lib/widgets/wallpaper/material_symbols_data.dart` (8559)
- `lib/widgets/wallpaper/icon_sources_catalog.dart` (352)
- `lib/widgets/wallpaper/curated_wallpaper_catalog.dart` (213)
- `lib/widgets/wallpaper/cupertino_icons_data.dart` (206)
- `lib/widgets/wallpaper/wallpaper_image_cache.dart` (313)
- `lib/widgets/wallpaper/wallpaper_color_resolver.dart` (109)
- `lib/widgets/wallpaper/chat_wallpaper_background.dart` (10)
- `lib/features/wallpaper/` (5 файлов, 1024)
- `lib/screens/settings_wallpaper_screen.dart` (24)
- `lib/models/chat_wallpaper_config.dart` (489)
- `lib/providers/chat_wallpaper_provider.dart` (170)
- `lib/core/identity/nios_weave.dart` (267)
- `assets/svg/pattern_icons/` (290 файлов, 142 КБ) + 2 строки в `pubspec.yaml`
- тесты: `chat_wallpaper_painter_test.dart` (185), `chat_wallpaper_config_test.dart` (138), `wallpaper_slider_field_test.dart` (45), `nios_weave_test.dart` (87), `weave_size_test.dart` (60), wallpaper-часть `moments_test.dart` (48)

Правки в живых файлах:
- `lib/screens/chat_detail_screen.dart`: убрать import (`:40`), `hasCustomWallpaper` (`:2380-2385`) → `NiosChroma.shouldApply` без флага (или удалить ветку Chroma), `ChatWallpaperBackground` (`:2487-2489`) → `ColoredBox(color: AppSurfaces.of(context))` или `SizedBox.shrink()`.
- `lib/widgets/chat/chat_viewport.dart:61,72-73,150-152` — параметр `wallpaper` сделать необязательным/убрать.
- `lib/router/app_router.dart:59` (import), `:221` (redirect whitelist), `:390-407` (`/wallpaper` deep link), `:683-686` (route).
- `lib/screens/profile_screen.dart:746` — вход в студию.
- `lib/core/theme/nios_chroma.dart:20-26` — упростить `shouldApply` (останется один флаг `userChromaEnabled`).
- `lib/l10n/**` — ~60 ключей `wallpaper*` + `backgroundsPaused` (ru/en + secret generated).
- `settings_registry` — узел `appearance.wallpaper` (иначе поиск «обои» ведёт в никуда).
- Совместимость prefs: ключи `nios_global_wallpaper_v1*` / `nios_chat_wallpapers_map_v1*` останутся сиротами; добавить одноразовую очистку в миграцию.

### 3.2 Что останется
Ничего пользовательского: ни студии, ни строки в настройках, ни deep link, ни Chroma-исключения. `ChatWallpaperConfig` не остаётся — иначе остаётся мёртвая модель на 489 строк и импорт `material_ui`. Скрывать из UI придётся в 4 местах (router, profile, settings registry, l10n) — если удалять, то удалять и входы, иначе получим 404/пустой экран.

### 3.3 Что сломается и что править
- `test/widgets/settings_master_detail_test.dart:808-924` — 7 ожиданий `SettingsWallpaperScreen` (сейчас проверяет переход в правую панель).
- `test/unit/settings_registry_test.dart:154-169` — «search leads to the wallpaper entry in Chats».
- `test/widgets/neutral_inbox_test.dart` — продолжит проходить, но тест станет бессмысленным (ссылается на удалённый класс) → заменить на `ColoredBox`/`PulseScaffoldBody`.
- `test/widgets/appearance_palette_test.dart:341-379` — тоже опирается на отсутствие фонов; можно оставить, убрав `RawImage`-ожидание.
- `test/perf/chat_performance_benchmarks_test.dart:97-113` — группа «Wallpaper Image Cache Memory Budget» станет неактуальной (импорт `WallpaperImageCache`) → удалить группу.
- Прочее: `flutter analyze` выдаст висячие импорты в `pubspec`-ассетах, `l10n`-генераторе; нужен полный прогон `flutter gen-l10n` + `flutter test`.

### 3.4 Риски B
Главный — **удалили то, что хотят доделать**. Признаки реальные: фича была полностью рабочей 2 коммита назад, коммит `a43a2a19` (26.11) помечен «wip… incomplete», а `ChatWallpaperConfig`/провайдер специально оставлены «preferences stay stored». Удаление обратимо только через git ( painter + 8.5 тыс. строк сгенерированных codepoint'ов восстанавливаются из истории, но не переписываются заново), поэтому перед B нужен явный ответ владельца: «обои не вернём в этом цикле». Второй риск — полуудаление: убрать painter, но оставить студию и входы, — тогда пользователь платит за настройку, которая гарантированно ничего не делает (сегодняшнее состояние).

## 4. Сводная таблица

| Вариант | Цена | Риск | Что останется |
|---|---|---|---|
| **A. Дошить (с «off» по умолчанию)** | **15–21 ч** (наивный restore 4–6 ч — неприемлем) | Высокий: дефолт включает узор всем; 41 МБ на кадр при DPR 2 против 32 МБ бюджета; 4 стража-теста кодируют обратное решение; Chroma/контраст в dark | Полная фича: узор/фото/градиенты в чате, живое превью, Chroma отключается, студия честная |
| **A-lite. Только restore из git** | 4–6 ч | Очень высокий: визуальный регресс во всех чатах, красные тесты, нет состояния «выкл» | Узорные обои везде, студия без тумблера |
| **B. Удалить стек** | **10–15 ч** | Средний: потеря 13 тыс. строк и 290 ассетов, нужен явный «нет» от владельца; полуудаление хуже полного | Ничего пользовательского; Chroma всегда включена; минус 4 входа, ~60 l10n-ключей, 6 тестов |

## 5. Рекомендация

**B — удалить стек целиком (10–15 ч), но только после подтверждения, что обои не возвращаются в этом цикле.** Пауза от 23.10 — не забытый код, а закреплённое тестами продуктовое решение «neutral surfaces», и сейчас хуже всего именно половинчатое состояние: студия сохраняет настройки и обещает превью, которого нет; при этом восстановление из git включается «всем и сразу» и упирается в 32 МБ кэша и 41 МБ кадр. Если владелец допускает возврат фичи в ближайшие 1–2 итерации — тогда не B, а A за 15–21 ч с обязательным состоянием «обоев нет» по умолчанию; в промежутке вход в студию надо спрятать, чтобы не продавать мёртвую настройку.

# NiosMess — полный аудит модалок, popup UI, dead code и нейрослоя

# Результат аудита

Проверен Flutter-клиент на HEAD `fe0cc46` / `3.75.0+164`: модальные окна, bottom sheets, side sheets, context menus, date/time pickers, overlays, toast/snackbar-пути, glass-слой, AI-репозиторий и кандидаты на удаление. Код репозитория в рамках этого отчёта не изменялся — ниже готовый план фиксов для агента. [[1]](https://github.com/SH20FK/NiosMess/tree/main/pulse_flutter/lib)

## Короткий вердикт

Главная проблема не в отсутствии M3-компонентов, а в отсутствии единого владельца modal motion и surface-правил. В проекте уже есть `AppDialog`, `showAppConfirmDialog` и `AppBottomSheets`, но рядом продолжают жить прямые `showDialog`, `showModalBottomSheet`, `showGeneralDialog`, `Dialog`, `AlertDialog` и собственные прозрачные контейнеры. Из-за этого один и тот же сценарий выглядит по-разному на desktop, mobile и в разных фичах.

Самые заметные источники старого вида:

- `AlertDialog` в отчёте о баге и OTA-разрешении;
- прямые `Dialog` с локальными radius/elevation в создании чата, профиле, бейджах и списке чатов;
- `showGeneralDialog` для профиля с отдельной slide/elevation-системой;
- raw time/date pickers;
- `backgroundColor: Colors.transparent` в самодельных sheets;
- живой `BackdropFilter` в `AdaptiveGlass`;
- ручные Snackbar и строки на русском прямо в feature-коде;
- AI-слой, где одна операция одновременно называется `processText`, `streamRewriteText`, `ai_process_text`, `rewrite/stream`, а режимы имеют синонимы `correct` / `fix_errors` и `formalize` / `formal`.

## 1. Зафиксированный baseline

По исходникам найдено:

- 11 прямых вызовов `showDialog`;
- 5 прямых вызовов `showModalBottomSheet`;
- 2 вызова `showGeneralDialog`;
- 8 прямых конструкторов `Dialog`;
- 2 `AlertDialog`;
- 4 `showTimePicker` и 1 `showDatePicker`;
- 3 `MenuAnchor`;
- отдельный `BackdropFilter` в `AdaptiveGlass`.

Это не число всех всплывающих элементов: часть интерфейса открывается через обёртки и feature-helper'ы. Поэтому проблема системная — raw API нельзя просто заменить поиском по одному паттерну.

## 2. P0 — единая modal-архитектура

### Что сделать

Создать один публичный слой `AppModal` в `lib/core/modal/`:

- `AppModal.showDialog<T>` — desktop/широкий экран;
- `AppModal.showSheet<T>` — mobile bottom sheet;
- `AppModal.showSideSheet<T>` — desktop profile/chat-info panel;
- `AppModal.confirm` — destructive/normal confirmation;
- `AppModal.select` — выбор одного или нескольких значений;
- `AppModal.form` — формы с keyboard inset, validation и loading state.

Feature-код не должен напрямую вызывать `showDialog`, `showModalBottomSheet` или `showGeneralDialog`. Сырые Flutter API остаются только внутри `AppModal` и его тестов.

### Единый surface contract

`M3ModalSurface` должен принимать `ModalVariant`, `maxWidth`, `maxHeight`, `showDragHandle`, `isScrollable`, `tone` и `destructive`. Внутри:

- tonal surface из `surfaceContainerLow/High`, без прозрачного стекла по умолчанию;
- без `BoxShadow` с большим blur; глубина только цветом, scrim и границей;
- radius из `AppRadii`, не локальные 18/20/22/24/28 в каждом файле;
- один scrim, один enter/exit motion и поддержка `MediaQuery.disableAnimations`;
- стабильная layout strategy для `AnimatedSwitcher`, чтобы sheet не прыгала при смене состояния;
- keyboard insets и SafeArea обрабатываются в одном месте;
- standard focus/semantics/barrier label для доступности.

`AppBottomSheets` уже является хорошей точкой входа, но сейчас его поверхность создаётся через прозрачный route и локальный контейнер, а desktop-диалоги обходят этот контракт. Его надо превратить в часть нового `AppModal`, а не оставлять вторым параллельным API. [[2]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/core/utils/app_bottom_sheets.dart)

## 3. Полный разбор модалок и всплывающих UI

### P0 — переписать в первую очередь

#### `widgets/profile/working_hours_planner_dialog.dart`

Сейчас один feature сам решает, когда использовать `showDialog`, а когда raw `showModalBottomSheet`; внутри ещё четыре raw `showTimePicker`, прозрачный mobile surface, собственные radius и несколько hardcoded Snackbar. Это самый яркий пример раздвоенной modal-системы. [[3]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/profile/working_hours_planner_dialog.dart)

Фикс:

1. `WorkingHoursPlanner` оставить feature-widget'ом, а открытие передать в `AppModal.form`.
2. Для desktop/mobile использовать один контент и один state machine, меняя только presentation variant.
3. Заменить raw time picker на тематизированный M3 time surface или хотя бы на централизованный `AppTimePicker.show`.
4. Вынести дни, ошибки пересечения и timezone в l10n.
5. Ошибка валидации должна жить рядом с интервалом, а не приходить случайным Snackbar.
6. Убрать `isDialog` из самого виджета: виджет не должен знать, в каком route он находится.

#### `screens/settings_about_screen.dart` — `_BugReportDialog`

`AlertDialog` и ручная форма выглядят старее общего `AppDialog`; локально переопределяются shape и `OutlineInputBorder`. Контроллеры на текущем HEAD корректно disposed — это не баг, но сам modal должен переехать на `AppDialog.form`, использовать общие поля, loading indicator и l10n. [[4]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/screens/settings_about_screen.dart)

#### `providers/ota_update_provider.dart` — permission dialog

Прямой `AlertDialog`, hardcoded русский текст и локальная стилизация действий. Это инфраструктурная операция, но она выглядит как отдельное старое приложение. Перенести в `AppModal.confirm/info`, вынести строки в l10n и не держать UI-слой внутри provider. Provider должен вернуть состояние/команду, а dialog должен находиться в update feature presentation. [[5]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/providers/ota_update_provider.dart)

#### `widgets/profile/badge_selector_dialog.dart`

Raw `showDialog`, обычный `Dialog`, `Checkbox`, hardcoded ограничения и Snackbar. Для M3 Expressive это должен быть selection sheet/dialog: preview выбранных бейджей сверху, tonal choice rows, fixed action footer и состояние `loading/error/empty` без скачка высоты. [[6]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/profile/badge_selector_dialog.dart)

#### `widgets/chat_creation_surfaces.dart`

В одном файле сразу несколько способов открыть создание чата, desktop `Dialog` с `elevation: 10`, mobile sheet и ещё отдельный menu flow. Плюс подзаголовки частично hardcoded. Разделить:

- `ChatCreationModal` — контент и state;
- `ChatCreationLauncher` — выбор presentation variant;
- `AppModal.select` — group/channel/direct choice.

Не смешивать feature business flow, route orchestration и дизайн поверхности в одном root-файле. [[7]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat_creation_surfaces.dart)

#### `screens/chat_list_screen.dart` — desktop chat context menu

На широком экране используется прозрачный raw `Dialog`, на мобильном — `AppBottomSheets`. Один и тот же контекстный набор действий получает разную геометрию и motion. Нужен `ChatActionsModal` на `AppModal.select`, с destructive action в error tonal container и общей семантикой. [[8]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/screens/chat_list_screen.dart)

### P1 — привести к одной системе

#### `widgets/profile/responsive_profile_sheet.dart`

Два почти одинаковых `showGeneralDialog` для public/group profile, свой `Curves.easeOutCubic`, elevation 16, radius 24 и hardcoded barrier labels. Заменить на один generic `AppSideSheet<T>` с параметром `child`, шириной, title/semantic label и M3 shared-axis motion. Не дублировать public/group implementation. [[9]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/profile/responsive_profile_sheet.dart)

#### `screens/profile_screen.dart` — edit profile

Wide-flow использует прозрачный `Dialog`, mobile-flow — `AppBottomSheets`, birthday открывается raw `showDatePicker`. Перевести edit profile на `AppModal.form`; date picker завернуть в `AppDatePicker.show`, чтобы тема, locale и reduced motion были едиными. Убрать `isDialog` из `_EditProfileSheet`. [[10]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/screens/profile_screen.dart)

#### `screens/settings_appearance_screen.dart` — custom color picker

Raw `showModalBottomSheet` с transparent background. Перевести на `AppModal.showSheet`, а color picker сделать bounded content с единым drag handle, l10n и закрытием после apply. [[11]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/screens/settings_appearance_screen.dart)

#### `widgets/media_grid_picker.dart` — album selector

Свой bottom sheet, свой handle, свой radius и собственный background. Это надо сделать `AppModal.select` с reusable `ModalHeader`, чтобы media picker не был отдельным визуальным островом. [[12]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/media_grid_picker.dart)

#### `widgets/chat/e2ee_verification_sheet.dart`

Основной вход уже использует `AppBottomSheets`, это правильнее остальных, но внутренний QR-sheet повторяет header/handle вручную, содержит hardcoded русский текст и использует прямые белый/тёмный цвета. Оставить QR в security-flow только после полноценного verify pipeline; поверхность перевести на общую sheet-систему, строки — в l10n, QR container — через контрастную semantic surface. [[13]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat/e2ee_verification_sheet.dart)

#### `widgets/chat/sticker_set_modal.dart` и `add_sticker_dialog.dart`

Архитектурно они уже ближе к sheet-подходу, но названия `Modal`/`Dialog` описывают разные presentation semantics. Зафиксировать правило: имя feature-компонента описывает задачу (`StickerSetDetails`, `AddSticker`), а presentation задаёт `AppModal`. [[14]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat/sticker_set_modal.dart)

### P2 — не критично, но убрать визуальный шум

- `post_card.dart` уже использует `MenuAnchor`, это оставить; подтверждение удаления должно идти через `AppModal.confirm`, а не смешиваться с menu lifecycle. [[15]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/post_card.dart)
- `chat_detail_app_bar.dart` и `chat_members_screen.dart` используют `MenuAnchor`; вынести menu item model в единый `AppActionMenuItem`, чтобы destructive/disabled/semantic правила не размножались.
- `app_toast.dart` оставить единственным владельцем Snackbar/toast. Прямые `ScaffoldMessenger.of(context).showSnackBar` в feature-коде запретить. Технические подробности ошибки должны открываться через `AppDialog`, а не отдельный raw dialog. [[16]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/core/utils/app_toast.dart)
- `AppErrorSnackbar` либо подключить как единый global error presenter, либо удалить после миграции: параллельное существование wrapper-а и прямых SnackBar создаёт непредсказуемый UX.

## 4. Жидкое стекло и blur

### Что найдено

`AdaptiveGlass` на tier A реально запускает `BackdropFilter` с blur sigma до 10, а документация самого файла подаёт его как штатный glass-компонент. Это прямо конфликтует с текущей целью проекта: M3 Expressive tonal surfaces, предсказуемый raster и отсутствие blur в повторяющихся UI. [[17]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/adaptive/adaptive_glass.dart)

На текущем production-графе прямых вызовов `AdaptiveGlass` не найдено — его используют только тесты. Поэтому это не «сломанный обязательный путь», а мёртвый/опасный экспериментальный слой: либо удалить вместе с тестом, либо переименовать в `AdaptiveTonalSurface` и полностью убрать `BackdropFilter`.

Отдельные blur-эффекты также остаются в wallpaper/background-коде. Они допустимы только как заранее закэшированный декоративный фон, но не должны попадать под modal/list repaint path. [[18]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/wallpaper/chat_wallpaper_background.dart)

### Решение

- Запретить `BackdropFilter`, `ImageFilter.blur` и `MaskFilter.blur` в `lib/widgets/**` для modal/list/repeating UI.
- Модальные окна использовать на непрозрачной `surfaceContainerLow/High`.
- Для выразительности использовать tonal contrast, shape morph, icon morph, scrim и spring — не стекло.
- Если нужен premium accent, добавить статический `TonalHighlight` без live blur.

## 5. Dead files — что можно удалить

### Высокая уверенность после symbol/import-проверки

Следующие файлы не имеют production-использований по текущему графу и их публичные символы не вызываются из `lib`/тестов, кроме явно отмеченных случаев:

- `pulse_flutter/lib/core/exceptions/api_exception.dart` — неиспользуемый re-export; все рабочие импорты идут напрямую в `core/network/api_exception.dart`.
- `pulse_flutter/lib/core/motion/circular_reveal_transition.dart` — `CircularRevealClipper` и `CircularRevealTransition` не используются; актуальная theme-reveal механика находится отдельно.
- `pulse_flutter/lib/widgets/active_color_orb.dart` — orphan experimental widget.
- `pulse_flutter/lib/widgets/call_bubble.dart` — orphan widget.
- `pulse_flutter/lib/widgets/file_attachment_chip.dart` — orphan widget.
- `pulse_flutter/lib/widgets/file_upload_progress_widget.dart` — orphan widget.
- `pulse_flutter/lib/widgets/fluid_preview_card.dart` — orphan/experimental widget.
- `pulse_flutter/lib/widgets/gooey_segment.dart` — orphan experimental segment; оставить только если его реально подключат вместо текущего selector.
- `pulse_flutter/lib/widgets/m3_badge.dart` — неиспользуемый параллельный badge API; актуальные бейджи живут в `badge_chip.dart`, `nios_mark_badge.dart` и profile-моделях.
- `pulse_flutter/lib/widgets/pulse_page_header.dart` — orphan header, экраны используют другие scaffold/header-компоненты.

### Удалять только после миграции/проверки теста

- `pulse_flutter/lib/widgets/adaptive/adaptive_glass.dart` — production-использований нет, но есть `adaptive_glass_test.dart`; удалить файл и тест либо заменить тестом `AdaptiveTonalSurface`.
- `pulse_flutter/lib/providers/adaptive_performance_provider.dart` — это barrel/re-export для совместимости, не удалять вслепую; сначала перевести внешние импорты на `core/performance/adaptive_performance_provider.dart`, затем удалить alias.
- `pulse_flutter/lib/providers/token_provider.dart` — не dead: его используют auth/api/websocket-пути. Переименовать можно, удалять нельзя.

### Гигиена репозитория

Локальные audit-артефакты `modal_inventory.txt`, `modal_legacy.txt`, `dart_files.txt`, `perf_patterns.txt` не являются частью приложения. Их не нужно коммитить; после передачи отчёта удалить из рабочей копии.

## 6. Нейрослоп и naming drift

### AI text rewrite: один intent — четыре имени

Сейчас в `AiRepository` есть `streamRewriteText` и `processText`. Первый ходит в `/api/ai/rewrite/stream` и отправляет `mode`, второй — в WebSocket event `ai_process_text` и отправляет `action`. На уровне UI есть `_processTextWithAi`, а fallback вызывает другой метод. При этом `correct` и `fix_errors` сводятся к одному действию, как и `formalize` и `formal`. Это не гибкость, а рассинхрон контракта. [[19]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/repositories/ai_repository.dart)

### Канонический вариант

Создать:

```dart
enum AiAction { correct, rewriteFormal, translate, shorten, expand, summarize }

class AiRewriteRequest {
  const AiRewriteRequest({required this.text, required this.action, this.targetLanguage});

  final String text;
  final AiAction action;
  final String? targetLanguage;
}

Future<AiRewriteResult> rewriteText(AiRewriteRequest request)
```

Правила:

- в Dart, HTTP и WebSocket использовать один canonical id; например `rewrite_formal`, а не `formal`, `formalize` и `chatAiFormal`;
- transport fallback спрятать внутри `AiRepository.rewriteText`; UI не знает про SSE/WS;
- `mode` и `action` оставить только в adapter-слое, если backend ещё требует разные поля;
- язык хранить как `Locale`/ISO-код, не как свободный текст `English`/`english`/`en`;
- UI actions рендерить из одной таблицы `AiActionDescriptor`, а не создавать отдельный card вручную на каждую кнопку;
- `_processTextWithAi` переименовать в `_runAiRewrite` или полностью убрать, если use-case переедет в notifier.

### AI quota / tokens

`ApiAiUsage` сейчас вложен в `profile_model.dart`, а UI-виджет называется `AiUsageIndicatorCard`; это смешивает profile DTO, usage snapshot и quota presentation. Дополнительно в profile fallback зашито значение `remainingTokens: 200000`, что может показать пользователю фальшивный баланс при неполном ответе API. Это нужно заменить на `null/unknown` и явное состояние «лимит недоступен». [[20]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/models/api/profile_model.dart)

Предлагаемая структура:

- `models/api/ai_quota_model.dart` → `AiQuota`;
- `repositories/ai_repository.dart` → единственная точка rewrite/generation;
- `providers/ai_quota_provider.dart` → кэш/refresh quota;
- `widgets/ai/ai_quota_card.dart` → только presentation;
- `remainingTokens`, `limitTokens`, `usedTokens`, `resetsAt` — одна терминология во всём проекте;
- `authTokenProvider` переименовать в `sessionAccessTokenProvider`, чтобы его никогда не путали с AI tokens;
- форматирование чисел и дат отдать `intl`/l10n, убрать ручные списки месяцев и hardcoded `AI-токены`.

`AiUsageIndicatorCard` также использует обычный `LinearProgressIndicator`, хотя проектный protocol требует `AppLoadingIndicator` для loading UI. Для quota это вообще лучше заменить на статический `M3QuotaMeter`/tonal segmented meter, потому что это не процесс загрузки, а измерение остатка. [[21]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/profile/ai_usage_card.dart)

### Дублирование badge/identity naming

Разделить понятия и закрепить только эти имена:

- `ApiBadge` — серверный DTO;
- `ProfileBadge` — доменная модель;
- `BadgeChip` — компактное отображение;
- `BadgePickerSheet` — выбор;
- `NiosMarkBadge` — продуктовый verified mark;
- `StatusEmojiBadge` — статус/emoji, не профильный badge.

Не использовать `M3Badge` как ещё один общий badge-термин, если его реализация не подключена.

### E2EE naming drift

В типах и полях смешаны `E2ee...`, `E2EE`, `e2ee`, `secret chat` и `Double Ratchet`. Оставить:

- Dart types: `E2eeService`, `E2eeSession`, `E2eeStatus`;
- fields: `e2ee...`;
- product copy: «Секретный чат»;
- protocol copy: «сквозное шифрование (E2EE)»;
- backend wire names не менять без миграции.

### Modal naming drift

`BadgeSelectorDialog`, `StickerSetModal`, `AddStickerDialog`, `WorkingHoursPlannerDialog`, `responsive_profile_sheet` описывают presentation вместо feature intent и делают навигацию трудно читаемой. После введения `AppModal` имена должны быть `BadgePicker`, `StickerSetDetails`, `AddSticker`, `WorkingHoursPlanner`, `ProfilePanel`.

## 7. AI-интерфейс, который стоит прокачать после уборки

Не добавлять новые AI-фичи поверх текущего naming drift. Сначала один action model, затем:

1. `Исправить` — орфография, пунктуация, опечатки.
2. `Сделать короче` — с сохранением смысла.
3. `Раскрыть мысль` — увеличить ясность без выдумывания фактов.
4. `Тон` — дружелюбный, деловой, нейтральный.
5. `Перевести` — отдельный language picker, а не четыре hardcoded card.
6. `Суммировать` — для выделенного сообщения/треда.
7. `Ответить по контексту` — draft only, никогда не отправлять автоматически.
8. `Проверить факты` — только как web-assisted draft с явной маркировкой источников.

UI: один expressive bottom sheet с preview результата, diff/original toggle, cancel/replace/copy, quota meter и понятным streaming state. AI не должен превращать composer в ещё один набор разрозненных карточек.

## 8. Структурный план

### Предлагаемая раскладка

```
lib/
  core/
    modal/
      app_modal.dart
      m3_modal_surface.dart
      app_side_sheet.dart
      app_date_picker.dart
      app_time_picker.dart
    ai/
      ai_action.dart
      ai_rewrite_request.dart
  features/
    chat/presentation/modals/
    profile/presentation/modals/
    settings/presentation/modals/
    security/presentation/modals/
    ai/presentation/
  widgets/
    common/
      modal_header.dart
      modal_action_row.dart
      modal_loading_state.dart
```

Не обязательно делать большой multi-package rewrite сразу. Первый безопасный шаг — создать `core/modal`, перенести туда presentation helpers и мигрировать P0. Root `widgets/` постепенно очистить от feature-specific modal-кода.

### Защитные проверки

Добавить `tool/check_ui_architecture.dart`, который падает в CI, если production-код вне `core/modal` содержит:

- `showDialog`, `showModalBottomSheet`, `showGeneralDialog`;
- `AlertDialog` или прямой `Dialog`;
- `BackdropFilter`, `ImageFilter.blur`, `MaskFilter.blur`;
- hardcoded user-facing Russian/English strings;
- новые alias-методы для уже существующих AI actions.

И добавить тесты:

- один modal contract для desktop/mobile/reduced-motion;
- keyboard inset и rotation;
- destructive confirm;
- profile side sheet;
- badge picker empty/loading/error/success;
- AI action serialization equality между SSE и WebSocket adapters;
- quota unknown state без фальшивого остатка;
- snapshot test на отсутствие live glass в modal tree.

## 9. Порядок внедрения для агента

### P0 — сначала убрать кривизну

1. Ввести `AppModal`/`M3ModalSurface`.
2. Мигрировать `working_hours`, bug report, OTA permission, badge picker, chat creation и chat-list context menu.
3. Убрать raw transparent surfaces и raw AlertDialog.
4. Выключить/удалить live glass; оставить только tonal surface.
5. Запретить прямые Snackbar из feature-кода.

### P1 — зачистить структуру

1. Мигрировать profile side sheet, edit profile, appearance color picker, media album selector.
2. Объединить public/group profile side sheet в один generic component.
3. Вынести l10n и radius/motion tokens.
4. Удалить dead files из списка с высокой уверенностью.
5. Перевести `ApiAiUsage` в отдельную модель и убрать fake 200k fallback.

### P2 — AI и polish

1. Ввести `AiAction` и один `rewriteText`.
2. Объединить SSE/WS через transport adapter.
3. Переделать AI sheet в preview/diff/quota flow.
4. Добавить новые AI actions только через enum + descriptor table.
5. Добавить CI architecture check и modal golden tests.

## 10. Acceptance criteria

- В feature-коде нет прямых `showDialog/showModalBottomSheet/showGeneralDialog`.
- Нет `AlertDialog` и прозрачных локальных modal surfaces вне `core/modal`.
- Desktop/mobile используют один modal contract, а не две визуально разные реализации.
- В модалках нет live blur/glass по умолчанию.
- Все строки и barrier labels локализованы.
- Один AI intent имеет один enum id, один request model и один public method.
- SSE и WebSocket не расходятся по `mode/action` на уровне UI.
- AI quota не показывает выдуманный баланс.
- Dead files удалены после финальной проверки imports/tests.
- `flutter analyze`, `dart test` и CI architecture check проходят.

## Готовый brief агенту

> Сначала введи единый `AppModal`/`M3ModalSurface` и запрети raw `showDialog`, `showModalBottomSheet`, `showGeneralDialog`, `AlertDialog` вне `core/modal`. Перепиши P0: working hours, bug report, OTA permission, badge picker, chat creation и chat-list menu. Убери transparent Dialog и live `AdaptiveGlass`/BackdropFilter из modal-пути. Затем мигрируй profile side sheet, edit profile, color picker и album selector. Удали orphan-файлы только после symbol/import/test-проверки. В AI-слое оставь один `AiAction`, один `AiRewriteRequest` и один `AiRepository.rewriteText`; спрячь SSE/WS fallback в transport adapter, убери `mode/action` и `correct/fix_errors` drift. Перенеси quota в `AiQuota`, убери fake `200000` fallback и переделай AI sheet в preview/diff/quota flow.
> 

## Дополнительный аудит: chat surfaces, long press, stickers, emoji и edge fades

Проверил отдельным проходом сценарии долгого нажатия на чат и сообщение, sticker/emoji hub, открытие sticker pack по клику, composer, safe area, верхний и нижний край message list, header и общую композицию chat screen. Ниже — конкретные проблемы, включая один вероятный баг, из-за которого pack действительно иногда не открывается.

### 11. Долгое нажатие на чат

#### Текущая реализация

`ChatTile` вызывает `onLongPress`, а `chat_list_screen.dart` открывает `_showChatContextMenu`. На desktop используется raw `Dialog`, на mobile — `AppBottomSheets`; внутри меню вручную собраны три большие surface-группы: preview чата, «прочитать» и destructive «выйти». [[1]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/screens/chat_list_screen.dart) [[2]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat_tile.dart)

#### Что криво

- Desktop и mobile получают два разных modal-контракта и разный motion.
- Меню не знает origin-rect чата, поэтому на desktop не ощущается как действие над конкретным tile.
- В текущем caller `ChatTile.actions` не передаётся, поэтому `_isExpanded` внутри `ChatTile` практически мёртвый: long press меняет локальное состояние только если внешний caller передал actions.
- Состояние выбранного чата не связывается с открытым меню: tile не получает устойчивый pressed/selected state на время sheet.
- Доступны только mark-read и leave; меню выглядит большим для двух действий и одновременно слишком бедным функционально.
- Внутри много повторяющихся контейнеров с radius 28, borders и icon containers. Это не expressive hierarchy, а три независимые карточки.

#### Фикс

Создать `ChatActionsModal` с единым `ChatAction` model и результатом `ChatActionResult`: `markRead`, `mute`, `pin`, `archive`, `leave`, `cancel`.

- Mobile: bottom sheet с компактным chat preview, одной action-list и отдельной error-tonal destructive row.
- Desktop: anchored menu/side surface около origin-rect, с clamping к viewport; не центрированный dialog.
- При открытии tile получает `isActionTargeted: true`, но не меняет размер и не запускает второй expansion.
- Меню должно открываться и с long press, и с secondary click через один launcher.
- После выбора modal возвращает enum, а mutation выполняется в screen; callbacks и повторные `Navigator.pop` не размазываются по UI.

### 12. Долгое нажатие на конкретное сообщение

#### Текущая реализация

`_showMessageActions` открывает `AppBottomSheets`, но внутрь дополнительно помещает собственный `Container` с цветом `surface`, radius 28 и ручным `viewInsets` padding. Внутри `MessageContextMenuSheet` повторно строятся preview, reaction rail и две группы action tiles. [[3]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/screens/chat_detail_screen.dart) [[4]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/message_context_menu_sheet.dart)

#### Проблемы

- Получается двойная surface-обёртка: `AppBottomSheets` уже создаёт modal surface, а caller добавляет ещё одну. Из-за этого появляются лишний контраст, лишний radius и резкий отрыв sheet от края.
- В sheet нет origin message rect. На телефоне это допустимо, но на desktop/tablet контекст теряется.
- Preview, реакции и действия имеют одинаковый визуальный вес; пользователь не видит главного действия.
- Quick reactions используют `M3SpringCurves.bouncy` и Scale до 1.28. Для элемента, который тут же закрывает sheet, большая часть анимации обрезается и ощущается как дёрганье.
- Каждый action сам закрывает Navigator и вызывает callback. Это усложняет race с `TriSync`, реакциями и последующим открытием следующего picker.
- Для secret chat часть действий скрывается, но нет явного объяснения, почему forward недоступен.

#### Новый message action surface

Сделать `MessageActionsSurface` без собственной внешней `Container`: его сразу отдаёт `AppModal.showSheet`.

1. Сверху — компактный preview bubble с реальным цветовым alignment mine/peer.
2. Ниже — горизонтальный reaction rail: 5–6 emoji, scale максимум `0.96..1.0`, без overshoot.
3. Далее — primary actions: Reply, Copy, Forward, Edit, Comments.
4. Внизу — одна error-tonal зона Delete/Report.
5. На desktop — anchored surface около bubble; на mobile — bottom sheet.
6. Действие возвращает enum, а screen закрывает modal ровно один раз и выполняет side effect после результата.

Acceptance: long press не даёт двойного pop, не оставляет TriSync в неправильном состоянии и не открывает второй modal поверх ещё не закрытого первого.

### 13. Почему sticker pack иногда не открывается

#### Найденный вероятный баг в `StickerSetModal`

`StickerSetModal._fetchSetIfNeeded()` запускает fetch, если переданный `stickerSet` пустой. Но в `build()` текущий набор выбирается как `widget.stickerSet ?? _fetchedSet`. Если `widget.stickerSet` существует, но содержит пустой список stickers, загруженный `_fetchedSet` игнорируется. В результате sheet остаётся в empty/loading-подобном состоянии, хотя API уже вернул pack. [[5]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat/sticker_set_modal.dart)

Фикс выбора:

```dart
final ApiStickerSet? provided = widget.stickerSet;
final ApiStickerSet? currentSet =
    provided != null && provided.stickers.isNotEmpty
        ? provided
        : (_fetchedSet ?? provided);
```

Лучше ещё проще: после успешного fetch заменить локальный `resolvedSet`, а не вычислять precedence в `build()`. Добавить тест: empty provided set + successful fetch must render fetched stickers.

#### Второй источник no-op

В `chat_message_list.dart` клик по sticker сначала использует `message.resolvedStickerSetId`, затем ищет sticker только в локальном `stickerSetsProvider`. Если в сообщении нет `sticker_set_id`, pack не сохранён в локальной коллекции, а sticker id не найден в cache — callback заканчивается без modal и без ошибки. [[6]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat/chat_message_list.dart) [[7]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/models/api/message_model.dart)

Надёжный контракт:

- сервер всегда возвращает `sticker_set_id` вместе со sticker message;
- если его нет — клиент вызывает `getStickerSetForSticker(stickerId)`, а не пытается угадать pack только из local cache;
- при ошибке показывается `AppToast.showError`, а не тихий no-op;
- `StickerSetModal.show` получает либо полный `ApiStickerSet`, либо обязательный `setId`, но не невалидный полуобъект;
- после fetch pack добавляется в memory cache/provider, чтобы второй клик был мгновенным.

`StickerRepository.getStickerSet` уже умеет загружать pack по set id, но нужен fallback-контракт по sticker id, если backend не гарантирует metadata. [[8]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/repositories/sticker_repository.dart)

#### UX-правило клика

Сейчас в picker одиночный tap по sticker отправляет его, long press открывает pack, а в переписке tap открывает pack. Это допустимо, но визуально никак не объяснено. Зафиксировать: picker = tap send, long press/info = pack details; sent sticker in chat = tap opens pack, double tap = reaction, long press = message actions. Добавить tooltip/semantics и не смешивать эти три контекста.

### 14. Sticker picker: функциональный и визуальный ревью

#### Состояние pack

`StickerPickerView` хранит `_selectedSetIndex`, а не id набора. При refresh/reorder списков выбранный index может начать указывать на другой pack. Перевести на `int? _selectedSetId` и восстанавливать его после обновления списка. [[9]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat/sticker_picker_view.dart)

#### Loading/error

`StickerSetModal` после fetch exception только пишет `debugPrint` и продолжает показывать общий empty state. Нужны три разные фазы: loading skeleton, loaded empty и load error с retry. Иначе пользователь видит «пустой набор» вместо понятной проблемы сети.

#### Дизайн

- Pack dock снизу сейчас использует `boxShadow`, alpha surfaces и отдельные radius; заменить active state на expressive tonal pill/shape morph без тени.
- Header pack и dock повторяют информацию о наборе и две кнопки Add/Info. Оставить один compact header, а add/info отправить в overflow.
- Grid tile слишком активно реагирует: `AnimatedScale` с bouncy curve и border flash. Использовать короткий press scale `0.96`, tonal highlight и один shared controller.
- `Add` tile должен быть последним action chip, а не притворяться обычным sticker.
- Добавить recent/favorites и «недавно использованные» в начало dock, чтобы pack rail не превращался в горизонтальный список без контекста.
- Все строки `Добавить`, `Создать стикерпак`, `О стикерпаке`, `Повторить` вынести в l10n.

### 15. Emoji + sticker hub в composer

`ChatInputBar` рендерит `EmojiPicker` и `StickerPickerView` одновременно внутри `PageView`. Это удобно для swipe, но обе тяжёлые ветки живут рядом, а `effectivePanelHeight` вручную вычисляется из keyboard inset и cached height 260–440. На разных устройствах это может давать скачок, пустую область или резкий resize. [[10]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat/chat_input_bar.dart)

Фикс:

- заменить ручную формулу `cachedKeyboardHeight - bottomInset` на measured panel constraint через `LayoutBuilder`;
- держать одну активную страницу через `IndexedStack` + `TickerMode`, либо lazy PageView с keep-alive;
- анимировать только panel size и indicator, не весь grid;
- использовать один `M3SegmentedPickerTabs` для Emoji/Stickers;
- backspace показывать только на Emoji tab; на Stickers использовать search/pack action;
- search state и selected pack сохранять при переключении, но отключать ticker inactive page;
- hardcoded labels и tooltip вынести в l10n.

#### Emoji search

`M3EmojiSearchView` последовательно запускает поиск по каждому словарному термину и не имеет query generation/cancellation. Быстрый ввод может вернуть устаревшие результаты позже новых. Перевести поиск на `Future.wait`, дедупликацию в одном месте и `requestId`, который отбрасывает старые ответы. Словарь вынести из widget-файла в `emoji_search_dictionary.dart`, чтобы UI не был забит огромным data blob. [[11]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat/m3_emoji_search_view.dart)

### 16. Composer и нижнее затухание сообщений

Сейчас `ChatDetailInputArea` оборачивает composer в `SafeArea(top: false)` и `RepaintBoundary`, а message list живёт выше в отдельном `Expanded`. `PulseScaffoldBody` запускается с `bottomSafe: false`. Между последней строкой сообщения и surface composer нет gradient buffer, поэтому текст резко обрезается краем input area. [[12]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat/chat_detail_input_area.dart) [[3]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/screens/chat_detail_screen.dart)

#### Предлагаемый `ChatMessageEdgeFade`

Внутри stack message viewport:

```
Stack
  message list
  top fade:    header surface -> transparent
  bottom fade: transparent -> composer surface
  scroll-to-bottom FAB
```

Параметры:

- top fade 36–52 dp под header/secret banner;
- bottom fade 48–72 dp над composer;
- только `DecoratedBox`/`LinearGradient`, без blur и save layer;
- `IgnorePointer`, чтобы fade не ломал scrolling и taps;
- цвет брать из текущего tonal surface, а не из `Colors.white/black`;
- внизу добавить `padding` message list на высоту fade, чтобы последняя строка полностью проходила через затухание;
- при появлении клавиатуры и emoji panel fade должен оставаться привязан к верхней границе composer, а не к экрану.

Важно: не накрывать fade-градиентом сам composer. Он должен иметь чёткую foreground surface, а затухание — принадлежать message viewport.

### 17. Верхнее затухание и header

`ChatDetailAppBar` сейчас имеет почти непрозрачный `surfaceContainerLow.withValues(alpha: 0.92)`, а message body начинается резко сразу под toolbar. Титульная зона также содержит много маленьких secondary marks: status emoji, verified icon, auto-delete chip, secret icon и overflow. [[13]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/widgets/chat/chat_detail_app_bar.dart)

Фикс:

- оставить header surface стабильным, но добавить под ним `ChatHeaderFade` высотой 28–40 dp, который растворяет wallpaper/body в цвет header;
- не делать header прозрачным glass; используем tonal fade;
- на narrow width сворачивать auto-delete и verified в один status chip/overflow, чтобы title не сжимался;
- secret status показывать единым `E2eeStatusChip`, а не отдельной security icon + full-width banner;
- header title/status block должен иметь один tap target профиля, а call/security/overflow — отдельные action targets;
- motion при изменении typingSubtitle — cross-fade/AnimatedSize только внутри subtitle, не перестраивать весь AppBar.

### 18. Остальные кривые места внутри chat screen

#### Blank body во время route transition

В `ChatDetailScreen` всё ещё остаётся ветка `_isTransitionActive`, которая заменяет body на пустой `ColoredBox`. Это тот самый резкий flash, который уже был найден в предыдущем отчёте: header виден, body исчезает, затем message list появляется отдельным скачком. Убрать blanking и анимировать уже существующий destination subtree. [[3]](https://github.com/SH20FK/NiosMess/blob/main/pulse_flutter/lib/screens/chat_detail_screen.dart)

#### Secret banner

Secret banner всё ещё является full-width цветной полосой. Перевести его в компактную `E2eeStatusCard` с tonal surface, status icon, кратким состоянием и action `Проверить/Подробнее`. Он должен участвовать в top fade-layout, а не внезапно вставлять новый ряд между offline banner и loading indicator.

#### Loading older messages

`AnimatedSize` добавляет/убирает элемент сверху списка и может сдвигать scroll offset. Лучше держать индикатор внутри top fade overlay или в фиксированном sliver slot, чтобы загрузка старых сообщений не меняла геометрию уже видимых bubble.

#### Error/empty states

Empty secret chat, normal empty chat и reconnect error используют разные icon/surface patterns. Свести их к `ChatStateSurface` с вариантами `empty`, `secret`, `offline`, `error`; отличаться должны только icon, copy и action.

#### Общая surface discipline

Внутри chat screen одновременно используются wallpaper, semi-transparent header, full-width secret banner, message bubbles, nested modal surfaces, composer surface и emoji panel. Нужна явная иерархия: wallpaper → body tonal veil → message bubbles → edge fade → composer. Не добавлять ещё один alpha-container поверх каждой зоны.

## 19. Порядок внедрения

### P0

1. Исправить `StickerSetModal` precedence: fetched non-empty pack не должен теряться из-за пустого provided set.
2. Убрать no-op при отсутствии `sticker_set_id`: добавить backend metadata или `getStickerSetForSticker`.
3. Убрать двойную surface-обёртку message long-press sheet.
4. Добавить `ChatMessageEdgeFade` сверху и снизу message viewport.
5. Убрать blank body через `_isTransitionActive`.

### P1

1. Унифицировать `ChatActionsModal` для long press/secondary click.
2. Унифицировать `MessageActionsSurface` и вернуть enum result вместо callback soup.
3. Перевести selected pack с index на stable id.
4. Добавить loading/error/retry states для pack fetch.
5. Перевести picker на measured panel height и lazy inactive page.
6. Добавить `ChatHeaderFade` и `E2eeStatusChip`.

### P2

1. Переделать emoji search с request cancellation.
2. Добавить recent/favorites sticker rail.
3. Объединить ChatStateSurface для empty/offline/error/secret.
4. Вынести все sticker/emoji strings в l10n.
5. Убрать лишние shadows, alpha layers и bouncy overshoots.

## 20. Acceptance criteria

- Long press chat и secondary click используют один action model и один design contract.
- Long press message не создаёт двойной surface, двойной pop или race с reaction picker.
- Tap по отправленному sticker всегда открывает его pack, если metadata доступна; при недоступности пользователь получает понятную ошибку.
- Empty provided pack + successful fetch всегда показывает fetched stickers.
- Picker не переключается на другой pack после refresh/reorder.
- Emoji/sticker panel не даёт пустого resize при открытии keyboard и не держит две тяжёлые активные страницы.
- Последнее сообщение мягко растворяется в composer через 48–72 dp gradient, без blur.
- Верхняя часть списка мягко растворяется под header, без резкого clipping.
- Secret banner, loading, empty и error states принадлежат одной chat surface system.
- Нет blank body flash при открытии чата.
- Все новые строки локализованы, а `flutter analyze` и widget tests проходят.

## Готовый follow-up brief агенту

> Проверь chat long press и sticker flow до полировки. В `StickerSetModal` исправь precedence пустого `widget.stickerSet` над `_fetchedSet`; добавь тест на successful fetch. В `chat_message_list.dart` убери тихий no-op, когда у message нет `sticker_set_id`: сервер должен присылать set id, иначе нужен fallback lookup по sticker id. Для long press message убери дополнительный Container внутри `AppBottomSheets`, сделай один `MessageActionsSurface` с preview/reactions/actions и enum result. Для long press chat объедини desktop/mobile в `ChatActionsModal`, привяжи desktop к origin rect и убери мёртвый `_isExpanded`. В composer добавь `ChatMessageEdgeFade` сверху/снизу message viewport: 36–52 dp сверху, 48–72 dp снизу, только tonal LinearGradient без blur. Header сделай стабильным tonal surface с `ChatHeaderFade`, secret status объедини в `E2eeStatusChip`. В picker замени selected index на pack id, добавь loading/error/retry и lazy emoji/sticker page. В emoji search добавь request cancellation, чтобы старые результаты не приезжали поверх новых.
> 

## Статус

Это обширный технический аудит и готовый план изменений для передачи агенту. Исходный код репозитория не изменялся.
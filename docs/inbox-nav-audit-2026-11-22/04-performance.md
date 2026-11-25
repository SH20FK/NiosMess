# Аудит производительности рендеринга и состояния: инбокс + оболочка (2026-11-22)

> Режим: только чтение. Ничего в `pulse_flutter/` не менялось, `flutter pub get` не запускался.
> Каждое утверждение привязано к `файл:строка` из реально прочитанного кода.
> Метка **«доказано кодом»** = видно из исходников без запуска. Метка **«подозрение, нужен DevTools»** = следует из кода, но итоговый эффект зависит от данных/устройства.

---

## 0. Что прочитано

Полностью: `lib/screens/chat_list_screen.dart`, `lib/widgets/chat_tile.dart`, `lib/widgets/chat/chat_list_header.dart`, `chat_filter_bar.dart`, `inbox_compose_button.dart`, `m3_speed_dial_fab.dart`, `swipe_action_row.dart`, `reorder_slide.dart`, `lib/widgets/pulse_avatar.dart`, `pulse_skeleton.dart`, `common/touch_container.dart`, `chat/custom_emoji_text.dart`, `chat/custom_emoji.dart`, `screens/main_shell_screen.dart`, `widgets/app_bottom_nav.dart`, `widgets/nav/m3_route_tab_switcher.dart`, `providers/backend_chat_provider.dart` (ключевые участки 1–1190 + карта функций), `providers/chat_productivity_provider.dart`, `providers/chat_filter_provider.dart`, `providers/chat_muted_provider.dart`, `providers/typing_provider.dart`, `providers/chat_list_fab_provider.dart`, `core/utils/draft_storage.dart`, `providers/encrypted_draft_sync_provider.dart`, `core/storage/cache_service.dart` (участок чтения кэша), `core/utils/message_preview_text.dart`, `core/identity/nios_mark.dart`, `core/utils/datetime_helpers.dart`, `models/api/chat_summary_model.dart`, `models/chat_productivity.dart`, `models/interactive_message.dart` + `live_location.dart` (`parse`), `core/performance/adaptive_performance_provider.dart`, `main.dart` (bootstrap + сборка темы), `router/app_router.dart` (ветка `/main/:tab`).

Гварды: `test/perf/ui_smoothness_regression_guard_test.dart`, `test/perf/ui_smoothness_benchmark_test.dart`, `integration_test/performance_test.dart`.

Фон: `docs/motion-audit-2026-11-21/03-chats.md`, `05-cross-cutting.md`. Проверял утверждения по текущему коду: часть уже исправлена (Dismissible → `SwipeActionRow`, `Colors.white` в `ShaderMask` → `scheme.surface`, `indexWhere` в `findChildIndexCallback` → карта), часть осталась (Opacity вокруг страницы таба, Opacity на аватаре, 3 `Opacity` в точках «печатает»).

Также сверился с SDK Flutter (`F:\Flutter\flutter`): `SliverChildBuilderDelegate.shouldRebuild` (`scroll_delegate.dart:579`), `RenderOffstage.performLayout` (`proxy_box.dart:3919-3925`), childless `RenderSliverPadding` (`rendering/sliver_padding.dart:117-127`), дефолтный `updateShouldNotify` для `Provider` в Riverpod (`provider/base.dart:349-351`, локальная копия 2.6.1 — семантика та же).

---

## 1. Карта перестроений

| Виджет | Что `watch` | `select` | Что перестраивает |
|---|---|---|---|
| `ChatListScreen` (:143-164) | `visibleChatsProvider` (:151), `chatFilterProvider` (:154), `uiSettingsProvider`, `authProvider.isAuthenticated`, `clientCapabilitiesProvider`, `desktopSelectedChatProvider`, `chatListFabVisibleProvider` (:164), `encryptedDraftSyncProvider` (:144) | да, кроме `visibleChatsProvider`, `chatFilterProvider`, `clientCapabilities`, `desktopSelectedChat` | любое новое сообщение (даже в закрытом чате), presence, изменение unread, read-receipt, **скролл** (показ/скрытие FAB), смена фильтра/папки, resize, смена объекта E2EE-синка |
| `_buildChatItemsSlivers` (:358-359) | `chatFoldersProvider`, `selectedChatFolderProvider` | нет | то же (watch внутри метода, вызываемого из `build`) |
| `ChatListHeader` (:73-79) | `chatListScrolledProvider`, `authProvider.select(profile)`, `authProvider.select(displayName)` | да | скролл за 8 dp, смена профиля |
| `ChatFilterBar` (:41-56) | `chatFilterProvider`, `chatFoldersProvider`, `selectedChatFolderProvider`, `chatsProvider` **и** `chatMuteHubProvider` — только если есть папки | нет | любое новое сообщение/presence/unread, если настроены папки |
| `Consumer` строки (:431-540) | `typingProvider(id).select(isNotEmpty)`, `liveDraftMapProvider.select(map[id])`, `secretChatRevisionProvider` (только secret), `uiSettingsProvider.select(haptics)`, `chatMutedProvider(id)`; `ref.read(authProvider)` ×2 (:477, :510) | да (кроме `chatMutedProvider` и secret-revision) | набирает текст в этом чате, черновик этого чата, mute этого чата, haptics |
| `ChatTile` (`chat_tile.dart:177-406`) | ничего из Riverpod; `Theme.of`, `MediaQuery.textScalerOf`, `LayoutBuilder`×2 | — | hover/selected/unread/title/subtitle/time |
| `PulseAvatar` (`pulse_avatar.dart:95`) | `authProvider.select(session.userId)` — только для authenticated-media URL | да | смена аккаунта |
| `_AnimatedBadge` (`chat_tile.dart:718-772`) | — | — | смена count/isMuted |
| `_TypingDots` (`chat_tile.dart:777-877`) | `TickerMode.valuesOf`, `context.reduceMotion` | — | включение/выключение таба (TickerMode) |
| `InboxComposeButton` (:16) / `_InboxComposerScrim` (`main_shell_screen.dart:817`) | `chatListFabVisibleProvider` | нет | скролл (FAB) |
| `AppBottomNav` (`app_bottom_nav.dart:51-52`) | `totalUnreadCountProvider` (**int**), `adaptivePerformanceProvider.select(tier)` | да | изменение суммарного unread, смена tier |

Ключевое: **в строке нет watch целого списка или целого объекта состояния**. Всё, что строка слушает, — family-провайдеры по `chat.id` или `select` до скаляра. Целый список слушает только сам экран (`visibleChatsProvider`, :151) и `ChatFilterBar` (`chatsProvider`, :51-53). Это правильная схема, но именно она делает экран единственной точкой лавины (см. находку F1).

Тик «печатает», черновик, mute, скролл — строку не перестраивают. Это проверено по коду: `typingProvider(id).select((s) => s.typingUserIds.isNotEmpty)` (:435-439), `liveDraftMapProvider.select((v) => v.value?[chat.id])` (:449-453).

---

## 2. Механика списка

* Контейнер: один `CustomScrollView` (`chat_list_screen.dart:189-224`) со слivers: adapter (SizedBox + `RepaintBoundary(ChatFilterBar)` :199), `const SliverToBoxAdapter(child: OrdinaryE2eeNotice())` (:204 — const, при перестройке экрана не перестраивается), список чатов, и завершающий **пустой** `SliverPadding` (:213-222).
  * Пустой `SliverPadding` действительно резервирует место: `RenderSliverEdgeInsetsPadding.performLayout` при `child == null` ставит `scrollExtent = mainAxisPadding` (SDK `rendering/sliver_padding.dart:117-127`). Не баг.
* Список: `SliverPadding(horizontal: 8)` + `SliverList` + `SliverChildBuilderDelegate` (:408-411). **Нет `itemExtent`, нет `prototypeItem`** — и это осознанно: `ChatTile.rowHeight = 76` / `compactRowHeight = 64` (`chat_tile.dart:92-93`) используются только для расчёта вертикального паддинга (:187-189), а фактическая высота строки задаётся содержимым `Column` и растёт с text scale. При 200% масштабе строка выше 76 → `itemExtent` применять нельзя.
* Ключи: внешний `ValueKey<int>(chat.id)` на `RepaintBoundary` (:545), внутренний `ValueKey<String>('chat_${chat.id}')` на `SwipeActionRow` (:415).
* `findChildIndexCallback` (:564-568) — O(1) по `idToIndex` (:402-404). Карта строится **на каждой сборке экрана** (O(n)), не кэшируется между сборками. Для 1000 чатов это ~1000 вставок в `Map` на каждое новое сообщение/presence.
* `addAutomaticKeepAlives: false`, `addRepaintBoundaries: false` (:562-563) + один ручной `RepaintBoundary` на строку (:544). Правильно: keep-alive не держит ушедшие строки, а граница одна и предсказуемая.
* `cacheExtent` не задан → дефолт (250 px, ~3-4 строки за вьюпортом). Для 78 dp строк это нормально; менять без профилирования не стоит.
* Перестановка при новом сообщении: провайдер делает полную сортировку `updated.sort(compareChatRecency)` (`backend_chat_provider.dart:768`) → новый порядок → `SliverList` перестраивает живые строки → у каждой сдвинувшейся строки `ReorderSlide.didUpdateWidget` (`reorder_slide.dart:48-67`) стартует пружину `moved * (height + gap)` до 0. То есть при прыжке чата наверх **все строки между** едут на одну позицию — по одному `SingleMotionController` (motor) на строку.
  * Стоимость: N одновременных тикеров (только `Transform.translate`, `AnimatedBuilder(child:)` — дерево не перестраивается), но `Transform` находится **внутри** `RepaintBoundary` (:544 снаружи, `reorder_slide.dart:77-83` внутри) → каждый кадр пере-растеризуется вся строка, а не только сдвигается готовый слой.
* `scope: (filter, selected)` (:555) — при смене фильтра/папки строки переставляются без анимации (сброс значения контроллера, `reorder_slide.dart:50-54`). Правильно.
* Свайп «Прочитано» — `SwipeActionRow` (`swipe_action_row.dart:91-134`), `enabled: chat.unreadCount > 0` (:416). Фон рендерится только при `extent > 0.5` (:108), drag идёт 1:1, отпускание — `springTo(0, velocity:)` (:82-88). Хорошо.

---

## 3. Стоимость одной строки

Дерево (сверху вниз): `RepaintBoundary > Padding > ReorderSlide > AnimatedBuilder > Transform > SwipeActionRow > GestureDetector > AnimatedBuilder > Stack > Consumer > ChatTile > MouseRegion > Semantics > TouchContainer > GestureDetector > M3PressScale(AnimatedScale) > AnimatedContainer > ValueListenableBuilder > AnimatedContainer > Stack > Padding > Row > Stack(avatar) / Expanded > Column > [LayoutBuilder > Row > … , LayoutBuilder > Row > …]`. Порядка 30+ элементов плюс аватар: `Stack > Hero > Opacity > PulseAvatar(ConsumerWidget) > Semantics > SizedBox > ClipOval > CachedNetworkImage`.

Текст: до 5 `RenderParagraph` на строку — title (`CustomEmojiText` → `Text.rich`), preview (`CustomEmojiText`), время/статус (`Text`), счётчик (`Text`), метка «Черновик» (`Text`). Каждый `Text.rich` строит `TextSpan` из `customEmojiSpans(...)` — прогон регулярки `customEmojiPattern.allMatches` по строке на каждую сборку строки (`custom_emoji.dart:88-117`, `custom_emoji_text.dart:179-190`).

Клипы/слои на строку:
* `ClipOval` вокруг аватара (`pulse_avatar.dart:65, 89`) — дефолтный `Clip.antiAlias`, то есть AA-клип (в Skia требует слоя маски) при каждой перерисовке аватара.
* `Opacity(opacity: widget.isMuted ? 0.9 : 1)` (`chat_tile.dart:307-310`) — у приглушённого чата это **не** 1.0, а значит постоянный save-layer на аватар при любой перерисовке строки.
* `Opacity` ×3 в `_TypingDots` (`chat_tile.dart:853-857`) — анимируются 60 раз/с.
* `AnimatedOpacity` индикатора выбора (`chat_tile.dart:381-395`) — в покое 0/1, слоя нет.
* `Stack(clipBehavior: Clip.none)` (`chat_tile.dart:274`), `TouchContainer(clipBehavior: Clip.none)` (дефолт, `touch_container.dart:29`) — правильно, save-layer нет. `ClipRRect`/`Clip.antiAlias` в строке отсутствуют.

Аватары: `CachedNetworkImage(memCacheWidth: 96, memCacheHeight: 96)` (`pulse_avatar.dart:99-100`) — декод в 96 px, полноразмерный файл в память не попадает. На 3x это мягковато визуально (48dp = 144 px), но по памяти правильно. `NiosMark.resolveColor` кэширован (`nios_mark.dart:95-113`), HCT не пересчитывается.

Кастомные эмодзи в превью: `CustomEmojiInline` → `CustomEmojiImage` (`custom_emoji.dart:22-59`) — это либо `SvgPicture.network` (вектор растеризуется на CPU, кэш по URL), либо `StickerVideoPlayer` (видео!). Видео-аватары (`pulse_avatar.dart:61-71`) идут через общий пул `AnimatedMediaControllerPool` с бюджетом и отключением на быстром скролле (`bubble_sticker_player.dart:32, 97, 117, 161`). Сам механизм хороший, но каждый такой аватар/эмодзи в списке — кандидат в очередь пула и в декодер.

Таймеры/тикеры на строку: 2 `SingleMotionController` (motor) — `SwipeActionRow` (`swipe_action_row.dart:47-51`) и `ReorderSlide` (`reorder_slide.dart:41-45`); до 4 неявных `AnimationController` (`AnimatedContainer`, `AnimatedScale`, `AnimatedDefaultTextStyle`, `AnimatedOpacity`) + `_AnimatedBadge` + `_TypingDots`. В покое тикеры не крутятся (неявные анимации запускаются только при смене цели), но 12 видимых строк ≈ 60+ контроллеров живут в памяти, и `forEachTween` прогоняется на каждой перестройке строки.

`LayoutBuilder` ×2 на строку (`chat_tile.dart:421-483` для слота времени и `:572-664` для превью) — два layout-прохода на строку, из-за которых поддерево нельзя кэшировать по constraints.

---

## 4. Стоимость оболочки

* Смена таба: `_onTapTab` (`main_shell_screen.dart:353-376`) делает `setState` (активация таба) + `context.go('/main/$targetTab')`. Роут один и тот же `/main/:tab` с постоянным ключом `main-shell` на нативе (`app_router.dart:264-266`), `_page` = `MaterialPage` (`app_router.dart:68-70`) → страница не пересоздаётся, анимации перехода страницы нет. Затем `didUpdateWidget` (`:304-318`) ещё раз `setState`.
* Что перестраивается при `setState` оболочки: `pages` создаются заново (`:474-567`) — `_InboxPane` (новый инстанс, но внутри `const ChatListScreen()` — `:787`, поэтому сам экран инбокса не перестраивается), `Center/ConstrainedBox` вокруг `const NiosgramScreen()` (обёртки новые, ребёнок тот же), и **`ProfileScreen(...)` без `const`** (`:560-566`) — перестраивается всегда. Плюс весь `M3RouteTabSwitcher` с новыми `children`.
* Скрытые табы **не тикают**: `TickerMode(enabled: isActive)` в оболочке (`:607-614`) и второй `TickerMode(enabled: i == widget.index && _phase == idle)` в свитчере (`m3_route_tab_switcher.dart:202-203`). Проверено: `TickerMode` вложенный и складывается по И.
* Скрытые табы **живут в дереве и раскладываются**: `Offstage` (m3_route_tab_switcher.dart:199-201) при `offstage: true` всё равно вызывает `child.layout(constraints)` (SDK `proxy_box.dart:3919-3925`), а `paint`/`hitTest`/`semantics` пропускает. Значит push, пришедший пока пользователь на «NiosGram», перестраивает и **раскладывает** и скрытый инбокс.
* `LayoutBuilder` + `setState` в оболочке (`:449-664`): при drag разделителя (`:486-501`) каждый `onDragUpdate` → `setState` → перестройка всего тела `LayoutBuilder`: новые `pages`, новый `ProfileScreen`, новые обёртки свитчера, новый `SizedBox(width: …)` → новые constraints для списка → **перераскладка всего `CustomScrollView`** на каждый пиксель перетаскивания. Только широкий режим.
* Разделитель `_DraggableSidebarDivider` (`:846-894`) сам по себе дешёвый: `setState` только на enter/exit/start/end, ширина 8dp, `AnimatedContainer` 150 мс (не токен).
* Навбар: обёрнут в `RepaintBoundary` (`:647-655`), слушает только `int` из `totalUnreadCountProvider` + tier. `Provider` в Riverpod уведомляет через `previous != next` (SDK `provider/base.dart:349-351`), значит presence-пуш не перестраивает навбар, если сумма не изменилась. Внутри `Theme.of(context).copyWith(...)` создаёт новую `ThemeData` на каждую сборку навбара (`app_bottom_nav.dart:86-111`) — заметно только при редких перестройках.
* `M3RouteTabSwitcher` во время перехода: `AnimatedBuilder` перестраивает `Stack` каждый кадр (дети — те же инстансы, поэтому поддерево таба не перестраивается), но **`Opacity` вокруг всей страницы** (`:210-212`) при `0 < value < 1` даёт полноэкранный save-layer на растровом потоке. Уходящая страница: fade 1→0 + `Transform`. Приходящая — после свопа ещё fade 0→1. Итого ~300 мс полноэкранного offscreen-композитинга на переход.
* Тема: `themeAnimationDuration: M3Durations.long2` (500 мс, `main.dart:380-389`). На смену темы (или dynamic color) `AnimatedTheme` 30 кадров перестраивает всех, кто читает `Theme.of`, — включая весь инбокс и навбар.
* Прогрев табов: `_scheduleTabWarmup` (`:172-188`) через 400 мс активирует по одному «спящему» табу через `setState`, каждый раз перестраивая оболочку и собирая новую страницу. Это осознанный обмен холодного старта на мгновенное переключение.

---

## 5. Сортировка, фильтрация, поиск

* Сортировка — в провайдере, UI-изолят: `updated.sort(compareChatRecency)` на каждое новое сообщение (`backend_chat_provider.dart:768`), в `_adoptSnapshot` (`:863`) и в `upsertChat` (`:1036`). Компаратор: `lastActivity` → `lastMessage.id` → `id` (`chat_summary_model.dart:24-31`). Для 1000 чатов ~10k сравнений на сообщение; закреплённых чатов компаратор не знает, поэтому «наверх» = полная пересортировка.
* `visibleChatsProvider` (`chat_productivity_provider.dart:410-437`) — `Provider`, пересобирает список при каждом изменении `chatsProvider`: проходит всех, собирает `Map<int, List>` топиков, для каждого корня делает `copyWith` (новый объект) и пересчитывает unread. O(n), без мемоизации, без `select`.
* Фильтрация — в `build`, не в провайдере: `_applyFilter` (:112-140) + `folder.includes` (:363) + `List.of(...)` (:361) + карта `idToIndex` (:402-404). Всё O(n) на каждую сборку экрана.
* `folder.includes` — `chatIds.contains(chat.id)` по `List<int>` (`models/chat_productivity.dart:37-41`), то есть O(k) на чат. В `_folderUnread` (`chat_filter_bar.dart:223-236`) это O(папки × чаты × chatIds) на каждую сборку полосы фильтров.
* Поиск — отдельный экран (`features/chats/presentation/inbox_search_screen.dart`), debounce 220 мс (:87), запрос на сервер (`searchRepositoryProvider`, :94), локальный префильтр по всем чатам в `build` (:150-158). `query.toLowerCase()` вызывается **внутри** `where` для каждого чата (:153) — 1000 лишних строк на нажатие.
* Изолятов нет нигде: JSON кэша (`CacheService.getCachedChats`, `cache_service.dart:186-195`) декодируется синхронно на UI-изоляте.

---

## 6. Холодный старт инбокса

1. `AppStartupGate` рисует первый кадр до инициализации хранилищ; `_initializeLocalState` параллелит Hive/кэши и `SharedPreferences` через `Future.wait` (`main.dart:95-110`). Правило «параллельный холодный старт» соблюдено.
2. Первый кадр инбокса: `ChatsNotifier.build()` (`backend_chat_provider.dart:206-354`) синхронно до первого `await` делает `state = const AsyncData([])` (:227).
3. Кэш читается синхронно: `getCachedChats` (:319-321) — `ApiChatSummary.fromJson` для каждого чата на UI-изоляте.
4. Если есть secret-координатор, **до публикации кэша** идёт `await secret.importChats(chats)` (:323) — содержимое появляется только после импорта.
5. Дальше `unawaited(_hydrateInboxPreviews(chats))` (:328) — расшифровка превью пачками по 4 (:649-671); каждая расшифровка заканчивается `_handleEditedPush(decoded)` (:634) → `state = AsyncData(updated)` (:600) → **отдельная перестройка всего списка**.
6. Сеть: `_fetch()` (:941-986) публикует снапшот и зовёт `_hydrateInboxPreviews` ещё раз через `Timer.run` (:971-976).
7. Скелетон: `ChatListSkeleton` (`pulse_skeleton.dart:35-125`, 6 строк, один общий пульс 1200 мс) показывается только в ветке `chatsAsync.when(loading:)` (:323-333) и в ветке `error`.
8. Отложенное: альфа-диалог через 600 мс (`main_shell_screen.dart:190-200`), push-промпт +800 мс (`:225`), OTA +2 с (`:271`), прогрев табов +400 мс (`:174`). Первый кадр они не блокируют.

---

## 7. Находки

### F1. Любой presence-пуш перестраивает весь инбокс — MAJOR (доказано кодом)

`ChatsNotifier._handleUserStatusPush` (`backend_chat_provider.dart:409-431`) на каждый `user_status` создаёт новый `List` и пишет `state = AsyncData(updated)` (:430). `visibleChatsProvider` (`chat_productivity_provider.dart:410`) — обычный `Provider`, значение сравнивается по `!=` (identity для `List`), поэтому уведомление уходит всегда. `ChatListScreen` смотрит его напрямую (:151), а `SliverChildBuilderDelegate.shouldRebuild` всегда `true` (SDK `scroll_delegate.dart:579`) → перестраиваются **все живые строки** (включая `customEmojiSpans`, `formatRelativeTime`, поиск цвета аватара, `LayoutBuilder`×2).

Частота: `WebSocketPushDispatcher` пробрасывает `user_status` без коалесинга (`websocket_dispatcher_provider.dart:211-221`); при возврате в приложение и при массовом онлайне контактов это пачка событий подряд.

Сколько стоит: 12 строк × ~30 элементов + 5 текстовых параграфов на строку + O(n) фильтр/карта. На среднем Android это единицы миллисекунд на событие, в пачке — кадр в минус.

Фикс: вынести presence из `ApiChatSummary` в отдельный `NotifierProvider<Map<int,bool>>` (или `presenceProvider(chatId)` family) и обновлять только флаг; `ChatTile.isOnline` читать через `ref.watch(presenceProvider(chat.id))` внутри `Consumer` строки. Тогда presence не порождает новый список и не трогает экран.

### F2. Видимость FAB перестраивает весь экран во время скролла — MAJOR (доказано кодом)

`ChatListScreen.build` читает `chatListFabVisibleProvider` (:164) только чтобы посчитать нижний отступ (:213-222). `show()/hide()` вызываются из обработчика скролла при пересечении порога 28 dp (`:235-265`) и из оболочки в конце списка (`main_shell_screen.dart:580-588`). Каждый вызов → перестройка экрана → перестройка всех видимых строк **в середине жеста скролла**, плюс новое значение `padding` у слivera → перерасчёт scroll extent.

Фикс: обернуть только завершающий `SliverPadding` в `Consumer` с `select((v) => v)`, либо вообще убрать зависимость от FAB из списка (оболочка уже держит постоянный зазор `kInboxComposerClearance = 88` и тональный скрим `main_shell_screen.dart:790-802, 812-844` — то есть запас уже есть дважды).

### F3. Первый запуск показывает «Нет чатов» вместо скелетона — MAJOR (доказано кодом, визуальный эффект — подозрение)

`state = const AsyncData([])` в начале `build()` (:227) означает, что состояние никогда не бывает `AsyncLoading` в нормальном первом запуске. `_buildChatSlivers` при пустом кэше уходит в `chatsAsync.when(data:)` (:315-322) → `filtered.isEmpty` → `EmptyStateWidget(chatListNoChats)` (:380-400). Ветка `loading:` со скелетоном (:323-333) недостижима, и пользователь до ответа `list_chats` видит пустой инбокс, потом «прыжок» в список.

Фикс: не писать `AsyncData([])` до загрузки кэша (или ставить `AsyncLoading` с сохранением `previous`), либо в `_buildChatSlivers` считать `loading` как «кэш пуст и сеть ещё в полёте» и показывать скелетон.

### F4. Кэш инбокса публикуется после `await secret.importChats` — MAJOR (доказано кодом)

`backend_chat_provider.dart:318-329`: чтение кэша синхронное, но `state` выставляется только после `await secret.importChats(chats)` (:323). При включённых секретных чатах первый экран ждёт импорт, хотя кэш уже в памяти.

Фикс: опубликовать кэш сразу (`state = AsyncData(chats)`), импорт и `mergeChats` выполнить после, следующим `state`-апдейтом.

### F5. Расшифровка превью публикует состояние по одному сообщению — MAJOR (доказано кодом)

`_hydrateInboxPreviews` (`:649-671`) идёт по чатам пачками по 4, но каждая расшифровка внутри `_decryptInboxPreview` вызывает `_handleEditedPush(decoded)` (:634) → `state = AsyncData(updated)` (:600). Для 30 E2EE-чатов это до 30 полных перестроек списка на старте, каждая — O(n) сортировки нет, но копия списка + rebuild всех строк.

Фикс: собрать расшифрованные превью в локальную карту и опубликовать один раз в конце пачки (или сделать точечный `updateChatPreview(chatId, message)` с `select` по id в строке).

### F6. Drag разделителя на десктопе перестраивает оболочку и раскладывает список каждый кадр — MAJOR (доказано кодом, десктоп/web)

`_DraggableSidebarDivider.onDragUpdate` → `setState` (`main_shell_screen.dart:487-495`) внутри `LayoutBuilder` (`:449`). Каждый пиксель движения: новые `pages` (:474-567), новый `ProfileScreen` (:560), новые обёртки свитчера, новый `SizedBox(width:)` (:479-485) → новые constraints для `CustomScrollView` → перераскладка всех видимых строк.

Фикс: держать ширину в `ValueNotifier<double>`, обернуть только `SizedBox` (и `_DraggableSidebarDivider`) в `ValueListenableBuilder`; `pages` строить один раз вне `onDragUpdate`-пути.

### F7. Полноэкранный `Opacity` вокруг страницы таба — MAJOR (доказано кодом)

`m3_route_tab_switcher.dart:210-221`: `RepaintBoundary > Opacity > Transform.translate > Transform.scale > страница`. Пока `_opacity.value` в (0,1), каждая страница композитится через offscreen-слой на весь экран; так идёт весь переход `medium2` = 300 мс (`main_shell_screen.dart:599-601`).

Фикс: заменить `Opacity` на `FadeTransition` (тот же слой, но дешевле по дереву — фактически проблема в самом alpha-слое) и/или ограничить переход slide+scale без изменения прозрачности целой страницы; на Tier C уже можно ставить `Duration.zero`.

### F8. `_folderUnread` — O(папки × чаты × chatIds) на каждую перестройку — MAJOR (доказано кодом)

`chat_filter_bar.dart:223-236` вложенно проходит чаты и для каждого вызывает `folder.includes` (`models/chat_productivity.dart:37-41`, `List<int>.contains`). При 20 папках и 1000 чатах это порядка 20 000 вызовов + внутренние `contains` по спискам id. Полоса перестраивается на каждое сообщение/presence, если есть папки (`chat_filter_bar.dart:51-56`).

Фикс: считать unread папок в провайдере (`Provider` с мемоизацией по `chatsProvider`) один раз, а в UI отдавать готовые числа; `includes` переписать на `Set<int>` (кэшировать `chatIds.toSet()` в модели).

### F9. Скрытый таб получает перестройку и раскладку — MAJOR (подозрение, нужен DevTools)

`Offstage` не отменяет `layout` (SDK `proxy_box.dart:3919-3925`). Пока открыт «NiosGram», каждое новое сообщение/presence перестраивает `ChatListScreen` (он жив и слушает `visibleChatsProvider`) и раскладывает его слiver. Проверить: DevTools → Performance с включённым «Widget rebuild stats» при получении сообщения на другой вкладке.

Фикс (если подтвердится): не строить инбокс, когда таб неактивен, — например, отдавать из провайдера «замороженное» значение, пока вкладка не активна, или не держать `ChatListScreen` смонтированным (`Visibility(maintainState: true)` тоже раскладывает, поэтому нужен именно гейт на подписки).

### F10. Точки «печатает» перерисовывают всю строку 60 раз в секунду — MINOR→MAJOR (доказано кодом)

`_TypingDots` (`chat_tile.dart:786-877`) анимирует 3 `FadeTransition`; единственный `RepaintBoundary` — вокруг всей строки (`chat_list_screen.dart:544`). Значит каждый кадр пере-растеризуется вся строка: текст, AA-клип аватара (`pulse_avatar.dart:89`), `Opacity(0.9)` при mute. Обычно «печатает» одна строка, но если их 3-4 — это 3-4 полноценных перерисовки строки на кадр.

Фикс: `RepaintBoundary` вокруг ряда превью или вокруг самих точек.

### F11. Сдвиг строки при перестановке — repaint вместо compositing — MINOR (доказано кодом)

`Transform.translate` внутри `RepaintBoundary` (`reorder_slide.dart:77-83` против `chat_list_screen.dart:544`) → во время пружины строка перерисовывается каждый кадр. Если поменять местами (`ReorderSlide` снаружи, `RepaintBoundary` внутри), слой можно двигать без перерисовки.

То же для `SwipeActionRow` (`swipe_action_row.dart:125-128`) — при свайпе строка перерисовывается каждый кадр, что для жеста приемлемо.

### F12. Два `LayoutBuilder` на строку — MINOR (доказано кодом)

`chat_tile.dart:421-483` и `:572-664`. Оба нужны только для `constraints.maxWidth` (ограничение слота времени и метки черновика). `LayoutBuilder` не даёт кэшировать поддерево по constraints и добавляет layout-проход. Фикс: считать `slotCap` один раз в `build` строки от известной ширины (или отдать ограничения из одного `LayoutBuilder` через `Builder`/параметр).

### F13. Инбокс зависит от `encryptedDraftSyncProvider` — MINOR (доказано кодом)

`chat_list_screen.dart:144` — `ref.watch(encryptedDraftSyncProvider)` только чтобы держать сервис живым. Провайдер пересоздаёт объект при смене `draftStorageProvider`/`ordinaryE2eeProvider` (`encrypted_draft_sync_provider.dart:7-22`), то есть смена E2EE-сервиса перестраивает инбокс. Фикс: держать сервис в `main.dart`/оболочке (`ref.watch` там), не в экране списка.

### F14. Гонка `Opacity` + `AnimatedContainer` на каждой строке — MINOR (доказано кодом)

`chat_tile.dart:257-270` (`AnimatedContainer` фон/рамка) + `:307-310` (`Opacity(0.9)` при mute) + `:381-395` (`AnimatedOpacity`) + `:511-522` (`AnimatedDefaultTextStyle`). В покое не тикают, но это 4 `AnimationController` на строку и постоянный save-layer у приглушённых чатов. Фикс: `Opacity` заменить на приглушённый цвет фона/текста (без alpha-слоя); фон строки рисовать отдельным слоем под контентом.

### F15. `chatMutedProvider` — family без autoDispose — MINOR (доказано кодом)

`chat_muted_provider.dart:102-143`: каждый чат, когда-либо отрисованный в инбоксе, оставляет живой элемент (и подписку на `chatMuteHubProvider.future`) до конца сессии. Для 500 чатов — 500 элементов. Сделано намеренно (комментарий :104-109), но память растёт линейно.

### F16. Время и превью считаются на каждую сборку строки — MINOR (доказано кодом)

`formatRelativeTime` (`chat_list_screen.dart:471-474`) вызывает `DateFormat.format` на каждую сборку каждой строки (`datetime_helpers.dart:53-89`). Markdown-превью кэшировано (`MessagePreviewFormatter`, `message_preview_text.dart:47-59`, до 512 записей) — это плюс, но `LiveLocation.parse`/`InteractiveMessage.parse` (`chat_list_screen.dart:577-581`) выполняются до кэша каждый раз.

### F17. Поиск: `toLowerCase()` в цикле — MINOR (доказано кодом)

`inbox_search_screen.dart:152-158`: `final q = query.toLowerCase();` внутри `where`. Плюс локальный фильтр по всем чатам на каждое нажатие. При 1000 чатах — 1000 лишних строк на нажатие. Фикс: вынести `toLowerCase()` до `where`, для >500 чатов — в isolate или через `compute`.

### F18. Полная пересортировка на каждое сообщение — MINOR (доказано кодом)

`backend_chat_provider.dart:768`. Для 1000 чатов ~10k сравнений `DateTime` на сообщение; в пачке (переподключение, replay mesh) — столько же раз на событие. Фикс: если `lastActivity` нового сообщения больше максимального в списке, `removeAt + insert(0)`; иначе — бинарная вставка.

---

## 8. Что измерить на устройстве

Все замеры — в release/profile, DevTools привязан к устройству (не к эмулятору с debug).

1. **DevTools → Performance, UI + Raster, 120 Гц, список 300+ чатов.** Сценарий: плавный флинг вниз-вверх 5 с.
   Приемлемо: p90 UI < 8 мс и p90 Raster < 8 мс, ни одного кадра > 16 мс; на 60 Гц — p99 < 16 мс.
2. **Presence-шторм.** Сценарий: свернуть/развернуть приложение (или включить много контактов онлайн) и считать в DevTools «Rebuild stats» число перестроек `ChatListScreen`/`ChatTile`.
   Приемлемо: 1 перестройка экрана на пакет событий, а не на событие; строки без изменившегося presence не перестраиваются (после фикса F1).
3. **Скролл мимо порога FAB.** Сценарий: проскроллить 100 dp вниз и обратно, замерять кадры в момент скрытия/показа FAB.
   Приемлемо: ни одного кадра > 16 мс в момент срабатывания (сейчас там полная перестройка списка — F2).
4. **Холодный старт.** Сценарий: kill → запуск с закешированным инбоксом (200+ чатов), Timeline-маркер `BOOTSTRAP_FIRST_FRAME` уже логируется (`main.dart:74-76`).
   Приемлемо: первый кадр < 400 мс, первый список чатов < 1.2 с; проверить, что не мелькает пустое состояние (F3) и что кэш появляется до расшифровок (F4/F5).
5. **Переключение табов ×10.** Сценарий: чаты→ниосграм→настройки, по кругу.
   Приемлемо: Raster p99 < 16 мс; в Raster-трейсе не должно быть полноэкранного offscreen-слоя на каждый кадр 300 мс (F7).
6. **Индикатор «печатает».** Сценарий: бот/второй клиент печатает в чате, список открыт.
   Приемлемо: в DevTools → Performance репейнтится только область точек (после F10), а не вся строка; Raster < 4 мс.
7. **Клавиатура и resize.** Сценарий: открыть/закрыть клавиатуру на инбоксе, на десктопе — потянуть разделитель.
   Приемлемо: 0 перестроек `ChatTile` при клавиатуре; при drag разделителя UI < 8 мс (сейчас — перестройка оболочки, F6).
8. **Память.** DevTools → Memory, snapshot после 5 минут скролла по 500 чатам: число `ChatTile`/`RenderParagraph`/`Image` не должно расти (утечка = keep-alive/семейства без autoDispose, F15).

Вспомогательно: в приложении уже есть `FrameTimingMonitor`, который собирает метрики в `_telemetry` и публикует в `performanceTelemetryProvider`, но **никто их не читает** (`adaptive_performance_provider.dart:266-284`; потребителей в `lib/` нет) — для замеров проще включить `showPerformanceOverlay` (`main.dart:391`, флаг есть в `uiSettingsProvider`, но экрана-переключателя нет) или метку `PERF_TRACE` (:278).

Важно: `test/perf/ui_smoothness_benchmark_test.dart` — синтетические фикстуры (`header` файла, строки 1-2), не измерения устройства; на них нельзя ссылаться как на доказательство.

---

## 9. Что уже хорошо и трогать нельзя

1. O(1) индекс в `findChildIndexCallback` (`chat_list_screen.dart:564-568`) + гвард-тест, который это фиксирует (`ui_smoothness_regression_guard_test.dart:86-106`).
2. `addRepaintBoundaries: false` + один ручной `RepaintBoundary` на строку и `addAutomaticKeepAlives: false` (`:544, :562-563`).
3. Узкие `select` в строке: typing, draft, haptics (`:435-453, :463-465`) — чужая печать/чужой черновик строку не трогают.
4. Единая подписка на typing (`typing_provider.dart:21-60`) и единое чтение prefs для mute (`chat_muted_provider.dart:14-51`) вместо N обработчиков на N чатов.
5. Кэш markdown-превью на экран (`message_preview_text.dart:47-59`) и кэш цветов `NiosMark` (`nios_mark.dart:95-113`).
6. Аватары декодируются в 96 px, не в полный размер (`pulse_avatar.dart:99-100`).
7. Видео-аватары/стикеры идут через общий пул с бюджетом и отключением на быстром скролле (`bubble_sticker_player.dart:32, 97, 117, 161-163`).
8. `TickerMode`-гейты: скрытые табы (`main_shell_screen.dart:607`, `m3_route_tab_switcher.dart:202`) и точки «печатает» (`chat_tile.dart:807-809`).
9. `Clip.none` по умолчанию в `TouchContainer` (`touch_container.dart:29`), `Stack(clipBehavior: Clip.none)` в строке; никаких `ClipRRect`/`BackdropFilter`/`MaskFilter.blur` в строке и в навбаре.
10. Навбар в `RepaintBoundary` и слушает только `int` (`main_shell_screen.dart:647-655`, `app_bottom_nav.dart:51`).
11. `ChatFilterBar` вообще не подписывается на `chatsProvider`, если папок нет (`chat_filter_bar.dart:49-56`).
12. Гистерезис FAB 28 dp и ранний выход из обработчика скролла (`chat_list_screen.dart:232-265`), `setScrolled` с проверкой равенства (`chat_list_header.dart:22-24`).
13. Параллельный бутстрап (`main.dart:95-110`), отложенные диалоги/проверки 400–2000 мс.
14. `SwipeActionRow` без `Dismissible`: возврат с переносом скорости, фон строится только при реальном сдвиге (`swipe_action_row.dart:82-88, 108`).

---

## 10. Что я не проверял

* Не запускал приложение, не снимал DevTools/FrameTiming — все оценки «сколько стоит» качественные, не в миллисекундах.
* Не проверял реальный размер `chatsProvider` (сколько чатов бывает у пользователя), частоту `user_status` от сервера и объём `chatIds` в папках — от этого напрямую зависят F1/F8/F18.
* Не читал целиком `chat_detail_screen.dart`, `niosgram_screen.dart`, `profile_screen.dart` — стоимость `ProfileScreen` при перестройке оболочки (F6) известна только по факту «перестраивается», не по цене.
* Не проверял Android/iOS-специфику: Impeller vs Skia для `ClipOval`/`Opacity` (на Impeller часть save-layer дешевле), поведение `ImageCache` по умолчанию (1000 изображений / 100 МБ) при 300+ аватарах.
* Не проверял веб-ветку `PulseAvatar` (`Image.network` без `cacheWidth`, `pulse_avatar.dart:72-87`) — на web декод может идти в полном размере.
* Не измерял `AnimatedTheme` (500 мс) на смене темы и `dynamic_color` — только зафиксировал путь (`main.dart:380-389`).
* Не проверял `adaptive_performance_provider.onTimings` под нагрузкой (он вызывается на каждый батч кадров и делает `ref.read(...select)` внутри `_evaluateHysteresis`, :315) — вне заявленного скоупа, но это глобальный per-frame колбэк.
* Не проверял `M3SpeedDialFab` как рантайм: он **нигде не инстанцируется** (grep по `lib/`: только объявление в `m3_speed_dial_fab.dart`), поэтому его `OverlayEntry`, scrim и стаггер в инбоксе не участвуют. Если он включится в будущем — scrim `scheme.scrim.withValues(alpha: 0.36)` поверх всего экрана (`:154-157`) добавит полноэкранный слой на время раскрытия.

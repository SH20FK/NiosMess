# Аудит инбокса NiosMess — 2026-11-16

Источники: 2 агента по коду (`deleg_1d14a2bb` task-0, task-1), 2 агента по
референсам (task-2 UX, task-3 техника). Все file:line — по состоянию коммита
`6972cce0`. P0-пункты №2 и №3 проверены вручную по исходнику.

Объём: ~100 находок в сыром виде, ниже — сведённый и приоритизированный список.

---

## P0 — гонки данных (чинить до релиза)

### 1. `refresh()` затирает состояние и кэш устаревшим снапшотом
`lib/providers/backend_chat_provider.dart:691-725` (`_fetch`), `:742-761`
(`refresh`), `:727-740` (`refreshOrThrow`).

`_fetch` берёт `list_chats` и делает `state = AsyncData(chats)` без сверки, что
за время RTT пришли пуши. `new_message`, пришедший в окне RTT, уже применён к
state (:619), затем затирается снапшотом, посчитанным до него: откатываются
`lastMessage` и `unreadCount`. Тот же устаревший снапшот уходит в Hive (:715),
т.е. откат переживает рестарт. Триггеры массовые: resume (`main.dart:144`),
WS-reconnect (`:245-249`), `productivity_changed` (`:216-220`), pull-to-refresh.

**Фикс:** монотонный `_refreshSeq` + мерж по `max(lastMessage.id)` /
`max(unread)` вместо замены; писать кэш из финального state, а не из ответа.

### 2. `_flushPendingChats` в `build()` — мёртвый код: до 2 с мутаций теряются
`backend_chat_provider.dart:129-152, 159-173, 183, 250-262`.

Riverpod вызывает `onDispose` **до** `build` (riverpod 3.4.3
`core/element.dart:617` `_performRebuild() → runOnDispose()`), а `onDispose`
(:257-261) обнуляет `_pendingChats`. Flush в build (:183) всегда видит `null`.
Потери при любом `ref.invalidate(chatsProvider)` — а его делают 6+ мест
(`create_group_controller:122`, `create_channel_screen:62`,
`e2ee_settings_screen:158`, `auto_delete_bottom_sheet:131`,
`widgets/chat_productivity:766,859`) — и при смерти процесса.

**Фикс (без `ref` в onDispose):** поля `_pendingChatsCache`/`_pendingChatsAccountId`
уже захвачены при постановке снапшота — писать кэш прямо в `onDispose`,
не читая провайдеров. Тест `chat_account_boundary_test` сейчас проходит
«вхолостую» — усилить, чтобы он падал на пустом пути.

---

## P1 — корректность и UX

### Непрочитанные
3. **Открытый чат помечается прочитанным на сервере, даже когда пользователь
   листает историю.** `:602-605, 623-626` — `isCurrentChatOpen` не учитывает
   `_followingLatest` (в `ChatMessagesNotifier` гейт есть: `:1841-1843`).
   → Передавать признак «у дна» и не репортить read, пока false.
4. **Счётчик инкрементируется локально без дедупа по `message.id`; mesh-replay
   на каждом rebuild даёт +1 за каждую операцию.** `:597-601` (дедуп только по
   `meshOperation`), `:184` (`_seenOperations.clear()`), `:298-307`
   (`mesh.replay()`). Для обычных сообщений дедупа нет вовсе.
   → Хранить `_seenMessageIds` вне rebuild, брать `unread_count` с сервера.
5. **«Отметить прочитанным» из инбокса грузит всю переписку.**
   `chat_list_screen.dart:93-94` → `chatMessagesProvider(id).build()` →
   `_buildHistory()` (`:1260-1360`) + `retention.retain()` (`retention:8-11`,
   6 чатов / 30 с) может вытеснить историю реально открытого чата.
   → Лёгкий путь `chatRepository.markRead(id)` + публичный метод на `ChatsNotifier`.
6. **markRead молча выходит** при `!isForeground` / `remoteId <= 0`
   (`:2659, 2661-2666`) — свайп выглядит как «ничего не произошло», бейдж не
   сбрасывается. → Оптимистичный локальный сброс с откатом по ошибке.
7. **«Прочитан» не чистит темы группы** (`:808-819`, `:394-428`); бейдж плитки
   агрегирует unread детей (`chat_productivity_provider.dart:251-269`) — у
   группы с темами бейдж остаётся. → Обнулять и `topic_child`.
8. **`markChatAsRead` пишет локальный ноль без сервера и без отката**
   (`:808-819`) — бейдж исчезает и возвращается после refresh. → Откат при неуспехе.

### Список и модель
9. **Secret-чаты уезжают в конец после каждого refresh** (`secret_chat_provider.dart:605-650`
   без сортировки; сортировка только в `_applyNewMessagePush` `:613-617`).
   → Сортировать один раз в состоянии, компаратор общий.
10. **Кэш теряет `is_blocked_*`, `key_mismatch`, `partner_status_emoji`,
    `partner_user_id`** (`chat_summary_model.dart:308-337` toJson; `:160-166`
    fromJson читает только `with_user_id/partner_id/other_user_id`). После
    рестарта: композер в заблокированном чате снова активен, пропадает бейдж
    «key mismatch», `_handleUserBlockedPush` (`:345-392`) не матчит cached DM.
    → Сериализовать все поля, cache-DTO с `schemaVersion`.
11. **Mute не синхронизируется и обходится прямым показом уведомления**
    (`chat_muted_provider.dart:12-36` — только prefs; `backend_chat_provider:686-688`
    зовёт `showLocalNotification` мимо проверки mute в `notifications_provider.dart:263-266`).
    → Mute на сервере (`messages._muted` в `list_chats`), единственный путь показа.
12. **`upsertChat` вставляет в начало без сортировки и затирает summary**
    (`:763-790`, `updated.insert(0, chat)`) — чат прыгает в топ с обнулённым
    `lastMessage`/`unreadCount`. → Мерж «непустое побеждает» + позиция по `lastActivity`.
13. **Реакции в списке ±1 без авторитетных счётчиков** (`:454-489`) — пропущенный
    пуш расходится навсегда. → Слать агрегат `reactions` в пуше.

### Реалтайм и синхронизация
14. **Нет обработчика `chat_updated`** (`websocket_dispatcher_provider.dart:168-250`;
    сервер шлёт — `chat_handler.py:800-810`). Переименование/автоудаление/добавление
    в группу видны только после resume. → Добавить + лёгкий `sync_since(ts)`.
15. **Presence-пуши не персистятся** (`:370-392`) — после рестарта зелёная точка
    врёт до ответа сети; и каждый пуш пересобирает весь `visibleChats`
    (`chat_productivity_provider.dart:243-271`). → TTL/не кэшировать + точечный select.
16. **`productivity_changed` вызывает полный `refresh()`** (`:216-220` +
    `chat_productivity_provider.dart:150-162`) — любое напоминание = лишний
    `list_chats` + N запросов. → Разбирать `payload.kind` точечно.
17. **`chatByIdProvider` — O(n)-скан всего списка без `select`** (`:827-843`);
    любой presence/unread пересчитывает все family-инстансы. → `select` по id.

### UI
18. **Overflow в тайле:** `Text(draftLabel)` в `Row` без `Flexible`
    (`chat_tile.dart:343-354`) — `maxLines/ellipsis` не работают, длинный
    черновик (до 10 000 символов) ломает строку. → `Flexible`.
19. **Двойное контекстное меню на ПКМ** (`chat_list_screen.dart:443-446` +
    `touch_container.dart:183`): внешний `onSecondaryTapDown` срабатывает через
    ~100 мс, внутренний на отпускании — два модала подряд. → Один путь.
20. **Мёртвая ветка поиска в инбоксе** (`chat_list_screen.dart:361-375, 367-369, 387-406`):
    `chatListSearchProvider` никто не наполняет (единственный писатель
    `chat_search_bar.dart:65-68` нигде не смонтирован), `hasActiveQuery` всегда
    false, `inboxSearchEmpty` недостижим. → Подключить `InboxSearchScreen` или удалить.
21. **Typing/presence: family без autoDispose** (`typing_provider.dart:112-115`,
    `chat_muted_provider.dart:38-40`) — каждый виденный чат навсегда держит
    подписку на `pushStream`; 200 чатов = 200 обработчиков на пуш.
    → `.autoDispose` или один общий notifier `Map<int, Set<int>>`.
22. **Хардкод русских строк в папках/отложенных** (`chat_productivity.dart:95, 104,
    124` + ещё ~55 строк, `ordinary_e2ee_notice.dart:25-26, 32`,
    `datetime_helpers.dart:65, 84, 131, 135`) — EN-интерфейс наполовину русский.
    → l10n-ключи.
23. **Папки теряют участников при сохранении** (`chat_productivity.dart:300+`: фильтр
    `_ids.where(chatByIdProvider != null)` выбрасывает чаты, которых нет в
    локальном списке) и нет контроля версий (`chat_productivity_provider.dart:209-222`
    last-write-wins при наличии `version`). → Не фильтровать, слать/проверять version.
24. **Выбор папки/фильтра не переживает рестарт** (`chat_productivity_provider.dart:230-238`)
    и молча показывает все чаты, если папка исчезла. → prefs по аккаунту.

---

## P2 — полировка (топ)

25. `PopupMenuButton` в папках (`chat_productivity.dart:214-236, 678-718, 836-880`) —
    запрещён AGENTS.md §M3E п.4. → `MenuAnchor`.
26. Шорткаты в папках — мёртвый код (`showShortcuts: false` единственный вызов,
    `chat_list_screen.dart:194`); `Navigator.push` мимо go_router.
27. Пустой список при загрузке папки (`chat_productivity.dart:314`) — нет скелетона.
28. «Избранное» делает сетевой запрос на каждый тап без busy (`chat_list_screen.dart:271`).
29. Скелетон не совпадает с тайлом геометрией (`pulse_skeleton.dart:45-49` vs
    `chat_tile.dart:183-190`: радиус 24 vs 16, padding 14 vs 12) — дёргается при загрузке.
30. Два `RepaintBoundary` на строку (`chat_tile.dart:152` + `chat_list_screen.dart:562`) —
    лишний save-layer (Motion-протокол п.2).
31. `Semantics` без `excludeSemantics` (`chat_tile.dart:157-159`) — TalkBack читает дважды.
32. Бейдж непрочитанного одинаковый для muted (`chat_tile.dart:370-385`) — по M3 muted
    нейтральный. `isPinned: chat.isSaved` (`chat_list_screen.dart:522`) — пин-иконка у
    «Избранного», реального пина в модели нет.
33. Время тайла из `lastActivity`, сортировка по `lastMessage.sentAt`
    (`chat_list_screen.dart:487-490` vs `:613-617`) — расхождение.
34. `RegExp` компилируется на каждый вызов (`chat_list_screen.dart:586`); `'Unknown'`
    литерал (`:589`); `chatListFailedLoad(commonError)` → «Не удалось загрузить чаты: Ошибка» (`:335`).
35. Мёртвые API тайла: `onTapWithRect`, `actions`, `animateEntrance`
    (`chat_tile.dart:27, 57, 120-132, 393-409`).
36. Магические `fontSize: 24 / w700` + `preferredSize: kToolbarHeight`
    (`chat_list_header.dart:27-32, 59`) — ломается при textScale 2.0.
37. Filter-чип активного типа теряет подпись (`chat_filter_bar.dart:108-126`);
    подчёркивание вне hit-area (`:33-58`).
38. `chat_actions_modal.dart:116-147` — мёртвая ветка disabled; на desktop модал
    центрированный вместо якорного меню у курсора.
39. `AsyncValue.value ?? false` у mute (`chat_muted_provider.dart:16` +
    `chat_list_screen.dart:525-526`) — мигание иконки на старте.
40. `list_chats` без лимита/пагинации обе стороны (`chat_repository.dart:79-92`,
    `chat_list_snapshot.py:52-80`) — 500+ чатов = гигантский WS-фрейм и полный
    JSON-энкод на UI-изоляте каждые 2 с.

---

## Новые фичи (по референсам лидеров, с источниками)

1. **Цветные счётчики папок (модель VK):** синий — есть непрочитанные в незамьюченных,
   серый — только в замьюченных, скрыт — ноль. Дёшево, снимает главную претензию к бейджам.
   [vk.ru/faq20513](https://vk.ru/faq20513)
2. **Архив отдельной строкой + правило «archived+muted не всплывает, archived+unmuted
   всплывает при новом сообщении»**, `@` при упоминании/ответе, счётчик архива — число
   чатов и не в общем бейдже.
   [telegram.org/blog/archive](https://telegram.org/blog/archive-and-new-design) ·
   [faq.whatsapp.com/1426887324388733](https://faq.whatsapp.com/1426887324388733)
3. **Manual unread без read-receipt** (флаг только локально — критично для E2EE):
   свайп/меню + массовый режим «Select» → read/unread/archive/mute.
   [faq.whatsapp.com/4387000164859366](https://faq.whatsapp.com/4387000164859366) ·
   [support.apple.com/iphe9b48b89e](https://support.apple.com/guide/iphone/iphe9b48b89e/ios)
4. **Mentions как отдельная ось:** «@»/точка в папке и архиве + фильтр «Упоминания»
   (`ChatFilter` уже есть — добавить mentions).
   [slack.com/blog/news/slack-activity-triage](https://slack.com/blog/news/slack-activity-triage-for-notifications)
5. **Два стабильных свайпа + настройка:** влево — архив (primary, full swipe),
   вправо — unread/read, остальное в «Ещё»; убрать `DismissDirection.none` у прочитанных
   (`chat_list_screen.dart:427` — анти-паттерн NN/g).
   [m3.material.io/components/lists/guidelines](https://m3.material.io/components/lists/guidelines) ·
   [nngroup.com/articles/contextual-swipe](https://www.nngroup.com/articles/contextual-swipe/)
6. **Жесты не конфликтуют с папками:** край экрана — действие с чатом, центр — смена папки
   (решение Telegram). [tginfo.me/tabs-for-losers-en](https://tginfo.me/tabs-for-losers-en)
7. **Pin-политика:** лимит 10, новый пин ниже предыдущих, drag-reorder, авто-unpin при
   архивации, пины в папках и архиве.
   [workspace.vk.ru/.../pinned-chats](https://workspace.vk.ru/docs/saas/user-guides/ru/messenger/groups/pinned-chats)
8. **Превью: draft > typing > last message**, метка «Черновик:», медиа-иконка,
   опция скрытия текста, скрытое превью для секретных чатов.
   [telegram.org/blog/drafts](https://telegram.org/blog/drafts) ·
   [wabetainfo.com/.../media-previews](https://wabetainfo.com/whatsapp-is-rolling-out-media-previews-in-the-chat-list/)
9. **Пустые состояния по причинам** (нет чатов / нет непрочитанных / пустой фильтр /
   нет результатов / оффлайн / загрузка) + скелетон вместо пустого экрана.
   [nngroup.com/articles/empty-state-interface-design](https://www.nngroup.com/articles/empty-state-interface-design/)
10. **Запросы сообщений / неизвестные отправители** — отдельная очередь, не в инбоксе
    и не в счётчике (Discord/Apple).
    [support.discord.com/.../7924992471191](https://support.discord.com/hc/en-us/articles/7924992471191-Message-Requests)
11. **Adaptive:** compact — push, medium/expanded — list+detail, папки как rail/sidebar.
    [m3 lists](https://m3.material.io/components/lists/guidelines) ·
    [developer.android.com/.../canonical-layouts](https://developer.android.com/develop/adaptive-apps/guides/canonical-layouts)
12. **Плотный/подробный режим списка** (Slack) и сворачиваемые секции (Element) —
    для больших экранов.
    [element.io/blog/organise-your-chats-your-way-with-sections](https://element.io/blog/organise-your-chats-your-way-with-sections)

---

## Архитектура и производительность

1. **Нормализовать состояние:** `Map<String, Chat> chatsById` + `List<String> order` +
   `Map<String, int> idToIndex` в одной `Notifier`; наружу — только `ids`.
   [riverpod.dev/docs/how_to/select](https://riverpod.dev/docs/how_to/select)
2. **Строка — `ConsumerWidget` с `chatProvider(id).select((c) => (...))`;** `itemBuilder`
   передаёт только `id`. Убирает ~90% лишних ребилдов (сейчас у каждой плитки 4 watch).
3. **`CustomScrollView` + `SliverList.builder` + `itemExtentBuilder`** по трём M3-высотам
   (56/72/88), `addAutomaticKeepAlives: false`, без `shrinkWrap`, `findChildIndexCallback`
   по `idToIndex` (сохраняет состояние при переупорядочивании).
   [api.flutter.dev/.../findChildIndexCallback](https://api.flutter.dev/flutter/widgets/SliverChildBuilderDelegate/findChildIndexCallback.html)
4. **Убрать ручные `RepaintBoundary`** — ListView/SliverList уже добавляют их на каждого
   ребёнка; оставить только на morph-контейнере выбранной строки и медиа-превью.
   [api.flutter.dev/.../RepaintBoundary-class](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html)
5. **Аватары:** серверные тамбнейлы под `size × DPR`, `ResizeImage`/`cacheWidth`,
   `FilterQuality.low`, двухуровневый кэш (memory+disk), `precacheImage` для 5–10
   следующих строк. [FluffyChat mxc_image.dart](https://github.com/krille-chan/fluffychat/blob/main/lib/widgets/mxc_image.dart)
6. **Coalescing WS-патчей** (батч за кадр/300 мс), патч-модель `upsert/remove/reorder`
   (TDLib `chatPosition`); `SliverAnimatedList` — только одиночные вставки/удаления.
   [TDLib chatPosition](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_position.html) ·
   [flyer diff](https://github.com/flyerhq/flutter_chat_ui/blob/main/packages/flutter_chat_ui/lib/src/utils/message_list_diff.dart)
7. **Cursor-пагинация `list_chats`** (`before_id`/`limit=30`), `loadMoreTriggerIndex = 3`,
   `hasMore`/`loadMoreError` отдельно, окно 500–1000 чатов.
   [codewithandrea.com/articles/flutter-riverpod-pagination](https://codewithandrea.com/articles/flutter-riverpod-pagination/)
8. **Сортировка/фильтрация не в `build`:** серверный `order` + бинарная вставка,
   для тяжёлых случаев `Isolate.run` с примитивами; поиск — debounce 300 мс.
   [docs.flutter.dev/perf/isolates](https://docs.flutter.dev/perf/isolates)
9. **Гидратация превью по видимости, а не батчами по всему списку**
   (`backend_chat_provider.dart:555-577` — 50 последовательных батчей на 200 чатов) +
   кэш неудачных расшифровок с TTL.
10. **M3 Expressive lists во Flutter нет** (umbrella [flutter#168813](https://github.com/flutter/flutter/issues/168813),
    lists — [flutter#196232](https://github.com/flutter/flutter/issues/196232)) → свой
    `_ExpressiveChatRow`: 56/72/88, морф 4→16 dp через `BoxDecoration(borderRadius:)`
    на `M3SpringCurves`, без `ClipRRect`/`BackdropFilter`.
    [m3.material.io/components/lists/specs](https://m3.material.io/components/lists/specs)

---

## Порядок внедрения

**Волна 1 (баги, ~1–2 дня):** P0-1, P0-2, №3, №4, №18, №19, №20, №5-8.
**Волна 2 (каркас перфа):** нормализованное состояние + `select` на строку,
SliverList + itemExtentBuilder + findChildIndexCallback, снять двойные
RepaintBoundary, coalescing пушей, тамбнейлы аватаров.
**Волна 3 (фичи):** цветные счётчики папок, архив+правило muted, manual unread,
mentions, свайпы влево/вправо+настройка, pin-политика, «Черновик:».
**Волна 4 (полировка):** l10n-долг по папкам, пустые состояния, скелетоны,
adaptive две панели, плотный режим.

**Серверные контракты, которые нужны по пути:** mute в `list_chats`,
`chat_updated`-пуш, агрегат `reactions` в пуше, `limit/before_id` для `list_chats`,
`saved`-папки с `version`.

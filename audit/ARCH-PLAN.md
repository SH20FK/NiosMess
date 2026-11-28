# План постепенного рефакторинга: `chat_detail_screen.dart` и `auth_provider.dart`

Документ составлен по фактическому коду на 28.11.2026. Ничего не переписывается «на архитектуру X»:
каждый шаг — механический перенос существующего кода в отдельный файл/класс с сохранением поведения,
в стиле, который в проекте уже применён (`ChatScrollCoordinator`, `lib/providers/chat/*` + barrel-экспорт
в `backend_chat_provider.dart`, листы-виджеты в `lib/widgets/chat/`).

---

## 0. Измеренная база (не по описанию задачи, а по файлам)

| Факт | Значение | Как измерено |
|---|---|---|
| `lib/screens/chat_detail_screen.dart` | **3464** строки | `(Get-Content …).Count` |
| `class _ChatDetailScreenState` | строки **106–2590** → **2485** строк | границы классов |
| методов/геттеров в `State` | **61** объявление | разбор объявлений на отступе 2 |
| `build()` | строки **2324–2590** → **266** строк | |
| виджеты в том же файле | `_ChatHeaderScope` 2594–2821 (228), `_ChatMessagesScope` 2822–2992 (171), `_ChatComposerScope` 2993–3191 (199), `_AnimatedMessage` 3192–3307, `_TypingSubtitle` 3308–3420, `_AiActionCard` 3421–3464 | |
| `lib/providers/auth_provider.dart` | **832** строки, `AuthNotifier` 96–820 (**724** строки) | |
| `auth_provider.dart` импортирует | `web_socket_provider`, `secret_chat_provider`, `call_incoming_provider`, `notifications_provider`, `auth_repository`, `token_provider`, `ui_settings_provider`, `call_session_provider` | строки 1–33 |
| мест, читающих `authProvider.notifier.isLoggingOut` | **27** в `lib/` | grep |
| тестов, переопределяющих `authProvider` / наследующих `AuthNotifier` | **61** файл | grep по `test/` |
| тестов, импортирующих `ChatDetailScreen` | **0** | grep по `test/` |
| CI-вход | `flutter analyze --fatal-infos`, `test/suite_test.dart` (агрегирующий) | `AGENTS.md` 67, 92–94 |

Проверка после каждого шага (обязательный минимум):

```
flutter analyze                      # локально; в CI --fatal-infos
dart test test/suite_test.dart       # предпочтительный прогон (AGENTS.md:105)
dart test test/<новый_файл>_test.dart
```

**Новые тест-файлы обязательно регистрируются в `test/suite_test.dart`** (`group('имя', файл.main);`) — иначе CI их не запустит.

Откат на всех шагах одинаковый: один шаг = один commit, откат `git revert <sha>`.
**Перед началом** рабочее дерево `F:\Niosmess V2` грязное: 5 изменённых файлов и 4 новых пути
(`pulse_flutter/lib/providers/chat/`, `chat_manage_provider.dart`, `chat_member_actions_provider.dart`,
`support_provider.dart` — незакоммиченное разбиение `backend_chat_provider.dart`). Эти изменения нужно
закоммитить/убрать отдельно, иначе откат шага будет тянуть чужие правки.

---

# ПЛАН A. `lib/screens/chat_detail_screen.dart` — 12 шагов, ≈53 ч

## A.0 Целевая структура (создаётся по шагам, не сразу)

```
lib/screens/chat_detail/
  chat_message_presenter.dart      // чистая логика текста/медиа/реплаев          (шаг 1)
  chat_ai_rewrite_controller.dart  // AI-стрим + SmoothTextStreamer                 (шаг 4)
  chat_draft_controller.dart       // черновик: restore/save/debounce/secret        (шаг 5)
  chat_media_controller.dart       // open media, playlist, media actions           (шаг 6)
  chat_composer_controller.dart    // reply/edit mode (владеет _composerNotifier)   (шаг 7)
  chat_message_action_controller.dart // delete/react/forward/dispatcher            (шаг 8)
  chat_send_controller.dart        // отправка текста + gating                      (шаг 9)
  chat_attachment_controller.dart  // 4 пути загрузки                               (шаг 10)
  chat_screen_lifecycle.dart       // init/dispose/refresh/screenshot/secure flag   (шаг 11)
  chat_detail_body.dart            // build-тело + 3 scope-виджета                  (шаг 12)
  chat_detail.dart                 // барrel (как backend_chat_provider.dart)
lib/widgets/chat/
  reaction_picker_sheet.dart                                                    // (шаг 2)
  report_message_sheet.dart                                                     // (шаг 2)
  ai_actions_sheet.dart (+ _AiActionCard)                                       // (шаг 3)
```

Правило для всех контроллеров — как у существующего `ChatScrollCoordinator` (`lib/widgets/chat/chat_scroll_coordinator.dart`):
**обычный класс, создаётся в `initState`, уничтожается в `dispose`, зависимости — колбэки, а не `WidgetRef`.**
`ref` и `BuildContext` остаются в `State`: контроллер не хранит ни `BuildContext`, ни `WidgetRef`, поэтому
вопрос «context после await» не размазывается по 8 файлам. Там, где контроллеру нужны данные провайдера,
он получает узкий колбэк (`Future<void> Function(String text, {int? replyToId, void Function()? onLocalSaved}) send`),
а не весь `ref`.

### Что остаётся в `State` после всех 12 шагов (~400–450 строк)

- поля идентичности: `_chatId`, `_isSecret`, `_secretCoordinator`, `_canPersistOrdinaryDraft`;
- владение ресурсами: `_inputController`, `_inputFocusNode`, `_scrollCoordinator`, `_composerNotifier`,
  `_loadingOlderNotifier` и их `dispose` — то, что жёстко привязано к `TickerProvider`/дереву;
- `initState`/`dispose`/`didChangeAppLifecycleState` — тонкие, делегируют в контроллеры;
- `_goBack`, `_scrollToBottom`, `_autoLoadOlderMessages`, `_loadOlderMessages`, `_refreshNow`;
- `_onInputChanged` (связывает драфт → typing → inline query: три разных владельца);
- `build`: `Scaffold` + `CallbackShortcuts` + `PopScope` + 3 scope-виджета;
- все `ref.read(...)` внутри колбэков, передаваемых в скоупы.

---

## A.1 Шаг 1 — `ChatMessagePresenter` (чистая логика)

| | |
|---|---|
| Файлы | **new** `lib/screens/chat_detail/chat_message_presenter.dart` (~230); **edit** `chat_detail_screen.dart`: удаляются 170–213, 1955–1976, 2066–2119, 2121–2222 |
| Что переезжает | `_isVideoMedia`, `_isImageMedia`, `_mediaUrlFor`, `_extractUrlFromText`, `_displayText`, `_mediaLabel`, `_resolveReplySnippet`, `_resolveReplyAuthor`, `_replyPreviewFor`, `_dateSeparatorLabel` |
| Сигнатуры | методы принимают `AppLocalizations l10n` параметром и `String chatName`/`int myUserId` — потому что сейчас они читают `context.l10n` и `ref.read(chatByIdProvider)`/`authProvider` (2197–2219). `ref`-чтения остаются в `State`, наружу отдаются значения |
| Риск | **низкий** — код переносится дословно, меняются только источники `l10n`/`chatName` |
| Проверка | new `test/screens/chat_message_presenter_test.dart`: `lookupAppLocalizations(Locale('ru'/'en'))`; кейсы — стикер с эмодзи и без, voice с `mediaDuration` и без, `circle/circle_video/video_note/round_video`, image/video/document с caption и без, `isCallEvent`, пустой текст, обрезка 64/80 символов, `chatReplyToId` fallback, все 7 расширений видео и 7 изображений, `https?://` из `content` при `msgType == 'media'` |
| Откат | `git revert` — новый файл ни на что не ссылается |
| Оценка | **3 ч** |

## A.2 Шаг 2 — два листа: реакции и жалоба

| | |
|---|---|
| Файлы | **new** `lib/widgets/chat/reaction_picker_sheet.dart` (из 1793–1881, включая `_allReactionEmojis` — 25 эмодзи), **new** `lib/widgets/chat/report_message_sheet.dart` (из 1684–1772, 6 причин: spam/scam/illegal/copyright/doxing/swatting) |
| Что меняется | листы возвращают значение через `Navigator.pop` (`String? emoji`, `String? reason`); `_react`/`toggleReaction` и `_submitReport` остаются в `State`. Минус ≈160 строк |
| Риск | **низкий** (только UI, обе точки вызова — 1632/1680) |
| Проверка | new `test/widgets/chat_message_sheets_test.dart`: 25 реакций, подсветка выбранной (`message.reactions[emoji] > 0`), 6 причин, pop-значение, `SafeArea` |
| Откат | revert |
| Оценка | **3 ч** |

## A.3 Шаг 3 — AI-лист

| | |
|---|---|
| Файлы | **new** `lib/widgets/chat/ai_actions_sheet.dart` (552–723 + `_AiActionCard` 3421–3464); **edit** экран: `_showAiBottomSheet` → `showAiActionsSheet(context)` возвращает `(AiAction, String? targetLanguage)?` |
| Что переезжает | 4 действия (`correct`, `rewriteFormal`, 4 языка перевода) + `Consumer` с `authProvider.select((a) => a.profile?.aiUsage)` (581–630) — остаётся внутри листа, `ref` там уже есть |
| Риск | **низкий** |
| Проверка | `test/widgets/chat_message_sheets_test.dart` (+2 кейса): пустой ввод → лист не открывается (`_showAiBottomSheet` 553), лист без квоты скрывает бейдж, выбор языка возвращает `('en'|'es'|'zh'|'ru')` |
| Откат | revert |
| Оценка | **2 ч** |

## A.4 Шаг 4 — `ChatAiRewriteController`

| | |
|---|---|
| Файлы | **new** `chat_ai_rewrite_controller.dart` (из 439–550 + поля 136–137); **edit** экран: остаются guard «секретный чат» (443–447) и `_processTextWithAi` как 3-строчный делегат |
| Ответственность | `start(AiAction, {String? targetLanguage})`, `cancel()`, `dispose()`, флаг `isProcessing` |
| Зависимости | `TickerProvider vsync` (обязателен: `SmoothTextStreamer` принимает `TickerProvider?` и создаёт `Ticker`), `TextEditingController`, `bool Function() reduceMotion`, `Future<Stream<String>> Function(AiRewriteRequest)` (сейчас `ref.read(aiRepositoryProvider).streamRewriteText`), `void Function(bool busy)`, `void Function(Object) onError`, `void Function(SoundEvent) onSound` |
| Обязательно сохранить | порядок в `dispose`: `_aiStreamSubscription.cancel()` → `_aiTextStreamer.dispose()`; восстановление `backupText` **только** если не пришёл первый чанк (482–484, 514–516, 530–532); ровно одно событие звука `aiStart`/`aiComplete`/`aiError`; `cancelOnError: true`; установку каретки в конец на каждом чанке (465–467) |
| Риск | **средний** — тикер + три разных обработчика ошибок |
| Проверка | new `test/screens/chat_ai_rewrite_controller_test.dart` с `const TestVSync()`: успешный стрим даёт полный текст и `busy=false`; ошибка до первого чанка возвращает исходный текст; ошибка после первого чанка текст **не** возвращает; `cancel()` до `done` останавливает запись; двойной `start` не оставляет два тикера |
| Откат | revert; `_processTextWithAi` возвращается целиком из одного коммита |
| Оценка | **4 ч** |

## A.5 Шаг 5 — `ChatDraftController`

| | |
|---|---|
| Файлы | **new** `chat_draft_controller.dart` (из 415–437 в части драфта, 757–793, поля 113 / 121–122 / 280); **edit** `_onInputChanged` оставляет только inline query + typing |
| Что переезжает | `restore()`, `saveNow()`, `scheduleSave()` (debounce 500 мс), `clear()` (`remove`/`saveDraft('')`), `applyRemote(String)` (для `liveDraftMapProvider`-листенера 2361–2371), флаг баннера «черновик восстановлен» |
| Обязательно сохранить | `DraftStorage` кэшируется в `initState` **до** `dispose` (219) — иначе `ref` в `dispose` небезопасен; в `dispose` сначала `_draftSaveTimer.cancel()`, затем `saveNow()` (353–354); secret-ветка (`engine.saveDraft` + проглоченный `catchError`, 783–790); гейт `_canPersistOrdinaryDraft` (791), который меняется из листенера `chatByIdProvider` (2341–2352); `isSecret` нужно читать лениво, а не в конструкторе |
| Риск | **средний** — потеря последних 500 мс ввода при ошибке в порядке `dispose` |
| Проверка | new `test/screens/chat_draft_controller_test.dart` (fake `DraftStorage implements DraftStorage`, fake secret-engine): save/restore, пустой текст сохраняется, debounce через `testWidgets` + `tester.pump(600ms)`, secret-чат не пишет в `DraftStorage`, `clear()` для secret и обычного, `applyRemote` не перетирает введённое |
| Откат | revert |
| Оценка | **4 ч** |

## A.6 Шаг 6 — `ChatMediaController`

| | |
|---|---|
| Файлы | **new** `chat_media_controller.dart`: `_openMedia` (1883–1953), `_showMediaActions` (1978–2064), плюс чистая `buildMediaPlaylist(messages, target)` (выделяется из 1901–1927) |
| Зависимости | `l10n`, `List<ApiMessage> Function()` (сообщения), `void Function(String location, {Object? extra}) push`, `Future<void> Function(ApiMessage) forward`, `void Function(ApiMessage) delete`, `WebSocketClient` для `saveM3File` |
| Обязательно сохранить | `heroTag: chatMediaHeroTag(chatId, msg.id)`; `initialIndex` по совпадению `id`; пропуск сообщений без `mediaUrl`; `playlist.isNotEmpty ? playlist : null` (1935); строку удаления только при `isMine || amAdminOrOwner` (2043); `onForward` внутри `showM3FilePreview` с проверкой `context.mounted` (1949) |
| Риск | **средний** — навигация с `extra`, hero-теги, права |
| Проверка | new `test/screens/chat_media_controller_test.dart`: порядок плейлиста и `initialIndex`, отсев не-медиа, проброс `e2eeFileKey`/`mediaName`; `test/widgets/chat_message_sheets_test.dart` (+1): 5 строк медиа-меню и отсутствие «Удалить» без прав |
| Откат | revert |
| Оценка | **5 ч** |

## A.7 Шаг 7 — `ChatComposerController` (reply / edit)

| | |
|---|---|
| Файлы | **new** `chat_composer_controller.dart`: `_setReply` (1496–1505), `_clearReply` (1507–1513), `_editMessage` (1282–1304), `_commitEdit` (1306–1350), `_cancelEdit` (1352–1359), `_editLastMessage` (1361–1379). Контроллер **становится владельцем** `ValueNotifier<ChatComposerState> _composerNotifier` (124–125), `State` берёт его у контроллера |
| Зависимости | `chatId`, `TextEditingController`, `Future<void> Function(int id, String text) editMessage`, `({int? userId, String? accessToken}) Function() identity`, `bool Function() haptics`, `void Function(Object) onError`, `void Function(String) info` |
| Обязательно сохранить | `ChatComposerState.copyWith` использует **функции-писатели** (`replyToMessageId: () => null` очищает, `null` — не трогает) — 33–46 в `chat_detail_input_area.dart`; не заменять на обычные nullable-поля; `identity != (current.userId, current.accessToken)` — сравнение записи (1312/1326/1334); три ветки обработки ошибки `_commitEdit` (1331–1349); запрет редактирования `InteractiveMessage` (1283–1289); в `_cancelEdit` поле ввода очищается (1358) — это дизайн, не баг |
| Риск | **средний** |
| Проверка | new `test/screens/chat_composer_controller_test.dart`: 4 исхода `commitEdit` (успех, успех после смены аккаунта, ошибка при неизменном тексте, ошибка при изменённом тексте), `editLastMessage` выбирает последнее своё непустое `text` и пропускает deleted/failed/не-text, `setReply` обрезает до 80 символов |
| Откат | revert |
| Оценка | **4 ч** |

## A.8 Шаг 8 — `ChatMessageActionController` (2 коммита)

| | |
|---|---|
| Файлы | **new** `chat_message_action_controller.dart`: коммит 8a — `_deleteMessage` (1445–1477), `_react` (1479–1494), `_showAllReactionsPicker` (1821–1881); коммит 8b — `_forwardMessage` (1515–1600), `_showMessageActions` (1602–1682), `_submitReport` (1774–1791) |
| Зависимости | `ChatDetailPorts` (новый маленький value-object в том же файле): `read<T>(ProviderListenable<T>)`, `l10n`, `chatId`, `void Function(Object) onError`, `void Function(String) onSuccess/onInfo`, `void Function(String location, {Object? extra}) push`, `void Function() scrollToBottom`, `bool Function() haptics` |
| Обязательно сохранить | `_forwardMessage` для медиа: `WsMediaFetcher.fetchAndDecryptMedia` → `base64Decode(e2eeFileKey)` → `_uploadAndSend(attachCurrentReply: false)` (1551–1588) — порядок и `false` критичны; ветку `saveToSaved` со ссылкой `?highlight=` (1650); `showScheduledMessageComposer` (1660–1667); `context.push('/channel/…/comments')`; `switch (result.type)` — в Dart 3 каждый `case` завершается неявно, при переносе должно остаться **ровно одно** действие на кейс (1631–1681) |
| Риск | **средний-высокий** (8b) |
| Проверка | new `test/screens/chat_message_action_controller_test.dart`: 12 значений `MessageActionType` → ожидаемый вызов ровно один раз; copy кладёт в буфер `_displayText`; медиа-форвард вызывает `fetchAndDecryptMedia` и `uploadAndSend(attachCurrentReply:false)`; жалоба отправляет `messageIds: [id]`, `reportedUserId: senderId` |
| Откат | revert по коммитам 8a/8b независимо |
| Оценка | **6 ч** (2 + 4) |

## A.9 Шаг 9 — `ChatSendController` (текст)

| | |
|---|---|
| Файлы | **new** `chat_send_controller.dart` (из 795–925) |
| Что переезжает | оба пути: secret (`chatMessages.send`, 854–871) и обычный (`send(..., onLocalSaved: clearSavedComposer)`, 885–924); гейты: метаданные чата с таймаутом 8 с (807–820), `isChatRestrictedBySpamBlock` (829–837), блокировка партнёра (838–848) |
| Обязательно сохранить | общий флаг `_savingSecretMessage` для **двух** путей; `savedLocally` + `whenComplete` (921–923); восстановление текста только если `_inputController.text == originalText` (895); классификацию ошибки по подстрокам `not accept direct messages` / `unavailable between these users` / `restricted by user` → `setChatBlockedByUser` (906–916); восстановление reply только при совпадении `replyId` (900–905) |
| Риск | **высокий** — деньги/UX: двойная отправка или затирание нового текста |
| Проверка | new `test/screens/chat_send_controller_test.dart` по образцу `test/providers/send_account_fence_test.dart`: пустой ввод; нет метаданных → таймаут → тост; spam-блок; блокировка; secret-путь; `onLocalSaved` вызывается один раз и чистит поле; поздняя ошибка не затирает новый текст; поздняя ошибка возвращает текст, если он не менялся; re-entry при `_savingSecretMessage` |
| Откат | revert |
| Оценка | **6 ч** |

## A.10 Шаг 10 — `ChatAttachmentController` (4 пути загрузки, 3 коммита)

| | |
|---|---|
| Файлы | **new** `chat_attachment_controller.dart`: 10a — `_uploadAndSend` (927–1060); 10b — `_pickAndUploadMedia` (1186–1280), `_previewPastedImages` (1133–1184), `_handleDesktopPaste` (1381–1401), `_uploadDesktopFiles` (1403–1443), `_pasteDeduplicator` (116–119); 10c — `_sendVoiceMessage` (1062–1077), `_sendCircleVideo` (1079–1099), `_sendSticker` (1101–1114) |
| Что переезжает | secret-ветка `enqueueAttachmentFile`/`enqueueAttachment` (951–994); обычная ветка: `localId = -(ms + Random(1000))` → `ApiMessage(isSending: true)` → `addOptimisticLocalMessage` → `uploadQueueProvider.enqueue` (996–1059) |
| Обязательно сохранить | secret-путь возвращает управление **до** создания оптимистичного сообщения; `type` = voice/circle/media (955–959); при `bytes` пусто — `StateError('Empty attachment')`; `int.parse(localId)` работает только на отрицательном id; альбом: `compute(_encodeAlbum, images)` + имя `NiosMess-Album.niosalbum.zip` (1148–1156); `attachCurrentReply` по умолчанию `true`, форвард передаёт `false`; окно дедупликации вставки 400 мс (1385–1389); очистка поля только при совпадении текста |
| Риск | **высокий** — самый связанный участок (4 входа × 2 хранилища × reply/caption) |
| Проверка | new `test/screens/chat_attachment_controller_test.dart`: secret+`filePath` → `enqueueAttachmentFile`, secret+`bytes` → `enqueueAttachment`, web+`filePath` → `enqueueAttachment`; обычный путь: сначала `addOptimisticLocalMessage`, затем `enqueue`, отрицательный `id`, `isSending: true`; форвард не прикрепляет текущий reply; альбом идёт как `document`; повторная вставка тех же файлов в 400 мс отбрасывается |
| Откат | revert по 10a/10b/10c |
| Оценка | **7 ч** (3 + 2.5 + 1.5) |

## A.11 Шаг 11 — `ChatScreenLifecycle`

| | |
|---|---|
| Файлы | **new** `chat_screen_lifecycle.dart`: `initState` (216–277), `dispose` (337–367), `didChangeAppLifecycleState` (370–386), `_applySecureFlag` (282–292), `_handleScreenshotAction` (296–312), `_showScreenshotOverlay`/`_removeScreenshotOverlay` (398–413), `_refreshNow` (725–755), `_autoLoadOlderMessages` (314–322), `_loadOlderMessages` (1116–1131), `_scrollToBottom` (324–334) |
| Обязательно сохранить | `ScreenSecurityService.setSecureFlag(true)` на входе и `false` только в `dispose` (290/364) — парность; `PushNotificationService.setCurrentChat(cid)` и `null` в `dispose`; `markChatAsRead` только при `PushNotificationService.isForeground`; `inlineQueryProvider.clear()` в `try/catch` (358–362) — провайдер может быть уже уничтожен; `_removeScreenshotOverlay()` не вызывается на desktop (375–378); троттлинг скриншота 5 с (299–302) |
| Риск | **средний** — утечка overlay/secure-флага заметна только на устройстве |
| Проверка | new `test/screens/chat_screen_lifecycle_test.dart` с mock `MethodChannel('com.niosmess.pulse/security')`: `true`/`false` парны, `removeObserver`, overlay вставлен на `paused/inactive/hidden` и снят на `resumed`, на desktop overlay не создаётся, `_refreshNow` не падает при ошибке (`debugPrint`) |
| Откат | revert |
| Оценка | **4 ч** |

## A.12 Шаг 12 — разбор `build` + scope-виджеты + smoke-тест

| | |
|---|---|
| Файлы | **new** `chat_detail_body.dart` (тело 2389–2580), `chat_header_scope.dart` (2594–2821), `chat_messages_scope.dart` (2822–2992), `chat_composer_scope.dart` (2993–3191), `chat_detail.dart` (барrel); **new** `test/screens/chat_detail_smoke_test.dart` |
| Что меняется | файл экрана остаётся с `State` (~400 строк) + `_AnimatedMessage`/`_TypingSubtitle` переносятся туда же, где используются (messages scope). `NiosChroma`-обёртка `Theme` и `CallbackShortcuts`/`PopScope` остаются в `build` |
| Обязательно сохранить | `ChatViewport` держит composer и messages раздельно (иначе печатание начнёт перестраивать список; это проверяет `test/widgets/chat_viewport_test.dart`); порядок `ref.listen`-ов в `build` (2341–2375) — они срабатывают при каждом rebuild; порядок веток Esc (2400–2407): edit → reply → back |
| Риск | **средний** (перф-регрессия, а не компиляция) |
| Проверка | `dart test test/widgets/chat_viewport_test.dart` не изменился; smoke-тест монтирует экран с оверрайдами `authProvider`, `chatsProvider`, `chatByIdProvider`, `chatMessagesProvider`, `uiSettingsProvider`, `draftStorageProvider`, `typingProvider`, `privacyProvider`, `inlineQueryProvider`, `uploadQueueProvider`, `secretChatCoordinatorProvider`, `encryptedDraftSyncProvider`, `webSocketClientProvider` + mock security-канала; проверяет: 3 сообщения отрисованы, ввод текста включает send, Esc из режима ответа очищает reply. **Оговорка:** это самый дорогой тест в плане (≈⅔ шага) и он может оказаться флаки — если так, его выносят в отдельный коммит и не блокируют шаг 12 |
| Откат | revert; smoke-тест отдельным коммитом |
| Оценка | **5 ч** (2 ч разбор + 3 ч тест) |

---

# ПЛАН B. `lib/providers/auth_provider.dart` — 9 шагов, ≈31 ч

## B.0 Фактические рёбра (что именно замкнуто)

| # | Ребро | Куда смотрит `auth_provider` | Куда смотрят они |
|---|---|---|---|
| 1 | `auth ↔ web_socket_provider` | `pushStream` (133), `disconnect()` (656), `onConnected` (709–711), `request('register_fcm_token')` (790–807) | `web_socket_provider:27` — `ref.read(authProvider.notifier).logout(eraseSecretData:false)` в `onUnauthorized` |
| 2 | `auth ↔ secret_chat_provider` | статик `SecretChatCoordinator.shutdownAccount` (585), `e2eeServiceProvider` (615) | `secret_chat_provider:1040–1045` (`watch identity`, `read username`), `1105` (`watch userId`) |
| 3 | `auth ↔ call_incoming_provider` | `incomingCallProvider.notifier.set(null)` (561–563) | `call_incoming_provider:74` — `ActiveChatCallsNotifier.build` watch'ит identity |
| 4 | `auth ↔ notifications_provider` | `notificationsProvider.notifier.stopAccount()` (558–560) | `notifications_provider:132` (watch userId), `155`, `226` (`isLoggingOut`) |
| 5 | `auth ↔ auth_repository` | `authRepositoryProvider` (361, 423, 471, 631, 640, 735) | `auth_repository` → `web_socket_provider` → `auth_provider` (через ребро 1); сам читает только `sessionAccessTokenProvider` (101/106/123/161/199/207) |
| 6 | токен/сессия размазаны | `_load`/`_saveSession`/`_clearSessionStorage` (172–346) пишут в `sessionAccessTokenProvider` | `web_socket_client.readToken` читает `sessionAccessTokenProvider`; токен — единственная «ручка», которую нельзя потерять между записью в secure storage и публикацией |

Важно: **Dart не запрещает циклические импорты**, поэтому «цикл» здесь — не ошибка сборки, а
runtime- и test-связанность: `AuthNotifier` при `build()` поднимает `webSocketClientProvider` (133),
а тот в замыкании держит `authProvider.notifier`; logout читает `notificationsProvider`, чей `build()`
смотрит в `authProvider` — отсюда `ref.exists(...)`-страховки (558, 561, 572), которые нельзя убирать
до того, как ребро разорвано.

## B.1 Низкий модуль, который вводится

1. `lib/features/auth/data/auth_session_store.dart` — **хранилище сессии** (не провайдер, не `Ref`):
   `read()`, `write(session)`, `clear()`, `markSignedOut()`, внутри — очередь `_sessionWrites`
   (сейчас 104/112–119), маркер `_signedOutKey`, легаси-миграция `SharedPreferences → FlutterSecureStorage`,
   отбраковка `demo_`-токенов. Сюда переезжают 172–301 (чтение), 303–327 (`_saveSession`), 329–346 (`_clearSessionStorage`).
2. `lib/features/auth/domain/session_identity_provider.dart` — **производный** провайдер
   `Provider<SessionIdentity>` поверх `authProvider.select((a) => (userId, accessToken, username, displayName))`.
   Ключевое решение: он **производный, а не «пушимый»**. Причина фактическая — 61 тест-файл переопределяет
   `authProvider` (список ниже), и «второй источник истины» потребовал бы правки всех 61. Производный вариант
   даёт потребителям узкую зависимость без изменения тестов.
3. `lib/features/auth/domain/auth_lifecycle_provider.dart` — `Notifier<bool> isLoggingOut` (и `Notifier<int> accountEpoch`).
   Пишет только `AuthNotifier` (начало/конец `logout`), читают остальные. Дефолт `false` совпадает с текущим
   поведением тест-двойников, поэтому переключение чтений не ломает тесты.

## B.2 Шаг B1 — `AuthSessionStore` (только перенос, без смены потребителей)

| | |
|---|---|
| Файлы | **new** `lib/features/auth/data/auth_session_store.dart`; **edit** `auth_provider.dart` (172–346 → вызовы стора) |
| Что меняется | стор получает `FlutterSecureStorage` (через `authSecureStorageProvider`), лоадер `SharedPreferences` (`authPreferencesLoaderProvider`), и — обязательно — `bool Function() cancelled`, потому что текущие проверки `_current(epoch)` стоят **между** записью в secure storage и снятием маркера `_signedOutKey` (314–319) и между удалением и `sessionAccessTokenProvider.clear()` (344). Без этого «устаревшая» запись снимет tombstone и воскресит отозванную сессию |
| Риск | **средний** — единственный шаг, который касается логики гонок |
| Проверка | `test/providers/auth_lifecycle_race_test.dart` должен пройти **без изменений** (он уже проверяет `failWrites`/`failDeletes` → `AUTH_SESSION_STORAGE_UNAVAILABLE`, tombstone, `_FailedAutomaticLogout`); new `test/features/auth/auth_session_store_test.dart`: ошибка чтения `prefs` → `error: 'AUTH_LOCAL_STATE_UNAVAILABLE'`; легаси-миграция и удаление plaintext-ключа; `demo_` → `clear()` + `cacheService.clearAll()`; устаревшая запись не снимает tombstone; `clear()` при ошибке удаления бросает `AUTH_SESSION_STORAGE_UNAVAILABLE` |
| Откат | revert; тело методов возвращается в notifier |
| Оценка | **4 ч** |

## B.3 Шаг B2 — `sessionIdentityProvider` + `authLifecycleProvider` (без переключения потребителей)

| | |
|---|---|
| Файлы | **new** два файла из B.1; **edit** `auth_provider.dart`: `logout` ставит `isLoggingOut=true` в lifecycle-нотифаере (и `false` в `finally`, 668) |
| Риск | **низкий** — аддитивно, `authProvider`-поверхность не меняется |
| Проверка | new `test/features/auth/session_identity_test.dart`: identity обновляется при смене `session`, `accountEpoch` растёт только на смену `userId`, `isLoggingOut` поднимается и опускается даже при исключении в logout |
| Откат | revert |
| Оценка | **1.5 ч** |

## B.4 Шаг B3 — разрыв рёбер 2, 3, 4 по чтению (secret_chat, call_incoming, notifications)

| | |
|---|---|
| Файлы | **edit** `secret_chat_provider.dart:1040–1045, 1105`; `notifications_provider.dart:132, 155, 226`; `call_incoming_provider.dart:74` — перевести на `sessionIdentityProvider` / `authLifecycleProvider` и удалить `import auth_provider.dart` из этих трёх файлов |
| Что это даёт | три модуля перестают зависеть от хаба; `AuthNotifier` остаётся единственным писателем состояния |
| Риск | **средний** — `ActiveChatCallsNotifier.build` и `NotificationsNotifier.build` пересоздаются при изменении identity; сейчас они пересоздаются при изменении `(userId, accessToken)` — набор полей в `sessionIdentityProvider.select` должен остаться **точно** `(userId, accessToken)`, иначе лишние rebuild (сброс баннера звонка/истории уведомлений) |
| Проверка | `dart test test/providers/secret_coordinator_lifecycle_test.dart test/providers/notification_reliability_test.dart test/notifications/notification_mute_gate_test.dart test/providers/incoming_call_delivery_test.dart test/providers/call_session_tick_test.dart`; вручную: вход → звонок в группе → баннер появился; logout → баннер исчез |
| Откат | revert (3 файла) |
| Оценка | **3 ч** |

## B.5 Шаг B4 — ребро 1: `SessionInvalidationSink`

| | |
|---|---|
| Файлы | **new** `lib/features/auth/domain/session_invalidation.dart` (`class SessionInvalidation {void Function()? handler; void invoke();}` + `Provider`); **edit** `web_socket_provider.dart:20–38` (`onUnauthorized: () => ref.read(sessionInvalidationProvider).invoke()`, импорт `auth_provider` удаляется); **edit** `auth_provider.dart` — в `build()` установить `handler = () => unawaited(logout(eraseSecretData:false))` с проверкой `ref.mounted`, в `onDispose` (159–164) обнулить |
| Риск | **средний** — при ошибке 401 вызов идёт из сетевого колбэка: возможна реэнтрантность `logout → disconnect → onUnauthorized`; хендлер должен быть идемпотентным (`_loggingOut` уже это даёт) |
| Проверка | `test/providers/auth_lifecycle_race_test.dart:390` (`_FailedAutomaticLogout`) — тест **обязан** остаться зелёным; он проверяет, что падение авто-logout не роняет сокет. Если он перестал видеть вызов, значит sink не установлен — это регрессия |
| Откат | revert |
| Оценка | **2.5 ч** |

## B.6 Шаг B5 — ребро 3: убрать `incomingCallProvider.set(null)` из logout

| | |
|---|---|
| Файлы | **edit** `call_incoming_provider.dart` — `IncomingCallNotifier.build()` начинает `ref.watch(sessionIdentityProvider.select((i) => i.userId))` и возвращает `null`; **edit** `auth_provider.dart` — удалить 561–563 |
| Риск | **средний** — до этого `incomingCallProvider` вообще не зависел от сессии; после — сброс при смене аккаунта происходит **в момент** публикации identity, а не в середине logout. Порядок «сначала сбросить звонок, потом стирать данные» сохраняется: identity меняется в `finally` (663) уже после очистки |
| Проверка | `dart test test/providers/incoming_call_delivery_test.dart test/widgets/call_media_hub_test.dart`; вручную: входящий звонок → logout → экран звонка закрыт, повторный вход не показывает старый звонок |
| Откат | revert |
| Оценка | **1.5 ч** |

## B.7 Шаг B6 — ребро 4: убрать `notificationsProvider.notifier.stopAccount()`

| | |
|---|---|
| Файлы | **edit** `notifications_provider.dart` — `build()` дополнительно смотрит `authLifecycleProvider` (или `accountEpoch`) и при «начался logout» возвращает `const NotificationsState()`; **edit** `auth_provider.dart` — удалить 558–560 |
| Почему это отдельный шаг | сейчас `stopAccount()` вызывается **до** остановки хендлеров и до стирания истории (558 против 566–605). Если просто удалить вызов, `NotificationsNotifier` продолжит принимать пуши до конца logout и может записать историю после `eraseAccount` — тихая потеря/воскрешение уведомлений |
| Риск | **средний-высокий** |
| Проверка | `dart test test/notifications/notification_reliability_test.dart test/notifications/notification_mute_gate_test.dart test/providers/notification_preferences_test.dart`; вручную: 3 непрочитанных → logout → пусто и после повторного входа; push во время logout не появляется и не пишется в историю |
| Откат | revert |
| Оценка | **3 ч** |

## B.8 Шаг B7 — вынести FCM-регистрацию

| | |
|---|---|
| Файлы | **new** `lib/features/auth/application/fcm_registration.dart` (~200 строк): 681–765 (`_registerFcmToken`, `_drainNotificationRegistration`, `_registerFcmTokenOnce`), 767–817 (`_sendFcmTokenWithRetry`), 819, поля 121–123; **edit** `auth_provider.dart`: после логина/загрузки — `ref.read(fcmRegistrationProvider.notifier).ensure(...)` (291–300, 401–407) |
| Обязательно сохранить | `_wsConnectedSubscription ??=` — одна подписка на реконнект; `!identical(state.session, session)` после **каждого** `await` (730, 740, 751); ранний выход на desktop (702–704); payload `notification_protocol: 2`, `muted_chat_ids` из префикса `chat_notifications_muted_<userId>_`, `locale`; 3 попытки с задержкой `attempt * 2` секунд; `PushNotificationService.deviceRegistered` |
| Риск | **средний** — сетевой код с ретраями, легко потерять guard |
| Проверка | new `test/features/auth/fcm_registration_test.dart` (fake `WebSocketClient.request`): payload полностью совпадает с текущим; 3 попытки и `FCM_REGISTRATION_PENDING` при постоянной ошибке; при выключенных уведомлениях — `unregisterFcmToken` вместо регистрации; смена сессии во время запроса не отправляет токен новой сессии под старым |
| Откат | revert |
| Оценка | **5 ч** |

## B.9 Шаг B8 — вынести оркестрацию logout

| | |
|---|---|
| Файлы | **new** `lib/features/auth/application/account_shutdown.dart` (~140 строк): 545–645 (tombstone → `notifications/incomingCall` → `Future.wait` стоп-хендлеров → `eraseAccountData = eraseSecretData && handlersStopped` → `SecretChatCoordinator.shutdownAccount` + `chatIds` → стирание `DraftStorage`/`EncryptedMessageCache`/`e2eeService`/`draft.<id>` → best-effort revocation). `AuthNotifier.logout` остаётся: флаг, `_authEpoch++`, вызов, `finally` (очистка стора, `clearAll`, состояние) |
| Обязательно сохранить | порядок: tombstone **первым**; `secretStopped`; при `handlersStopped == false` данные **не** стираются (581); `chatIds` из secret-shutdown используются для `EncryptedMessageCache.clearAccount` (609); `eraseSecretData:false` (авто-logout по 401) не стирает ничего |
| Риск | **высокий** — единственный шаг, где ошибка приводит к невосстановимой потере данных или воскрешению сессии |
| Проверка | `dart test test/providers/auth_lifecycle_race_test.dart` (там уже есть `_FailedCallShutdown` и `_PendingCallShutdown` — оба про порядок и про `AUTH_LOGOUT_CLEANUP_INCOMPLETE`), `test/widgets/account_deletion_screen_test.dart`; вручную: logout с идущей загрузкой и с секретным чатом, повторный вход |
| Откат | revert |
| Оценка | **6 ч** |

## B.10 Шаг B9 (опционально) — реестр задач выключения аккаунта

| | |
|---|---|
| Файлы | **new** `lib/features/auth/domain/account_shutdown_tasks.dart` (`Provider<List<AccountShutdownTask>>`, по умолчанию пусто); реализации в `secret_chat_provider`, `call_session_provider`, `notifications_provider`; сборка списка — в `main.dart` (`ProviderScope(overrides: [...])`, строка 73) |
| Что даёт | `auth_provider.dart` перестаёт импортировать `secret_chat_provider`/`call_incoming_provider`/`notifications_provider`/`call_session_provider`; последние 4 импорта уходят, хаб становится листом |
| Риск | **высокий** — если оверрайд забыт (тесты, второй вход в приложение), logout молча перестаёт останавливать секретные чаты и звонки. Дефолт «пустой список» = тихая регрессия |
| Проверка | тест, который падает, если список пуст при непустом аккаунте: `expect(tasks, isNotEmpty)` в интеграционном `test/integration/secret_chat_backend_test.dart`-стиле; полный `dart test test/suite_test.dart` |
| Откат | revert |
| Оценка | **4 ч** |
| Решение | делать **только** если после B8 остаётся потребность в чистом графе импортов. Для поведения он не нужен |

---

# C. Что НЕ трогать

**В `chat_detail_screen.dart`:**
1. `ChatComposerState.copyWith` с функциями-писателями (`chat_detail_input_area.dart:33–46`). `replyToMessageId: null` значит «не менять», `() => null` — «очистить». «Упрощение» до обычных nullable-полей тихо ломает очистку reply при отправке.
2. `ChatScrollCoordinator` и разделение `ChatViewport` на `messagesBuilder`/`composer` — это работающая перф-гарантия (`test/widgets/chat_viewport_test.dart` утверждает, что ввод не перестраивает список).
3. `_composerNotifier` как `ValueNotifier`, а не провайдер: `_ChatComposerScope` и `ChatDetailInputArea` читают его синхронно, вне Riverpod.
4. Порядок в `dispose` (337–367): `removeObserver` → cancel AI → `removeScreenshotOverlay` → `scrollCoordinator.dispose` → `_saveDraft()` → `_inputController.dispose()` → `inlineQuery.clear()` → снять secure flag.
5. `ScreenSecurityService.setSecureFlag` — парность true/false, вызовы без `await` (fire-and-forget) оставить как есть.
6. Латч `_isSecret`: `bool _isSecret = false` + `if (isSecret && !_isSecret)` (2372–2375). Он не даёт «разжаловать» секретный чат при обновлении метаданных.
7. Паттерн `ref.read(chatByIdProvider(_chatId ?? 0))?.isSecret != false` (418–419, 443–444): «метаданных нет → считаем секретным/запрещённым». Замена на `== false` инвертирует защиту.
8. Строковая классификация ошибок отправки (906–909) — пока сервер не отдаёт код, это контракт.
9. `_secretCoordinator` и `_draftStorage`, кэшированные до `dispose` (113, 219).

**В `auth_provider.dart`:**
10. `_current(epoch, [session])` (106–110) и все поля-эпохи `_authEpoch`/`_profileRequest`/`_profileMutation` — это защита от гонок аккаунтов; ни один шаг не должен ослабить `identical(state.session, session)`.
11. Очередь `_sessionWrites` (112–119) — сериализация записи/удаления сессии.
12. Маркер `_signedOutKey` и правило «tombstone раньше удаления» (550–557).
13. `ref.exists(...)`-страховки перед `stopAccount`/`incomingCall.set`/`callSession.shutdown` (558, 561, 572) — до разрыва соответствующего ребра они предотвращают создание провайдера во время logout.
14. `logout(eraseSecretData: false)` из авто-logout по 401 — не стирает данные.
15. `updateAiUsage` — вызывается из `ai_repository` в двух местах (122, 171); это публичный метод нотифаера, не переносить.

---

# D. Где можно сломать поведение незаметно

| Место | Как проявляется | Чем ловится |
|---|---|---|
| `_saveDraft()` в `dispose` (354) | последние ≤500 мс набранного текста теряются, если контроллер черновика уничтожен раньше | тест на порядок `dispose` + ручной сценарий «набрал → назад → вернулся» |
| `applyRemote` из `liveDraftMapProvider` (2361–2371) | синхронизированный черновик с другого устройства перетирает ввод, если убрать проверку `text.trim() == before` | тест: локальный текст изменён → remote не применяется |
| `_showDraftRestoredBanner` | баннер «черновик восстановлен» остаётся висеть после очистки | widget-тест композера |
| Троттлинг скриншота 5 с (299–302) | двойной тост + два системных сообщения в чат | тест с fake clock |
| `_pasteDeduplicator` (400 мс) | одна вставка уходит дважды (Ctrl+V обрабатывается и шорткатом, и полем — см. комментарий 2414–2415) | тест на повторный вызов |
| `typingProvider.sendTyping` (425–431) | индикатор «печатает» не гаснет или не появляется, если перенести `_onInputChanged` целиком | ручной сценарий в двух клиентах |
| `markRead` только при `isForeground` (255, 329–331, 339–342) | непрочитанные не сбрасываются после выхода из чата | ручной: фон → открыть чат → вернуться |
| `int.parse(localId)` (999) | исключение при неотрицательном id → вложение не отправляется | тест на знак id |
| `attachCurrentReply: false` у форварда (1587) | форвард прикрепляет reply из текущего композера | тест форварда |
| `identity != (userId, accessToken)` (1312/1326/1334) | правка/отправка «протекает» в чужой аккаунт после смены пользователя | тест смены сессии в середине операции |
| `identical(state.session, session)` в FCM-цикле (730/740/751) | токен старого аккаунта регистрируется новому | тест `fcm_registration` |
| `_wsConnectedSubscription ??=` (709) | после нескольких логинов остаётся подписка от первого клиента | тест «логин → логаут → логин» |
| Порядок erase при `handlersStopped == false` (581) | секретные ключи стёрты при живом хендлере → нечитаемая история | `auth_lifecycle_race_test` |
| `notifications`-сброс | push во время logout пишется в историю уже после `eraseAccount` | `notification_reliability_test` |
| `_loadingOlderNotifier` (134) | повторная автоподгрузка при быстром скролле (двойные страницы) | тест на повторный вход в `_autoLoadOlderMessages` |

---

# E. Сводка

| План | Шагов | Часы | Крупнейшие шаги |
|---|---|---|---|
| A. `chat_detail_screen.dart` | 12 | **53** | A10 загрузки (7), A9 отправка (6), A8 действия (6) |
| B. `auth_provider.dart` | 9 | **31** | B8 logout (6), B7 FCM (5), B1 session store (4) |
| **Итого** | **21** | **84 ч** | без ревью/QA; с буфером 20 % ≈ **100 ч** |

Порядок исполнения: A1 → A3 → A2 → C-коммит (закрепление) → B1 → B2 → B3 → B4 → B5 → B6 → B7 → B8 → затем
A4…A12 (они не пересекаются с auth-файлами, кроме `ai_repository`/`authProvider` в чтении, которое не меняется).
Если нужен только один план — начинать с B1/B4: там меньше файлов и есть покрытие тестами.

## Три самых опасных шага

1. **A10 — `ChatAttachmentController`** (927–1060 + 4 входа, 7 ч). Четыре входа (пикер, desktop-вставка/дроп, голос/кружок, форвард) × два хранилища (secret `enqueueAttachment*` и обычный `uploadQueue`) × владение reply/caption. Ошибка не падает: вложение уходит дважды, теряет подпись или прикрепляет чужой reply. Тестов на экран нет — регрессию поймает только новый unit-тест и ручной прогон.
2. **A9 — `ChatSendController`** (795–925, 6 ч). Логика `savedLocally`/`whenComplete`/`onLocalSaved` и восстановление текста «только если пользователь не начал печатать заново» — это защита от затирания ввода и от двойной отправки. Плюс классификация серверных ошибок по подстрокам и общий флаг `_savingSecretMessage` для двух путей. Тихое повреждение: дубль сообщения или пропавший текст.
3. **B8 — вынос оркестрации logout** (545–645, 6 ч). Порядок необратим: tombstone → стоп хендлеров → `eraseAccountData` → стирание ключей/кэшей по `chatIds` от secret-shutdown → best-effort revoke. Ошибка в порядке = либо невосстановимая потеря секретных данных при живом хендлере, либо воскрешение отозванной сессии на следующем холодном старте. Проверяется только `auth_lifecycle_race_test` и ручным сценарием.

Отдельно: **у `chat_detail_screen.dart` нет ни одного теста** (0 импортов в `test/`), поэтому первые шаги плана A
обязаны быть «безрисковыми переносами» с новыми unit-тестами, а не переписыванием.

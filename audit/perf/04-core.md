# Аудит производительности — зона `lib/core/**`

Дата: 2026-11-25
Объём зоны: 129 dart-файлов в `pulse_flutter/lib/core/` (все подпапки + корневые файлы).
База проверки: https://docs.flutter.dev/perf/best-practices + «Motion & Performance Protocol» из `AGENTS.md`.
Метод: grep по классам нарушений → чтение окружающего кода для **каждого** хита. Ничего не правилось, сборка не запускалась.

## Счётчики

| severity | count |
|---|---|
| blocker | 0 |
| major | 3 |
| minor | 9 |
| nit | 7 |

Итого 19 находок. Отсутствие `blocker` — не вежливость: в `core` действительно нет ни одного saveLayer-в-цикле, ни одной неленивой прокрутки, ни одного `AnimationController` в `build()`.

---

## major

### M1. Телеметрия сама себе роняет кадр: 3 сортировки по 7200 элементов раз в секунду на UI-изоляте
`core/performance/frame_timing_monitor.dart:286` (+ `:300-305`), `core/performance/adaptive_performance_provider.dart:122`, `:273`

```dart
// frame_timing_monitor.dart:286
final List<FrameMetric> metrics = currentMetrics;
// :300-305
final List<double> builds =
    metrics.map((m) => m.buildDurationMs).toList(growable: false)..sort();
```
```dart
// adaptive_performance_provider.dart:122
final FrameTimingMonitor _telemetry = FrameTimingMonitor(capacity: 7200);
// :273  (внутри addTimingsCallback → onTimings, т.е. на UI-изоляте)
final snapshot = _telemetry.createSnapshot(
```

**Правило:** п.7 (тяжёлая работа в main isolate, кадр 16 мс) + п.5 (сортировки в горячем пути).

**Почему реально дорого.** `_publishTelemetry` троттлится до 1 раза в секунду, но внутри одной публикации: `currentMetrics` аллоцирует список из 7200 объектов, затем **три** `map().toList()..sort()` по 7200 double (≈ 290k сравнений суммарно) плюс пять линейных проходов по 7200 (`averageBuildMs`, `averageRasterMs`, `getJankRatio`, `getUiJankFrames`, `getRasterJankFrames`). Всё это исполняется в `addTimingsCallback`, то есть на UI-изоляте, раз в секунду, и может совпасть с уже занятым кадром. Кол-во аллокаций за секунду: ~6 списков по 7200 (≈ 340 КБ мусора). Оценка стоимости 2–4 мс/с — **требует замера** (DevTools Timeline, метка `niosmess.frame_metrics` при `--dart-define=PERF_TRACE`).

**Фикс.** Считать средние и jank-счётчики инкрементально в `recordMetric` (бегущая сумма + счётчик), а перцентили — по фиксированному гистограммному массиву бакетов (например, 0.5 мс × 64 бакета, O(64) на публикацию вместо O(n log n)). Альтернатива: `compute()` для `createSnapshot` (snapshot уже immutable) либо `capacity: 600` + публикация раз в 5 с.

---

### M2. Сериализация до 2000 сообщений на UI-изоляте перед `Isolate.run`
`core/storage/encrypted_message_cache.dart:236-242`

```dart
final int maxLimit = isSecretChat ? 2000 : 100;
final List<Map<String, dynamic>> messagesJson = messages.length > maxLimit
    ? messages.sublist(messages.length - maxLimit).map((m) => m.toJson()).toList()
    : messages.map((m) => m.toJson()).toList();
```

**Правило:** п.7 (тяжёлая работа в main isolate вместо `compute`/`Isolate`).

**Почему реально дорого.** `jsonEncode` ушёл в изолят (строка 244), а вот `toJson()` для каждого из 2000 сообщений строится **до** этого, синхронно на UI-потоке: 2000 `Map<String,dynamic>` по ~10–14 ключей ≈ 25k записей. Это самый дорогой кусок при закрытии/сворачивании секретного чата — единый синхронный блок 8–30 мс (**требует замера**), то есть гарантированный пропуск кадра при выходе из чата с длинной историей.

**Фикс.** Передавать в изолят сам `List<ApiMessage>` (`ApiMessage` — обычная модель, копируется через `SendPort`) и вызывать `.map((m) => m.toJson())` внутри `_runCompute`; при необходимости — резать по `maxLimit` до передачи и отдавать байты, а не строку.

---

### M3. `MediaPlaybackVisibility`: обход дерева рендер-объектов на каждое scroll-уведомление, для каждого медиа-виджета
`core/media/media_playback_visibility.dart:50`, `:55-80`

```dart
void _onScroll(ScrollNotification _) => _scheduleCheck();
...
WidgetsBinding.instance.addPostFrameCallback((_) {
  ...
  RenderObject? ancestor = box.parent;
  while (ancestor != null) { ... viewportBounds = viewportBounds.intersect(
        viewportBox.localToGlobal(Offset.zero) & viewportBox.size); ... }
```

**Правило:** п.7 (горячий путь, отсутствие coalescing) + п.4 протокола (Clip/пересчёт в переиспользуемых плитках).

**Почему реально дорого.** Виджет оборачивает **каждый** медиа-бабл: `widgets/chat/bubble/bubble_circle_player.dart:224`, `bubble_sticker_player.dart:280`, `media_album_bubble.dart:96`, `noto_message_emoji.dart:325`, `video_message_preview.dart:197`. `ScrollNotificationObserver` эмитит `ScrollUpdateNotification` каждый кадр скролла, значит при 10–16 смонтированных медиа-баблах получаем 10–16 post-frame колбэков за кадр, в каждом — `localToGlobal` (обход цепочки трансформов) и обход предков до корня (20–40 узлов). Итого десятки `localToGlobal` и сотни итераций по дереву **каждый кадр прокрутки** — при этом видимость меняется в лучшем случае раз на границу вьюпорта. Насколько это заметно — **требует замера** (DevTools, профиль скролла ленты с GIF), но архитектурно это O(N × depth) на кадр, и N не ограничен.

**Фикс.** Один общий «планировщик проверок» на кадр: статический `SchedulerBinding`-hook, который собирает зарегистрированные инстансы и считает их видимость один раз за кадр (или только для тех, у кого изменился layout), а не по колбэку на инстанс. Дополнительно: не пересчитывать при `_foreground == false` и дебаунсить до `ScrollEndNotification` + редкого таймера при продолжающемся скролле.

---

## minor

### m1. `SpringCurve.transformInternal` пересчитывает `_rawResponse(settleTime)` на каждом кадре
`core/motion/m3_spring_constants.dart:114-120`

```dart
final double raw = _rawResponse(t * span);
final double rawEnd = _rawResponse(span);
```
**Правило:** п.7 (`core/motion`: «отсутствие аллокаций в transform» — аллокаций нет, но есть лишняя трансцендентная математика).
`rawEnd` — константа для каждого из шести токенов (const-объекты), но каждый вызов `transform` (то есть каждый кадр любой spring-анимации) делает `sqrt(stiffness/mass)` + `exp` + `cos`/`sin` **дважды**. При входных анимациях 10–20 плиток это ~40 лишних `exp/cos/sin` на кадр. Стоимость мала (**требует замера**), но фикс бесплатный.
**Фикс:** держать предвычисленные `omegaN` и `rawEnd` рядом с токенами: `static const` не даст (конструктор `const`, поля final), поэтому — либо non-const объекты с `late final double _rawEnd = _rawResponse(span);` на инстанс, либо `static final Map<SpringCurve, double>` / отдельный класс `_PreparedSpring`, которым инициализируются токены `M3SpringCurves`.

### m2. `RegExp` литералом в самых горячих хелперах дат
`core/utils/datetime_helpers.dart:55`, `:200`

```dart
final locale = (localeCode ?? AppTimeSettings.localeCode).split(RegExp(r"[_-]")).first;   // :55
return RegExp(r'(?:[tT ].*)(?:[zZ]|[+-]\d\d(?::?\d\d)?)$').hasMatch(value);              // :200
```
**Правило:** п.7. `formatRelativeTime` вызывается в `itemBuilder` списка чатов (`screens/chat_list_screen.dart:1041`) и в каждой карточке ленты (`widgets/post_card.dart:583`), то есть на каждый билд плитки при скролле; `parseApiDateTime` — на каждое сообщение при разборе страницы истории. `RegExp(...)` компилируется заново при каждом вызове (в отличие от `chat_media_cache.dart:20` и `message_formatter.dart:5-6`, где паттерны корректно вынесены в `static final`).
**Фикс:** `static final RegExp _localeSeparator = RegExp(r'[_-]');` и `static final RegExp _explicitTz = RegExp(...)` — на уровне библиотеки.

### m3. `messagePreviewText`: разбор Markdown и `RegExp` на каждый вызов, кэш обходится вызывающим
`core/utils/message_preview_text.dart:36-43`

```dart
final document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored, encodeHtml: false);
for (final node in document.parseLines(source.split('\n'))) { write(node); }
final plain = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
```
**Правило:** п.7. `StringBuffer` тут применён правильно (п.2 — ок), но `md.Document` создаётся и парсит на каждый вызов, плюс `RegExp(r'\s+')` компилируется каждый раз. `MessagePreviewFormatter` (строка 48) кэширует, но ветка черновика его обходит: `screens/chat_list_screen.dart:1038` вызывает сырой `messagePreviewText(draft!)` прямо в `itemBuilder` — то есть Markdown-парсер на каждый билд строки с черновиком при скролле.
**Фикс:** вынести `RegExp(r'\s+')` в `static final`; в `chat_list_screen` использовать `_previewFormatter.format(draft!)` (форматтер там уже создан, строка 456). Стоимость одного парса — микросекунды, но их N на кадр.

### m4. `SmoothTextStreamer`: таймер 16 мс вместо vsync + `substring(0, n)` на каждый тик
`core/motion/smooth_text_streamer.dart:69`, `:108`

```dart
_ticker = Timer.periodic(const Duration(milliseconds: 16), _onTick);
...
_currentRendered = target.substring(0, nextLength);
```
**Правило:** п.7 (`main isolate`, кадр в 16 мс). `Timer.periodic` не синхронизирован с vsync — на 120 Гц даёт «догоняющие» пачки колбэков, на загруженном кадре колбэк приходит позже и текст дёргается. `substring(0, n)` копирует всю строку на каждом тике: для 4000 символов это O(n²) суммарно (≈ 8 МБ копий за стрим) и `setState`/rebuild текста 60 раз в секунду. На кадр это 8 КБ в конце стрима — немного, но GC-давление реальное; **требует замера** на длинных AI-ответах.
**Фикс:** гнать тик через `Ticker`/`SchedulerBinding.addPersistentFrameCallback` (или `Ticker` из `SingleTickerProviderStateMixin`, если аниматор переедет в State), увеличить базовый шаг до 32 мс при длинных сообщениях, и вместо полного `substring` держать растущий `List<String>` чанков, отдавая в `Text.rich` только «закрытые» чанки + хвост.

### m5. `AppLogger`: `debugPrint` со стектрейсом в release, копия списка на каждый `entries`
`core/diagnostics/app_logger.dart:102`, `:54`, `:104-106`

```dart
void _add(AppLogEntry entry) {
  debugPrint(entry.toLogLine());      // :102 — работает и в release
  _entries.add(entry);
  if (_entries.length > _maxEntries) { _entries.removeAt(0); }
```
**Правило:** п.7. `debugPrint` не выключен в release (в отличие от `kDebugMode`-веток в `app_sound.dart:260-324`), а `toLogLine()` для ошибок содержит `timestamp.toIso8601String()` + до 24 строк стектрейса. `entries` (строка 54) каждый раз аллоцирует `List.unmodifiable` копию до 500 записей — если экран диагностики её `watch`-ит, то на каждый лог. `removeAt(0)` — O(500) сдвиг, незначимо.
**Фикс:** завернуть `debugPrint` в `if (kDebugMode)`, для ошибок в release писать только `error_type`; `entries` отдавать `UnmodifiableListView(_entries)` (view, без копии).

### m6. Расшифровка WS-сообщений на UI-изоляте для всего, что меньше 64 КБ
`core/network/web_socket_client.dart:657-660`, `:680-683`

```dart
if (!kIsWeb && ciphertextB64.length >= _kCryptoIsolateThresholdBytes) {
  return compute(_decryptEnvelopeWorker, job);
}
return _decryptEnvelopeWorker(job);
```
**Правило:** п.7 (крипто/`jsonDecode` в main isolate). Порог 64 КБ означает, что **все обычные сообщения** (1–8 КБ) расшифровываются и парсятся на UI-потоке: `base64Decode` ×3 + AES-GCM + `utf8.decode` + `jsonDecode` ≈ 0.1–0.3 мс на сообщение. Поштучно это нормально и правильно (изолят дороже самой работы), но при первичной синхронизации истории пачкой в 100+ сообщений набегает 15–30 мс одного кадра (**требует замера**).
**Фикс:** не менять порог, а батчить приём: если за один event-loop тик пришло > N конвертов — отдавать пачку в один `compute` (одна передача управления вместо N). Положительно: `_FrameDecodeGate` (строка 53) уже ограничивает 2 параллельных декода — это правильно.

### m7. `TextPainter` внутри `LayoutBuilder` в теле диалога
`core/modal/app_modal_content.dart:134-148`

```dart
child: LayoutBuilder(builder: (context, constraints) {
  double width = 0;
  for (final action in actions) {
    final painter = TextPainter(...)..layout();
```
**Правило:** п.7 (работа в layout-фазе). `LayoutBuilder` перезапускается на каждый проход layout (в том числе при анимации размера/клавиатуре), и каждый раз для каждой кнопки строится и лэйаутится `TextPainter` (≈ 0.05–0.15 мс на кнопку). Для модалки терпимо, но это измерение текста там, где хватило бы `Wrap`/`OverflowBar` (последний как раз делает ровно это без ручного замера).
**Фикс:** заменить ручной замер + `Row`/`Column` на `OverflowBar(overflowAlignment: OverflowBarAlignment.end, spacing: 8, overflowSpacing: 8)`. Стоимость — ноль ручных `TextPainter`.

### m8. Двойное `jsonEncode` каждого события при сохранении истории уведомлений
`core/notifications/notification_history_store.dart:56-60`

```dart
final snapshot = events.map((e) => jsonEncode(e.toJson())).toList();
...
await box.put('snapshot', jsonEncode(snapshot));
```
**Правило:** п.2/п.7. Каждое событие кодируется в строку, строки складываются в список, список кодируется ещё раз — то есть JSON-экранирование всего содержимого дважды и вдвое больший blob на диске. Вызывается при каждом новом пуше/уведомлении.
**Фикс:** `await box.put('snapshot', events.map((e) => e.toJson()).toList())` — Hive сам сериализует `List<Map>` (как это уже делают `cache_service.dart:127-131` и `chat_media_cache.dart:165-170`), чтение — симметрично.

### m9. `NiosChroma.resolveChromaScheme`: `ColorScheme.fromSeed` на промахе кэша прямо из `build`
`core/theme/nios_chroma.dart:34-35`, `:52-55`; вызов — `screens/chat_detail_screen.dart:2362`

```dart
final String cacheKey =
    '${chatId}_${partnerId}_${userScheme.brightness.index}_${userScheme.primary.toARGB32()}';
...
final ColorScheme harmonizedScheme = ColorScheme.fromSeed(seedColor: harmonizedSeed, ...);
```
**Правило:** п.7 (пересоздание дорогих объектов в build). На попадании — дёшево (конкатенация строки + 2 lookup'а, кэш на 64). Но при первом открытии direct-чата с новым партнёром `ColorScheme.fromSeed` (полная генерация HCT-палитры) идёт синхронно внутри `build` экрана чата — это единичный кадр-хич ~5–20 мс (**требует замера**). Плюс ключ кэша аллоцирует строку на каждый ребилд экрана.
**Фикс:** прогревать схему заранее (при открытии списка чатов / в `initState` через `Future.microtask`) либо кэшировать по `(partnerId, brightness, primary)` без `chatId` (chatId в ключе не нужен — схема зависит только от партнёра и темы), чтобы кэш реально попадал между чатами с одним партнёром.

---

## nit

### n1. `getBubbleRadius` аллоцирует `Radius`/`BorderRadius` на каждый бабл
`core/theme/expressive_tokens.dart:308-343`, вызов — `widgets/message_bubble.dart:250`
```dart
final Radius rLg = Radius.circular(baseRadius);
final Radius rSm = Radius.circular((baseRadius * 0.6).clamp(8.0, 16.0));
```
3 аллокации + `clamp` на каждый билд каждого бабла. Всего 4 «формы» (2 стороны × кластерные позиции) при фиксированном `baseRadius` — просится мемоизация по `(isOutgoing, position, baseRadius)` или `switch` с константными `BorderRadius.only`. Плюс `baseRadius * 0.6` не может дать `const`. Ничтожно по отдельности, но это горячий список.

### n2. `AppTypography.textTheme` — геттер, собирающий весь `TextTheme` (16 `TextStyle`) на каждое обращение
`core/theme/app_typography.dart:26`
```dart
static TextTheme get textTheme => build(const ColorScheme.light());
```
Сейчас не используется (единственный вызов — `app_theme.dart:63` через `build(scheme)`), то есть это мёртвый код-ловушка: первый, кто напишет `AppTypography.textTheme`, получит 16 аллокаций `TextStyle` + список `FontFeature` на каждый билд и, что хуже, цвета от `ColorScheme.light()` в тёмной теме. Удалить.

### n3. `getIconForFileType` / `getIconColorForFileType`: два `toLowerCase()` и дублирующиеся цепочки по ~40 `endsWith`
`core/utils/shared_utilities.dart:19-49`, `:56-70`
Вызывается на каждый билд бабла с файлом. Две почти идентичные цепочки (иконка/цвет) + `lower()` на mime и на имени. Дёшево на вызов, но заменить на один разбор расширения (`fileName.split('.').last`) и `Map<String, IconData>` (как уже сделано в `file_type_detector.dart:_typeMap`).

### n4. `MediaQuery.of` вместо `.sizeOf` в билдерах модалок
`core/modal/app_modal.dart:77`, `:153`
```dart
final media = MediaQuery.of(ctx);
```
Подписывает билдер на весь `MediaQueryData` (включая `textScaler`, `platformBrightness` и т.д.). Здесь реально нужны `size`, `viewInsets`, `padding` — почти всё, поэтому эффект мал; правильнее `MediaQuery.sizeOf(ctx)` + `viewInsetsOf(ctx)` + `paddingOf(ctx)`, чтобы смена `textScaler` не ребилдила оболочку шторки.

### n5. `extractMonogram` компилирует `RegExp` на каждый промах кэша; `NiosMarkData ==` игнорирует половину полей
`core/identity/nios_mark.dart:83`, `:45-55`
```dart
final parts = trimmed.split(RegExp(r'\s+'));
```
Вызывается только на промахе `_markCache` (256), то есть редко — потому nit: вынести `static final RegExp _whitespace`. Заодно `operator ==` сравнивает только `id/seed/color/shape` (не `monogram/accentColor/tiltDegrees`): не перф, но равенство «полу-истинное» и `hashCode` с ним согласован — риск логических багов при кэшировании по `==`.

### n6. `_entries.removeAt(0)` в логгере
`core/diagnostics/app_logger.dart:105` — сдвиг до 500 указателей после каждого лога сверх лимита. Заменить кольцевой буфер или `_entries.removeRange(0, _entries.length - _maxEntries)` раз в N. Практически не видно.

### n7. `Clip.antiAlias` на всей поверхности модалки, включая side sheet с целым экраном
`core/modal/m3_modal_surface.dart:121`
```dart
clipBehavior: Clip.antiAlias,
```
Для скруглённой шторки клип нужен, но для `ModalVariant.sideSheet` (внутри — целый экран настроек, `Expanded(child: content)`, строка 96-97) это клип всего поддерева: лишний проход клиппинга при каждом репейнте. Поставить `Clip.none` для `sideSheet` (у него всё равно скруглены только левые углы, а контент — обычные прямоугольники) и оставить `antiAlias` для dialog/bottomSheet.

---

## Что проверил и признал нормальным

1. **`core/theme` — кэш темы работает.** `AppTheme.themed` (`app_theme.dart:15-16`, `:37-51`, `:454-458`) держит LRU на 64 `ThemeData` с ключом `Object.hash` из 8 значимых полей и переустанавливает элемент при попадании. `ColorScheme.fromSeed` + 16 `TextStyle` + ~30 `*ThemeData` собираются только на промахе. `main.dart:394/400` вызывает его внутри `build`, но это lookup, а не пересборка. `AppSurfaces.neutralize` и `AppRadiiTheme.fromCornerRadius` — чистые функции поверх уже готовой схемы.
2. **`core/motion` — нормализация и токены корректны.** `SpringCurve.transformInternal` делит на `_rawResponse(settleTime)`, поэтому `f(0)==0` и `f(1)==1`; `transform` клампит `t∈[0,1]`. Все шесть токенов `M3SpringCurves` и `M3Spring` — `const`, внутри `build` ни один curve-объект не создаётся (grep по `SpringCurve(|Cubic(` дал только объявления в токенах). Никакого overshoot на прозрачности: opacity везде идёт через `effects*`/`expressive*`/`Interval(Cubic)` — `m3_page_transitions.dart:19-28`, `m3_modal_route.dart:36-40`, `app_illustration.dart:113-117`; `spatialDefault` (overshoot ~1.5 %) применяется только к позиции/масштабу. `AnimatedBuilder` в `nios_dismissible.dart:204-228` и `m3_page_transitions.dart:154-159` — с `child`, тяжёлое поддерево не перестраивается.
3. **Save-layer'ов, неленивых списков и intrinsic-проходов в `core` нет.** Grep по `Opacity(|ClipRRect|ClipOval|ClipPath|BackdropFilter|ShaderMask|MaskFilter.blur|antiAliasWithSaveLayer|IntrinsicWidth|IntrinsicHeight` по всему `lib/core` — **0 хитов** (единственный `ColorFilter` — `illustration/app_illustration.dart:34`, это перекраска одной SVG, не saveLayer на поддереве; единственный клип во всей зоне — `Clip.antiAlias` поверхности модалки, см. n7). Прозрачность везде через `withValues(alpha:)`. Ни `ListView(children:)`, ни `GridView.count`, ни `shrinkWrap` в `core` нет (UI-списки живут вне зоны). `AnimationController` создаётся только в `initState` (`app_illustration.dart:99-121`).
4. **Тяжёлые операции вне UI-потока там, где это ожидаешь.** `e2ee_file_crypto.dart:29-41` (очередь `_fileWork` + `Isolate.run`, порог 256 КБ), `sticker_formatter.dart:59` (`compute`), `local_storage_service.dart:184` (`compute(_scanDirectories, paths)` для обхода тысяч файлов), `encrypted_message_cache.dart:148-153` (`Isolate.run`, JSON+AES там же), `background_stream_crypto.dart:43` (`Isolate.run`), `hive_bootstrap.dart` (одна инициализация на всё приложение). `AppSound` поднимает 9 `AudioPlayer`-ов один раз за `_initialize()` (`app_sound.dart:270-325`), а не на каждое событие.
5. **`core/performance` действительно работает, а не лежит мёртвым грузом.** `adaptivePerformanceProvider` читается в `main_shell_screen.dart:113/711`, `app_bottom_nav.dart:43`, `app_nav_rail.dart:40`, `adaptive_glass.dart:42`, `bubble_sticker_player.dart:96/119/162`, `chat_message_list.dart:613`; `setInteractionActive` вызывается из скролла чата и шелла (`chat_message_list.dart:427/432`, `main_shell_screen.dart:149`) — то есть смена тира во время жеста действительно блокируется, а `AnimatedMediaControllerPool` на `tierC`/быстром скролле выдаёт `0` активных декодеров (`animated_media_controller_pool.dart:74-83`). Замечание только к цене телеметрии (M1).

---

## Что требует профилирования, а не чтения кода

- **Скролл ленты чата с GIF/стикерами/видео** — цена `MediaPlaybackVisibility` (M3): сколько инстансов реально смонтировано и сколько даёт post-frame обходов на кадр. Нужен DevTools Timeline в профиле с реальными баблами.
- **Пик раз в секунду от телеметрии** (M1): видно как одиночный «толстый» UI-фрейм каждую секунду; проверить на 60 и 120 Гц и на `capacity: 7200`.
- **Закрытие секретного чата с историей ~2000 сообщений** (M2): длительность синхронного блока `toJson` — сравнить до/после переноса в изолят.
- **Первое открытие direct-чата с новым партнёром** (m9): `ColorScheme.fromSeed` + `Blend.harmonize` в кадре — замер FrameTiming на холодном кэше.
- **Длинный потоковый AI-ответ** (m4): дрожание текста на 120 Гц и GC-паузы от `substring`.
- **Холодный старт**: `getCachedChats`/`getCachedMessages` (`cache_service.dart:137-151`, `:186-200`) парсят весь кэш синхронно на UI-изоляте — вне моего горячего пути, но это первый кандидат на «белый экран» при N>500 чатов; нужен `Timeline` от `runApp` до первого кадра.
- **Burst-приём истории по WS** (m6): 100+ конвертов подряд — суммарное время `_decryptEnvelopeWorker` в одном кадре.

# Аудит производительности — чат-стек

Зона: `lib/widgets/chat/**` (включая `bubble/**`), экраны `lib/screens/*chat*`,
плюс фактически входящие в чат-стек `lib/widgets/message_bubble.dart`,
`lib/widgets/chat_tile.dart`, `lib/widgets/voice_message_player.dart`,
`lib/widgets/wallpaper/chat_wallpaper_background.dart`.

Эталон: https://docs.flutter.dev/perf/best-practices + «Motion & Performance Protocol» (AGENTS.md).
Метод: grep по каждому правилу → чтение окружающего кода → находка/опровержение.
Сборка не запускалась, `lib/` не правился. Игнорировались `*.g.dart`, `*.freezed.dart`,
`lib/l10n/secret/generated/**`, `build/`, тесты.

Дата: 2026-11-25.

---

## Счётчики

| Severity | Кол-во |
|---|---|
| blocker | 0 |
| major | 3 |
| minor | 8 |
| nit | 6 |

Явных блокеров в зоне нет: список сообщений ленивый (два `SliverList` с
`SliverChildBuilderDelegate`), у каждой строки свой `RepaintBoundary`,
индекс O(1), тяжёлые медиа-контроллеры загейчены пулом. Ниже — то, что реально
осталось.

---

## MAJOR

### M1. Голосовое сообщение поднимает плеер и качает файл прямо из `initState`, без гейта видимости

`F:\Niosmess V2\pulse_flutter\lib\widgets\voice_message_player.dart:72`, `:79`, `:153-181`
(вызывается из бабла: `lib\widgets\message_bubble.dart:864-878`, бабл строится
строкой списка `lib\widgets\chat\chat_message_list.dart:636`)

```dart
58:   late final AudioPlayer _player;
72:     _player = AudioPlayer(handleInterruptions: true);
79:     _setupPlayer();
...
164:       final source = await WsMediaFetcher.acquirePlaybackSource(
165:         filePath: widget.audioUrl,
177:         await _player.setAudioSource(
```

Нарушено: «тяжёлая работа в main isolate / файловые операции и сеть вне кадра»,
плюс собственный протокол проекта — все остальные медиа в чате гейтятся
видимостью и бюджетом (`AnimatedMediaControllerPool` + `MediaPlaybackVisibility`,
см. `bubble_sticker_player.dart:153`, `video_message_preview.dart:89-119`,
`media_album_bubble.dart:64-76`). Голос — единственное исключение.

Почему реально дорого: `SliverChildBuilderDelegate` строит не только видимые
строки, но и весь `cacheExtent` (`chat_message_list.dart:617-621`: 250 / 350–500 /
350–750 логических px). Каждая построенная строка с голосовым создаёт нативный
`AudioPlayer`, делает `getFileFromCache` и, при промахе, `fetchToLocalFile`
(сеть) + `E2eeFileCrypto.decryptFile` + `putFileStream`
(`core/network/ws_media_fetcher.dart:499-549, 580-586`). При быстром скролле чата
с 10–20 голосовыми это 10–20 одновременных нативных плееров и столько же
загрузок/расшифровок файлов, которые пользователь никогда не включит. Именно
такой паттерн (медиа «на всякий случай») и даёт просадки при входе в старый чат.

Фикс: не звать `_setupPlayer()` в `initState`. Обернуть бабл в
`MediaPlaybackVisibility` (как у стикеров/видео) и поднимать источник по
`visible == true`, а на `visible == false` — освобождать (`_player.setAudioSource(null)`
или dispose + пересоздание). Дополнительно уважать `autoDownloadAllowedProvider`
для `Audio` и брать инициализацию из `AnimatedMediaControllerPool`.

---

### M2. `MediaQuery.of(context)` в build поля ввода → пересборка всей панели ввода на каждом кадре анимации клавиатуры

`F:\Niosmess V2\pulse_flutter\lib\widgets\chat\chat_input_bar.dart:531`

```dart
517:     final bool isCompact = MediaQuery.sizeOf(context).width < 360;
...
521:       MediaQuery.viewInsetsOf(context).bottom,
...
531:     final media = MediaQuery.of(context);
535:       media.size.height - media.padding.vertical - bottomInset - 160,
```

Нарушено: «MediaQuery.of вместо .sizeOf/.maybeOf в глубоких виджетах» (правило 7).

Почему реально дорого: `MediaQuery.of` подписывается на **весь**
`MediaQueryData` (viewInsets, padding, size, textScaler, платформенная яркость…).
Клавиатура приходит кадрами, и в том же виджете есть свой
`didChangeMetrics() → setState` (`:155-157`) — то есть на каждый кадр подъёма
клавиатуры панель ввода (1322-строчный виджет, ~300 элементов: анимации
эмодзи-панели, `AnimatedContainer`, пикеры) перестраивается дважды. В файле уже
рядом используются `.sizeOf` (`:517`) и `.viewInsetsOf` (`:521`) — 531-я строка
просто выпала из этого стиля.

Фикс: заменить на `MediaQuery.sizeOf(context)` и `MediaQuery.paddingOf(context)`:

```dart
final size = MediaQuery.sizeOf(context);
final padding = MediaQuery.paddingOf(context);
```

---

### M3. `InteractiveMessage.parse` вызывается 2–3 раза на один build бабла, и сам парсер компилирует `RegExp` на каждый вызов

`F:\Niosmess V2\pulse_flutter\lib\screens\chat_detail_screen.dart:1946-1949`,
`F:\Niosmess V2\pulse_flutter\lib\widgets\chat\chat_message_list.dart:730`,
`F:\Niosmess V2\pulse_flutter\lib\widgets\message_bubble.dart:1554-1556`,
`F:\Niosmess V2\pulse_flutter\lib\models\interactive_message.dart:44-56`

```dart
// chat_detail_screen.dart:1946
  String _displayText(ApiMessage message) =>
      LiveLocation.parse(message.content)?.preview ??
      InteractiveMessage.parse(message.content)?.preview ??
      message.content;

// chat_message_list.dart:730
          text: InteractiveMessage.parse(rawText)?.preview ?? rawText,

// message_bubble.dart:1554
    final interactive = messageData != null && !isDeleted
        ? InteractiveMessage.parse(messageData!.content)
        : null;
```

```dart
// interactive_message.dart:44-54
      final raw = jsonDecode(text.substring(start + marker.length));
...
      if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{8,64}$').hasMatch(id)) {
...
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(raw['definition'])) {
```

Нарушено: «дорогая работа в build() бабла» + «пересоздание объектов в build».

Почему реально дорого: для интерактивного сообщения (опрос/квиз/список)
`parse` = `jsonDecode` (до 12 000 символов) + **две свежескомпилированные
регулярки** (в `InteractiveMessage.parse` ещё и `RegExp` в ветке `assign`).
Этот результат выбрасывается и считается заново три раза: в билдере строки
(превью), в `_displayText` и в самом бабле. Любая пересборка строки (реакция,
подсветка перехода, тик аплоада, обновление результата голосования) повторяет
этот цикл. Компиляция `RegExp` в Dart не бесплатна и не кэшируется.

Фикс: (1) вынести `RegExp` в `static final` в `interactive_message.dart`;
(2) распарсить один раз — в `_displayText`/`MessageLayoutStore` рядом с
`layout` и передавать готовый `InteractiveMessage?` в `MessageBubble`
(поле `definition`) вместо повторного парсинга внутри.

---

## MINOR

### m1. `Opacity(0.9)` на аватаре каждого замьюченного чата — saveLayer на строку

`F:\Niosmess V2\pulse_flutter\lib\widgets\chat_tile.dart:425-428`

```dart
                                  : Opacity(
                                      // Muted chats recede without losing the
                                      opacity: widget.isMuted ? 0.9 : 1,
                                      child: PulseAvatar(
```

Нарушено: «Opacity вместо полупрозрачного цвета».

Почему дорого: при `opacity == 1` `RenderOpacity` картину не оборачивает —
для незамьюченных строк цена нулевая. Но у каждого замьюченного чата (в большом
инбоксе их десятки) аватар с картинкой идёт через `saveLayer` на каждый
перерерисовки — то есть на каждый кадр скролла.

Фикс: не использовать `Opacity`; передать прозрачность внутрь
`PulseAvatar`/`fallbackColor` (`withValues(alpha: 0.9)`) или применить
`ColorFiltered`/заранее приглушённый цвет, чтобы слой не создавался.

### m2. `ShaderMask` (dstIn) вокруг всей ленты папок в инбоксе

`F:\Niosmess V2\pulse_flutter\lib\widgets\chat\chat_filter_bar.dart:291-308`

```dart
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: ValueListenableBuilder<bool>(
        builder: (BuildContext context, bool more, Widget? child) => ShaderMask(
          shaderCallback: (Rect bounds) => LinearGradient(
...
          blendMode: BlendMode.dstIn,
          child: child,
```

Нарушено: saveLayer-правило (ShaderMask = слой).

Почему дорого: маска накрывает весь горизонтальный `SingleChildScrollView`
(полная ширина экрана × 52 dp) и пересоздаёт слой при каждой перерисовке ленты —
в том числе на каждом кадре её инерционного скролла и при обновлении счётчиков
папок.

Фикс: рисовать затухание как `DecoratedBox` с `LinearGradient` по альфе поверх
правого края (как уже сделано в `chat_message_edge_fade.dart` — там ноль
save-слоёв), либо оставить `ShaderMask` только на 24 dp у края.

### m3. Инбокс пересчитывает весь список чатов в build, включая `indexWhere` + `insert/removeAt`

`F:\Niosmess V2\pulse_flutter\lib\screens\chat_list_screen.dart:839-867`, `:911-913`

```dart
839:    final List<ApiChatSummary> archived = chats
844:    final List<ApiChatSummary> filtered = archiveOpen
846:        : List<ApiChatSummary>.of(
...
865:      final index = filtered.indexWhere((chat) => chat.isSaved);
866:      if (index > 0) filtered.insert(0, filtered.removeAt(index));
```

Нарушено: «O(n) операции в горячем пути» (indexWhere в build) + пересоздание
объектов в build.

Почему дорого: `_buildChatItemsSlivers` вызывается на каждую пересборку экрана, а
она происходит на каждое входящее сообщение и на каждое read-подтверждение
(`visibleChatsProvider`). Каждый такой проход — 2–3 `where/toList` по всем чатам,
`indexWhere` (O(n)) + `removeAt/insert` (сдвиг всего списка) + построение
`idToIndex` (`:911-913`). При 200+ чатах это заметная работа на UI-изоляторе,
которую можно не делать вовсе.

Фикс: держать «закреплённый self-chat» на первом месте в самом источнике
(`visibleChatsProvider`) или кэшировать отсортированный список и
`idToIndex` в нотифаере, пересобирая их только при реальном изменении набора
чатов.

### m4. `SliverList` инбокса без `itemExtent`, хотя высота строки константна

`F:\Niosmess V2\pulse_flutter\lib\screens\chat_list_screen.dart:920-921`
+ `F:\Niosmess V2\pulse_flutter\lib\widgets\chat_tile.dart:82-86`

```dart
920:        sliver: SliverList(
921:          delegate: SliverChildBuilderDelegate(
```
```dart
82:  /// Row height at 1.0 text scale. A failed delivery takes the preview slot,
85:  static const double rowHeight = 76;
86:  static const double compactRowHeight = 64;
```

Нарушено: «отсутствие itemExtent/prototypeItem».

Почему дорого: без `itemExtent` слой вынужден мерить каждую строку и держать
оценочные экстенты; на длинном инбоксе это лишние проходы layout, неточный
`maxScrollExtent` и «прыжки» при drag скроллбара/jump. Здесь высота строки уже
объявлена константой, так что безопасно.

Фикс: `SliverFixedExtentList(delegate: ..., itemExtent: compact ? ChatTile.compactRowHeight : ChatTile.rowHeight)`
(проверить на `textScale > 1.0` — см. раздел «требует замеров»).

### m5. `RegExp` создаётся на каждый вызов в горячем пути строки

`F:\Niosmess V2\pulse_flutter\lib\screens\chat_detail_screen.dart:2055-2057`

```dart
  String? _extractUrlFromText(String text) {
    final RegExp rx = RegExp(r'https?://[^\s]+');
```

Почему дорого: `_mediaUrlFor` → `_extractUrlFromText` вызывается из
`buildRow` (`chat_message_list.dart:643`) для каждого сообщения с
`msgType == 'media'` на каждую пересборку. Компиляция регулярок не кэшируется
движком.

Фикс: `static final RegExp _urlRegExp = RegExp(...)`.

### m6. `FileTypeDetector.detect` вызывается 2–3 раза на один build файлового бабла

`F:\Niosmess V2\pulse_flutter\lib\widgets\message_bubble.dart:1036-1039`, `:1198-1200`, `:1353`

```dart
1036:    final FileTypeInfo typeInfo = FileTypeDetector.detect(
1037:      fileName: mediaLabel ?? mediaUrl ?? 'file',
...
1198:                      getIconDataByName(
1199:                        FileTypeDetector.detect(
...
1353:        FileTypeDetector.detect(fileName: mediaLabel ?? mediaUrl ?? '').isVideo;
```

Почему дорого: `detect` (`core/utils/file_type_detector.dart:176-208`) на каждый
вызов делает `split('.').last.toLowerCase()` и линейный проход по всей таблице
типов (сотни сравнений `List.contains`). Трижды на строку при каждой
пересборке.

Фикс: посчитать один раз в начале `build` (или в `_mediaPreview`) и передавать
`FileTypeInfo` вниз.

### m7. Новый `Map` заголовков авторизации на каждый build медиа-бабла

`F:\Niosmess V2\pulse_flutter\lib\widgets\message_bubble.dart:242`

```dart
    final Map<String, String> headers = cachedAuthHeaders(mediaUrl);
```
```dart
// providers/token_provider.dart:6-13 — возвращает новый литерал
  return {'Authorization': 'Bearer $_cachedToken'};
```

Почему дорого: аллокация карты на каждую строку с медиа при каждой пересборке,
и новая ссылка уходит в `CachedNetworkImage.httpHeaders` — сравнение виджетов
по `==` карты не срабатывает, лишние обновления провайдера изображения.

Фикс: кэшировать карту (или `const []`/`const {}` для неаутентифицированных URL)
в статике `token_provider.dart`.

### m8. Разбор пересылки регекспом на каждый build бабла

`F:\Niosmess V2\pulse_flutter\lib\widgets\message_bubble.dart:1512-1519`

```dart
  ForwardedPayload? _parseForwarded(String rawText) {
    final String trimmed = rawText.trim();
    final Match? result = MessageFormatter.fwdRegExp.firstMatch(trimmed);
```

Почему дорого: `trim()` (копия строки) + `firstMatch` по всему тексту на каждой
пересборке каждой видимой строки, при том что пересылка — редкое свойство
сообщения.

Фикс: вычислять один раз при получении/парсинге сообщения (флаг на `ApiMessage`
или в `MessageLayoutStore`), либо быстрый `startsWith` префикса перед регулярок.

---

## NIT

### n1. Хелперы, возвращающие `Widget`, вместо `StatelessWidget`

`F:\Niosmess V2\pulse_flutter\lib\widgets\message_bubble.dart:600, 782, 852, 1336, 1522, 1530`
(`_buildStickerContent`, `_buildCircleVideoContent`, `_mediaPreview`,
`_buildUnframedMessage`, `_buildInlineKeyboard`, `_buildMessageTextAndFooter`)

Нарушено: «Avoid helper methods that return widgets» (гайд) — у таких хелперов
нет своего элемента, они всегда пересобираются вместе с родителем и не получают
собственную область пересборки; const-оптимизации тоже не применяются.

Фикс: минимальный — вынести `_mediaPreview` и `_buildMessageTextAndFooter` в
`StatelessWidget`; тогда при пересборке бабла (реакция/подсветка/аплоад) тяжёлое
медиа-поддерево не перестраивается.

### n2. `MediaQuery.of` ради `viewInsets`/`size` в билдерах шитов

`lib\widgets\chat\moderation_bottom_sheet.dart:170`,
`lib\screens\chat_detail_screen.dart:1586`,
`lib\screens\chat_members_screen.dart:91, 116`

```dart
170:           20 + MediaQuery.of(context).viewInsets.bottom,
```

Фикс: `MediaQuery.viewInsetsOf(context).bottom` / `MediaQuery.sizeOf(context)`.
Шиты не в горячем пути, но правило то же, что в M2.

### n3. `Opacity` в одноразовой анимации появления пустого состояния

`F:\Niosmess V2\pulse_flutter\lib\widgets\chat\chat_empty_state.dart:130-144`

```dart
130:      child: TweenAnimationBuilder<double>(
137:          return Opacity(
138:            opacity: value,
```

Одноразово (260 мс), вне скролла — цена мала, но правильный инструмент —
`AnimatedOpacity`/`FadeTransition` (альфа-слой без `saveLayer`).

### n4. `setState` на весь инбокс при завершении retry

`F:\Niosmess V2\pulse_flutter\lib\screens\chat_list_screen.dart:465-477`

```dart
465:        setState(() => _retrying = true);
477:        if (mounted) setState(() => _retrying = false);
```

Пересобирает заголовок и весь список чатов ради флага загрузки. Дешевле —
`ValueListenableBuilder` вокруг кнопки/скелетона.

### n5. Отдельный `Timer.periodic(15s)` на каждую карточку live-location

`F:\Niosmess V2\pulse_flutter\lib\widgets\chat\live_location_card.dart:98-100`

```dart
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
```

Один таймер и `setState` на каждый такой бабл. По образцу
`SelfDestructCountdownPill` (`bubble_footer.dart:182-206`) лучше общий
`_SecondTicker`/`_MinuteTicker` на весь список.

### n6. Нерезиновые `ListView(children:)` на экранах управления чатом

`F:\Niosmess V2\pulse_flutter\lib\screens\chat_manage_screen.dart:278` —
`ListView(children: <Widget>[...])` для статичной страницы настроек (~40
виджетов). Ограничено, поэтому это nit; при росте страницы заменить на
builder-делегат.
`F:\Niosmess V2\pulse_flutter\lib\screens\chat_members_screen.dart:123-124` —
`ListView.builder(shrinkWrap: true)` внутри `ConstrainedBox(maxHeight: 0.4h)`:
высота ограничена, протокол не нарушен — nit.

---

## Проверено и признано нормальным

1. **Список сообщений** (`lib\widgets\chat\chat_message_list.dart:1019-1057`).
   Ленивый `SliverChildBuilderDelegate` (никаких `Column`/`ListView(children:)`),
   `addRepaintBoundaries: false` + собственный `RepaintBoundary` на каждую строку
   (`:679, 699, 871, 915`) — двойных слоёв нет, `findChildIndexCallback` работает
   за O(1) через `_rowIndexes` (`:1001-1002, 1031-1036`), `addAutomaticKeepAlives:
   false`, ключи строк стабильны (`_syncRowIds`, `:129-158`), `indexWhere` в
   горячем пути отсутствует, `itemExtent` неприменим — баблы переменной высоты
   (медиа/текст/стикеры), это корректно. Две `SliverList` вокруг `center`
   оправданы якорной прокруткой.

2. **Поле ввода и курсор изолированы от списка.** `RepaintBoundary` вокруг
   композера (`chat_viewport.dart:184-192`) и вокруг всей панели ввода
   (`chat_detail_input_area.dart:243-245`), `TextField` внутри. Ввод не
   пересобирает бабл-лист: `ChatInputBar._onTextChanged`
   (`chat_input_bar.dart:186-193`) делает `setState` только на переходе
   пусто↔непусто, черновик пишется дебаунсом 500 мс
   (`chat_detail_screen.dart:432-435`), `typing` троттлится 3 с
   (`providers/typing_provider.dart:_sendThrottle`).

3. **Анимации в баблах не создают save-слоёв и контроллеров в build.** Вход
   сообщения — `AnimationController` в `initState` + `AnimatedBuilder` с
   `child` (`chat_detail_screen.dart:3183-3263`); подсветка перехода —
   `TweenAnimationBuilder` с `child` (`message_bubble.dart:571-587`); реакции —
   `FadeTransition`/`ScaleTransition` (`bubble_reaction_chip.dart:271-278`);
   шапка `_AnimatedMessage` не пересоздаётся (`_controller == null` → `child`,
   `:3243-3245`). Стикеры/видео/альбомы/Noto-эмодзи загейчены
   `AnimatedMediaControllerPool` + `MediaPlaybackVisibility` и встают на паузу
   при скролле. `MaskFilter.blur`, `BackdropFilter`,
   `Clip.antiAliasWithSaveLayer`, `Chip(disabledColor)` в зоне отсутствуют;
   склейки строк в циклах (`+=` по String) нет; `AnimationController` в
   `build()` не создаётся нигде в зоне.

---

## Требует профилирования, а не чтения кода

- `cacheExtent` списка сообщений (`chat_message_list.dart:617-621`): 750 px на
  tierA достаточно, чтобы держать в дереве 1.5–2 экрана строк с медиа. Нужен
  DevTools timeline при быстром скролле чата с видео/стикерами, чтобы понять,
  где граница между «плавный скроллбэк» и лишние плееры/декоды.
- Вклад `_rebaseAnchor` / `_syncRowIds` / `_store.sync` (O(n), n ≤ 300, включая
  `resolvedSentAt` и `localToGlobal` по видимым строкам) на каждом изменении
  окна сообщений — замерить на 300-сообщенном чате с ручной таймзоной
  (`AppTimeSettings.resolve` тогда идёт через `tz.TZDateTime.from`).
- `_measureScrollAnchor` (`chat_message_list.dart:170-212`) — проходит по
  `_anchors` и делает `localToGlobal` дважды на строку раз в 180 мс во время
  скролла; насколько это видно в профиле (особенно на Windows/веб).
- Выигрыш от `itemExtent` в инбоксе (M4) — сравнить `maxScrollExtent`
  стабильность и layout-время на 300+ чатах при `textScale > 1.0`.
- Стоимость `ShaderMask` в ленте папок (m2) при горизонтальном флике.
- Стоимость `VoiceMessagePlayer` на реальном чате с 20 голосовыми (M1):
  количество одновременных `AudioPlayer` и сетевых запросов в DevTools /
  network inspector.

---

## Что проверялось по правилам и где чисто

| Правило | Результат |
|---|---|
| 1. Стоимость build / огромные build / setState высоко / хелперы-виджеты | M3, m3, n1, n4 (setState высоко в дереве в чате не найден: экран разбит на скоупы `_ChatHeaderScope` / `_ChatMessagesScope` / `_ChatComposerScope`, `chat_detail_screen.dart:2579, 2807, 2978`) |
| 2. StringBuffer вместо `+` в циклах | чисто (единственные `+=` — числа и `unreadWhileScrolledNotifier`) |
| 3. saveLayer | m2, m1 (blur/BackdropFilter/antiAliasWithSaveLayer — нет) |
| 4. Opacity и clip | m1, n3; `ClipRRect` в баблах стоит только там, где реально обрезается картинка/медиа |
| 5. Списки и гриды | m3, m4, n6; в бабл-листе всё ленивое, ключи и O(1)-индекс на месте |
| 6. Intrinsic-проходы | чисто: `IntrinsicWidth/IntrinsicHeight/IntrinsicColumnWidth` в зоне отсутствуют |
| 7. Кадр в 16 мс | M1, M2, M3, m5, m6, m7, m8; `compute` используется для альбомов (`media_album_bubble.dart:42, 52`), `MediaQuery.sizeOf` — в баблах (`message_bubble.dart:450-452, 1354`) |

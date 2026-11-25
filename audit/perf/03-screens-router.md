# Аудит производительности — зона `lib/screens/**` + `lib/router/**`

Дата: 2026-11-25
Зона: `pulse_flutter/lib/screens/**` (включая `screens/calls/**`, 52 файла) и `pulse_flutter/lib/router/**` (3 файла).
Эталон: https://docs.flutter.dev/perf/best-practices + «Motion & Performance Protocol» из `AGENTS.md`.

Метод: grep по антипаттернам → чтение окружающего кода для каждого хита. Ни одна находка
не основана только на grep-хите. Код не менялся, сборка не запускалась.
Вне зоны (но упомянуто по причине влияния): `lib/widgets/nav/m3_route_tab_switcher.dart`,
`lib/providers/call_session_provider.dart` — они обслуживают мою зону, ссылаюсь на них явно.

## Счётчики

| severity | кол-во |
|---|---|
| blocker | 2 |
| major | 7 |
| minor | 4 |
| nit | 4 |
| **всего** | **17** |

---

# BLOCKER

## B-1. Видеозвонок: полная пересборка экрана раз в секунду + `ThemeData`/`ColorScheme.fromSeed` в `build()`

`lib/screens/calls/active_video_call_screen.dart:110-111`
```dart
_timerNotifier.value = data.durationSeconds;
setState(() {});
```

Нарушено: п.7 «кадр в 16 мс» (тяжёлая работа в `build()`/пересоздание объектов в `build()`;
перерисовка всего экрана на каждый тик) + п.3 (`ThemeData`/`ColorScheme` — дорогие объекты).

Почему реально дорого — цепочка целиком проверена:

1. `services/calls/webrtc_call_session.dart` — `Timer.periodic(const Duration(seconds: 1), ...)`
   → `_elapsedSeconds++` → `_triggerStateUpdate()` → `stateStream` отдаёт `CallSessionData`
   **каждую секунду**, даже когда в звонке ничего не меняется.
2. `providers/call_session_provider.dart:217-222` — на каждое такое событие:
   ```dart
   ref.read(callSessionProvider.notifier).notify();
   ```
   а `notify()` (строки 61-65) делает `state = null; state = cur;` — то есть **два**
   уведомления всех подписчиков (экран звонка — подписчик).
3. Экран сам делает `setState(() {})` на то же событие.

Итого: 3 полных прохода `build()` этого экрана в секунду. В самой функции `build()`
(`:206-216`) заново считается палитра:

```dart
final scheme = AppSurfaces.neutralize(
  ColorScheme.fromSeed(seedColor: appScheme.primary, brightness: Brightness.dark),
);
final textTheme = ThemeData(brightness: Brightness.dark, colorScheme: scheme).textTheme;
```

`ColorScheme.fromSeed` — это полная CAM16/HCT-палитра (десятки токенов), `ThemeData(...)` —
ещё дороже (текстовые темы, материалы). Оба вызываются в `build()`, то есть 3 раза в секунду
на протяжении всего видеозвонка, плюс полное перестроение дерева (~200 виджетов поверх живого
`RTCVideoView`). На слабом устройстве это регулярный дроп кадра раз в секунду рядом с
аудио/видеотрактом.

Фикс (дешёвый, три шага):
- Убрать `setState(() {})` из слушателя `stateStream` (`:111`). Всё, что экран реально берёт
  из нового `data` (таймер, `hasRemoteVideo`, `isListener`, `participantName`), должно жить в
  `ValueNotifier`/`ValueListenableBuilder`. Таймер уже так и сделан (`_timerNotifier`,
  `:366-397`) — `setState` его оптимизацию просто обнуляет.
- `scheme`/`textTheme` вынести в `State` (пересчитывать в `didChangeDependencies`, когда
  меняется `Theme.of(context).brightness`/`colorScheme.primary`), а не в `build()`.
- В провайдере — не дёргать `notify()` на каждый тик: сравнивать `currentData` и
  уведомлять только при смысловом изменении состояния (см. ниже, «вне зоны»).

---

## B-2. Голосовой звонок: та же пересборка всего экрана раз в секунду + `ColorScheme.fromSeed` в `build()`

`lib/screens/calls/active_voice_call_screen.dart:92-93`
```dart
_timerNotifier.value = data.durationSeconds;
setState(() {});
```
и `:126-131`
```dart
final ColorScheme callScheme = AppSurfaces.neutralize(
  ColorScheme.fromSeed(seedColor: appScheme.primary, brightness: Brightness.dark),
);
```

Нарушено: то же, что B-1. Отдельная находка, потому что это отдельный экран и он собирается
заново при каждом звонке; корень проблемы общий (см. B-1, шаги 1-2), но здесь нет даже
`ThemeData`, зато есть полноэкранный `Column` + `CallAudioRipple` с работающим
`AnimationController`, которых незачем пересобирать.

Показательно, что автор сознательно сделал `_timerNotifier` (`:30`) и обернул пилюлю
таймера в `ValueListenableBuilder` (`:292-415`) — и тут же свёл выигрыш на нет строкой `:93`.

Фикс: тот же, что B-1. Для голосового экрана это буквально удаление одной строки `setState`.

---

# MAJOR

## M-1. Медиавьюер: `setState()` на каждый шаг свайпа ради поля, которое никто не читает

`lib/screens/media_viewer_screen.dart:269-272`
```dart
onProgress: (double progress) {
  if ((_dragProgress - progress).abs() > 0.01) {
    setState(() => _dragProgress = progress);
  }
},
```

Нарушено: п.7 — `setState()` в горячем пути жеста без визуального эффекта.

`_dragProgress` в файле встречается ровно три раза: объявление (`:112`), проверка (`:270`) и
присваивание (`:271`). В `build()` он **не читается** — затемнение считаётся из `progress`
параметра builder'а (`:275: final double scrimAlpha = (1.0 - progress.abs())...`). То есть при
каждом свайпе вниз (порог 1 % прогресса → десятки раз за жест) выполняется полная пересборка
`Scaffold` → `Stack` → `PageView.builder` → видимого `_FullScreenImage`, при нулевом изменении
картинки. Для видеозаписи в плейлисте это ещё и оверхед вокруг активной поверхности.

Фикс: удалить поле `_dragProgress` и весь `onProgress` (оставить `null`), либо, если оно
понадобится, сделать `ValueNotifier<double>` и вешать его на `AnimatedBuilder` только там, где
значение реально используется.

## M-2. Просмотрщик текстовых файлов: `split('\n')` всего файла в `build()` на каждое нажатие клавиши

`lib/screens/native_file_viewer_screen.dart:869`
```dart
final List<String> lines = _content.split('\n');
```
и `:911-912`
```dart
onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
```

Нарушено: п.7 (тяжёлая работа в `build()`) + п.5 (данные готовятся на каждом кадре).

`_content` — это весь файл (просмотрщик открывает `.txt`/`.log`/`.json` любого размера, в т.ч.
через `bytes`/`localPath`). `split` создаёт N новых строк на каждый `build()`. При поиске
каждая буква в поле вызывает `setState` → повторный `split` всего документа + полный
`ListView.builder` перезапрашивает видимые строки. Файл на 1 МБ / ~30 тыс. строк — это десятки
тысяч аллокаций на одно нажатие клавиши; Джанк гарантирован.

Фикс: считать `_lines` один раз в `_loadContent()` (`:840-855`), хранить в поле и передавать в
builder; `LineSplitter` из `dart:convert` быстрее `split`.

## M-3. Юридический документ: неленивый `Column` на весь документ + пересборка всего текста на каждый символ поиска

`lib/screens/legal_viewer_screen.dart:317-364`
```dart
child: SingleChildScrollView(
  child: Column(
    children: [
      ...
      for (int i = 0; i < _parsedDoc!.sections.length; i++) ...[
        if (_searchQuery.isEmpty ||
            _parsedDoc!.sections[i].title.toLowerCase().contains(_searchQuery) ||
            _parsedDoc!.sections[i].paragraphs.any((p) => p.toLowerCase().contains(_searchQuery)))
```
плюс `:52-56`
```dart
_searchController.addListener(() {
  setState(() { _searchQuery = _searchController.text.trim().toLowerCase(); });
});
```

Нарушено: п.5 (неленивый `Column` для длинного списка), п.7 (тяжёлая работа в `build()`).

`assets/legal/ToS.txt` — 28 КБ / 171 строка; после парсинга это десятки секций и ~200-300
абзацев. Всё это строится и раскладывается одним `Column` внутри `SingleChildScrollView`
(никакой ленивости и виртуализации текста). При вводе в поле поиска **каждый символ** запускает:
- проход фильтра по всем секциям с `toLowerCase()` по каждому абзацу (`:341-347` — O(текст)
  с аллокациями);
- пересборку всех карточек секций, каждая из которых снова компилирует 4-8 `RegExp`
  (`:695`, `:703`, `:711`, `:812`, `:821`, `:891`) и заново режет абзацы на `InlineSpan`
  (`_parseMarkdownSpans`, `:1109-1140`, `RegExp` создаётся в теле функции).

Итого на одно нажатие клавиши — сотни компиляций регулярок и пересборка всего дерева документа.
Поиск по документу после этого ощущается «тяжёлым», особенно на телефоне.

Фикс:
1. `ListView.builder` по секциям (`itemCount: sections.length`) вместо `Column` — тогда
   раскладка ограничена вьюпортом.
2. Кэшировать распарсенные `List<InlineSpan>` на абзац (по абзацу или по секции) — они не
   зависят от `_searchQuery`, только от темы. Инвалидировать при смене `colorScheme`.
3. Один раз посчитать `lowercase`-версию текста при парсинге (в `_parseDoc`) и искать по ней.
4. `RegExp` в `static final` (перечисленные выше), а не в теле метода.
5. Дебаунс поиска (250 мс) либо перенос фильтрации в `setState` только по завершении ввода.

## M-4. Шит «Переслать»: все чаты строятся сразу в неленивом `Column` внутри непрокручиваемого шита

`lib/screens/chat_detail_screen.dart:1494-1517`
```dart
final ApiChatSummary? target = await AppModal.showSheet<ApiChatSummary>(
  builder: (BuildContext ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ...
        ...chats.map((ApiChatSummary c) => ListTile(leading: PulseAvatar(...), ...)),
```

Нарушено: п.5 — «неленивые `ListView(children:)`/`Column(...)` для длинных списков», плюс
«шиты с длинными списками».

`chats` — это весь список чатов аккаунта. На 200 чатов открытие шита синхронно создаёт 200
`ListTile` + 200 `PulseAvatar` (каждый — сетевой аватар/`CircleAvatar` с фолбэком) до первого
кадра. Это и заметная задержка открытия шита, и (побочно) контент без скролла: `AppModal.showSheet`
вызывается без `isScrollable: true`, поэтому длинный список не помещается. Сравнить: основной
инбокс для того же набора данных использует `SliverList` + `findChildIndexCallback`.

Фикс: `showSheet(..., isScrollable: true)` + `ListView.builder` с фиксированной высотой
(`SizedBox(height: 0.75 * MediaQuery.sizeOf(ctx).height, child: ListView.builder(...))`),
либо переиспользовать `PeoplePickerScreen`-подобный экран.

## M-5. Переключатель табов: `AnimatedBuilder` без `child` + `Opacity`/`Transform` на всю страницу каждый кадр

`lib/widgets/nav/m3_route_tab_switcher.dart:193-220` (используется из `main_shell_screen.dart:735-758`)
```dart
Widget build(BuildContext context) => AnimatedBuilder(
  animation: _opacity,
  builder: (context, _) => Stack(          // ← child не используется
    ...
      child: RepaintBoundary(
        child: Opacity(
          opacity: i == _visible ? _opacity.value : 1,
          child: Transform.translate(
            child: Transform.scale(scale: ..., child: widget.children[i]),
```

Нарушено: п.7 «`AnimatedBuilder`/`AnimatedWidget` без `child` для неизменяемого поддерева» и
п.4 «`Opacity` в анимации вместо `FadeTransition`».

На каждый кадр переключения таба (250 мс, `M3Durations.medium2`) пересобирается `Stack` со
всеми 4 обёртками (`Offstage`, `TickerMode`, `ExcludeFocus`, `ExcludeSemantics`, `IgnorePointer`,
`RepaintBoundary`, `Opacity`, 2×`Transform`) — для **всех** страниц, включая offstage. Плюс
сама анимация — `Opacity` (слой полупрозрачности на всю страницу) одновременно с двумя
`Transform` на всём поддереве активного таба. На tier C дешёвых устройств это самый дорогой
участок тапа по табу, при этом `animate` завязан только на `reduceMotion` — деградации по
`PerformanceTier` нет (в `main_shell_screen.dart:741-743` по тиру меняется только длительность).

Фикс:
- `FadeTransition` + `SlideTransition`/`ScaleTransition` поверх одного `Animation<double>` —
  тогда пересборки виджетов в анимации не будет вообще (только layer-трансформация);
- минимум — передать неизменяемую часть через `child:` у `AnimatedBuilder` и считать
  `opacity`/`offset` только для `i == _visible`, не пересобирая обёртки offstage-страниц;
- на `tier.isTierC` отключать `Opacity`-фазу (оставить голый cross-fade длиной `short4`).

## M-6. Оболочка табов: `pages` собирается заново на каждую пересборку shell → пересборка настроек (а в двухпанельном режиме — всего чата) на каждый тап

`lib/screens/main_shell_screen.dart:607-709`
```dart
final List<Widget> pages = <Widget>[
  ...
  const NiosgramScreen(),
  ProfileScreen(                     // ← не const, новый инстанс каждый build
    initialSection: ...,
    initialAnchor: ...,
  ),
];
```

Нарушено: п.1 (стоимость `build()`/`setState` высоко в дереве), косвенно п.7.

Проверено:
- `const NiosgramScreen()` и `const _InboxPane(...)` в компактном режиме — канонизируются,
  их поддеревья **не** пересобираются (это хорошо).
- `ProfileScreen` — не `const` (принимает `initialSection`/`initialAnchor`), поэтому каждый
  `build()` shell'а даёт новый инстанс → `_ProfileScreenState.build()` выполняется целиком:
  `ref.watch(authProvider)`, два `LayoutBuilder`, `_sectionGroups()` с `ref.watch` внутри
  цикла по секциям, `_healthIssues()`, `_buildMobileHub` со `SliverChildListDelegate`
  на все строки настроек. Это происходит **на каждый тап по табу** (`_onTapTab` → `context.go`
  → новая страница → `didUpdateWidget` → `build`), а также на любое изменение
  `connectivityProvider`/`haptics`/`desktopSelectedChatProvider`.
- В широком режиме (десктоп/планшет, `isWide`, `:608-682`) `_InboxPane(overlayComposer: true, ...)`
  и, что важнее, `ChatDetailScreen(key: ValueKey(desktopChatId), ...)` тоже пересоздаются
  каждый `build()` shell'а → полная пересборка всей панели чата (в `ChatDetailScreen.build`
  есть выбор chroma-палитры и длинный `Scaffold`) на каждое переключение таба. Именно это
  и есть «всё пересобирается на каждый тап» в двухпанельном режиме.

Усугубляет `_scheduleTabWarmup` (`:187-203`): в первые ~1.6 с после старта он делает
`setState(() => _activatedTabs.add(pending))` три раза подряд, и каждый `setState` — это
полный `build()` shell'а со всеми последствиями выше.

Фикс: держать инстансы страниц в `State` (поля) и пересоздавать только при изменении их
аргументов (для `ProfileScreen` — в `didUpdateWidget` при смене `widget.settingsSection`/
`settingsAnchor`), либо обернуть каждую страницу в `ValueListenable`-gate, чтобы shell читал
их как `child:`. Для `ChatDetailScreen` в широком режиме достаточно вынести его в отдельное
поле, пересоздаваемое по `desktopChatId`.

## M-7. Создание поста: `setState()` на каждый символ в основном поле

`lib/screens/create_post_screen.dart:898`
```dart
onChanged: (_) => setState(() {}),
```

Нарушено: п.1 (`setState()` высоко в дереве на каждый ввод).

Поле — основной текст поста (`_textController`, `:861-899`). `setState` здесь нужен только
чтобы включить/выключить кнопку публикации, но пересобирает весь экран: `SingleChildScrollView`
→ `Column` с автором, полем, до 5 превью медиа, редактором опроса (`:954`) и т.д. Набор текста
10 символов/с = 10 полных пересборок в секунду.

Фикс: `ValueListenableBuilder<TextEditingValue>(valueListenable: _textController, builder: ...)`
вокруг одной кнопки/счётчика, либо `ListenableBuilder` на контроллере. Сам `TextField`
пересобирать не нужно.

---

# MINOR

## m-1. Контакты: компиляция `RegExp` на каждый контакт при каждой пересборке

`lib/screens/contacts_screen.dart:86`
```dart
final String key = RegExp(r'^[A-ZА-ЯЁ]').hasMatch(letter) ? letter : '#';
```
Вызывается из `_groupAlphabetically` → `:778-779`, которая выполняется в `build()` на каждый
рендер вкладки контактов. Экран при этом `ref.watch(chatsProvider)` (`:300`) — то есть любое
обновление списка чатов (новое сообщение, presence-апдейт списка) пересобирает вкладку и
компилирует по одной регулярке на контакт. На 300 контактов — 300 компиляций на пересборку.

Фикс: `static final RegExp _startsLetter = RegExp(r'^[A-ZА-ЯЁ]');` (по аналогии с уже
сделанным `static final RegExp _forwardedPattern` в `chat_list_screen.dart:376`). Ещё лучше —
считать группы один раз при изменении данных, а не в `build()`.

## m-2. `ActiveCallScreen`: `ColorScheme.fromSeed` считается и выбрасывается

`lib/screens/calls/active_call_screen.dart:82-88`
```dart
final callScheme = AppSurfaces.neutralize(
  ColorScheme.fromSeed(seedColor: appScheme.primary, brightness: Brightness.dark),
);
```
Ниже (`:336-341`) при наличии сессии функция просто возвращает
`const ActiveVideoCallScreen()` / `const ActiveVoiceCallScreen()`, которые считают эту же
палитру у себя. То есть в горячем пути (сессия есть — это 100 % времени звонка) палитра
считается дважды, а используется ноль раз. С учётом B-1/B-2 и `notify()` из провайдера этот
экран пересобирается несколько раз в секунду.

Фикс: перенести вычисление внутрь веток, где оно нужно (или убрать вовсе — им пользуются
дочерние экраны).

## m-3. Круговой видеорекордер: `setState` раз в секунду поверх превью камеры

`lib/screens/circle_video_recorder_screen.dart:172-179`
```dart
_recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
  if (mounted) { setState(() => _elapsedSec++); ... }
});
```
`_elapsedSec` нужен только для текста таймера, но `setState` пересобирает весь экран записи,
включая обёртки вокруг `CameraPreview` (`:390-434`) и четыре `AnimatedBuilder`. Сами
`AnimatedBuilder` сделаны правильно (`child:` передаётся, см. `:394-433`) — их и надо оставить
единственными, кто пересобирается.

Фикс: `ValueNotifier<int>` + `ValueListenableBuilder` вокруг текста таймера (ровно как сделано
в экранах звонков).

## m-4. Онбординг: `setState` раз в секунду на всю страницу

`lib/screens/onboarding_screen.dart:81-85`
```dart
_clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
  if (mounted && _index == 3) setState(() => _now = DateTime.now());
});
```
Шаг с часами пересобирает `Scaffold` + `PageView.builder` целиком каждую секунду. Не критично
(страница лёгкая), но это тот же паттерн, что B-1, и лечится так же: `ValueListenableBuilder`
вокруг блока времени.

---

# NIT

## n-1. `MediaQuery.of(context)` вместо точечных аксессоров

- `lib/screens/circle_video_recorder_screen.dart:303` — `final media = MediaQuery.of(context);`
  (нужны только `size`/`padding`), `:444` — `MediaQuery.of(context).padding.top`, `:566` —
  `MediaQuery.of(context).padding.bottom`.
- `lib/screens/chat_members_screen.dart:91` — `MediaQuery.of(ctx).viewInsets.bottom`,
  `:116` — `MediaQuery.of(ctx).size.height`.
- `lib/screens/chat_detail_screen.dart:1586` — `MediaQuery.of(ctx).viewInsets.bottom`.

`MediaQuery.of` подписывает виджет на **весь** `MediaQueryData`: смена `viewInsets` при
открытии клавиатуры или `padding` пересобирает и того, кому нужен только `size`. Замена на
`MediaQuery.sizeOf` / `.paddingOf` / `.viewInsetsOf` — по одной строке на каждое место.
(В остальной зоне привычка правильная: `paddingOf`/`viewPaddingOf`/`sizeOf` используются в
`main_shell_screen`, `niosgram_screen`, `contacts_screen`, экранах звонков.)

## n-2. Инбокс: нет `itemExtent`/`prototypeItem` при известной высоте строки

`lib/screens/chat_list_screen.dart:918-1174` — `SliverChildBuilderDelegate` без `itemExtent`,
хотя `ChatTile.rowHeight`/`ChatTile.compactRowHeight` (`:249-251`) — константы, а строка
дополняется фиксированными 2 dp (`:1150-1154`). Без `itemExtent`/`prototypeItem` вьюпорт не
знает экстент заранее: скроллбар и `jumpTo`/оценка позиции считаются по детям.
Требует замера и осторожности (архивная строка `_ArchiveRow` и `_savedShortcut` живут в
отдельных `SliverToBoxAdapter`, так что `itemExtent` применим только к `SliverList` — это
можно сделать). Не блокер: паттерн списка здесь в остальном образцовый.

## n-3. Двойной `TickerMode` на страницах табов

`lib/screens/main_shell_screen.dart:749-756` оборачивает страницу в `TickerMode(enabled: isActive)`,
и `lib/widgets/nav/m3_route_tab_switcher.dart:202-204` делает это ещё раз (с условием
`_phase == _Phase.idle`). Второй слой перекрывает первый: во время перехода тикеры гасятся
даже у целевой страницы, что и задумано, но первый `TickerMode` становится мёртвым кодом,
который читают как «здесь что-то важно». Оставить один (в свитчере).

## n-4. Регэксп в горячем пути `mediaUrlBuilder`

`lib/screens/chat_detail_screen.dart:2056` — `final RegExp rx = RegExp(r'https?://[^\s]+');`
внутри `_extractUrlFromText`, вызываемой из `_mediaUrlFor` → этот builder дёргается на каждое
сообщение при каждой пересборке списка. Срабатывает только для `msgType == 'media'` без
`mediaUrl`, поэтому цена мала, но правило «регулярка — в `static final`» рядом уже соблюдено
(`chat_list_screen.dart:376`), стоит соблюсти и тут.

---

# Проверено и признано нормальным

1. **`lib/router/app_router.dart` — redirect не делает дорогой работы.** `redirect` (`:133-199`)
   читает только `ref.read(authProvider)` (синхронное состояние в памяти) и сравнивает строки;
   список публичных путей — 13 `startsWith`/`==` по строке. Дорогая ветка
   `AppUrlLauncher.resolveInternalAppRoute` (`:151-164`) вызывается **только** при
   `uri.scheme == 'niosmess'` или хосте `ni-os.ru`, то есть на обычной внутренней навигации
   (`context.go('/main/chats')`) не выполняется вовсе — ни storage, ни JSON, ни сети.
   Дополнительно `:272-275` переиспользует `pageKey: const ValueKey('main-shell')` на нативе,
   поэтому переключение таба не создаёт новую страницу в стеке (нет лишнего Hero/anim-прохода).
   `AppUrlLauncher` тоже не читает диск: `handleDeepLink` лишь парсит `Uri`.

2. **Инбокс (`chat_list_screen.dart`) — ленивый, с O(1) поиском индекса и изолированными
   подписками.** `SliverList` + `SliverChildBuilderDelegate` с
   `findChildIndexCallback: (key) => idToIndex[id]` (`:1168-1172`) и готовой картой
   `idToIndex` (`:911-913`) — без `indexWhere` в горячем пути. `addRepaintBoundaries: false` +
   ручной `RepaintBoundary` на строку (`:1148-1149`), `addAutomaticKeepAlives: false`.
   Presence вынесен из снимка списка (`_PresenceBlindChats`, `:85-114`) и читается построчно
   (`:1078`), typing/draft/выделение — тоже через `select` в `Consumer` на строку
   (`:990-1020`). Скролл-уведомления не вызывают пересборок: `chatListFabVisibleProvider`
   и `chatListScrolledProvider` пишут только при реальной смене значения
   (`chat_list_fab_provider.dart:12-20`, `chat_list_header.dart:23-25`), а `_ComposerClearance`
   и `_InboxComposerScrim` — отдельные подписчики, поэтому FAB/скрим не тянут за собой список.

3. **Экраны звонков — анимации сделаны правильно (проблема только в таймере, B-1/B-2).**
   Все `AnimationController` создаются в `initState` (`active_voice_call_screen.dart:40`,
   `active_video_call_screen.dart:68`, `incoming_call_overlay.dart:57/73`,
   `circle_video_recorder_screen.dart:55-80`, `chat_detail_screen.dart:3186`), ни одного в
   `build()`. `incoming_call_overlay` гасит пульс по `TickerMode`/`reduceMotion`
   (`:114-123`), использует `SlideTransition`+`FadeTransition` вместо `Opacity`
   (`:205-208`), `AnimatedBuilder(child:)` в PiP-перетаскивании
   (`active_video_call_screen.dart:405-411`) — при драге пересобирается только `Positioned`,
   а не видео; `_AnimatedMessage` (`chat_detail_screen.dart:3246-3263`) — `FadeTransition` +
   `AnimatedBuilder(child:)`. Таймер входящего/исходящего не тикает вовсе — там нет ошибки.

4. **`ChatViewport` (обслуживает `chat_detail_screen`): композер изолирован.** Панель ввода
   в `RepaintBoundary` (`widgets/chat/chat_viewport.dart:186-192`), а высота композера ходит
   через `ValueNotifier` (`:112-123`), а не через `setState` — рост композера не пересобирает
   список сообщений. Сообщения и композер передаются билдером/полем, а не строятся в
   `ChatDetailScreen.build` напрямую, поэтому набор текста не пересобирает историю.

5. **Лента NiosGram — образцово ленивая.** `ListView.builder` с `findChildIndexCallback`
   (`niosgram_screen.dart:179-243`), по одному `RepaintBoundary` на пост через сам `PostCard`
   (`addRepaintBoundaries: false`, `:182`), каждая карточка подписана на свой пост
   (`_FeedPostEntry`, `:254-266`), а снапшот ленты сравнивается по значению
   (`NiosgramFeedLayout` с `==`, `providers/niosgram_provider.dart:47-57`), поэтому реакция на
   одном посте не пересобирает ленту. `_LoadMoreTrigger` — отдельный виджет под `itemBuilder`.

6. **Разбор тяжёлых данных вынесен из кадра.** `legal_viewer_screen` парсит документ один раз
   в `_loadContent`/`initState` (`:41-51`, `:66-100`), `native_file_viewer` — в `initState`
   (`:602-620`), `chat_detail_screen` кодирует альбом через `compute(_encodeAlbum, images)`
   (`:1144`), сплэш грузит `sessionProvider`/`authProvider` параллельно через `Future.wait`
   (`splash_screen.dart:42-47`) — п.8 протокола соблюдён. Размеры хранилища в
   `settings_storage_screen` приходят из провайдера, а не читаются синхронно в `build`.

7. **`ColorScheme.fromSeed` для свотчей палитры считается не в `build`.**
   `settings_appearance_screen.dart:559-581` — `_updatePreview()` вызывается в `initState` и
   `didUpdateWidget` при реальной смене seed/brightness/variant. Так и надо; в экранах звонков
   (B-1/B-2) — наоборот.

8. **`shrinkWrap: true` в моей зоне всегда с ограниченной высотой** — не нарушение п.7
   протокола: `chat_members_screen.dart:114-124` (`maxHeight: 40 % экрана`),
   `onboarding_screen.dart:787-790` (`maxHeight: 360`). Таймзон-пикер
   (`settings_language_region_screen.dart:279-286`) и остальные длинные списки — `builder`.

---

# Требует профилирования, а не чтения кода

1. **Сколько на самом деле стоит `ColorScheme.fromSeed`/`ThemeData` на целевых устройствах.**
   По коду видно, что они вызываются в горячем пути (B-1/B-2, m-2); насколько это больно —
   только DevTools timeline (секция UI/Raster) на реальном Android-девайсе среднего класса.
   От этого зависит, оставлять B-1/B-2 в blocker или опустить в major.
2. **Есть ли реальный offscreen-проход (saveLayer) на `Opacity` в `M3RouteTabSwitcher` (M-5).**
   В Impeller `OpacityLayer` на поддереве может композититься без offscreen-таргета; тогда
   цена M-5 — только лишние пересборки обёрток, а не полноэкранный рендер-таргет. Нужен
   `--profile` + трейс переключения таба (`flutter run --profile --trace-skia`/DevTools
   «Frame chart»), лучше на tier C.
3. **`DocxParser.parseBytes` на главном изоляте** (`native_file_viewer_screen.dart:607-619`).
   Парсинг `.docx` в `initState` синхронный, без `compute`. Для документа на 50-200 КБ это
   может быть 10-50 мс в одном кадре. Нужен замер на реальном файле, прежде чем переносить в
   изолят.
4. **Стоимость кадра при скролле инбокса с 300+ чатами и включённым presence.** По коду всё
   изолировано (см. п.2 нормального), но `SliverList` без `itemExtent` (n-2) и 2 dp-паддинг
   на строку могут давать раскладку каждого видимого ребёнка при каждом изменении списка.
   Нужен `--profile` с реальным объёмом чатов.
5. **Реакция видеоповерхности на пересборку.** В B-1 `RTCVideoView` пересобирается 3 раза в
   секунду; текстурный путь обычно к этому устойчив, но проверить дропы кадров на активном
   видеозвонке нужно трейсом, а не чтением.

---

## Вне моей зоны, но усиливает находки (для владельцев зон)

- `lib/providers/call_session_provider.dart:61-65, 217-222` — `notify()` через
  `state = null; state = cur;` на каждое событие `stateStream`, включая секундный тик
  длительности. Это двойная пересборка всех подписчиков (B-1, B-2, m-2) и единственный
  источник «бесплатной» работы в секунду. Логично уведомлять только при смысловой смене
  `currentData`.
- `lib/widgets/nav/m3_route_tab_switcher.dart:193-220` — M-5 целиком там.
- `lib/widgets/chat/chat_viewport.dart` — проверено, всё правильно (см. нормальное п.4).

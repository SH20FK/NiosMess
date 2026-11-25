# Аудит производительности — зона `lib/widgets/**` (без `chat/`, без `motion/`)

Дата: 2026-11-25. База: <https://docs.flutter.dev/perf/best-practices> + «Motion & Performance Protocol» из `F:\Niosmess V2\AGENTS.md`.
Метод: grep-разведка по 7 группам правил → чтение окружающего кода для каждого хита. Код не правился, сборки не запускались.

Покрытие: 110 dart-файлов (`widgets/settings` 19, `widgets/profile` 11, `widgets/wallpaper` 8, `widgets/nav` 5, `widgets/calls` 5, `widgets/common` 4, `widgets/contacts` 2, `widgets/media` 2, `widgets/notifications` 2, `update`, `about`, `adaptive`, `auth`, корень `lib/widgets/*.dart`).
Исключено по заданию: `*.g.dart`, `*.freezed.dart`, `lib/l10n/secret/generated/**`, `build/`, тесты, платформенные файлы.

## Счётчики

| Severity | Кол-во |
|---|---|
| blocker | 1 |
| major | 6 |
| minor | 10 |
| nit | 5 |
| **всего** | **22** |

---

## BLOCKER

### B1. Переключение табов: `saveLayer` на весь экран + полная перерисовка страницы каждый кадр
`lib/widgets/nav/m3_route_tab_switcher.dart:210-220`

```dart
child: RepaintBoundary(
  child: Opacity(
    opacity: i == _visible ? _opacity.value : 1,
```

Нарушено: п.4 гайда (Opacity вместо полупрозрачного цвета / Opacity в анимации) + saveLayer-правило + AGENTS «Zero Per-Frame Blur Rasterization» / «Eliminate Save-Layers».

Почему дорого: `RepaintBoundary` стоит **снаружи** `Opacity`. `RenderOpacity` умеет дешёвый путь только когда его *ребёнок* — repaint boundary: тогда альфа применяется на этапе композитинга (`context.pushOpacity`), без растеризации. Здесь порядок обратный: `saveLayer` попадает внутрь кэширующего слоя, и поскольку `_opacity.value` меняется каждый кадр, слой инвалидируется — каждый кадр перезаписывается вся страница таба (полный экран) + новый `saveLayer`. Плюс `AnimatedBuilder` (строка 193) без `child` пересобирает 5 `Offstage`-веток (~50 виджетов) на каждом кадре.

Фикс:
```dart
RepaintBoundary(                      // ← убрать
  child: Opacity(...                  // ← поменять порядок
Opacity(
  opacity: ...,
  child: RepaintBoundary(            // ← сюда
    child: Transform.translate(...),
```
и вынести неизменяемые обёртки (`Offstage`/`TickerMode`/`ExcludeFocus`…) в `child:` у `AnimatedBuilder`, оставив в билдере только `Opacity`+`Transform`.

---

## MAJOR

### M1. Хедер профиля: `Opacity` поверх всего содержимого на каждом пикселе скролла
`lib/widgets/profile_header_delegate.dart:40-43`, использует `:84-87` и `:212-218`

```dart
Widget _buildFadedLayer(double opacity, Widget child) {
  if (opacity <= 0.0) return const SizedBox.shrink();
  if (opacity >= 0.98) return child;
  return Opacity(opacity: opacity, child: child);
```

Нарушено: п.4 гайда + AGENTS «Eliminate Save-Layers» / «No per-frame layer».

Почему дорого: `SliverPersistentHeaderDelegate.build` вызывается на **каждое изменение `shrinkOffset`**, то есть на каждый кадр прокрутки профиля. `expandedOpacity` плавно меняется 1.0→0.0, поэтому почти весь скролл идёт через ветку `Opacity`: `saveLayer` на область ~230dp × ширина экрана, внутри — аватар 96dp (декодированное изображение), бейджи, текст. Каждый кадр = растеризация всей шапки заново + пересборка поддерева (включая `BadgeChip` → `BadgeResolver.resolve` и `PulseAvatar` с `RegExp` в `build`, см. m4).

Фикс: тот же приём, что в B1 — `RepaintBoundary` **внутрь** `Opacity` (шапка растеризуется один раз, альфа меняется на композитинге). Второй вариант — не анимировать альфу контейнера вовсе: переключать слои на пороге (`opacity < 0.02 → SizedBox.shrink()`) и анимировать только цвет фона (`Color.lerp` уже есть, строка 62, это дёшево).

### M2. Пикер файлов: `FutureBuilder` с future, создаваемым в `build()` — перезагрузка превью на каждое выделение
`lib/widgets/m3_file_picker_bottom_sheet.dart:1121-1128` (сетка) и `:1275-1289` (просмотр)

```dart
child: FutureBuilder<Uint8List?>(
  future: asset.thumbnailDataWithSize(
    const ThumbnailSize(250, 250),
```

Нарушено: п.1/п.7 гайда («пересоздание объектов в build()», работа в `build()`).

Почему дорого: `_toggleAssetSelection` (`:402-411`) делает `setState` → `GridView.builder` пересобирает видимые плитки → у каждой плитки создаётся **новый** `Future` → `FutureBuilder` сбрасывается в `waiting` (серая заглушка) и заново дёргает platform-channel `photo_manager`. Один тап по чекбоксу = N (число видимых плиток) round-trip'ов и мигание всех превью. В режиме просмотра (`:1275`) перезагрузка 1920×1920 превью происходит на каждый свайп страницы и на любой другой `setState` этого экрана (например переключатель «отправить как файл»).

Фикс: сделать плитку `StatefulWidget` с загрузкой в `initState`/`didUpdateWidget` и кэшем — ровно так уже сделано в `lib/widgets/media_grid_picker.dart:1409-1483` (`_AssetThumbnail` + `_AssetThumbnailCache` + `cacheWidth`). Для просмотра — тот же `_AssetThumbnail`-паттерн на 1920px с кэшем по `asset.id`.

### M3. Пузырь сообщения: `Image.memory` / `Image.file` без `cacheWidth` — декод в полном разрешении
`lib/widgets/message_bubble.dart:915-919` и `:930-933`

```dart
child: Image.memory(
  uploadTask!.bytes!,
  width: double.infinity,
  fit: BoxFit.cover,
```

Нарушено: п.4/п.7 гайда (декодирование изображений), «16 мс на кадр».

Почему дорого: фото с камеры 12 МП (4000×3000) декодируется в RGBA ~48 МБ и кладётся в `ImageCache`, хотя пузырь показывает максимум 320dp по высоте (`bubbleMaxHeight`). Для `Image.file` то же самое. Это происходит для каждого отправляемого изображения, пока идёт загрузка, и давит `ImageCache` (вытесняет остальные картинки → повторные декоды в списке чата).

Фикс: `cacheWidth`/`cacheHeight` (или `ResizeImage`), оценка — 2× ширина пузыря в физических пикселях:
```dart
Image.memory(uploadTask!.bytes!, cacheWidth: (400 * devicePixelRatio).round(), ...)
```
В этом же файле правильный пример уже есть: `:673-677` (`CachedNetworkImage` с `memCacheWidth: 400`).

### M4. `PostCard`: парсинг markdown + построение полного `MarkdownStyleSheet` на каждый `build()` фида
`lib/widgets/post_card.dart:368-383` (вызов из `:621`)

```dart
final markdown = MarkdownBody(
  data: post.content,
  inlineSyntaxes: [CustomEmojiSyntax()],
  builders: {'nios-emoji': CustomEmojiMarkdownBuilder()},
  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
```

Нарушено: п.1 гайда (тяжёлая работа в `build()`), п.7 (пересоздание объектов в `build()`).

Почему дорого: `MarkdownStyleSheet.fromTheme(...)` собирает десятки `TextStyle` на каждый билд каждой карточки, а `MarkdownBody` парсит разметку и строит дерево виджетов на каждый билд. Любой `setState` карточки (лайк, раскрытие «читать далее», смена `saved`/`isOwn`) заново парсит текст; в списке из 30 карточек это 30 парсингов на проход. `customEmojiSyntax`/`builders` — тоже новые объекты каждый раз.

Фикс: вынести `MarkdownBody` в отдельный `StatelessWidget` (`_PostMarkdown`) с `const`-подобной конфигурацией, `styleSheet` строить один раз на `Theme` (мемоизировать через `Theme.of(context)`-кэш или `static final` билдер синтаксисов), а сам результат парсинга — через `KeyedSubtree`/`ValueKey(post.content)` чтобы Flutter переиспользовал элемент. Дополнительно: `post.content.length > 400 || '\n'.allMatches(post.content).length > 6` (`:367-368`) — это O(n) проход по тексту в `build`, считать один раз при получении поста.

### M5. Настройки E2EE: `ref.watch(chatsProvider)` — вся страница пересобирается на каждое сообщение
`lib/widgets/settings/ordinary_e2ee_settings.dart:574` (внутри `build`, вызывается из `:350`)

```dart
Widget _contactSection() {
  final chats = ref.watch(chatsProvider).value ?? const [];
```

Нарушено: п.1 гайда (стоимость `build()`, пересборка большого поддерева), п.7 (пересборка высоко в дереве).

Почему дорого: страница — это `Column` со всеми секциями E2EE (~10 `SettingsListItem` + разделы с `SelectableText`/`DropdownButtonFormField`, и `DropdownMenuItem` на каждый direct-чат). `chatsProvider` меняется на любое событие чатов (новое сообщение, unread, presence-latящий апдейт), значит пока пользователь сидит в настройках, каждая входящая пересобирает всю страницу целиком. Плюс `build` заново пересобирает список `candidates` (`:575-577`) и `items:` дропдауна.

Фикс: `ref.watch(chatsProvider.select((v) => v.value?.where((c) => c.chatType == 'direct' && !c.isSecret && !c.isBotChat).map((c) => (c.id, c.name)).toList()))` — или вынести `_contactSection` в отдельный `ConsumerWidget`, который один подписан на селект; лучше — отдельный провайдер `directChatOptionsProvider`.

### M6. Мастер создания чата: неленивые `ListView` внутри `SingleChildScrollView` + coarse watch
`lib/widgets/create_chat_wizard_view.dart:917-918`, `:1035-1036`, watch на `:767`

```dart
child: ListView.separated(
  shrinkWrap: true,
```

Нарушено: п.5 гайда (`shrinkWrap: true` внутри другого скролла без ограниченной высоты, неленивые списки), п.1 (стоимость `build()`).

Почему дорого: оба списка вложены в `SingleChildScrollView` (`:776`), то есть получают бесконечную высоту — `shrinkWrap` в этом случае материализует **все** элементы сразу (контакты, результаты поиска), а не только видимые. Плюс `ref.watch(chatsProvider)` на `:767` без `select` пересобирает шаг со всеми строками на любое обновление чатов. Для аккаунта с 300+ диалогов это полный build+layout списка на каждый кадр ввода в поиск и на каждое сообщение.

Фикс: заменить пару «`SingleChildScrollView` + `shrinkWrap`» на один `CustomScrollView` (шапка — `SliverToBoxAdapter`, список — `SliverList.builder`) либо ограничить высоту списка (`SizedBox(height: …)`) и оставить `ListView.builder` без `shrinkWrap`. Watch — через `select` по нужным полям (`id`, `name`, `username`, `avatarUrl`).

---

## MINOR

### m1. `ChatTile`: два `LayoutBuilder` на строку в ленивом списке
`lib/widgets/chat_tile.dart:587`, `:726`

```dart
return LayoutBuilder(
  builder: (BuildContext context, BoxConstraints constraints) {
    final double slotCap = math.min(
```

Нарушено: п.6/п.7 (дополнительные layout-проходы в горячем пути). `LayoutBuilder` заставляет пересчитывать layout своего поддерева отдельной фазой; в строке их два. Для 15 видимых строк — 30 дополнительных проходов на кадр прокрутки/обновления presence.
Фикс: ширину для `slotCap` взять из родительского `ConstrainedBox`/`MediaQuery.sizeOf` (список одноколоночный), а `draftMaxWidth` заменить на `FractionallySizedBox`/`ConstrainedBox` с относительной шириной.

### m2. `ChatTile.build`: сборка строки semantics + `Map` экшенов на каждый билд
`lib/widgets/chat_tile.dart:259-282`, `:308-328`

```dart
final String semanticsLabel = <String>[
  widget.title,
  if (widget.isOnline && !widget.isSaved) context.l10n.online,
```

Почему дорого: ~15 обращений к `l10n` + `join(', ')` на каждую пересборку строки (а строки пересобираются при hover/presence/typing/selected), и это происходит даже когда semantics выключен. `actions: <Type, Action<Intent>>{...}` + `CallbackAction` аллоцируются заново каждый билд.
Фикс: ранний выход `if (!SemanticsBinding.instance.semanticsEnabled)` для метки; `actions` строить один раз в `initState`/`late final`.

### m3. `BadgeResolver.resolve` не мемоизирован, вызывается 2-3 раза на один бейдж
`lib/widgets/badge_chip.dart:277` (в `build`), `:216-222` (`isStatusBadge` → снова `resolve`), `:142-211` (~19 групп `contains` + `toLowerCase`)

```dart
static bool isStatusBadge(ApiBadge badge) {
  final res = resolve(badge.name, badge.icon);
```

Почему дорого: функция чистая и детерминированная, но каждый вызов делает две `toLowerCase` (аллокации) и до ~50 `String.contains`. В `post_card.dart:522-536` `isStatusBadge` вызывается дважды в `.where(...)` (для `isNotEmpty` и для `map`), плюс ещё раз внутри `BadgeChip.build`. На 30 карточек × 2 бейджа — ~180-250 полных резолвов за проход сборки.
Фикс: `static final Map<String, _BadgeResolved> _cache = {}` с ключом `'$name\u0000$icon'` (размер ограничить), и в `post_card` кэшировать отфильтрованный список бейджей в `late final`/`didUpdateWidget`.

### m4. `RegExp` и `split` в `build()` горячих виджетов
`lib/widgets/post_card.dart:736-740`, `lib/widgets/pulse_avatar.dart:61-64`, `:153-158`

```dart
return RegExp(r'\.(mp4|webm|mov|mkv|avi|3gp)$').hasMatch(path) ||
```
```dart
} else if (RegExp(r'\.(mp4|webm|mov)$', caseSensitive: false)
    .hasMatch(Uri.tryParse(url)?.path ?? '')) {
```

Почему дорого: `PulseAvatar` — самый частый виджет в приложении (каждая строка чата, каждый пост, каждый комментарий); на каждый его билд компилируется `RegExp`, а `_initials` дополнительно делает `split(RegExp)` + `toList` + `characters.take`. В `post_card` регулярка создаётся в `_isFeedVideo`, которая вызывается на каждый элемент карусели при каждом билде.
Фикс: `static final RegExp _videoExt = …` / `_spaceRe = RegExp(r'\s+')` рядом с классом; в `PulseAvatar` посчитать `initials` один раз (в `late final` по `id/name`) и передавать как параметр.

### m5. `TabMorphIcon`: `AnimatedBuilder` без `child` + два `Opacity` на кадр
`lib/widgets/nav/app_nav_item.dart:479-516`

```dart
return AnimatedBuilder(
  animation: _animation,
  builder: (BuildContext context, _) {
    final double t = _animation.value;
```

Нарушено: п.7 гайда (`AnimatedBuilder` без `child` для неизменяемого поддерева), п.4 (`Opacity` в анимации вместо `FadeTransition`).
Почему дорого: на каждом кадре морфа иконки заново собираются `Stack`, `SizedBox`, 2 `Icon`, 2 `Opacity` (каждый со своим `saveLayer` 24×24), `Transform.translate`, `Transform.scale`.
Фикс: `child:` = готовый `Stack` с двумя иконками, в билдере только `Transform`s, а прозрачность — двумя `FadeTransition` (это `RenderAnimatedOpacity`, слой не нужен при `child.isRepaintBoundary`).

### m6. Скелетоны: `FadeTransition` без `RepaintBoundary` внутри — пульсация перерисовывает все строки
`lib/widgets/pulse_skeleton.dart:177-178`, `:315` и `:530`

```dart
child: FadeTransition(
  opacity: opacity,
  child: SizedBox(
```

Почему дорого: одна общая анимация альфы (1200 мс, ping-pong) крутится всё время загрузки; без `RepaintBoundary` под `FadeTransition` каждая строка/карточка целиком перерисовывается на каждом кадре (а `PostCardSkeleton` — это ~40 контейнеров).
Фикс: `FadeTransition(opacity: opacity, child: RepaintBoundary(child: content))` — тогда альфа применяется при композитинге кэшированного слоя.

### m7. Пикер файлов: `indexWhere` в `itemBuilder` (O(n·m) на каждое выделение)
`lib/widgets/m3_file_picker_bottom_sheet.dart:806-809`

```dart
final int selectedIndex = _selectedAssets.indexWhere(
  (a) => a.id == asset.id,
);
```

Почему дорого: линейный поиск по списку выделенных для **каждой** пересобираемой плитки; тап по чекбоксу пересобирает все видимые плитки → `visible × selected` сравнений строк. Живёт в том же `setState`, что и M2.
Фикс: держать `Map<String, int> _selectedIndexById` (обновлять в `_toggleAssetSelection`) — O(1) на плитку.

### m8. Диалог устройств звонка: `setState` всего диалога 8 раз в секунду по таймеру
`lib/widgets/calls/call_devices_dialog.dart:128-140`

```dart
_timer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
  if (_reading || !mounted || _meter == null) return;
  _reading = true;
  try {
    final level = await _meter!.readLevel();
    if (mounted && generation == _generation) setState(() => _level = level);
```

Почему дорого: каждый тик — platform-channel вызов + пересборка всего диалога, включая `_selector` (`:167-177`), который на каждый билд делает `where(...).toList()` + дедуп через `Set`. Только `_level` реально меняется.
Фикс: `ValueNotifier<double> _level` + `ValueListenableBuilder` вокруг одного индикатора уровня; интервал 150-200 мс.

### m9. `StatusEmojiBadge` без `memCacheWidth` — полноразмерный декод в каждой строке чата
`lib/widgets/status_emoji_badge.dart:30-38`

```dart
: CachedNetworkImage(
    imageUrl: emoji.url,
    color: emoji.isAdaptive
```

Почему дорого: рисуется в слоте 16-18dp, но декодируется из исходника (если сервер отдаёт 256-512px — это в 100+ раз больше нужного по площади) и попадает в `ImageCache` на каждую строку списка чатов.
Фикс: `memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round()` (+ `cacheKey` со `size`).

### m10. `PostCard`: `select` со сканированием списка закладок — O(карточки × закладки)
`lib/widgets/post_card.dart:428-433`

```dart
final saved = ref.watch(
  niosgramSavedProvider.select(
    (value) => value.value?.any((post) => post.id == widget.post.id) ?? false,
```

Почему дорого: селектор выполняется при каждом эмите `niosgramSavedProvider` для **каждой** смонтированной карточки; при 50 карточках и 500 закладках — 25k сравнений на одно сохранение (и столько же на каждую загрузку списка закладок). Не катастрофа, но это O(n·m) в горячем пути и легко устранимо.
Фикс: отдать вниз готовый `isBookmarked` от фида либо держать в провайдере `Set<int> savedIds` и делать `select((v) => v.savedIds.contains(id))`.

---

## NIT

### n1. Настройки: всё дерево строк материализуется сразу, `Material` на каждую строку
`lib/widgets/settings/settings_shell.dart:84-89`, `lib/widgets/settings_ui.dart:107-121`, `:49`

```dart
sliver: SliverToBoxAdapter(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
```

Комментарий в коде (`:82-83`) объясняет решение (поиск должен находить контролы вне вьюпорта) — это осознанный компромисс, не ошибка. Но цена: `SliverToBoxAdapter` лэйаутит всю колонку, а каждая строка — это `Builder` + `SettingsGroupScope` + `Material` + `PressableSurface` (`ConsumerStatefulWidget`) + `FocusableActionDetector` + `GestureDetector` + `MouseRegion` + `M3PressScale`. На странице из 60 строк — ~600 виджетов и 120 подписок Riverpod, всё монтируется при открытии. `SettingsSection.build` вдобавок делает `children.where((c) => c is! Divider).toList()` (`settings_ui.dart:49`) на каждый билд.
Фикс (если замер покажет проблему): заменить `Material` на `DecoratedBox` там, где нет ink-splash (строка рисует свой state layer), и кэшировать отфильтрованный список в `didUpdateWidget`. Требует замера времени первого кадра.

### n2. Лист альбомов: `ListView.builder(shrinkWrap: true)`
`lib/widgets/media_grid_picker.dart:579-580`
`shrinkWrap: true` в шите материализует все альбомы и запускает `FutureBuilder` (`:603-604`, `album.assetCountAsync`) + превью для каждого. При 30-50 альбомах — 50+ platform-вызовов на открытие.
Фикс: ограничить высоту шита и снять `shrinkWrap` (или `ListView.builder` + `itemExtent`).

### n3. `CommentIcon`: `SvgPicture.string` в `build()`
`lib/widgets/comment_item.dart:19-34`
flutter_svg кэширует распарсенную картинку по ключу загрузчика, так что повторного парсинга XML нет — но на каждый билд аллоцируется `SvgStringLoader` и хэшируется ~300-символьная строка, в списке комментариев это десятки раз за проход.
Фикс: `static final Map<String, Widget Function(double, Color?)>` с готовыми `SvgPicture` или перейти на `Icons.*` там, где форма совпадает.

### n4. `IncrementalMediaList` не размонтирует элементы
`lib/widgets/profile/incremental_media_list.dart:98-107`
Батчи по 8 ограничивают **первый** кадр, но `_limit` только растёт: после прокрутки всего таба в дереве остаются все N изображений и виджетов (виртуализации нет). Для профиля с 500 фото это 500 `WsCachedImage` + `RepaintBoundary` + `ClipRRect` живых одновременно.
Фикс: для больших наборов — `SliverGrid`/`CustomScrollView` (он и так внутри скролла есть); либо окно `[start..end]` вместо накопительного `_limit`.

### n5. Мёртвая подсистема обоев
`lib/widgets/wallpaper/chat_wallpaper_background.dart:11-12` возвращает `ColoredBox`; `ChatWallpaperPainter.paintToCanvas` вызывается только из `wallpaper_image_cache.dart:329`, а `WallpaperImageCache` во всём `lib/` только `clear()`-ится (`providers/chat_wallpaper_provider.dart:128,141,174,183`) — картинка обоев никогда не запрашивается.
На кадр не влияет, но в бандле лежат `chat_wallpaper_painter.dart` (727 строк), `material_symbols_data.dart` (8559 строк map-литералов), `icon_sources_catalog.dart`, `cupertino_icons_data.dart`. Если фича отключена осознанно — код стоит удалить (и `saveLayer` на глиф в `chat_wallpaper_painter.dart:519` вместе с ним).

---

## Что проверил и признал нормальным

1. **`TouchContainer` — эталон по протоколу.** `clipBehavior: Clip.none` по умолчанию (`common/touch_container.dart:29`), state layer — `foregroundDecoration` (`:194-196`), а не блюр/`Opacity`; `setState` локален для строки, пресс-анимация — `M3PressScale`. Плитки/карточки не платят `saveLayer`. Так же аккуратно `PressableSurface` (`settings/pressable_surface.dart:104-123`).
2. **Списки ленивые.** Во всей зоне нет ни одного `ListView(children:)`, `GridView.count` или `Column` внутри скролла вместо списка (кроме осознанного `SettingsShell` и названного M6). Все — `.builder`/`.separated`; в ленте и профиле есть `RepaintBoundary` на плитку (`post_card.dart:448`, `profile_shared_media_tab_view.dart:740`), а в профиле ещё и `memCacheWidth: 280`. Дорогие производные списки мемоизированы по идентичности: `_mergeMediaMessages` (`profile_shared_media_tab_view.dart:424-442`), `_getOrExtractMedia` (`:321-352`).
3. **Анимации и контроллеры.** Ни одного `AnimationController` в `build()`; бесконечные циклы (`_TypingDots` `chat_tile.dart:1044-1052`, `_SkeletonPulse` `pulse_skeleton.dart:83-103`) сделаны через status-listener с проверкой `TickerMode`/`reduceMotion`, а не `.repeat()`. `CircularThemeReveal` снимает старое дерево через `toImageSync` с ограничением `pixelRatio` (`circular_theme_reveal.dart:115-120`) — ровно как требует LAG-12.
4. **Мелочи, которых нет:** ни одной конкатенации строк в цикле (везде `List<String>` + `join`), ни одного `operator ==` у `Widget`, `MediaQuery.of` в глубоких горячих виджетах отсутствует (два оставшихся — `call_overlay.dart:151` и `circular_theme_reveal.dart:101` — одноразовые, не в скролле), `IntrinsicWidth/Height` не используются вообще.

---

## Требует профилирования, а не чтения кода

- **M1/B1 количественно.** Нужен DevTools frame timeline на Impeller: сколько мс добавляет `saveLayer` хедера профиля и переключения таба на реальном устройстве (Impeller может обрабатывать слои иначе, чем Skia). Проверять сценарии «скролл профиля» и «быстрое переключение 5 табов».
- **M4 (markdown).** Цена парсинга `MarkdownBody` на реальных постах (400+ символов, эмодзи-синтаксис) в фиде из 30-50 карточек — по коду видно, что парсинг в билде, но нужен замер «rebuild» времени, чтобы понять, попадает ли в бюджет кадра.
- **n1 (настройки).** Время первого кадра длинной страницы настроек (privacy / e2ee / notifications) на low-end Android — станет ясно, нужна ли ленификация `SettingsShell` вопреки комментарию про поиск.
- **m3 (BadgeResolver).** Реальная стоимость `resolve` на боевых payload'ах бейджей; я оцениваю десятки микросекунд на вызов, но без замеров это оценка.
- **M3 (декод).** Фактическое время декода и рост RSS для `Image.memory` 12 МП JPEG на целевом устройстве (зависит от SoC и от того, отдаёт ли file_picker уже сжатые байты).
- **m1/m2 (ChatTile).** Попадают ли пересборки строки (presence/typing раз в секунду на N собеседников) в бюджет кадра в инбоксе с 30+ диалогами.
- **m6 (скелетоны).** Заметна ли пульсация альфы в профайлере как постоянная нагрузка во время загрузки ленты — зависит от того, сколько карточек-скелетонов в кадре.

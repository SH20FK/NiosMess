# 06 — Motion-примитивы + сквозная сверка: аудит производительности

Дата: 2026-11-25. Проект: `F:\Niosmess V2\pulse_flutter` (560 dart-файлов в `lib/` после игнора).
Эталон: <https://docs.flutter.dev/perf/best-practices> + локальный «Motion & Performance Protocol» из `F:\Niosmess V2\AGENTS.md`.

Ничего не правилось. Метод: grep по всему `lib/`, затем чтение **каждого** hit'а; отдельно вынесены ложные срабатывания.

## 0. Итог

| severity | кол-во |
|---|---|
| blocker | 1 |
| major | 7 |
| minor | 12 |
| nit | 6 |
| **всего** | **26** |

Главный вывод: **архитектура движения в этом проекте заметно выше среднего** — централизованные `M3SpringCurves`, ноль `MaskFilter.blur` в коде, ноль `IntrinsicWidth/Height`, ноль `AnimationController` в `build()`, O(1)-индексы в `findChildIndexCallback`, `RepaintBoundary` на поле ввода и панели записи, холодный старт через `AppStartupGate` + `Future.wait`. Основные потери — не в примитивах, а в трёх местах: **полноэкранные `Opacity`/`FadeTransition` вокруг целых вкладок и панелей**, **некэшированное декодирование изображений в пузыре сообщения**, и **`ShaderMask`/`Opacity` в скроллящихся полосах**.

## 1. Зона A — `lib/main.dart` (холодный старт)

Вердикт: **соответствует**. Ни одного замечания уровня major+.

- `main.dart:65-75` — `runApp(AppStartupGate(...))` вызывается **до** любой асинхронной работы; `AppStartupGate.initState` (`app_startup_gate.dart:36`) запускает инициализацию из `addPostFrameCallback`, т.е. первый кадр (сплэш) уже на экране. Тяжёлой синхронной работы до `runApp` нет: только `registerNiosProtocolLicenses()` / `registerNotoEmojiLicenses()` (регистрация строк лицензий, не парсинг).
- `main.dart:97-112` — `SharedPreferences`, `HiveBootstrap` и три кэша (`CacheService`, `EncryptedMessageCache`, `ChatMediaCache`) параллелятся через два вложенных `Future.wait`. Протокол «Parallelized Cold Start» соблюдён.
- `main.dart:239-294` — `DeepLinkService`, `DesktopWindowService`, Firebase инициализируются после первого кадра, каждое в `guarded(...)`, всё в одном `Future.wait`.
- `main.dart:329-452` — `build()` читает 7 срезов `uiSettingsProvider` через `select`, пересоздаёт тему (`AppTheme.themed`) на каждый ребилд `PulseApp`. Ребилды редкие (тема/локаль/шрифт), стоимость приемлемая; но `AppTheme.themed` в этом методе строит полный `ColorScheme.fromSeed` — если `PulseApp` начнёт ребилдиться часто (например, из-за `ref.watch(notificationsProvider)`), это станет дорого. Требует замера, а не правки.

Единственный nit: `main.dart:365` `_syncTimeSettings(...)` вызывается прямо из `build()` и мутирует глобальный `AppTimeSettings` (побочный эффект в `build`). Он идемпотентен и защищён сравнением с полями, поэтому дешёвый, но это тот же класс, что «no side-effects in build».

## 2. Зона B — `lib/widgets/motion/**` (10) и `lib/core/motion/**` (6)

### 2.1 Нормализация `SpringCurve` — корректна

`core/motion/m3_spring_constants.dart:84-121`:

```dart
final double raw = _rawResponse(t * span);
final double rawEnd = _rawResponse(span);
if (rawEnd == 0.0) return raw;
return raw / rawEnd;
```

Для всех трёх ветвей (ζ<1, ζ=1, ζ>1) `_rawResponse(0) == 0` (проверено по формулам: underdamped `1 - 1*(cos0 + 0)`, critical `1 - 1*(1+0)`, overdamped `1 - (r2-r1)/(r2-r1)`), а деление на `rawEnd` даёт `f(1) == 1` точно. Плюс `transform` (`:107-111`) клампит `t` в `[0,1]`. **Требование протокола «M3SpringCurves нормализованы» выполнено.**

- **nit** `m3_spring_constants.dart:117-118` — `_rawResponse(span)` пересчитывается на **каждом** вызове `transform` (2 лишних `exp`+`cos`/`sin` на кадр на каждую кривую). Значение константно для конкретного `SpringCurve`; можно посчитать один раз в конструкторе (класс `const`, поэтому — поле с `late final` или статический кэш). Экономия ~десятки наносекунд на кадр: чистота, не FPS.
- Отдельно: `SpringCurve` для `spatial*` законно даёт значения **>1** в середине (overshoot ~1.5% / ~9%). Это ок для `Transform`, но см. 2.3 про `SizeTransition`.

### 2.2 `M3PressScale`, `M3SelectionMotion` — чисто

`widgets/motion/m3_press_scale.dart:29-42` — `AnimatedScale` с `Duration.zero` под reduce-motion, никаких аллокаций в `build`, никакого `Opacity`.

`widgets/motion/m3_selection_motion.dart:27-36` — `TweenAnimationBuilder` с `child:` (поддерево не пересобирается), `transformHitTests: false`, `Transform.scale`. Образцовое решение.

### 2.3 `M3Reveal` — overshoot на layout-свойстве

- **minor** `widgets/motion/m3_reveal.dart:145-150` — `SizeTransition(sizeFactor: _spatialAnimation)` по умолчанию получает `curve = M3SpringCurves.spatialDefault` (`:28`), а он поднимается до ~1.015:

```dart
return SizeTransition(
  sizeFactor: _spatialAnimation,   // spatialDefault: >1 в середине
```

`SizeTransition` реализован через `Align(heightFactor:)`: фактор >1 означает, что содержимое рисуется **выше** своего бокса и обрезается `Clip.hardEdge` по умолчанию — на последних кадрах раскрытия контент дёргается на 1-2 px. Фикс: для `expandY` использовать не-overshoot кривую (`M3SpringCurves.effectsDefault` или `expressiveDecel`), а `spatialDefault` оставить только для `fadeScale`.
- **major-ish cost внутри примитива**: `expandY` (тип по умолчанию) каждый кадр меняет высоту → **релейаут всего поддерева** 60-120 раз за раскрытие. Для `M3Reveal` вокруг настроечной группы это нормально; для больших поддеревьев — дорого. Требует замера на реальных call-site (см. ниже), правки примитива не нужно.
- Call-sites проверены: `settings_privacy_screen.dart:46`, `settings_plus_screen.dart:265`, `settings_notifications_screen.dart:111`, `notifications/notification_settings_section.dart:152`, `features/sessions/presentation/sessions_screen.dart:88`, `settings/background_delivery_section.dart:120`, `settings/account_security_section.dart:141`, `features/account_deletion/presentation/account_deletion_screen.dart:279` — все вокруг небольших групп строк. Приемлемо.

### 2.4 `M3MorphingIcon` — два `Opacity` на кадр + устаревшая кривая

- **minor** `widgets/motion/m3_morphing_icon.dart:134,147` — две `Opacity` внутри `AnimatedBuilder.builder`:

```dart
final Widget outgoing = Opacity(opacity: (outProgress * 1.5).clamp(0.0, 1.0), child: Transform.scale(...));
final Widget incoming = Opacity(opacity: _fadeAnimation.value.clamp(0.0, 1.0), child: ...);
```

Иконка 24×24 → два `saveLayer` на кадр на каждую морфящую иконку. Для одной иконки в AppBar это шум, но `M3MorphingIcon` используется в `chat_list_screen.dart:312` и в `TabMorphIcon` (нижняя навигация, всегда на экране). Фикс: заменить `Opacity` на `FadeTransition` (тот же `saveLayer`, но без пересборки `builder`) — или, ради нуля слоёв, красить иконку через `color.withValues(alpha: t)`. Ничего не блокирует.
- **minor (корректность, не перф)** `m3_morphing_icon.dart:64-89` + `:91-99`: `_buildAnimations()` вызывается только в `initState`, а `didUpdateWidget` обновляет лишь `_currentIcon`. При смене `widget.curve` или `widget.duration` анимация остаётся на старой кривой/длительности (`_controller.duration` не обновляется вообще). `M3Reveal` это делает правильно (`m3_reveal.dart:101-108`) — здесь забыли.
- `M3MorphingIcon` под reduce-motion (`:111-118`) отдаёт голый `Icon` — правильно.

### 2.5 `M3Entrance` — правильный, один nit

`widgets/motion/m3_entrance.dart:46-60` — контроллер в `initState`, задержка внутри таймлайна (`Interval`), без `Timer`. `:83-96` — `AnimatedBuilder` с `child:` (поддерево не пересобирается). `:98` — `FadeTransition` по `effectsDefault` (без overshoot). Хорошо.

- **nit** `m3_entrance.dart:64-71` — `didChangeDependencies` не перезапускает/не сбрасывает анимацию при смене `delay`/`scaleFrom` в `didUpdateWidget` (их вообще нет). Для one-shot виджета приемлемо.
- Call-site `chat_list_screen.dart:682-693` — `M3Entrance` на строках контекстного меню с `delay: 20ms * index`. Меню монтируется заново при каждом открытии (комментарий это фиксирует), т.е. анимация не крутится в списке. Ложная тревога.

### 2.6 `M3StaggeredList` — `Timer` вне `TickerMode`

- **minor** `widgets/motion/m3_staggered_list.dart:85-89`:

```dart
_delayTimer = Timer(Duration(milliseconds: delayMs), () {
  if (mounted) { _controller?.forward(); }
});
```

`Timer` не подчиняется `TickerMode`, поэтому элемент, уехавший за пределы вьюпорта (или в `Offstage`) до срабатывания таймера, всё равно запустит тикер. Ограничение `index < maxStaggerIndex` (8) делает ущерб малым. Фикс: `TickerMode.of(context)` в колбэке или `_controller.forward()` только при `TickerMode.valuesOf(context).enabled` (как сделано в `chat_tile.dart:1050-1052`).
- **nit** `:117` — `Opacity` + `Transform.translate` в `builder` (поддерево кэшировано через `child:` — хорошо); при одновременном входе 8 плиток это 8 `saveLayer` на кадр в течение 300 мс. Можно заменить на `FadeTransition` (без пересборки builder'а).

### 2.7 `M3SpringSwitcher` — утечка `CurvedAnimation`

- **nit** `widgets/motion/m3_spring_switcher.dart:62-141` — в `_buildTransition` на каждый переход создаются `CurvedAnimation` (`:64`, `:72`, `:89`, `:106`, `:120`), которые нигде не `dispose()`. `transitionBuilder` вызывается не на каждый кадр (только при смене ребёнка), поэтому это не FPS-проблема, но листенеры висят на внутреннем `AnimationController` `AnimatedSwitcher` до его смерти. Чисто: хранить их в `State` или использовать `CurveTween` через `animation.drive(...)` (как сделано в `bubble_reaction_chip.dart:36-49`).

### 2.8 `M3ReactionBurst`, `M3AnimatedBadge` — чисто

- `m3_reaction_burst.dart:106-127` — `CustomPaint` под `AnimatedBuilder` без `saveLayer`, `clipBehavior: Clip.none`; painter создаёт `Paint` в `paint()` (1 аллокация на кадр) — ничтожно, `:177-182` корректный `shouldRepaint`.
- `m3_animated_badge.dart` — `ScaleTransition`, без `Opacity`; **nit** `:94-104` не обновляет `_controller.duration` при смене `widget.duration` (та же болезнь, что в 2.4).

### 2.9 `core/motion` — остальное

- `m3_page_transitions.dart:133-160` — `FadeTransition` + `AnimatedBuilder(child: child)` для `Transform.translate`: поддерево не пересобирается. **Цена**: полноэкранный `FadeTransition` = полноэкранный `saveLayer` на каждый кадр перехода между экранами (500 мс). Это цена выбранного дизайна (shared-axis с кросс-фейдом), а не ошибка; см. «требует профилирования».
- `nios_dismissible.dart:204-228` — `AnimatedBuilder` с `child: widget.child`, корректно. **nit** `:91-93` — `widget.onProgress` вызывается на каждый тик **в дополнение** к ребилду `AnimatedBuilder`; если подписчик делает `setState`, получаем двойную работу на кадр. Стоит задокументировать, что `onProgress` не должен вызывать `setState`.
- `smooth_text_streamer.dart` — см. 3.5 (major).
- `tri_sync.dart` — троттлинг 45 мс на тип события, `_lastTriggerTimes` — статическая карта; на кадр не влияет.

## 3. Зона C — сквозная сверка по всему `lib/`

Счётчики вхождений (файлы после игнора `*.g.dart`, `*.freezed.dart`, `lib/l10n/secret/generated/**`, `build/`, тестов):

| класс | вхождений | где самое критичное |
|---|---|---|
| `AnimationController(` | 32 | все в `State.initState`/`late final` — **нарушений нет** |
| `TickerProvider` (миксины) | 37 | — |
| `AnimatedBuilder(` | 29 | `m3_route_tab_switcher.dart:193` (без `child`) |
| `Opacity(` | 10 | `m3_route_tab_switcher.dart:211` (целая вкладка) |
| `AnimatedOpacity(` | 8 | `post_card.dart:829` (полноэкранное фото) |
| `FadeTransition(` | 40 | `m3_page_transitions.dart:152`, `chat_detail_screen.dart:3246` |
| `ShaderMask` | 1 | `chat/filter_bar.dart:295` (в скролле) |
| `BackdropFilter` | 4 (1 код) | `adaptive/adaptive_glass.dart:79` — **виджет не используется в `lib/`** |
| `MaskFilter.blur` | **0** | — |
| `ClipRRect(` / `ClipOval(` / `ClipPath(` | 31 / 10 / 0 виджетов (1 `canvas.clipPath`) | `circular_theme_reveal.dart:216` |
| `clipBehavior: Clip.antiAlias` | 12 | `message_bubble.dart:1423` (условный — ок) |
| `clipBehavior: Clip.hardEdge` | 2 | `expression_panel_frame.dart:120` |
| `clipBehavior: Clip.none` | 19 | `touch_container.dart:29` — дефолт правильный |
| `shrinkWrap: true` | 10 | `chat_members_screen.dart:124`, `create_chat_wizard_view.dart:918,1036` |
| `IntrinsicWidth/Height/IntrinsicColumnWidth` | **0** | — |
| `jsonDecode` | 108 | в `build()` — нет (все в сервисах/провайдерах) |
| `compute(` / `Isolate.` | 8 / 19 | `media_album_bubble.dart:42,52`, `ws_media_fetcher`, E2EE |
| `indexWhere` | 38 | **в лейауте — 0** (см. 3.4) |
| `findChildIndexCallback` | 4 | все на O(1)-картах |
| `operator ==` | 26 | ни одного у `Widget`-подкласса (см. 3.8) |

### 3.1 [blocker] Декодирование камерных изображений без `cacheWidth` в пузыре сообщения

`widgets/message_bubble.dart:910-944`:

```dart
child: Image.memory(uploadTask!.bytes!, width: double.infinity, fit: BoxFit.cover),
...
child: Image.file(localFile, width: double.infinity, fit: BoxFit.cover, ...),
```

Пузырь ограничен `maxHeight: 320` (`:905-906`), но `Image` декодирует исходник в полном размере: кадр с телефона 4000×3000 = **48 МБ RGBA на одну картинку** (`Image.memory` ещё и держит исходные байты). Пользователь отправляет альбом из 4 фото — 190+ МБ только на превью, до OOM на 3-4 ГБ Android. Это ровно тот пункт гайда, где `cacheWidth` обязателен, и ровно тот, который роняет приложение, а не «роняет FPS».

Фикс: `cacheWidth: (MediaQuery.sizeOf(context).width * dpr).round()` (≤1080) для обоих, `cacheHeight` не нужен при `BoxFit.cover` + ограниченной высоте; для `Image.file` достаточно `cacheWidth`.

Тот же дефект мельче: `widgets/create_chat_wizard_view.dart:556-561` — аватар 76×76 из сырых байтов пикера без `cacheWidth` (декодируется 4000×3000 ради 76 px).

Проверенные аналоги **корректны** (не трогать): `message_bubble` для уже отправленных фото идёт через `chat/ws_cached_image.dart:291-298` (считает `cacheWidth/Height` из размеров × dpr, дефолт 720); `native_file_viewer_screen.dart:1043-1050` (`safeDecodeWidth = screenW*dpr` в `[1080, 2048]`); `post_media_strip.dart:135-140` (`cacheWidth/Height: 200`); `pasted_images_dialog.dart:142-149` (`1600`) и `:182-184` (`176`); `media_grid_picker.dart:1478-1482` (`280`); `pulse_avatar.dart:99-100` (`memCacheWidth/Height` для `CachedNetworkImage`).

### 3.2 [major] Полноэкранный `Opacity` на каждой смене вкладки

`widgets/nav/m3_route_tab_switcher.dart:193-228`:

```dart
builder: (context, _) => Stack(... Offstage(... RepaintBoundary(
  child: Opacity(
    opacity: i == _visible ? _opacity.value : 1,
```

`AnimatedBuilder` без `child:` пересобирает `Stack` **на каждый кадр** перехода, и `Opacity < 1` на видимой вкладке означает **saveLayer размером с экран** 60-120 раз за ~300 мс на каждое переключение табов. Поддеревья вкладок при этом не пересобираются (`widget.children[i]` — те же инстансы, `Element.updateChild` их пропускает), так что это чистая цена растра.

Почему дорого: saveLayer полного экрана = аллокация offscreen-текстуры (например 1080×2400×4 ≈ 10 МБ) + полный blit каждый кадр; на Android это самый частый источник «просадки на переключении таба».
Фикс (по возрастанию радикальности): (а) не менять `opacity` у вкладки вообще — оставить `Transform.translate` + `Transform.scale` (они уже есть, `:213-218`) и кросс-фейдить только тонкий слой-подложку; (б) если кросс-фейд обязателен — фейдить не вкладку, а `ColoredBox(surface)` поверх неё (площадь та же, но без offscreen-копии контента); (в) оставить как есть и признать цену осознанной. Требует замера перед правкой — вариант (а) меняет дизайн.

### 3.3 [major] Кросс-фейд двух `ChatDetailScreen` на десктопе

`screens/main_shell_screen.dart:642-663`:

```dart
AnimatedSwitcher(
  transitionBuilder: (child, animation) => FadeTransition(
    opacity: animation, child: SlideTransition(position: ..., child: child)),
  child: desktopChatId != null ? ChatDetailScreen(key: ValueKey<int>(desktopChatId), ...)
```

При выборе другого чата `AnimatedSwitcher` на 250 мс держит **оба** `ChatDetailScreen` живыми: два `CustomScrollView` со своими строками, два `RepaintBoundary`, два `FadeTransition` (2 × saveLayer на весь пейн). На слабом десктопе это ровно тот кадр, где пользователь ждёт отклика. Фикс: убрать `FadeTransition` для такого крупного ребёнка (оставить `SlideTransition`/`ScaleTransition` — transform без слоёв) или перейти на `IndexedStack`-подход, как уже сделано для табов.

### 3.4 [major] `toImageSync` в 2× + `clipPath` на весь экран при смене темы

`widgets/circular_theme_reveal.dart:116-120`:

```dart
snapshotImage = boundary.toImageSync(
  pixelRatio: MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0).toDouble(),
);
```

Снимок **всего экрана** при 2× на телефоне 411×891 dp → текстура 2160×4680×4 ≈ **40 МБ**, выделяемая синхронно в момент тапа. На бюджетных Android это реальный шанс получить OOM/фриз именно на «смене темы». Плюс `:199-223` каждый кадр рисует полноэкранный `Path` с `fillType evenOdd` и `canvas.clipPath(path)` — клип по пути на полном экране дороже прямоугольного клипа на порядок.

Фикс: ограничить `pixelRatio` по площади (`min(2.0, sqrt(maxPixels / (w*h)))`, `maxPixels ≈ 4M`), а дырку рисовать без `clipPath`: `canvas.saveLayer` + `drawRect` + `BlendMode.clear` (или `drawCircle` маской через `saveLayer`), либо ограничиться `drawImageRect` с прямоугольным клипом по bounding box круга. Требует замера peak-memory.

### 3.5 [major] `SmoothTextStreamer`: таймер 16 мс + O(n²) строк

`core/motion/smooth_text_streamer.dart:35-40, 69, 108`:

```dart
_targetBuffer.write(chunk);
_target = _targetBuffer.toString();       // O(n) на каждый чанк → O(n²) на сообщение
...
_ticker = Timer.periodic(const Duration(milliseconds: 16), _onTick);
...
_currentRendered = target.substring(0, nextLength);   // новая строка каждый кадр
```

Три отдельные проблемы: (1) `StringBuffer` используется, но сразу же `toString()` на каждый чанк — выигрыша от `StringBuffer` нет, для длинного ответа AI (10-20 КБ, чанки по 1-5 символов) это мегабайты мусора и квадратичное копирование; (2) `Timer.periodic(16ms)` не синхронизирован с vsync — на 120 Гц кадры 8.3 мс, тик приходит «между кадрами», на 60 Гц — дрейфует; (3) `substring` каждый тик — неизбежно для текста, но с `Text.rich`/`buildTextSpan` лучше отдавать `target.substring(0, n)` без промежуточной строки-поля.

Фикс: хранить только `_targetLength` и `_target` (append к строке чанков редко, через `StringBuffer` + отдельный счётчик), а «тик» делать из `Ticker` (`createTicker`) или `SchedulerBinding.instance.scheduleFrameCallback`, чтобы кадры шли в ритме дисплея.

### 3.6 [major] `Opacity` в скролл-заголовке профиля

`widgets/profile_header_delegate.dart:40-44`:

```dart
Widget _buildFadedLayer(double opacity, Widget child) {
  if (opacity <= 0.0) return const SizedBox.shrink();
  if (opacity >= 0.98) return child;
  return Opacity(opacity: opacity, child: child);
}
```

`SliverPersistentHeaderDelegate.build` вызывается на **каждый** пиксель скролла (`shrinkOffset` меняется), и в диапазоне `progress` ~0.0-0.55 слой аватара/имени/бейджей проходит через `Opacity` → saveLayer на каждый кадр скролла, поверх картинки аватара. Классический пункт «Clip/Opacity внутри скролла».

Фикс: вместо `Opacity` на всём слое — сложить альфу в цвета (`textTheme...copyWith(color: base.withValues(alpha: o))`, `PulseAvatar` уже принимает `fallbackColor`/`textColor`) и оставить `Opacity` только для аватара-картинки, либо `FadeTransition` на двух отдельных маленьких поддеревьях.

### 3.7 [major] `ShaderMask` внутри горизонтального скролла

`widgets/chat/chat_filter_bar.dart:291-308`:

```dart
return ClipRRect(
  borderRadius: ...,
  child: ValueListenableBuilder<bool>(... => ShaderMask(
    shaderCallback: (bounds) => LinearGradient(...).createShader(bounds, ...),
    blendMode: BlendMode.dstIn,
    child: child,   // Listener > ... > SingleChildScrollView(horizontal)
```

`ShaderMask` = `saveLayer` на всю полосу, а полоса скроллится горизонтально: каждый кадр прокрутки — новый шейдер + saveLayer + композит. Площадь небольшая (~высота 40 dp), поэтому это major только при частом скролле; на 120 Гц заметно.

Фикс: заменить `ShaderMask` на два статических градиентных `DecoratedBox` по краям (fade-маска «поверх» полосы) — ноль слоёв, тот же вид. `shaderCallback` заодно перестанет создавать `LinearGradient` на каждый paint.

### 3.8 [minor] `Opacity` на плитке чата (saveLayer в скроллящемся списке)

`widgets/chat_tile.dart:425-442`:

```dart
: Opacity(
    opacity: widget.isMuted ? 0.9 : 1,
    child: PulseAvatar(...),
```

`Opacity` с `1.0` — no-op (Flutter не создаёт слой при alpha == 255), поэтому платят только замьюченные чаты: по одному saveLayer на такой ряд **на каждый кадр скролла**. Протокол требует «не создавать saveLayer в скроллируемых плитках».

Фикс: пробросить альфу в `PulseAvatar(textColor: ..., fallbackColor: ...)` и в `CachedNetworkImage` (обёртка `ColorFiltered` тоже плохо — лучше `Image(color: ...)` не выйдет; проще: `Opacity` заменить на `ColorFiltered`? нет) — практически: уменьшить прозрачность в цветах текста/фона и не оборачивать картинку. Если картинку обязательно гасить — гасить только на статичном экране, не в списке.

### 3.9 [minor] `ClipOval` на каждом аватаре

`widgets/pulse_avatar.dart:65, 74, 89` — три `ClipOval` (видео/веб/мобильный путь). `ClipOval` в плитке списка — это клип-слой на каждый ряд. `CircleAvatar` (используется в fallback, `:140`) умеет рисовать `backgroundImage` без отдельного клипа. Фикс: `CircleAvatar(backgroundImage: ...)` / `ClipRRect(borderRadius: BorderRadius.circular(radius))` там, где нужен именно клип — либо оставить (стандартная практика Flutter, экономия небольшая). Требует замера, чтобы понять, видно ли это в профиле.

### 3.10 [minor] `setState`/работа в горячем пути `build()` списка

- `widgets/chat/chat_message_list.dart:712-717` — **побочный эффект в build**:

```dart
if (shouldAnimate) {
  WidgetsBinding.instance.addPostFrameCallback((_) { _animatedMessageIds.add(_rowId(message)); });
}
```

Каждый ребилд такой строки регистрирует новый post-frame колбэк (сет идемпотентен, но колбэки копятся). Фикс: перенести в `didUpdateWidget`-эквивалент уровня списка/провайдера или проверить `if (!_animatedMessageIds.contains(id))` до регистрации.
- `widgets/chat/chat_message_list.dart:870-915` — при `addRepaintBoundaries: false` на `SliverList` (`:1030,1048`) строки оборачиваются в `RepaintBoundary` вручную (это ок и даже лучше: контролируемо), но `addAutomaticKeepAlives: false` + ручные boundary — убедиться, что список не перерисовывает весь viewport при появлении нового сообщения. Требует профилирования.
- `widgets/pulse_avatar.dart:61-64, 153-168` — `RegExp(r'\.(mp4|webm|mov)$')` и `RegExp(r'\s+')` **компилируются на каждый `build`** каждого аватара в списке. Фикс: `static final RegExp`. Мелочь, но в `ListView` на 50 рядов это 100 компиляций регулярки за кадр при скролле.

### 3.11 [minor] `shrinkWrap: true` + `NeverScrollableScrollPhysics` = неленивый список

Проверены все 10: это **не** «неограниченный shrinkWrap во вложенном скролле» (правило протокола формально не нарушено — везде есть либо `ConstrainedBox`, либо родитель даёт конечную высоту после shrink), но все они **строят всех детей сразу**:

| file:line | контекст | вердикт |
|---|---|---|
| `screens/chat_members_screen.dart:124` | `ListView.builder` результатов поиска пользователей в `ConstrainedBox(maxHeight: 0.4*H)` | **major-кандидат**: при 200+ результатах строятся все ряды. Убрать `shrinkWrap`, оставить скролл внутри `ConstrainedBox` |
| `widgets/create_chat_wizard_view.dart:918, 1036` | `ListView.separated` (контакты / результаты) внутри `SingleChildScrollView` (`:776-779`) | **неленивый список контактов**; заменить на `Column` с `...map` (тот же результат, без вьюпорта) или перевести экран на `CustomScrollView` |
| `features/chats/presentation/create_group_details_screen.dart:241` | `ListView.separated` выбранных участников внутри `ListView` (`:88`) | приемлемо: выбранных обычно < 20; формально — скролл в скролле |
| `screens/onboarding_screen.dart:790` | список таймзон в модалке, `ConstrainedBox(360)` | приемлемо (часовые пояса ~сотни, но модалка разовая) |
| `widgets/media_grid_picker.dart:580` | альбомы в bottom sheet | приемлемо |
| `features/wallpaper/.../presets_tab.dart:58` | `GridView.builder` пресетов, статический список | приемлемо |
| `widgets/chat/interactive_message_card.dart:143,252` | меню/голосующие в bottom sheet | приемлемо |
| `widgets/chat/interactive_composer.dart:337` | `ReorderableListView` внутри `SingleChildScrollView` (`:271`), максимум 20 | приемлемо |

### 3.12 [minor] `FadeTransition` по 10 скелетон-рядам одновременно

`widgets/pulse_skeleton.dart:177` (и `:315`, `:530`) — один контроллер, но `FadeTransition` **на каждом ряду** скелетона: 8-12 saveLayer на кадр, пока грузится список. Фикс: один `FadeTransition` вокруг всего `Column`/`ListView` скелетона.

### 3.13 [minor] Покадровый `select` в колбэке фреймтаймингов

`core/performance/adaptive_performance_provider.dart:314-317`:

```dart
final bool weakDeviceForced = ref.read(uiSettingsProvider.select((s) => s.optimizeForWeakDevices));
```

`_evaluateHysteresis` вызывается из `onTimings` на каждый батч `FrameTiming` (т.е. практически каждый кадр), а `provider.select(...)`, созданный инлайн, — это новый объект-селектор + подписка/отписка на родителя на каждый вызов. Это не «дорого» в абсолютных числах, но это работа **внутри** перф-контура, который сам себя измеряет — эффект наблюдателя. Фикс: читать `bool` из `ref.read(uiSettingsProvider).optimizeForWeakDevices` (без `select`), либо кэшировать значение через `ref.listenManual` в `build()` нотифаера.

### 3.14 [nit] прочее, проверенное и признанное нормальным

- `adaptive/adaptive_glass.dart:79` — единственный `BackdropFilter` в коде, но **`AdaptiveGlass` не используется ни в одном файле `lib/`** (только `test/widgets/adaptive_glass_test.dart`). Условия `isStaticPanel && inScrollable != true && tierA` (`:71-75`) корректны, но код мёртв → `tool/check_ui_architecture.dart:129` проверяет правило против виджета, который никуда не подключён. Решить: либо подключить осознанно, либо удалить (тогда `BackdropFilter` в приложении = 0).
- `widgets/common/touch_container.dart:29` — `clipBehavior = Clip.none` по умолчанию. **Требование протокола выполнено.**
- `widgets/message_bubble.dart:1423` — `clipBehavior: clipsMedia ? Clip.antiAlias : Clip.none`. **Правильно**: клип только когда он нужен.
- `widgets/chat/expression_panel_frame.dart:112-141` — `AnimatedBuilder` анимирует **высоту** контейнера с `Clip.hardEdge`, но `OverflowBox(minHeight: layoutHeight, maxHeight: layoutHeight)` держит констрейнты ребёнка постоянными → релейаута поддерева нет, только клип. Грамотно.
- `widgets/calls/call_audio_ripple.dart:80-89` — 4 `Paint` на кадр внутри `paint()`; `RepaintBoundary` вокруг есть (`:31`). Ничтожно.
- `main.dart:379-388` — `themeAnimationDuration: M3Durations.long2` (500 мс) + `themeAnimationCurve: M3SpringCurves.expressiveStandard` (Cubic, без overshoot). 500 мс анимации темы по всему дереву — заметно, но однократно; `Duration.zero` под reduce-motion и во время circular reveal — правильно.
- `widgets/nav/app_nav_item.dart:495,503` — две `Opacity` на иконку таба внутри `AnimatedBuilder` **без `child:`** (`:479-481`): поддерево (2 иконки в `Stack`) пересобирается каждый кадр переключения таба. Стоимость мала (2 иконки), но `child:` напрашивается.
- `widgets/nav/app_nav_item.dart:179-193` — `_withIndicator` использует `FadeTransition` + `AnimatedBuilder(child: DecoratedBox)` — образцово.

## 4. Ложные срабатывания (hit был, нарушения нет)

Приведены, чтобы их не «чинили» повторно:

1. `pulse_avatar.dart:75` `Image.network` — `width/height = radius*2` заданы, но `cacheWidth` для web-ветки формально нет; на web декодер работает иначе, а мобильный путь идёт через `CachedNetworkImage` с `memCacheWidth` (`:99`). Не дефект.
2. `native_file_viewer_screen.dart:1046` — есть `cacheWidth: safeDecodeWidth` (`:1049`).
3. `post_media_strip.dart:135` — `cacheWidth/Height: 200` (`:139-140`).
4. `pasted_images_dialog.dart:142,182` — `cacheWidth: 1600` / `176`.
5. `media_grid_picker.dart:1478` — `cacheWidth/Height: 280`; `:1376` — источник уже 1920-миниатюра (`thumbnailDataWithSize(1920,1920)`), но `cacheWidth` всё равно стоило бы добавить (nit).
6. `m3_file_picker_bottom_sheet.dart:1128` — источник 250×250 (`ThumbnailSize(250,250)`); `:1286` — 1920-миниатюра, nit.
7. `chat/ws_cached_image.dart:291` — `cacheWidth/Height` вычисляются из `widget.width/height × dpr` (`:266-289`). Образцово.
8. `chat_message_list.dart:1031,1049`, `chat_list_screen.dart:1168`, `niosgram_screen.dart:183` — `findChildIndexCallback` **не** использует `indexWhere`: везде O(1) (`_rowIndexes[key.value]`, `idToIndex[id]`, `idToIndex[key.value]`). **Требование протокола выполнено.**
9. `backend_chat_provider.dart` — 17 `indexWhere` в мутациях состояния (не в лейауте); это O(n) на операцию, но не на кадр. Вне зоны перф-рендера.
10. `shrinkWrap: true` × 10 — ни одного «неограниченного» случая (см. 3.11 — там же реальная цена неленивости).
11. `chat_tile.dart:1091` `Opacity` — только в ветке reduce-motion (статичная, один кадр).
12. `chat_empty_state.dart:137` — статичный экран, один paint.
13. `profile_header_delegate.dart:41-42` — ранние return (`opacity <= 0` → `SizedBox.shrink`, `>= 0.98` → ребёнок без слоя) — экономия есть, нарушение только в середине диапазона (см. 3.6).
14. `app_refresh_indicator.dart:130-135` — `AnimatedBuilder` + `child:`; `FadeTransition` получает кэшированное поддерево. Чисто.
15. `chat/noto_message_emoji.dart:337-356` — `AnimatedBuilder` с `child:`, `RepaintBoundary`, `addRepaintBoundary: false` у Lottie. Чисто.
16. `m3_staggered_list` в `settings_ui.dart:120` — `stagger` включается не всегда, лимит 8. Приемлемо.
17. `chat_detail_screen.dart:3183-3223` (`_AnimatedMessage`) — контроллер в `initState`, `Timer` отменяется в `dispose`, вход ограничен `_maxEntranceBatch` (`chat_message_list.dart:629-633`). Чисто; **nit**: `FadeTransition` на каждый входящий пузырь — по одному saveLayer на пузырь, но только для «свежего» батча.
18. `native_file_viewer_screen.dart:741` `Table` — без `IntrinsicColumnWidth`, колонки flex. `Intrinsic*` в проекте **ноль**.

## 5. Соответствие «Motion & Performance Protocol» (AGENTS.md)

| требование | статус | доказательство |
|---|---|---|
| никакого `MaskFilter.blur`/`BackdropFilter` в повторяющемся рендере и плитках | ✅ | `MaskFilter.blur` = **0**; `BackdropFilter` = 1, в виджете, который не используется в `lib/` |
| статические блюры — пре-рендер в `ui.Image` через `PictureRecorder`+`toImageSync`+`RawImage` | ✅/n.a. | блюров нет; отдельный `toImageSync` есть в `circular_theme_reveal.dart:116` (для снапшота темы, не блюра) |
| `clipBehavior: Clip.none` по умолчанию у переиспользуемых плиток/обёрток | ✅ | `touch_container.dart:29`; `19` явных `Clip.none`; `12` `Clip.antiAlias` — точечно и по делу |
| O(1) разрешение индекса, никакого `indexWhere` в `findChildIndexCallback`/лейауте | ✅ | 4 callback'а, все на `Map`; в `builder`/лейауте `indexWhere` нет |
| поле ввода и индикатор записи голоса в `RepaintBoundary` | ✅ | `chat_detail_input_area.dart:229,245`; `voice_recording_panel.dart:79` |
| `M3SpringCurves` нормализованы, никаких overshoot на `Opacity`/`FadeTransition` | ✅ (с nit) | `m3_spring_constants.dart:107-121`; все `FadeTransition`/`Opacity` используют `effects*`/`expressive*`; overshoot попадает только на `Transform` и на `SizeTransition` (см. 2.3) |
| никаких создания/старта/остановки `AnimationController` в `build()` | ✅ | 32 контроллера — все в `initState`/`late final`; у всех файлов с контроллером есть `dispose()` |
| никаких неограниченных `shrinkWrap: true` во вложенном скролле | ✅ формально | 10 случаев, все с конечной высотой; цена — неленивость (3.11) |

## 6. Что требует профилирования, а не чтения кода

1. **`m3_route_tab_switcher` Opacity (3.2)** — измерить raster time на переключении таба в DevTools (Performance → Raster) на Tier B Android; сравнить с вариантом без фейда вкладки.
2. **`main_shell` AnimatedSwitcher (3.3)** — время кадра при переключении чата на Windows-десктопе; проверить, действительно ли два `ChatDetailScreen` дают два прохода лейаута.
3. **`circular_theme_reveal` (3.4)** — peak memory (`adb shell dumpsys meminfo`) и raster time на 450 мс анимации; проверить на 1080p-устройстве с dpr 2.75 (там клампится в 2.0).
4. **`SmoothTextStreamer` (3.5)** — сколько мусора даёт длинный ответ AI (DevTools Memory, allocation profile); сравнить `Timer` vs `Ticker` по джиттеру кадров на 120 Гц.
5. **`chat_filter_bar` ShaderMask (3.7)** — raster time при горизонтальной прокрутке полосы фильтров.
6. **`profile_header_delegate` (3.6)** — время кадра при скролле профиля вверх (там же `SliverPersistentHeader` ребилдит всё).
7. **`chat_members_screen` / `create_chat_wizard` (3.11)** — время первого кадра при 200+ результатах поиска (eager build).
8. **`adaptive_performance_provider` (3.13)** — влияние покадрового `select` на собственные метрики (самонаблюдение).
9. **`chat_message_list`** — поведение `addRepaintBoundaries: false` + ручные boundary при появлении сообщения в середине стека (перерисовка только одной строки или всего viewport) и цена `findChildIndexCallback` на картах при большой истории.
10. **`ClipOval` в аватарах (3.9)** — есть ли вообще разница в raster time; если нет — не трогать.

## 7. Приоритет исправлений

1. `message_bubble.dart:915,930` — `cacheWidth` (blocker, риск OOM).
2. `m3_route_tab_switcher.dart:211` + `main_shell_screen.dart:650` — убрать полноэкранные `Opacity`/`FadeTransition` с целых вкладок/панелей (major).
3. `circular_theme_reveal.dart:116-120,216` — ограничить `pixelRatio` по площади, убрать `clipPath` (major).
4. `smooth_text_streamer.dart:35-40,69` — убрать `toString()` на чанк, перейти на `Ticker` (major).
5. `profile_header_delegate.dart:43` и `chat_filter_bar.dart:295` — убрать `Opacity`/`ShaderMask` из скролла (major).
6. `chat_members_screen.dart:124`, `create_chat_wizard_view.dart:918,1036` — убрать `shrinkWrap` (major-кандидат).
7. `m3_reveal.dart:145` — не-overshoot кривая для `SizeTransition` (minor, визуальный артефакт).

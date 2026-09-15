# NiosMess: план доведения плавности UI до уровня Telegram/WhatsApp

<aside>
🎯

План написан как рабочее задание для ИИ-агента по репозиторию `SH20FK/NiosMess` (ветка по умолчанию, ревизия `128d117`). Все находки — из фактического кода `pulse_flutter/lib`, не общие рекомендации. Работать строго по фазам: одна фаза = один PR = замер «до/после».

</aside>

## 1. Диагноз в одном абзаце

Приложение «дешевит» не из-за одной ошибки, а из-за наложения четырёх системных проблем: (1) под каждым экраном постоянно крутится декоративный фон, который каждый кадр пересобирает `Path` и накладывает `MaskFilter.blur(56)` — растеризатор занят всегда, даже когда UI статичен; (2) самописные «пружинные» кривые математически не нормированы и не приходят в 1.0 — каждая анимация заканчивается микро-рывком; (3) строка списка чатов содержит 4–5 неявных анимаций и `Clip.antiAlias`, то есть десятки `AnimationController` и save-layer'ов на один экран прокрутки; (4) в `build` списка сообщений выполняется работа O(n) и O(n²) на каждый кадр. Плюс переключение табов анимирует масштаб всего шелла, а адаптивная деградация производительности сама переключает визуал на ходу, создавая видимые скачки.

Важно: субъективная «плавность» Telegram/WhatsApp — это не «больше анимаций», а **дешёвый кадр + отсутствие рывков в конце анимации + отсутствие визуальных переключений режимов**. Половина задач ниже — это удаление, а не добавление.

## 3. Корневые причины (по приоритету)

### P0-1. Постоянная фоновая растеризация под всеми экранами

`lib/widgets/pulse_scaffold_body.dart` → `_PulseBackdrop` / `_BackdropPainter`:

- `AnimationController(duration: 80s)..repeat(reverse: true)` + `AnimatedBuilder` → `CustomPaint` перекрашивается **каждый кадр**;
- внутри `paint()` на каждом кадре: новый `Paint()`, `AppTheme.heroGradient(scheme).createShader(rect)`, три `Path` собираются заново в `_roundedPolygonPath` (тригонометрия + `quadraticBezierTo`), для каждой — свой `LinearGradient(...).createShader(...)` и `MaskFilter.blur(BlurStyle.normal, 56)` (на web 16);
- `shouldRepaint` возвращает true при любом изменении `t`, то есть 60–120 раз в секунду;
- `PulseScaffoldBody` обёрнут вокруг `body` в `MainShellScreen` → это работает на списке чатов, контактах, NiosGram и профиле одновременно с прокруткой.

Blur-маска радиусом 56 по полноэкранным путям каждый кадр — самая дорогая операция в приложении. За 80 секунд период анимация всё равно не читается глазом, то есть цена нулевой пользы.

То же семейство проблем: `lib/widgets/animated_mesh_background.dart` (контроллер 15 с `repeat()`, `MediaQuery.sizeOf(context)` внутри покадрового билдера, `Scaffold` в роли обёртки фона), `lib/widgets/m3_organic_background.dart`, `animated_background_blobs.dart`, `active_color_orb.dart`, `widgets/adaptive/adaptive_organic_background.dart`, `adaptive_mesh_background.dart`.

Отдельно: в `_PulseBackdropState.build()` и в `AnimatedMeshBackground.build()` контроллер создаётся/останавливается/перезапускается **внутри build** — это побочный эффект в билде, который сам генерирует лишние кадры.

<aside>
✅

В репозитории уже есть правильный образец: `lib/widgets/wallpaper/wallpaper_image_cache.dart` + `chat_wallpaper_background.dart` рендерят обои один раз в `ui.Image` и показывают через `RawImage`. Фоны нужно привести к этой же схеме.

</aside>

### P0-2. Самописные пружинные кривые не нормированы → рывок в конце каждой анимации

Два конкурирующих набора кривых:

- `lib/core/motion/m3_spring_constants.dart` → `SpringCurve extends Curve`: в `transformInternal(t)` считается затухающий осциллятор, где `t` из `[0,1]` подставляется как **время в секундах**. При `stiffness: 220, mass: 1` собственная частота ≈ 14.8 рад/с, то есть за `t = 1` система физически не успевает прийти в покой: `transform(1)` ≠ 1.0, а базовый `Curve.transform` принудительно возвращает 1.0 на конце → **разрыв на последнем кадре**. Это ровно то «дёрганье в конце», которое видно в интерфейсе.
- `lib/core/utils/app_curves.dart` → `_SpringCurve` делает то же самое с магическим множителем `t * 6`, и тоже не гарантирует `f(1) = 1`.
- Недодемпфированные кривые (`bouncy`, `springBouncy`) дают значения > 1, что нельзя использовать в `Opacity`/`FadeTransition`/`AnimatedOpacity` — значение клампится, анимация «залипает».
- В `expressive_tokens.dart` `AppMotion.spring = Curves.easeOutBack` (перелёт), и он же по умолчанию идёт в `TouchContainer` как `releaseCurve`.
- Каждая пружина считает `math.exp`, `math.sin`, `math.cos` на каждый сэмпл — не критично, но бессмысленно.

### P0-3. Слишком дорогая строка списка чатов

`lib/widgets/chat_tile.dart` на одну строку:

- `AnimatedContainer(150ms)` — 1 контроллер;
- `AnimatedSize(300ms, Curves.easeOutBack)` — 1 контроллер **плюс анимация layout'а** (самый дорогой тип анимации в списке);
- `_AnimatedBadge` → `AnimatedSwitcher(180ms)` — ещё контроллер;
- `TouchContainer` → `AnimatedScale` — ещё контроллер;
- при `animateEntrance` — пятый контроллер (`FadeTransition` + `SlideTransition`);
- `MouseRegion` с `setState` на hover → полный ребилд строки;
- `Hero(tag: 'chat_avatar_...')` на каждой строке списка.

При 10 видимых и ~20 закэшированных строках это 100+ живых `AnimationController`. Дополнительно `lib/widgets/common/touch_container.dart` по умолчанию ставит `clipBehavior: Clip.antiAlias` на `Container` с `decoration` → `ClipRRect` + сглаживание, то есть **save-layer на каждую строку**, хотя обрезка там не нужна.

В `lib/screens/chat_list_screen.dart` каждая строка ещё обёрнута в `Dismissible`, у которого `confirmDismiss` всегда возвращает `false` — то есть полноценный `Dismissible` (со своим контроллером и layout-логикой) используется только как детектор свайпа.

### P0-4. O(n) и O(n²) работа в `build` списка сообщений

`lib/widgets/chat/chat_message_list.dart`:

- `findChildIndexCallback` делает `messages.indexWhere(...)` — O(n) на каждый ключ, вызывается для многих ключей за layout → **O(n²)** на длинных чатах;
- `Set<int> replyTargets` пересобирается перебором **всех** сообщений на каждый `build` (а `build` случается на каждое нажатие клавиши, тик typing-индикатора, апдейт провайдера);
- `now = AppTimeSettings.now()` читается в `build`, и флаг анимации считается как `now.difference(message.resolvedSentAt).inSeconds < 4` → в течение 4 секунд любой посторонний ребилд **перезапускает анимацию появления** сообщения;
- параллельно в `animatedMessageBuilder` передаётся ещё один флаг `animate` для «самого нового» сообщения (`index == 0`) → два независимых конфликтующих сигнала анимации на один пузырь (`_AnimatedMessage` в `chat_detail_screen.dart`);
- определение звонков делается строковыми эвристиками в билде: `rawText.startsWith('📹')`, `rawText.contains('Видеозвонок')`, `rawText.contains('Голосовой звонок')` — плюс это нарушает правило локализации из корневого `AGENTS.md`;
- `cacheExtent: 350` — очень мало: новые пузыри строятся прямо в кадре прокрутки;
- каждый элемент обёрнут в `InkWell` (ink-слой и ripple в скроллящемся списке) + лишний `Container(key: itemKey)`;
- `Hero(tag: 'sender-avatar-<senderId>')` внутри списка → при нескольких сообщениях одного автора на экране получаются **дублирующиеся Hero-теги**;
- `GlobalKey` аллоцируется для любого сообщения, на которое есть ответ (`_messageKeys.putIfAbsent`);
- `lib/widgets/message_bubble.dart` — 74 КБ одного виджета: гигантский `build`, который целиком пересобирается на любое изменение.

`_scrollToMessage`: `setState` → `addPostFrameCallback` → `Scrollable.ensureVisible` → оценка позиции через магические `reversedIndex * 76.0` → вложенный второй `ensureVisible` → `Future.delayed(1600ms)` + `setState` для снятия подсветки. Итог: двойной прыжок скролла и два полных ребилда списка.

### P1-5. Переключение табов анимирует весь шелл

`lib/screens/main_shell_screen.dart`: `FadeTransition` + `ScaleTransition` навешены **вокруг всего `IndexedStack`**, то есть масштабируется и перекрашивается весь экран (включая уже смонтированные соседние табы), а `_tabScaleAnimation` использует `M3SpringCurves.spatial` с перелётом → весь интерфейс слегка «дышит» при каждом переключении. Плюс список `pages` целиком пересоздаётся внутри `LayoutBuilder` на каждый `build`, а переключение идёт через `context.go('/main/<tab>')`, то есть перестраивается вся страница роутера.

### P1-6. Predictive back: `setState` и save-layer'ы на каждый кадр жеста

`lib/core/motion/pulse_predictive_back_transition.dart`: `handleUpdateBackGestureProgress` вызывает `setState` на каждое событие прогресса, а `build` возвращает цепочку `Transform.scale` → `Transform.translate` → **`Opacity`** → **`ClipRRect`** → child. `Opacity` и `ClipRRect` создают save-layer на каждом кадре ровно в том жесте, который пользователь замечает сильнее всего. Плюс `MediaQuery.sizeOf` / `heightOf` читаются внутри покадрового билдера.

### P1-7. Адаптивная деградация сама создаёт скачки

`lib/core/performance/adaptive_performance_provider.dart` + `frame_timing_monitor.dart` работают корректно как телеметрия, но переключение `PerformanceTier` мгновенно меняет визуал: `AdaptiveGlass` перескакивает с `BackdropFilter(sigma 20)` на плоский контейнер, `AnimatedMeshBackground` останавливает/запускает контроллер посередине анимации. Деградация срабатывает по 4 тяжёлым кадрам подряд или jank-ratio > 0.15 — то есть именно в момент, когда кадры уже теряются, происходит массовая инвалидация виджетов и получается положительная обратная связь. `FrameTimingMonitor` при этом использует `_ringBuffer.removeAt(0)` (O(n) сдвиг) на каждый кадр.

### P1-8. `BackdropFilter` над скроллящимся контентом

`lib/widgets/adaptive/adaptive_glass.dart` — `ImageFilter.blur` sigma 20 (tier A) / 8 (tier B) внутри `ClipRRect(clipBehavior: Clip.antiAlias)`. `BackdropFilter` заставляет растеризатор снимать и блюрить всё, что под ним, каждый кадр. Также `BackdropFilter` используется в `splash_screen.dart` и `widgets/notifications/in_app_notification_banner.dart`. Отдельно: `lib/widgets/app_bottom_nav.dart` в floating-режиме рисует `BoxShadow(blurRadius: 28)` под `ClipRRect(28)` — и это ещё противоречит собственному правилу «no harsh BoxShadow» из `AGENTS.md`.

### P1-9. Клавиатура

Android-манифест ставит `windowSoftInputMode="adjustResize"`, Flutter отдаёт `viewInsets` пошагово во время системной анимации клавиатуры. Если поверх этого навешена любая неявная анимация (`AnimatedPadding`/`AnimatedContainer`) — получаются две анимации поверх друг друга и характерный «дребезг» панели ввода. Нужно проверить `chat_input_bar.dart` (45 КБ) и `chat_detail_input_area.dart` на этот паттерн.

### P2-10. Гранулярность состояния и старт

- `PulseApp` в `main.dart` — один `ConsumerWidget`, который слушает 6 срезов `uiSettingsProvider`, `appRouterProvider` и `callPushHandlerProvider` внутри `DynamicColorBuilder`, и на любое изменение настроек пересчитывает `AppTheme.themed(...)` дважды (светлая + тёмная). Плюс `builder` оборачивает каждый роут в `CircularThemeSwitcher` + `Stack` с тремя всегда смонтированными оверлеями.
- `AppTheme.themed` кэширует `ThemeData`, но ключ кэша собирается через XOR (`^`) разнородных значений → возможны коллизии ключей.
- `ChatListScreen.build` делает `ref.watch(authProvider)` целиком (а не через `.select`) → перестройка всего списка на любое поле auth.
- `main.dart` перед `runApp` последовательно ждёт `CacheService`, `EncryptedMessageCache`, `ChatMediaCache`, `SharedPreferences`, Firebase, `DeepLinkService`, `BackgroundService` → долгий холодный старт.
- `MainShellScreen.initState` запускает цепочку `Future.delayed` (500 мс биометрия, 800 мс alpha-диалог, 1500 мс web-push, 3 с OTA) → тяжёлая работа ровно в первые секунды после запуска.
- `AppScrollBehavior` в `main.dart` ставит `BouncingScrollPhysics` на всех платформах — на Android это чужая физика и читается как «не родное» приложение.
- Прогревается только один шейдер (`animated_mesh_gradient.frag`); остальные фрагментные шейдеры и первые кадры blur'ов дают компиляционный джанк на первом показе.

## 4. План работ по фазам

<aside>
⚠️

Порядок фаз не менять. Фаза 0 обязательна: без baseline любые «оптимизации» — угадывание. Фазы 1 и 2 дают 80 % ощутимого эффекта.

</aside>

### Фаза 0. Измерительный стенд и baseline

1. Прочитать `AGENTS.md` (корень), `pulse_flutter/AUDIT_REPORT.md`, `NIOSMESS_FULL_AUDIT_AND_UPGRADE_BLUEPRINT.md` — учесть уже зафиксированные договорённости и не ломать конвенции (Riverpod v3 без `StateProvider`, `universal_io`, `withValues(alpha:)`, M3E-протокол, обязательный bump версии + строка в `CHANGELOG.md`).
2. Завести `pulse_flutter/integration_test/perf/` со сценариями и прогонять через `flutter drive --profile --trace-startup`, сохраняя `TimelineSummary` в `perf/baseline/*.json`:
    - прокрутка списка чатов 5 с (≥ 50 чатов);
    - прокрутка чата с 500+ сообщениями 5 с в обе стороны;
    - открытие чата из списка и возврат свайпом;
    - переключение всех четырёх табов по кругу ×3;
    - открытие/закрытие клавиатуры ×5;
    - отправка 10 сообщений подряд;
    - экран в простое 3 с (контроль растеризации без взаимодействия).
3. Расширить существующий `FrameTimingMonitor`: заменить `_ringBuffer.removeAt(0)` на кольцевой индекс, добавить перцентили p50/p90/p99 отдельно по `buildDuration` и `rasterDuration` (сейчас считается только `max`, из-за чего непонятно, кто виноват — UI или GPU).
4. Добавить dev-экран/флаг для `PerformanceOverlay`, `debugRepaintRainbowEnabled`, `debugProfileBuildsEnabled`.
5. Зафиксировать в отчёте: для каждого сценария — p50/p90/p99 UI и raster, число пропущенных кадров, «кто виноват» (UI или raster).

**Критерий готовности:** в репозитории лежит воспроизводимый baseline и скрипт его повторного снятия.

### Фаза 1. Убрать постоянную нагрузку на растеризатор

1. `_PulseBackdrop` / `_BackdropPainter`: перевести на однократный рендер в `ui.Image` по схеме `WallpaperImageCache` (ключ кэша: `ColorScheme` + размер + DPR + brightness). Показывать через `RawImage`. Если анимация нужна — двигать **готовый закэшированный слой** дешёвым `Transform`/`FractionalTranslation`, без пересборки `Path`, без `createShader` и **без `MaskFilter.blur` в кадре**.
2. Вынести создание/старт/стоп `AnimationController` из `build` в `initState` / `didUpdateWidget` / `didChangeDependencies` во всех фонах (`pulse_scaffold_body.dart`, `animated_mesh_background.dart`, `adaptive_*_background.dart`).
3. Пройти по списку `AnimationController` (33 места) и для каждого декоративного фона решить: закэшировать в изображение, перевести на фрагментный шейдер через уже подключённый `flutter_shaders`/`AnimatedSampler`, либо удалить анимацию.
4. `AdaptiveGlass`: запретить использование над скроллящимися областями; ограничить sigma ≤ 10; для tier B/C — тональные `surfaceContainer*` вместо блюра (это и есть требование M3E из `AGENTS.md`).
5. `app_bottom_nav.dart`: убрать `BoxShadow(blurRadius: 28)`, заменить на тональную поверхность.
6. Проверить, что каждый декоративный фон обёрнут в `RepaintBoundary` и **не** находится внутри поддерева, которое пересобирается при прокрутке.

**Критерий готовности:** на экране в простое raster ≈ 0 мс, GPU не работает; raster p99 при прокрутке списка чатов упал минимум вдвое от baseline.

### Фаза 2. Плавность списков

**Список сообщений (`chat_message_list.dart`):**

1. Построить `Map<int, int> idToIndex` рядом с `byId` при пересчёте `_precomputeLayout` и использовать его в `findChildIndexCallback` — O(1) вместо `indexWhere`.
2. Вынести `replyTargets` и все производные множества/мапы из `build` в мемоизированное состояние, пересчитывать инкрементально при изменении списка, а не на каждый кадр.
3. Убрать зависимость анимации от часов: флаг «анимировать появление» должен вычисляться **один раз** при первом монтировании элемента (например, `Set<int> alreadyAnimated` в состоянии), а не через `now.difference(...) < 4`. Оставить **один** источник сигнала анимации, убрать конфликт `isNewest` vs `now.difference(...)`.
4. Заменить строковые эвристики определения звонков на поле/enum в модели сообщения (`msgType`), убрать хардкод русских строк.
5. Убрать `InkWell` и лишний `Container` вокруг пузыря; жесты — один `GestureDetector` на элемент; убрать `Hero` из элементов списка (или оставить только для конкретного элемента, по которому произошёл тап, через shuttle).
6. Разбить `message_bubble.dart` (74 КБ) на небольшие виджеты с `const`-конструкторами; всё форматирование, парсинг markdown/ссылок/времени вынести из `build` в предвычисление на уровне модели или селектора.
7. Подобрать `cacheExtent` экспериментально (пробовать 600–1200) **после** того, как элемент станет дешёвым; рассмотреть `itemExtentBuilder`/`prototypeItem` для однотипных пузырей.
8. Переписать `_scrollToMessage`: убрать магический `reversedIndex * 76.0`, двойной `ensureVisible` и `Future.delayed(1600ms) + setState`. Подсветку сделать локальным состоянием самого пузыря (`ValueNotifier`/`AnimationController` внутри элемента), чтобы снятие подсветки не ребилдило список. Для перехода к сообщению рассмотреть `super_sliver_list` или `scrollable_positioned_list` — они умеют точный jump по индексу в reverse-списке.

**Список чатов (`chat_tile.dart`, `chat_list_screen.dart`):**

1. В `TouchContainer` заменить дефолт `clipBehavior: Clip.antiAlias` на `Clip.none` (обрезку включать явно там, где она реально нужна) — убирает save-layer на каждую строку.
2. Сократить число неявных анимаций на строку до одной: `AnimatedSize` убрать полностью (инлайн-раскрытие действий заменить на bottom sheet / контекстное меню `MenuAnchor`), hover/pressed сделать чисто «покрасочным» (без `setState` всей строки — через `ValueListenableBuilder` или `DecoratedBox` с оверлеем).
3. Убрать `Hero` из строки списка чатов, `animateEntrance` — только для реально новых строк, не для всех при первом показе.
4. Заменить `Dismissible` (который никогда не dismiss'ит) на лёгкий собственный свайп-детектор с одним контроллером, либо убрать свайп в пользу long-press меню.
5. `findChildIndexCallback` в `chat_list_screen.dart` — тоже на `Map<int, int>` вместо `indexWhere`.
6. `ref.watch(authProvider)` → `.select` по нужному полю; аналогично пройтись по `ref.watch` без `select` в экранах списков.

**Критерий готовности:** 0 пропущенных кадров за 5 с прокрутки 500 сообщений и 50 чатов; UI p99 ≤ 6 мс; число живых `AnimationController` на экране списка снижено минимум в 3 раза (замерить через DevTools / счётчик в dev-сборке).

### Фаза 3. Единая корректная система движения

1. Оставить **один** набор токенов движения. Рекомендация: `core/motion/` как источник истины, `AppCurves` удалить, `AppMotion` — переключить на него (сейчас `AppMotion.spring = Curves.easeOutBack`, что противоречит собственному правилу «always use `M3SpringCurves`»).
2. Починить `SpringCurve`: либо нормировать время по времени успокоения (чтобы `f(0) = 0`, `f(1) = 1` строго, без клампа на конце), либо — предпочтительно — **не использовать кривую для пружины**. Для жестовых и «физических» анимаций брать реальную симуляцию: `SpringDescription` + `SpringSimulation` и `AnimationController.animateWith(...)`; для остального — длительность + кубическая кривая (`Curves.easeOutCubic`, `Curves.easeInOutCubicEmphasized`).
3. Запретить кривые с перелётом (`bouncy`, `easeOutBack`, `springBouncy`) для `Opacity`/`FadeTransition`/`AnimatedOpacity` и для масштабирования крупных поверхностей. Для этого добавить в кривые аннотацию/разделение: `opacitySafe` vs `spatial`.
4. Свести длительности к `M3Durations` (short/medium/long) и зафиксировать правило: реакция на тап ≤ 150 мс, переход внутри экрана 200–300 мс, переход между экранами 300–400 мс.
5. Уважать `MediaQuery.disableAnimations` / `AccessibilityFeatures.disableAnimations` — при включённом режиме отключать декоративные анимации, а не просто ускорять.
6. Добавить golden/unit-тесты на кривые: `curve.transform(0) == 0`, `curve.transform(1) == 1`, монотонность для opacity-кривых, отсутствие значений вне `[0, 1]`.

**Критерий готовности:** тесты кривых зелёные; визуально исчез рывок на последнем кадре анимаций (проверить записью экрана 120 fps или пошаговым скриншотом через `--slow-motion`).

### Фаза 4. Переходы: табы, роуты, back-жест

1. `MainShellScreen`: убрать `ScaleTransition` вокруг `IndexedStack`. Анимировать только **входящую** страницу — `FadeThroughTransition` из уже подключённого пакета `animations`, либо просто мгновенное переключение (как в Telegram) + анимация индикатора в навбаре.
2. Вынести построение списка `pages` из `build`/`LayoutBuilder` в мемоизированные поля, чтобы поддеревья табов не пересоздавались на каждый ребилд шелла.
3. `pulse_predictive_back_transition.dart`: убрать `setState` на каждое событие прогресса — драйвить трансформации напрямую от `route.animation` через `AnimatedBuilder`/`Animation` без перестроения дерева; заменить `Opacity` на `FadeTransition`, `ClipRRect` перевести на `Clip.hardEdge`, радиус не анимировать покадрово (или взять статический `MediaQuery.displayCornerRadiiOf`); `MediaQuery.sizeOf/heightOf` кэшировать в `didChangeDependencies`.
4. Провести аудит всех `Hero`-тегов на уникальность в один момент времени (в первую очередь `sender-avatar-<senderId>` в `chat_message_list.dart` и `chat_avatar_*` в `chat_tile.dart`).
5. `AppScrollBehavior`: физика по платформе — `ClampingScrollPhysics` на Android, `BouncingScrollPhysics` на iOS/macOS (сейчас bouncing везде).

**Критерий готовности:** raster p99 во время перехода между экранами и жеста «назад» ≤ бюджета кадра; нет ассертов дублирующихся Hero-тегов; переключение табов — 0 пропущенных кадров.

### Фаза 5. Клавиатура и панель ввода

1. Проверить `chat_input_bar.dart` и `chat_detail_input_area.dart`: убрать любые неявные анимации, которые дублируют системную анимацию клавиатуры; позиционировать панель напрямую по `MediaQuery.viewInsetsOf(context).bottom` без `AnimatedPadding`/`AnimatedContainer`.
2. Убедиться, что изменение текста в поле ввода и typing-индикатор **не** приводят к ребилду списка сообщений: панель ввода и список должны быть независимыми поддеревьями с `RepaintBoundary` и раздельными провайдерами (`select`).
3. Оптимистичная отправка: новый пузырь должен появляться в том же кадре, без полного пересчёта layout списка (см. инкрементальный `_precomputeLayout` из фазы 2).

**Критерий готовности:** открытие/закрытие клавиатуры — 0 пропущенных кадров; набор текста не вызывает `build` списка сообщений (проверить счётчиком билдов в тесте).

### Фаза 6. Адаптивная деградация без визуальных скачков

1. Переключение `PerformanceTier` применять только в «спокойные» моменты: не во время активного жеста/прокрутки/перехода. Добавить в `AdaptivePerformanceNotifier` условие «нет активного скролла и нет активного роут-перехода».
2. Любое переключение визуала по tier — через кроссфейд (`AnimatedSwitcher`/`AnimatedCrossFade`), а не мгновенной подменой дерева.
3. Увеличить гистерезис и cooldown (сейчас 8 с вниз / 5 с вверх, деградация по 4 тяжёлым кадрам). Цель: не более 1 переключения за сессию в нормальных условиях.
4. Не останавливать/запускать контроллеры в `build` (см. фазу 1) — после кэширования фонов бóльшая часть tier-логики для фонов вообще станет ненужной.

**Критерий готовности:** в сценариях фазы 0 не происходит ни одного переключения tier; при принудительном переключении нет визуального «щелчка».

### Фаза 7. Старт, шейдеры, платформа

1. Распараллелить инициализацию в `main.dart`: то, что не нужно до первого кадра (Firebase, `BackgroundService`, `DeepLinkService`, прогрев кэшей), выполнять после первого кадра через `addPostFrameCallback` + `SchedulerBinding.instance.scheduleTask(..., Priority.idle)`; `Future.wait` для независимых инициализаций.
2. Цепочку `Future.delayed` в `MainShellScreen.initState` (биометрия/alpha-диалог/web-push/OTA) перевести на idle-планирование и разнести так, чтобы они не накладывались на первые секунды работы.
3. `PulseApp`: разбить на несколько узких `Consumer`-поддеревьев, чтобы изменение одной настройки не пересобирало всё приложение; `AppTheme.themed` — заменить XOR-ключ кэша на `Object.hash(...)`; пересчитывать только актуальную яркость темы.
4. Проверить рендер-бэкенд: убедиться, что на Android используется Impeller (и зафиксировать это осознанно в конфигурации), снять трейс с `--trace-skia`/DevTools Raster, отдельно измерить джанк первого показа каждого экрана (компиляция шейдеров). Прогревать не только `animated_mesh_gradient.frag`, но и остальные используемые шейдеры/эффекты.
5. Проверить поведение на 90/120 Гц: `FrameTimingMonitor.detectRefreshRate` уже есть — убедиться, что бюджет считается по фактической частоте и что анимации не привязаны к 60 fps неявно.

**Критерий готовности:** cold start −30 %; при первом открытии каждого экрана нет одиночного кадра > 2× бюджета.

### Фаза 8. Защита от регрессий

1. Перф-сценарии из фазы 0 — в CI (`.github/workflows/build.yml`), с порогами: падение сборки при росте p99 или числа пропущенных кадров.
2. Тесты на количество билдов: «набор текста не ребилдит список», «изменение typing не ребилдит строку чата».
3. Скрипт/линт-гард (можно grep-скриптом в CI) на запрещённые паттерны:
    - `BackdropFilter` в файлах элементов списков;
    - `MaskFilter.blur` внутри `CustomPainter.paint`;
    - создание `Paint`/`createShader`/`Path` внутри `paint()` без кэша;
    - `Clip.antiAlias` по умолчанию в переиспользуемых контейнерах;
    - `shrinkWrap: true` внутри другого скроллящегося виджета (сейчас встречается в 13 файлах — проверить каждый: `post_card.dart`, `chat_detail_screen.dart`, `create_chat_wizard_view.dart`, `profile_shared_media_tab_view.dart`, `chat_members_screen.dart`, `sticker_set_screen.dart`, `inline_query_overlay.dart`, `user_search_picker_sheet.dart`, `badge_selector_dialog.dart`, `setup_onboarding_screen.dart`, `settings_language_region_screen.dart`, `app_error_banner.dart`, `spamblock_banner.dart`);
    - `indexWhere` внутри `findChildIndexCallback`;
    - `AnimationController` создаётся/останавливается в `build`.
4. Раздел «Motion & Performance» в корневой `AGENTS.md` с этими правилами, чтобы будущие агенты не откатывали работу.

## 5. Жёсткие инварианты для агента

- Плавность оценивать **только** в `--profile` на физическом устройстве. Debug-сборка бесполезна для этого.
- Одна фаза = один PR. В описании PR — таблица «до/после» по метрикам из фазы 0. Без цифр PR не принимается.
- Никаких «косметических» рефакторингов вперемешку с перф-изменениями.
- Ничего не добавлять в `build`, что можно вычислить один раз. Особенно в билдерах списков.
- Внутри `CustomPainter.paint` запрещено создавать `Paint`, `Path`, шейдеры и `MaskFilter` — только переиспользовать заранее собранные.
- `Opacity`, `ClipRRect(Clip.antiAlias)`, `BackdropFilter`, `ShaderMask`, `ColorFiltered` — каждый вызов save-layer'а должен быть обоснован; в элементах списков и в пер-кадровых билдерах их не должно быть.
- Не добавлять новые анимации в этом проекте. Задача — убрать рывки существующих.
- Соблюдать конвенции из корневого `AGENTS.md`: Riverpod v3 (`NotifierProvider`/`AsyncNotifierProvider`), `universal_io` вместо `dart:io`, `withValues(alpha:)`, все строки через `context.l10n`, никаких `CircularProgressIndicator` напрямую, `MenuAnchor` вместо `PopupMenuButton`.
- Не редактировать `lib/l10n/app_localizations.dart`, `*.g.dart`, `*.freezed.dart`, `pubspec.lock`.
- На каждую задачу — bump `version: X.Y.Z+build` в `pulse_flutter/pubspec.yaml`; при minor-бампе запросить у пользователя человеческую строку для `CHANGELOG.md` (без маркетингового мусора).
- Перед коммитом: `flutter analyze`, `dart test` (или `flutter test`, где нужны `flutter_test`/`dart:ui`), `flutter gen-l10n` при изменении строк.

## 6. Готовый бриф для ИИ-агента (копировать в задачу)

```
Репозиторий: SH20FK/NiosMess, рабочая директория pulse_flutter.
Цель: устранить дёрганые анимации и довести плавность до уровня Telegram/WhatsApp.

Сначала прочитай: AGENTS.md (корень), pulse_flutter/AUDIT_REPORT.md,
NIOSMESS_FULL_AUDIT_AND_UPGRADE_BLUEPRINT.md и этот план целиком.

Работай строго по фазам 0 → 8. Одна фаза = один PR.
В каждом PR обязательно: таблица метрик до/после (UI p50/p99, raster p99,
пропущенные кадры) по сценариям из фазы 0, снятых в --profile на реальном
устройстве. Без цифр PR не закрывается.

Запрещено: оценивать плавность в debug; добавлять новые декоративные
анимации; создавать Paint/Path/шейдеры внутри CustomPainter.paint;
использовать BackdropFilter или Clip.antiAlias в элементах списков;
стартовать/останавливать AnimationController внутри build; использовать
кривые с перелётом для Opacity.

Начни с фазы 0 и покажи мне baseline перед тем, как что-либо менять.
```

## 7. Риски и подводные камни

- **Изменение физики скролла на Android** заметят пользователи, привыкшие к bouncing. Это корректное решение (родное поведение платформы), но стоит упомянуть в changelog.
- **Кэширование фонов в `ui.Image`** даёт рост потребления памяти. Ключ кэша должен включать размер и DPR, а сам кэш — иметь ограничение по количеству записей и сброс на `didChangeMetrics`/смене темы.
- **Удаление `AnimatedSize` и инлайн-раскрытия в строке чата** — это изменение UX, не только перфоманса. Согласовать с пользователем до реализации.
- **Отказ от `Dismissible`** требует аккуратной реализации свайпа, иначе пострадает доступность и жесты будут конфликтовать со свайпом «назад».
- **Нормализация пружинных кривых** изменит тайминги во всём приложении сразу — делать отдельным PR и просматривать визуально ключевые экраны.
- **Перф-тесты в CI** без реального устройства/GPU ненадёжны. Реалистичный компромисс: в CI держать тесты на количество билдов и grep-гарды, а полный перф-прогон делать вручную на устройстве по чек-листу перед релизом.

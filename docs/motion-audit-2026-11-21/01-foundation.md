# Аудит motion: фундамент (2026-11-21)

# Аудит motion-фундамента NiosMess (`lib/core/motion`, `lib/widgets/motion`)

Прочитано целиком: все 6 файлов `lib/core/motion/`, все 11 файлов `lib/widgets/motion/`, плюс точки интеграции (`app_router.dart`, `app_theme.dart`, `app_modal.dart`, `expressive_tokens.dart`, `app_curves.dart`, `call_design_tokens.dart`, `touch_container.dart`, `pressable_surface.dart`, `m3_route_tab_switcher.dart`, `settings_appearance_screen.dart`, `chat_detail_screen.dart`). Все цифры ζ/ωn/overshoot посчитаны из кода, не взяты из комментариев.

---

## 1. Инвентарь

### 1.1 SpringDescription-токены (`M3Spring`)

| Токен | файл:строка | mass / stiffness / damping | Фактическая ζ = c/(2√(k·m)) | Заявлено в комментарии | Эталон M3E | Использований в `lib/` |
|---|---|---|---|---|---|---|
| `spatial` | `m3_spring_constants.dart:14-18` | 1.0 / 220 / 26 | **0.876** | «~0.75» (:13) | expressive slow spatial 200 / 0.8; standard slow 300 / 0.9 | 1 (`nios_dismissible.dart:168`) + алиасы `nios_motion.dart:14` |
| `emphasized` | `:21-25` | 1.0 / 200 / 22 | **0.778** | «~0.70» (:20) | токена нет (M3E отказался от «emphasized» в пользу expressive/standard) | 0 (только алиас `nios_motion.dart:18`) |
| `snappy` | `:28-32` | 1.0 / 340 / 32 | **0.868** | «~0.85» | fast spatial 800 / 0.6 — не совпадает | 0 |
| `bouncy` | `:35-39` | 1.0 / 260 / 18 | **0.558** | «~0.55» ✔ | expressive fast 800 / 0.6 | 1 (`settings_appearance_screen.dart:501`, как `ScrollPhysics.spring`) |
| `gentle` | `:42-46` | 1.0 / 150 / 22 | **0.898** | «~0.90» ✔ | effects — всегда ζ = 1.0; здесь 0.898 | 0 |

Ни один из пяти токенов не совпадает с эталоном ни по stiffness, ни по ζ. Ближайший — `spatial` к expressive-slow (200/0.8), но ζ завышена на 0.076; fast-спатиала (800) и всей effects-группы нет вообще. Тесты это закрепляют как «правильное»: `test/unit/nios_motion_test.dart:7-17` проверяет ровно 220/26, 200/22, 340/32.

### 1.2 `SpringCurve`-пресеты (`M3SpringCurves`)

Это **другой физический мир** — те же имена, другие параметры:

| Токен | файл:строка | k / ζ | ωn, рад/с | Время затухания 4/(ζωn) | Пик после нормировки | Использований (только код) |
|---|---|---|---|---|---|---|
| `spatial` | `:106-109` | 32 / 0.75 | 5.66 | **0.94 с** | 1.0072 (+0.7 %) | **46** |
| `emphasized` | `:112-115` | 36 / 0.70 | 6.00 | 0.95 с | 1.0259 (+2.6 %) | **1** (только алиас `expressive_tokens.dart:256`, сам `AppMotion.emphasized` не используется) |
| `snappy` | `:118-121` | 52 / 0.85 | 7.21 | 0.65 с | 1.0024 | **17** |
| `bouncy` | `:124-127` | 58 / 0.55 | 7.62 | 0.95 с | **1.1445 (+14.4 %)** | **8** |
| `gentle` | `:130-133` | 24 / 0.90 | 4.90 | 0.91 с | 1.0000 | **19** |

Сравнение `M3Spring.spatial` (k = 220) и `M3SpringCurves.spatial` (k = 32) — расхождение по stiffness **в 6.9 раза**, по ωn в 2.6 раза. Одно имя, две несовместимые пружины (`m3_spring_constants.dart:14` vs `:106`).

### 1.3 Cubic-токены (effects)

| Токен | файл:строка | Значение | Использований |
|---|---|---|---|
| `expressiveDecel` | `m3_spring_constants.dart:137` | `Cubic(0.05, 0.7, 0.1, 1.0)` | **59** |
| `expressiveStandard` | `:140` | `Cubic(0.2, 0.0, 0.0, 1.0)` | **23** |
| `expressiveAccel` | `:143` | `Cubic(0.3, 0.0, 0.8, 0.15)` | **17** |

### 1.4 Длительности (`M3Durations`, `:147-163`) — это старый MD3-набор

| Токен | мс | Использований |
|---|---|---|
| short1 | 50 | **0** |
| short2 | 100 | 2 |
| short3 | 150 | 12 |
| short4 | 200 | **28** |
| medium1 | 250 | 13 |
| medium2 | 300 | 17 |
| medium3 | 350 | 4 |
| medium4 | 400 | 1 |
| long1 | 450 | 1 |
| long2 | 500 | 2 |
| extraLong1 | 700 | **0** |
| extraLong2 | 1000 | **0** |

### 1.5 Виджеты `lib/widgets/motion/`

| Виджет | файл:строки | Параметры по умолчанию | Использований в проде |
|---|---|---|---|
| `M3StaggeredItem` | `m3_staggered_list.dart:11-128` | 280 мс, delay 30 мс/индекс, max 8, `spatial` | **0** |
| `M3SpringSwitcher` | `m3_spring_switcher.dart:28-156` | 300 мс, in `spatial` / out `expressiveDecel`, 5 режимов | **1** (`settings_energy_saving_screen.dart:122`) |
| `M3SharedAxis` | `m3_shared_axis.dart:8-103` | 320 мс, `spatial`, `slideDistance: 30.0` | **0** |
| `M3SelectionMotion` | `m3_selection_motion.dart:12-36` | 200 мс, `snappy`, scale 0.98 | **2** (`settings_chats_screen.dart:69`, `features/chats/presentation/inbox_search_screen.dart:266`) |
| `M3Reveal` | `m3_reveal.dart:20-172` | 280 мс, `spatial` + `expressiveDecel` | **2** (`settings_preferences_screen.dart:99`, `settings_plus_screen.dart:264`) |
| `M3ReactionBurst` | `m3_reaction_burst.dart:9-176` | 400 мс, 6 частиц, `spatial` | **0** |
| `M3Pressable` | `m3_pressable.dart:11-174` | 140 мс, `snappy`, 0.96 | **0** |
| `M3MorphingSurface` | `m3_morphing_surface.dart:9-98` | 260 мс, `spatial`, `Clip.none` | **0** |
| `M3MorphingIcon` | `m3_morphing_icon.dart:8-177` | 260 мс, scale 0.35→1, поворот −0.12 об | **0** |
| `M3AnimatedBadge` | `m3_animated_badge.dart:8-157` | 320 мс, `bouncy` | **0** |

Счёт проверен двумя способами (`\bName\b` и `Name(`): у «мёртвых» виджетов единственное совпадение — собственный конструктор. Виджеты покрыты тестами (`test/widgets/m3_motion_kit_test.dart`), но в приложении не вызываются.

### 1.6 Утилиты `lib/core/motion/`

| Сущность | файл:строка | Использований |
|---|---|---|
| `NiosMotion.simulate` | `nios_motion.dart:37-50` | 1 (`nios_dismissible.dart:167`) |
| `normalizeVelocity` | `:56-59` | 1 (`nios_dismissible.dart:139`) |
| `animateWithSpring` (extension) | `:68-86` | **0** |
| `NiosDismissible` | `nios_dismissible.dart:24-219` | 1 (`media_viewer_screen.dart:265`) |
| `SmoothTextStreamer` | `smooth_text_streamer.dart:7-119` | 1 (`chat_detail_screen.dart:460`) |
| `TriSync` | `tri_sync.dart:34-154` | tap **0**, snap 2, pop 3, dismiss 3, reaction 5, destructive **0** |
| `PulsePredictiveBackPageTransitionsBuilder` | `pulse_predictive_back_transition.dart:35-86` | 1 (`app_theme.dart:485`, только при `predictiveBackEnabled`) |

---

## 2. Проблемы

### CRITICAL

**C1. `SpringCurve` — это не пружина, а запечённая кривая с фиксированной длительностью.**
`m3_spring_constants.dart:50-100`. `transformInternal` считает аналитический отклик осциллятора и **делит на значение в t=1** (`:96-98`). Следствия:
- длительность задаётся отдельно (`M3Durations`) и никак не связана с физикой: `spatial` физически затухает 0.94 с, но применяется на 200–320 мс (`m3_reveal.dart:26`, `m3_spring_switcher.dart:33`, `m3_shared_axis.dart:14`). То есть вы видите первые ~30 % реального отклика, растянутые на весь отрезок;
- нет `AnimationController.velocity`: при перехвате анимации значение просто продолжается с новым таргетом и полной длительностью. Явный пример — `m3_pressable.dart:113-127`: `forward()` и `reverse()` на одном контроллере с одинаковой `duration: 140ms` (`:70`), отпускание пальца всегда занимает столько же, сколько нажатие, скорость не переносится. Так же ведут себя все `AnimatedContainer` (29 в `lib/`) и `AnimatedScale` (10) — они перезапускают кривую с нулевой скоростью;
- `SpringSimulation` во всём проекте используется **ровно один раз** (`nios_dismissible.dart:167`). Расширение `animateWithSpring` (`nios_motion.dart:68-86`), которое и есть «настоящая» M3E-механика, **не вызывается нигде** (0).

**C2. Документированные коэффициенты демпфирования не соответствуют коду.**
`m3_spring_constants.dart:13` заявляет «~damping ratio 0.75» при 26/(2√220) = **0.876**; `:20` заявляет «~0.70» при 22/(2√200) = **0.778**. То же продублировано в `nios_motion.dart:13,17`. Любой, кто выбирает токен по документации, получит не тот характер движения (0.876 — почти без отскока, «мягкий», а не «spatial с лёгким overshoot»).

**C3. Нет разделения spatial / effects на уровне API — overshoot на opacity ничем не запрещён.**
Все пять `SpringDescription` имеют ζ = 0.558…0.898 (`:14-46`), критически задемпфированной пружины (ζ = 1.0) в проекте **нет ни одной**. Opacity везде делается через Cubic (`expressiveDecel` — 59 использований). При этом тип `Curve` полностью открыт: `M3AnimatedBadge.curve` (`m3_animated_badge.dart:19`) — `bouncy` с пиком 1.1445, и его можно передать в `Opacity`/`FadeTransition` вообще без предупреждения. Единственная фактическая защита — комментарий `nios_motion.dart:25` («Strictly prohibited for opacity»). Это нарушение эталона: effects-группа должна быть отдельным типом/набором токенов.

**C4. `bouncy` с +14.4 % overshoot применяется к `PageController.animateToPage`.**
`settings_appearance_screen.dart:400-404`: `_controller.animateToPage(page, duration: M3Durations.long1, curve: M3SpringCurves.bouncy)`. Нормированный пик `bouncy` = 1.1445 при t≈0.49 (посчитано по `_rawResponse`/`rawEnd`). Прокрутка страницы уезжает за целевой офсет и возвращается — визуальный «перелёт» карусели палитр. Для page-snap нужен spatial (без overshoot) либо реальная simulation-пружина со скоростью.

**C5. Одни и те же имена означают разную физику в двух системах.**
`M3Spring.spatial` (k = 220, ζ = 0.876, реальная симуляция) vs `M3SpringCurves.spatial` (k = 32, ζ = 0.75, запечённая кривая). `AppMotion.spatial` (`expressive_tokens.dart:253`) ссылается на кривую, а `NiosMotion.spatial` — на описание. Разработчик не может по имени понять, что получит.

### MAJOR

**M1. `M3SharedAxis.slideDistance` документирован в логических пикселях, а используется как доля размера.**
`m3_shared_axis.dart:34-35`: «Distance in logical pixels», `:80-84`: `slideDistance / 100.0` → в `SlideTransition` это доля ширины/высоты ребёнка. При дефолте 30.0 и ширине 360 dp реальный сдвиг ≈ 108 dp, а не 30. Тот же приём в `m3_spring_switcher.dart:86` (`Offset(0, 0.12)`), но там это осознанная доля.

**M2. `M3SpringSwitcher` режим `scale` полностью схлопывает контент.**
`m3_spring_switcher.dart:118-127`: `ScaleTransition(scale: scaleAnim)`, где `scaleAnim` идёт 0→1 (входящий) и 1→0 (уходящий). Ожидаемое 0.88→1.0 есть только в `fadeScale` (`:78-81`). Включение `M3SwitcherType.scale` даёт исчезновение в точку.

**M3. `M3Pressable` даёт ложную вибрацию при скролле.**
`m3_pressable.dart:113-119`: `HapticService.tap()` вызывается в `_onTapDown`, то есть до того, как стало ясно, тап это или начало прокрутки списка. В `TouchContainer` эта проблема решена таймером 90 мс (`touch_container.dart:116-124`), но `M3Pressable` этот паттерн не унаследовал. Сейчас латентно (0 использований), но при внедрении даст спам.

**M4. `M3ReactionBurst` игнорирует `MediaQuery.disableAnimations`.**
В `m3_reaction_burst.dart` нет ни одной проверки reduced-motion (сравните с `m3_reveal.dart:88-95`, `m3_pressable.dart:133`). `fire()` (`:89-91`) всегда запускает 400 мс частиц. Нарушение доступности.

**M5. `NiosDismissible`: прыжок при повторном захвате + неверное направление dismiss.**
- `:95-102` резиновое сопротивление необратимо (offset → `-pow(fraction, 0.7) * dim * 0.25`), а `:111` восстанавливает `_dragOffset = _controller.value * height` из уже сжатого прогресса. При перехвате во время возврата контент скачком смещается.
- `:147-158`: при `NiosDismissDirection.down` и отрицательном прогрессе (`isDown == false`) достаточная скорость даёт `target = -1.0` (`:158`), то есть свайп вверх тоже закрывает вьюер, хотя направление объявлено «только вниз».
- Нет проверки `disableAnimations` — пружина всё равно анимируется.
- `_onAnimationTick` (`:90-92`) вызывает `onProgress` каждый кадр; `media_viewer_screen.dart` на этом строит scrim, то есть перерисовка внешнего виджета 60–120 раз/с.

**M6. Predictive back: побочные эффекты в `build()` и обход токенов.**
`pulse_predictive_back_transition.dart:351` (`_lastBounceAnimationValue = _bounceAnimation.value`) и `:357-360` (присваивание `_lastDrag` внутри `switch`-выражения в `build`) — мутация состояния во время сборки, прямо против правила AGENTS.md «No side-effects in build()». Плюс:
- `:251` — `Curves.easeOut` вместо `M3SpringCurves`;
- `:201-207` — `Curves.easeInOutCubicEmphasized` и `Interval` с фиксированными 400 мс, без передачи скорости на commit;
- `:298-306` + `:335-336` — `_updateCurvedAnimations()` диспозит `CurvedAnimation`, которые уже назначены родителями `ProxyAnimation`; повторный вызов из `didChangeDependencies` может оставить `_animation.parent` ссылающимся на уничтоженный объект;
- нет обработки reduced-motion.

**M7. 7 из 10 motion-виджетов не используются в проде.** `M3StaggeredItem`, `M3SharedAxis`, `M3ReactionBurst`, `M3Pressable`, `M3MorphingSurface`, `M3MorphingIcon`, `M3AnimatedBadge` — 0 вызовов (см. §1.5). Это не «фундамент», а склад: `M3Pressable` (правильный press-примитив) не используется, а вместо него в проде живут `TouchContainer` (22 вызова) и `PressableSurface` (2) с `Curves.easeOutCubic` (`touch_container.dart:180,238`).

**M8. Barrel-файл `motion.dart` неполный и им никто не пользуется.**
`motion.dart:1-10` экспортирует 9 файлов, но **не экспортирует `m3_selection_motion.dart`** (единственный виджет, который реально используется и импортируется точечно — `settings_chats_screen.dart:9`). В `lib/` нет ни одного импорта `widgets/motion/motion.dart` (только тест `test/widgets/m3_motion_kit_test.dart:3`). Плюс `:1` реэкспортирует токены из `core` через слой `widgets` — нарушение слоёв.

**M9. `SmoothTextStreamer` не является spring-анимацией, хотя документация это обещает.**
`:4-6` — «pacing characters through an adaptive, spring-smoothed typewriter queue». Фактически `:67-70` — `Timer.periodic(Duration(milliseconds: 16))`, не привязанный к vsync `Ticker`, и `:95-105` — жёсткие ступеньки (1 / 2 / 2–4 / `remaining/10` символов за тик). Ни пружины, ни интерполяции. Потребитель переписывает весь `TextEditingController.text` каждые 16 мс и сбрасывает селекцию (`chat_detail_screen.dart:463-466`) — это гарантированные переустановки композера/курсора. Reduced-motion не учитывается.

**M10. `TriSync` не синхронизирован с анимацией.**
`:31` — «Keyframe-synchronized feedback across tactile, audio, and visual channels». В коде нет ни одной привязки к animation ticker/CurvedAnimation: только `DateTime.now()` и троттлинг 45 мс (`:40, :52-58`). Видео-канал отсутствует, остаются haptics + audio. `TriSync.tap` (0) и `TriSync.destructive` (0) вообще не используются, при этом «destructive» звук/хаптик обычно приходит из `HapticService` напрямую (`app_modal.dart:292-296`).

**M11. `M3Durations` — легаси-шкала MD3, а не M3E-токены.**
`:147-163` — это 50/100/150/200/250/300/350/400/450/500/700/1000. Она используется как «длительность пружины» (`m3_reveal.dart:26`, `m3_shared_axis.dart:14`), хотя в M3E длительность выводится из stiffness/damping, а explicit durations остаются только для не-spring переходов. `short1`, `extraLong1`, `extraLong2` — 0 использований.

### MINOR

**m1. `SpringCurve` для ζ > 1 считает по формуле критического демпфирования.** `:80-83` использует один и тот же `1 - e^{-ωt}(1+ωt)` и для ζ > 1 (овердемпфирование), что физически неверно. Сейчас не проявляется (все токены ζ < 1), но API открыт.

**m2. `M3StaggeredItem`.** `:84` — задержка через `Timer` (не привязана к кадрам, сработает и в фоне); `:104-109` — `disableAnimations` проверяется только в `build`, контроллер всё равно крутится; `:114-116` — при завершении дерево меняется (`Opacity`+`Transform` → голый `child`), лишний rebuild; нет `didUpdateWidget` (при смене `index` анимация не переигрывается).

**m3. `M3Reveal`.** `:145-150` — `SizeTransition` пересчитывает layout каждый кадр (для больших поддеревьев дорого, `AnimatedSize`/`SizeTransition` в списках — известный источник jank); `:139-141` — смена структуры дерева при `isDismissed`.

**m4. `M3MorphingIcon`.** `:72-78` — поворот −0.12 оборота = **−43°** (`:150` умножает на 2π), это очень много для иконочного морфа; `:93-97` — `forward(from: 0)` запускается даже при `disableAnimations` (build её уважает на `:108-118`, но тикер всё равно работает).

**m5. `M3AnimatedBadge`.** `:98` — `forward(from: 0.2)`, то есть pop всегда стартует с 20 % шкалы, а не с 0; «полу-поп» вместо честного overshoot; `:88` — на реверсе `expressiveAccel` применён к масштабу (spatial-свойство), что даёт ускоренное сжатие.

**m6. `M3MorphingSurface` вешает spatial-кривую на цвет.** `:82-96` — один `AnimatedContainer` с `curve: spatial` анимирует и `BorderRadius`, и `color`. У `spatial` пик 1.0072, то есть цвет на ~0.7 % выходит за конечную точку. Практически незаметно, но формально это то самое «overshoot на цвет», которое запрещено; и API не позволяет задать отдельную effects-кривую.

**m7. Нет единого reduced-motion хелпера.** В `lib/` три разных способа чтения: `MediaQuery.maybeOf(context)?.disableAnimations` — 9 раз, `MediaQuery.disableAnimationsOf(context)` — 165, `MediaQuery.maybeDisableAnimationsOf(context)` — 2. Внутри motion-зоны тоже вразнобой: `m3_reveal.dart:89` (`maybeOf`), `m3_selection_motion.dart:28` (`disableAnimationsOf`), `m3_route_tab_switcher.dart:64` (`maybeDisableAnimationsOf`).

**m8. Длительность короче физики пружины.** `m3_selection_motion.dart:28-31`: 200 мс + `snappy` (затухание 0.65 с). `m3_staggered_list.dart:18-19`: 280 мс + `spatial` (0.94 с). Реакция обрывается до того, как пружина «доедет» — визуально это ease-out, а не пружина, и заявленный overshoot часто не успевает появиться.

**m9. `TriSync` троттлит по типу события, а не глобально.** `:37, :52-58` — частота 45 мс на каждый `TriSyncEvent` независимо; одновременные `pop` + `dismiss` (как в `nios_dismissible.dart:129` и `:161`) пройдут оба, что для «мотора» не спасает.

---

## 3. Несогласованности и дубли

| Что | Где | Статус |
|---|---|---|
| `M3Spring` (симуляция) vs `M3SpringCurves` (кривая) | `m3_spring_constants.dart:12-47` vs `:104-144` | Одно имя — две разные физики (k=220 vs k=32). Должно быть один источник правды. |
| `NiosMotion` — тонкий алиас | `nios_motion.dart:14-31` | 5 констант = копии `M3Spring`, ноль собственной логики. Живой метод только `simulate`/`normalizeVelocity`, и он вызывается 1 раз. |
| `AppMotion` — второй фасад токенов | `expressive_tokens.dart:247-275` | `spatial`/`emphasized`/`snappy`/`bouncy` — **0** использований, `spring` — 2, `scalePressed`/`pressTimeout` — 2, `durationPress`/`durationRelease` — 4. Дублирует `M3Durations` (140/240 мс) своими числами. |
| `AppCurves` — мёртвый легаси-фасад | `app_curves.dart:1-26` | 0 использований в `lib/` вообще; 4 алиаса на `M3SpringCurves` + 4 легаси `Cubic`. |
| `CallTokens` — третий набор кривых | `call_design_tokens.dart:40-55` | `controlsFadeCurve = Curves.easeInOutCubic` (не токен), остальные — алиасы. |
| Три системы press-фидбека | `TouchContainer` (`touch_container.dart`, 22), `PressableSurface` (`pressable_surface.dart`, 2), `M3Pressable` (`m3_pressable.dart`, 0) | Все три делают одно и то же разными кривыми: `Curves.easeOutCubic` / `expressiveStandard` / `snappy`. |
| Три «переключателя» контента | `M3RouteTabSwitcher` (`m3_route_tab_switcher.dart`, 5 применений), `M3SpringSwitcher` (1), `M3SharedAxis` (0) | Своя машина состояний с ручным `transform()` кривой (`:58, :69, :124`) конкурирует с двумя готовыми. |
| `_AnimatedMessage` — копия `M3Reveal` внутри экрана | `chat_detail_screen.dart:3158-3216` | fade+scale+slide на одном `CurvedAnimation(gentle)`, 200 мс. Ещё одна реализация того же примитива. |
| `flutter_animate` живёт параллельно | `auth_scaffold.dart:2`, `login_screen.dart:5`, `splash_screen.dart:2`, `onboarding_screen.dart:4`, `empty_feed_widget.dart:2`, `m3_responsive_auth_layout.dart:3`, `vector_illustrations.dart:2`, `profile_shared_media_tab_view.dart:4` | Свои длительности (200/250/300/400 мс) и `Curves`/`autoPlay`, M3-токены не используются. |
| Легаси `Curves` вплетены в новые экраны | `app_router.dart:81,86,117,124,450,451`, `pulse_predictive_back_transition.dart:251,201`, `touch_container.dart:180,238` | `easeOutCubic` 10, `easeOut` 17, `easeInCubic` 4, `easeInOutCubicEmphasized` 1, `fastOutSlowIn` 1, `linear` 5. |
| Тесты фиксируют неверные числа | `test/unit/nios_motion_test.dart:7-17`, `test/unit/m3_spring_curves_test.dart` | Любая миграция на M3E-числа сломает «зелёные» тесты — их придётся переписать вместе с токенами. |

---

## 4. Предложение целевой структуры

### 4.1 Токены: одна ось «роль × скорость × схема»

```
lib/core/motion/tokens/m3_motion_springs.dart
  enum MotionRole   { spatial, effects }
  enum MotionSpeed  { fast, defaultSpeed, slow }
  enum MotionScheme { expressive, standard }

  // damping = 2 * ζ * sqrt(k * m), m = 1
  MotionSpec.resolve(role, speed, scheme) -> SpringDescription
```

| | expressive spatial | expressive effects | standard spatial |
|---|---|---|---|
| fast | 800 / **33.94** (ζ 0.6) | 3800 / **123.29** (ζ 1.0) | 1400 / **67.35** (ζ 0.9) |
| default | 380 / **31.19** (ζ 0.8) | 1600 / **80.00** (ζ 1.0) | 700 / **47.62** (ζ 0.9) |
| slow | 200 / **22.63** (ζ 0.8) | 800 / **56.57** (ζ 1.0) | 300 / **31.18** (ζ 0.9) |

Тип `SpringDescription` не должен быть доступен снаружи напрямую — только через `resolve(role, ...)`, чтобы effects-роль физически не могла получить ζ < 1. Это закрывает C3 на уровне компилятора.

### 4.2 Примитив движения вместо `Curve`

```
lib/core/motion/engine/
  spring_motor.dart      // обёртка над AnimationController.unbounded + velocity handoff
  motion_scope.dart      // MotionPolicy.of(context): reducedMotion, scheme, performance tier
  motion_curve_adapter.dart // CompatCurve: безопасный (без overshoot) Curve для AnimatedContainer/AnimatedSwitcher
```

- `SpringMotor` хранит `_target` и `_animation`; при смене цели делает `animateWith(SpringSimulation(spec, value, target, controller.velocity))` — сохраняет скорость перехвата (сейчас это умеет только `NiosDismissible`, `nios_dismissible.dart:165-173`).
- `MotionScope` заменяет три разных чтения `disableAnimations` (m7) и подключает уже существующий `adaptivePerformanceProvider` (его использует `noto_message_emoji.dart:180-187`, а motion-слой — нет) для деградации до `Duration.zero` на tierC.
- `CompatCurve` — явный мост для 29 `AnimatedContainer` и 10 `AnimatedScale`: кривая строится из spatial-спеки с **отсечённым** overshoot (или из effects-спеки для цвета), чтобы не переписывать пол-экрана одним махом.

### 4.3 Набор примитивов (переименовать/добить существующие)

1. `MotionPressable` — замена `M3Pressable`/`TouchContainer`/`PressableSurface`: длительность из `fast spatial`, хайлайт 8 %, `HapticService` после 90 мс таймера, `TickerMode`-осведомлённость.
2. `MotionContainerTransform` — M3E container transform (сейчас нет вообще), на `Hero` + `ClipRRect`-морфе.
3. `MotionSharedAxis` — починить `slideDistance` (M1) и перевести на `SpringMotor`.
4. `MotionSwitcher` — один `AnimatedSwitcher`-совместимый враппер; параметр `MotionRole` вместо отдельного `scale`.
5. `MotionReveal` — `expandY` через `SizeTransition` только для маленьких подписей, для контента — `ClipRect` + translate.
6. `MotionShapeMorph` — на `flutter_m3shapes` (уже в зависимостях, в motion-слое не используется).
7. `MotionBadge` / `MotionIconMorph` — оставить, но с overshoot только из spatial-роли и с корректным стартом из 0/1.
8. `MotionStagger` — delay через `Ticker`/`Future.delayed` внутри `MotionScope`, без `Timer`.
9. `MotionFeedback` (бывший `TriSync`) — убрать из motion-слоя в `core/feedback`, честно назвать «haptics+audio», без слова «keyframe-synchronized».

### 4.4 Что удалить

`AppCurves` (0 использований), `AppMotion` (оставить только `scalePressed`/`pressTimeout`), `NiosMotion`-алиасы (оставить только `simulate`/`normalizeVelocity`), `M3Durations.short1/extraLong1/extraLong2`, дублирующие кривые в `CallTokens`, `M3SpringCurves` переименовать в `M3Easing` (только 3 Cubic-токена) — чтобы имя «spring» больше не врало.

---

## 5. Что сделано хорошо и трогать не нужно

1. **Нормировка `SpringCurve` гарантирует f(0)=0 и f(1)=1** — `m3_spring_constants.dart:86-99` (`raw / rawEnd` + клампы `:88-89`). Требование AGENTS.md выполнено математически, тесты это проверяют (`test/unit/moments_test.dart:29-39`).
2. **Ни один `AnimationController` в `lib/widgets/motion/` не создаётся в `build()`** — все в `initState`: `m3_staggered_list.dart:61`, `m3_pressable.dart:70`, `m3_reveal.dart:63`, `m3_reaction_burst.dart:52`, `m3_morphing_icon.dart:55`, `m3_animated_badge.dart:73`, `nios_dismissible.dart:77`. Правило AGENTS.md №6 соблюдено.
3. **`NiosDismissible` — единственная честная M3E-физика в проекте**: нормализация скорости по размеру (`nios_motion.dart:56-59`, использование `nios_dismissible.dart:139-140`) и прямой перенос `primaryVelocity` в `SpringSimulation` (`:165-173`), плюс `AnimationController.unbounded`, чтобы overshoot не отсекался (`:77-80`). Этот код — образец для `SpringMotor`.
4. **Ручное разделение spatial/effects там, где его делали осознанно**: `m3_morphing_icon.dart:80-87` (alpha — `expressiveDecel`, scale/rotation — `spatial`), `m3_reaction_burst.dart:76-79` (fade через `Interval` + `expressiveDecel`), `m3_reveal.dart:72-82`. Схему «spatial на трансформ, Cubic на альфу» надо просто поднять в API.
5. **`M3SelectionMotion`** — `m3_selection_motion.dart:26-34`: `transformHitTests: false` (ряд не рефлоуится при движении выделения), и осознанный отказ от сжатия невыделенных чипов (док `:4-11`). Логика верная, её стоит сохранить при переносе на `SpringMotor`.
6. **`M3MorphingSurface` по умолчанию `Clip.none`** — `m3_morphing_surface.dart:22,55-56,89`, то есть без лишних saveLayer; и вообще в motion-слое нет ни `BackdropFilter`, ни `MaskFilter.blur` (проверено по всем 17 файлам зоны).
7. **`M3Pressable` использует только `Transform.translate`/`Transform.scale`** и не тянет клиппинг/ripple-saveLayer (`m3_pressable.dart:152-171`) — хорошая база для `MotionPressable`.
8. **`M3Reveal` уважает `TickerMode`**, а не только `disableAnimations` — `m3_reveal.dart:88-95`. Это единственный виджет зоны, который гасит анимацию в offstage-ветках; остальным стоит перенять.

---

### Что не проверялось (честно)
- Поведение фреймворка `FadeForwardsPageTransitionsBuilder` при `MediaQuery.disableAnimations` — я лишь зафиксировал, что в `pulse_predictive_back_transition.dart` собственной проверки нет; утверждать, что фреймворк её не делает, не берусь.
- Как именно `Color.lerp` обрабатывает t > 1 в `M3MorphingSurface` (пик spatial всего +0.7 %, поэтому практического значения это не имеет — я не измерял цветовые артефакты).
- Перф-профиль реальных кадров (jank/время кадра) не снимался: выводы о стоимости `SizeTransition` и `onProgress`-каждый-кадр — из устройства кода, не из замеров.
- `packages/nios_sdk` и `packages/nios_mls` не читались: подсчёт использований ограничен `pulse_flutter/lib/`.

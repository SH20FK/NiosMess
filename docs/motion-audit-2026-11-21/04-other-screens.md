# Аудит motion: остальные экраны (2026-11-21)

Корень проекта: `F:/Niosmess V2/pulse_flutter`. Все пути ниже — от него; в таблицах и проблемах указаны `файл:строка`. Прочитаны целиком/частями все перечисленные файлы; для «остальных» settings-экранов и фич проверено grep-ом, что анимаций там нет (см. раздел «Что не проверял»).

---

## 0. Ключевой системный вывод до таблиц

Слой токенов **не является** M3E motion-physics системой, которую вы описали:

- `lib/core/motion/m3_spring_constants.dart:12-47` — `SpringDescription` со stiffness 150–340 и damping 18–32. Это не спека M3E (spatial fast 800/0.6, default 380/0.8, slow 200/0.8; effects 3800/1600/800). Фактические damping ratio: `spatial` ≈ 0.876 (а не 0.75, как в комментарии `:13`), `emphasized` ≈ 0.778 (а не 0.70, `:20`), `snappy` ≈ 0.868 (а не 0.85, `:27`).
- `m3_spring_constants.dart:104-133` — `M3SpringCurves` это `SpringCurve` (damped oscillator, зажатый в фиксированную длительность 140–500 мс), stiffness 24–58. То есть это **time-warped cubic-подобная кривая**, а не физика с сохранением скорости. Все `AnimatedContainer`/`AnimatedSwitcher`/`AnimatedScale` с этой кривой физически не прерываемы «с сохранением скорости».
- `m3_spring_constants.dart:147-163` — `M3Durations` это baseline MD3 durations, не M3E physics.
- `M3Spring` используется только в `settings_appearance_screen.dart:501` (`_PalettePagePhysics.spring`). Всё остальное живёт на `M3SpringCurves`.

Отсюда следует главный вывод аудита: **приложение повсеместно имитирует M3E кривыми с фиксированной длительностью**. Реальные пружины (`AnimationController.animateWith(SpringSimulation(...))`) не используются нигде в моей зоне.

---

## 1. Инвентарь анимаций зоны

### 1.1 Звонки

| Файл:строка | Что анимируется | Механизм | Длительность | Кривая/пружина |
|---|---|---|---|---|
| `lib/screens/calls/incoming_call_overlay.dart:56-70` | Вход/выход баннера входящего (slide сверху + fade) | controller | 320 мс (`CallTokens.incomingOverlayAnimationDuration`) | slide `M3SpringCurves.spatial`, fade `expressiveStandard` |
| `...incoming_call_overlay.dart:72-86` | Пульс-кольцо иконки (scale 1→1.45, opacity .45→0) | controller `.repeat()` | 1800 мс | scale `M3SpringCurves.gentle`, opacity `expressiveDecel` |
| `...incoming_call_overlay.dart:113-122` | Старт/стоп пульса по `TickerMode`/reduced-motion | controller | — | — |
| `...incoming_call_overlay.dart:428-450` | Рендер кольца `Transform.scale` + `Opacity` | AnimatedBuilder | 1800 мс loop | — |
| `...incoming_call_overlay.dart:270-291` | Accept/Decline press | implicit (TouchContainer) | 140/240 мс | press `easeOutCubic`, release `AppMotion.spring` |
| `lib/screens/calls/active_voice_call_screen.dart:39-57` | «Дыхание» аватара (ripple) | controller `.repeat()` | 2000 мс | progress линейный, painter сам считает α |
| `lib/widgets/calls/call_audio_ripple.dart:31-45,60-111` | 4 кольца CustomPaint + RepaintBoundary | AnimatedBuilder+CustomPainter | 2000 мс | нет (линейный прогресс) |
| `lib/screens/calls/active_video_call_screen.dart:54-62` | Автоскрытие контролов (только opacity) | controller | 220 мс | `CallTokens.controlsFadeCurve = Curves.easeInOutCubic` |
| `...active_video_call_screen.dart:111-143` | Таймер автоскрытия 4 с и toggle | Timer+controller | 4 с / 220 мс | easeInOutCubic |
| `...active_video_call_screen.dart:256-264,465-473` | Появление top bar и bottom dock | AnimatedBuilder+Opacity | 220 мс | easeInOutCubic |
| `...active_video_call_screen.dart:379-390` | Перетаскивание PiP | `setState` на `onPanUpdate` | — | нет физики/снапа |
| `lib/widgets/calls/call_overlay.dart:32-46` | Снап к краю | controller + `setState` listener | 320 мс | `M3SpringCurves.spatial` |
| `...call_overlay.dart:55-72` | Расчёт цели и `Tween(begin, end)` | controller | 320 мс | spatial |
| `lib/screens/calls/active_call_screen.dart:269,303-324` | Connecting: индикатор + press end | AppLoadingIndicator + TouchContainer | — / 140-240 мс | — |
| `lib/widgets/calls/call_control_dock.dart:149-168,206-222` | Press кнопок дока | TouchContainer | 140/240 мс | release spatial |
| `lib/widgets/calls/call_devices_dialog.dart:128-140` | Уровень микрофона (16 сегментов) | Timer 120 мс + setState | 120 мс шаг | нет анимации (мгновенные сегменты) |
| `lib/widgets/calls/call_quality_badge.dart` | — | — | — | анимаций нет |

### 1.2 NiosGram

| Файл:строка | Что анимируется | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `lib/widgets/post_card.dart:80-105` | Двойной тап: heart scale 0→1.15→1→0, opacity | controller + TweenSequence | 600 мс | `Curves.easeOut` / `Curves.easeIn` |
| `...post_card.dart:123-133` | Триггер heart | controller | 600 мс | — |
| `...post_card.dart:673-697` | Рендер heart + `Shadow(blurRadius: 24)` | AnimatedBuilder | 600 мс | — |
| `...post_card.dart:386-405` | «Читать дальше» (высота текста) | implicit `AnimatedSize` | 260 мс | `expressiveDecel` |
| `...post_card.dart:705-719` | Вход в full-screen изображение | route `PageRouteBuilder` | дефолт ~300 мс | `Curves.easeOut`, + Hero (дефолтная кривая) |
| `...post_card.dart:812-816` | Появление изображения (opacity) | implicit `AnimatedOpacity` | `M3Durations.medium1` 250 мс | **не задана** (linear) |
| `...post_card.dart:848-853` | Скрытие top bar во full-screen | `AnimatedOpacity` | 150 мс | `expressiveDecel` |
| `...post_card.dart:942-963,946-948` | Карусель PageView | PageView + `setState` | физика платформы | — |
| `...post_card.dart:1049-1065` | Точки карусели (width 16/6) | implicit `AnimatedContainer` | 200 мс | `expressiveStandard` |
| `...post_card.dart:1081-1115` | Spark-линии лайка | CustomPainter | 250 мс | `expressiveDecel.transform` |
| `...post_card.dart:1147-1173` | Pop лайка scale 1→1.12→1 | controller + TweenSequence | 250 мс | 1-я половина `easeOutCubic`, 2-я `M3SpringCurves.snappy` |
| `...post_card.dart:1219-1242` | Рендер pop + sparks | AnimatedBuilder+CustomPaint | 250 мс | — |
| `...post_card.dart:1508-1520` | Плейсхолдер медиа | **статичный** | — | — |
| `lib/screens/niosgram_screen.dart:105-125` | Кнопка «вверх» появляется/исчезает | условный FAB (нет анимации) | — | скролл 300 мс `expressiveDecel` |
| `...niosgram_screen.dart:302-339` | Badge уведомлений | `AnimatedScale(scale: 1.0)` | 200 мс | `M3SpringCurves.bouncy` (мёртвая) |
| `lib/screens/niosgram_screen.dart:130-137` | Скелетон → контент | прямой `when()` | — | нет перехода |
| `lib/widgets/pulse_skeleton.dart:53-96` | Пульс ChatListSkeleton | controller ping-pong | 1200 мс | `Curves.easeInOut` |
| `lib/widgets/pulse_skeleton.dart:320-488,508-535` | PostCard/PostFeedSkeleton | **статичные** | — | — |
| `lib/widgets/feed_poll_card.dart:184-190` | Полоса результата опроса | `TweenAnimationBuilder` | 400 мс | `M3SpringCurves.spatial` |
| `lib/widgets/media/m3_video_controls.dart:53-63` | Play/pause icon | `AnimatedSwitcher` | 100 мс | decel |
| `lib/widgets/media/m3_video_controls.dart:236-241` | Панель видео | `AnimatedOpacity` | 150 мс | decel |
| `lib/screens/niosgram_video_screen.dart:127-128` | Загрузка видео | AppLoadingIndicator | — | — |

### 1.3 Камера / кружок

| Файл:строка | Что анимируется | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `lib/screens/circle_video_recorder_screen.dart:54-63` | Пульс записи scale 1→1.06 | controller `.repeat(reverse:true)` | 800 мс | `expressiveStandard` |
| `...circle_video_recorder_screen.dart:65-68` | Прогресс 60 с | controller | 60 с | linear (нужно) |
| `...circle_video_recorder_screen.dart:70-77` | Scrim fade-in | controller + FadeTransition | 350 мс | `expressiveDecel` |
| `...circle_video_recorder_screen.dart:79-86` | Переворот камеры | controller + Matrix4 | 300 мс | `expressiveStandard` |
| `...circle_video_recorder_screen.dart:100-107` | Старт/стоп пульса | controller | 800 мс | — |
| `...circle_video_recorder_screen.dart:361-377` | Кольцо прогресса | CustomPainter | 60 с | linear |
| `...circle_video_recorder_screen.dart:399-417` | 3D flip превью | AnimatedBuilder | 300 мс | — |
| `...circle_video_recorder_screen.dart:468-476,603-611` | Пульс бейджа таймера и кнопки | AnimatedBuilder | 800 мс | — |
| `...circle_video_recorder_screen.dart:612-650` | **Shape morph** кнопки записи (radius 40→26, inner 18→7) | implicit `AnimatedContainer` ×2 | 150 мс | `expressiveDecel` |
| `lib/widgets/quick_camera_capture_screen.dart:41-48` | Flip 3D | controller | 320 мс | `expressiveStandard` |
| `...quick_camera_capture_screen.dart:159-181` | Рендер flip | AnimatedBuilder | 320 мс | — |
| `...quick_camera_capture_screen.dart:225-248` | Затвор | **нет анимации/нажатия** | — | — |

### 1.4 Смена темы / цвет

| Файл:строка | Что анимируется | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `lib/widgets/circular_theme_reveal.dart:43-46` | Круглый reveal | controller + snapshot `toImageSync` | 450 мс | `expressiveDecel` |
| `...circular_theme_reveal.dart:101` | Снимок старой темы | `toImageSync(pixelRatio: 1.0)` | — | — |
| `...circular_theme_reveal.dart:141-151,163-200` | Painter: clipPath + drawImageRect | CustomPaint | 450 мс | — |
| `lib/main.dart:372-380` | Глобальный переход темы | MaterialApp AnimatedTheme | 500 мс | `expressiveStandard` |
| `lib/screens/settings_appearance_screen.dart:104-109` | Локальный AnimatedTheme | implicit | 500 мс | `expressiveStandard` |
| `...settings_appearance_screen.dart:395-405` | Пагинация палитр | `PageController.animateToPage` | 450 мс (`long1`) | `M3SpringCurves.bouncy` |
| `...settings_appearance_screen.dart:497-506` | Физика страниц палитры | `PageScrollPhysics` | — | `M3Spring.bouncy` |
| `...settings_appearance_screen.dart:471-484` | Точка активной страницы | implicit `AnimatedContainer` | 300 мс | `M3SpringCurves.snappy` |
| `...settings_appearance_screen.dart:591-600` | Выбор палитры (рамка/фон) | **мгновенно** | — | — |
| `lib/widgets/color_ripple_overlay.dart:24-48` | Рябь по тапу (мёртвый код) | controller per tap | 600 мс | `Curves.fastLinearToSlowEaseIn` |
| `...color_ripple_overlay.dart:63-84` | CustomPaint 3 круга | AnimatedBuilder | 600 мс | — |
| `lib/widgets/settings/custom_color_picker_sheet.dart:112-180` | Превью цвета | implicit `AnimatedContainer` | 350 мс | `expressiveStandard` |

### 1.5 Скелетоны и загрузка

| Файл:строка | Что | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `lib/widgets/pulse_skeleton.dart:58-66` | ChatListSkeleton пульс | controller ping-pong | 1200 мс | `Curves.easeInOut` |
| `...pulse_skeleton.dart:161-162` | Fade рядов | FadeTransition | 1200 мс | easeInOut |
| `...pulse_skeleton.dart:252-315` | MessageListSkeleton | **статичный** | — | — |
| `...pulse_skeleton.dart:320-535` | PostCard/Feed skeleton | **статичный** | — | — |
| `lib/widgets/vector_illustrations.dart:78-89` | EmptyFeedIllustration (если `animate:true`) | flutter_animate | 320/260 мс | `easeOutCubic` / `easeOut` |
| `...vector_illustrations.dart:123-166` | MediaPlaceholderIllustration | **флаг `animate` не используется** | — | — |
| `lib/widgets/motion/m3_staggered_list.dart` | Готовый stagger-элемент | controller + Timer | 280 мс + 30 мс/индекс | spatial/decel — **0 использований** |
| `lib/widgets/pulse_loading_indicator.dart:34-48` | Детерминированный прогресс | `LinearProgressIndicator` (разрешённое исключение) | — | — |

### 1.6 Авторизация / онбординг

| Файл:строка | Что | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `lib/screens/splash_screen.dart:96-128` | Hero-лого + scale/fade, тексты | flutter_animate | 380/300/280 мс, delays 80/140 | `spatial` (лого), остальное дефолт пакета |
| `...splash_screen.dart:187,192-195` | Ошибка/индикатор | flutter_animate fade | 250/300 мс, delay 500 | дефолт |
| `lib/screens/login_screen.dart:386-397` | Hero-лого scale | flutter_animate | 380 мс | `spatial` |
| `...login_screen.dart:402-429` | Заголовок, слоган | flutter_animate fade | 300 мс + delay 80 | дефолт |
| `...login_screen.dart:452-466,470-478,482-494` | Offline/кнопки | fade | 250/300 мс + delay 120/160 | дефолт |
| `...login_screen.dart:544-553` | Шеврон explainer | `AnimatedRotation` | 280 мс | `spatial` |
| `...login_screen.dart:556-590` | Раскрытие explainer | `AnimatedCrossFade` | 280 мс | sizeCurve spatial, fade-кривые дефолтные linear |
| `...login_screen.dart:656-937` | Device-code карточка | flutter_animate scale+fade | 300/250 мс | `spatial` |
| `lib/widgets/auth/auth_scaffold.dart:198-221` | Бейдж | flutter_animate | 360/280 мс | `spatial` |
| `...auth_scaffold.dart:223-247` | Заголовок/подзаголовок | fade | 300 мс + delay 100 | дефолт |
| `...auth_scaffold.dart:253-285` | Loading overlay | fade | 200 мс | дефолт |
| `lib/screens/onboarding_screen.dart:117-137` | Перелистывание | `PageController.animateToPage` | 350 мс | `spatial` |
| `...onboarding_screen.dart:165-218` | Лого + название | flutter_animate | 400/300 мс + delay 150 | spatial/дефолт |
| `...onboarding_screen.dart:241-289` | Индикатор-точки | implicit `AnimatedContainer` | 200 мс | spatial |
| `...onboarding_screen.dart:449-455` | Lottie | `Lottie.asset(repeat:true, frameRate: FrameRate.max)` | ∞ | — |
| `lib/widgets/m3_otp_input_field.dart:52-69` | Shake ошибки | controller + TweenSequence | 400 мс | `Curves.easeInOutSine` |
| `...m3_otp_input_field.dart:309-323` | Fokus/ошибка ячейки | implicit scale/container | 200 мс | snappy / expressiveStandard |
| `lib/widgets/about/morphing_brand_mark.dart:116-140` | Морф бренд-формы | controller | 500 мс (`long2`) | `M3SpringCurves.bouncy`, **clamp 0..1** (см. проблемы) |
| `lib/core/illustration/app_illustration.dart:101-120` | Вход иллюстрации | controller | 320 мс | scale decel, fade `Curves.easeOut` |
| `lib/widgets/nios_mark_badge.dart:38-44,205-211` | Press-пульс | controller | 250 мс | `Curves.easeOutCubic` |

### 1.7 Настройки / профиль

| Файл:строка | Что | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `lib/widgets/settings/pressable_surface.dart:54-57,85-96,137-150` | Press строки | implicit container + scale | 200/140/240 мс | expressiveStandard/snappy/spatial |
| `lib/features/settings/presentation/settings_row.dart:90-97` | Scroll-to-anchor | `Scrollable.ensureVisible` | 320 мс | `expressiveStandard` |
| `...settings_row.dart:119-130` | Подсветка найденного | implicit `AnimatedContainer` | 260 мс | `expressiveStandard` |
| `...settings_row.dart:66-72` | Раскрывашка | `ExpansionTile` по умолчанию | ~200 мс (Flutter) | дефолтные `easeIn/easeOut` |
| `lib/widgets/settings/settings_profile_header.dart:136-148` | Сворачивание шапки | scroll-driven `lerpDouble` + `Opacity` | — | `expressiveStandard` |
| `...settings_profile_header.dart:153` | `Material(clipBehavior: Clip.hardEdge)` | clip | — | — |
| `lib/widgets/settings/settings_list_item.dart:188-206` | Pending-спиннер, Switch | AppLoading + M3 Switch | — | M3 default |
| `lib/widgets/settings/system_resource_meter.dart:61-91` | Заполнение шкалы | `TweenAnimationBuilder` | 400 мс | `expressiveDecel` |
| `lib/widgets/settings/ordinary_e2ee_settings.dart:677-700` | Раскрытие + reveal | `AnimationStyle` + `AnimatedSize` | 300 мс | `expressiveStandard` |
| `lib/screens/settings_about_screen.dart:166-182` | Смена таба | `AnimatedSize`+`AnimatedSwitcher` | 300 мс | decel/accel |
| `lib/screens/settings_energy_saving_screen.dart:122-141` | Смена описания режима | `M3SpringSwitcher(fade)` | 200 мс | decel |
| `lib/screens/settings_preferences_screen.dart:99-101` | Появление громкости | `M3Reveal` | 300 мс | spatial+fade |
| `lib/screens/settings_plus_screen.dart:264-283` | Появление кнопки trial | `M3Reveal` | 300 мс | spatial+fade |
| `lib/screens/settings_chats_screen.dart:69-86` | Выбор эмодзи | `M3SelectionMotion` | 200 мс | snappy |
| `lib/screens/profile_screen.dart:569-599` | Смена detail-панели | `AnimatedSwitcher` fade+slide | 250/150 мс | decel/accel |
| `lib/screens/profile_screen.dart:537` | Pull-to-refresh | Material `RefreshIndicator` | — | — |
| `lib/widgets/profile/profile_shared_media_tab_view.dart:398-418` | Смена таба | `AnimatedSwitcher` | 200 мс | decel/accel |
| `...profile_shared_media_tab_view.dart:544-559` | Таб-пилюля | implicit `AnimatedContainer` | 250 мс | `M3SpringCurves.spatial` |
| `lib/widgets/profile/profile_sheet_layout.dart:168-173` | Раскрытие секции | `ExpansionTile` + AnimationStyle | 300 мс | `expressiveDecel` |
| `lib/widgets/profile/ai_usage_card.dart:103-108` | Полоса использования | `TweenAnimationBuilder` | 300 мс | `expressiveStandard` |
| `lib/widgets/settings/settings_shell.dart:151-163` | Список + RefreshIndicator | — | — | — |
| `lib/widgets/settings/settings_period...` нет | — | — | — | — |
| `lib/screens/settings_appearance_screen.dart` | см. 1.4 | | | |

### 1.8 Общие навигационные виджеты (тоже в зоне)

| Файл:строка | Что | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `lib/widgets/nav/m3_route_tab_switcher.dart:56-72,144-181,193-226` | Shared-axis табов, сохраняет прогресс | controller | 320 мс | `gentle`/decel/accel |
| `lib/widgets/app_bottom_nav.dart:18-166` | TravelingNavIndicator (pill) | controller | 220 мс | spatial — **0 использований** |
| `lib/widgets/app_bottom_nav.dart:207-209,269` | Переключение NavigationBar | M3 NavigationBar | 280 мс (200 на tier C) | M3 default |
| `lib/widgets/app_bottom_nav.dart:349-460` | TabMorphIcon (pulse scale/translate) | controller `animateTo` | 280 мс | `Curves.linear` |
| `lib/widgets/offline_banner.dart:15-20` | Появление баннера | `AnimatedSize`+`AnimatedOpacity` | 250/200 мс | easeOutCubic / нет |
| `lib/widgets/empty_feed_widget.dart:59-71` | Вход иллюстрации | flutter_animate | 250/200 мс | decel/дефолт |
| `lib/screens/legal_viewer_screen.dart:213-224` | Скролл к секции | `ensureVisible` | 380 мс | `Curves.easeInOutCubic` |
| `lib/screens/main_shell_screen.dart:503-540` | Смена чата на desktop | `AnimatedSwitcher` | 250 мс | decel/accel |
| `lib/screens/main_shell_screen.dart:819-825` | Scrim композера | `AnimatedOpacity` | 200 мс | decel |
| `lib/core/modal/app_modal.dart:41-48,129-131,197-208` | Все шиты/диалоги | `AnimationStyle`/route | 300/250/280 мс | decel/accel, scale `gentle` |

---

## 2. Проблемы (с серьёзностью и конкретным исправлением)

### CRITICAL

**P1. Токены пружин не соответствуют M3E motion-physics**
`F:/Niosmess V2/pulse_flutter/lib/core/motion/m3_spring_constants.dart:12-47,104-133`.
`SpringDescription` имеют stiffness 150–340 вместо spatial fast 800/default 380/slow 200 и effects 3800/1600/800; `M3SpringCurves` — не физика, а кривая, растянутая на 150–500 мс. Из-за этого ни один переход в приложении не «сохраняет скорость» при перехвате: все `AnimatedContainer`/`AnimatedSwitcher` ретаргетят значение и заново проигрывают фиксированную длительность.
Исправление: ввести `M3MotionSpatial.fast/default/slow` и `M3MotionEffects.fast/default/slow` как `SpringDescription` (800/0.6, 380/0.8, 200/0.8; 3800/1.0, 1600/1.0, 800/1.0) и драйвить их через `AnimationController.animateWith(SpringSimulation(spring, from, to, velocity))` в общем примитиве; `M3SpringCurves` оставить только как fallback для implicit-виджетов, где физика невозможна. Поправить ложные значения в doc-комментариях (`:13,20,27`).

**P2. Оверлей звонка: снап без физики + `setState` на каждый кадр**
`F:/Niosmess V2/pulse_flutter/lib/widgets/calls/call_overlay.dart:38-46,55-72,139-152`.
- `onPanEnd` строит `Tween(begin: startX, end: targetX)` и `forward(from: 0)` — скорость жеста полностью теряется; `onPanStart` делает `_snapController.stop()` (скорость тоже теряется).
- `_snapController.addListener` вызывает `setState` на оверлее, внутри которого `StreamBuilder` + `RTCVideoView` (`:99-180,366-376`). Для видеозвонка это перестройка всего PiP-дерева каждый кадр снапа и каждый `onPanUpdate` (`:140-151`) — прямой путь к джанку.
Исправление: перетаскивать через `Listener`/`GestureDetector` + `ValueNotifier<double>`, а `Positioned` оборачивать в `ValueListenableBuilder` (только позиция, без `RTCVideoView`); снап делать `animateWith(SpringSimulation(M3MotionSpatial.fast, current, target, velocityFromPan))`, передавая `details.velocity.pixelsPerSecond.dx`. При перехвате — `stop()` + продолжение с текущей velocity.

**P3. Смена темы: три перекрывающихся механизма + блёрный снимок**
`F:/Niosmess V2/pulse_flutter/lib/widgets/circular_theme_reveal.dart:43-46,101,141-151`; `lib/main.dart:372-380`; `lib/screens/settings_appearance_screen.dart:104-109`.
- Круглый reveal 450 мс (`expressiveDecel`) + глобальный `AnimatedTheme` 500 мс + локальный `AnimatedTheme` 500 мс. Снимок снимается при `pixelRatio: 1.0` (`:101`) и растягивается до полного экрана с `FilterQuality.medium` (`:197`) — на 2x/3x экранах старая тема видна мылом, а после снятия оверлея на 450-й мс цвета ещё 50 мс доезжают под ним.
- Кривая — cubic, не spatial-пружина; повторный тап во время анимации игнорируется (`:73`).
Исправление: оставить **один** путь — `CircularThemeSwitcher` (или `AnimatedTheme`) — и убрать второй; снимок брать `pixelRatio: math.min(devicePixelRatio, 2.0)`; радиус вести пружиной `M3MotionSpatial.slow` (полноэкранный эффект); тайминги привязать к `M3Durations.long1`/M3-токенам; локальный `AnimatedTheme` в appearance-экране удалить.

### MAJOR

**P4. Пульс-кольцо входящего звонка обрезается**
`F:/Niosmess V2/pulse_flutter/lib/screens/calls/incoming_call_overlay.dart:428-450`.
`SizedBox(48×48)` содержит `Stack` без `clipBehavior: Clip.none`; ring `44 px` масштабируется до `1.45` → ~64 px и режется квадратом 48 px. Также пульс — один ring, scale по `gentle` (time-curve) с `.repeat()`; M3E ожидает экспрессивную форму/морф, а не один «дыхательный» кружок.
Исправление: `clipBehavior: Clip.none`; заменить на два staggered-кольца через `AnimationController` c `M3MotionSpatial.default` и `CurvedAnimation` только для opacity (`expressiveDecel`); либо использовать `flutter_m3shapes`/`M3AnimatedBadge` для shape-pop.

**P5. Видеозвонок: контролы только по opacity, кривая — MD2**
`F:/Niosmess V2/pulse_flutter/lib/screens/calls/active_video_call_screen.dart:54-62,256-264,465-473`; `lib/core/call_design_tokens.dart:53`.
`CallTokens.controlsFadeCurve = Curves.easeInOutCubic` — единственная «кривая-токен» в файле токенов и она не M3. Верхний бар и нижний док просто растворяются без движения; M3E требует spatial-хореографию (верх вверх, док вниз) + effects-fast на opacity, прерываемую.
Исправление: `AnimationController` + два `Tween<Offset>` (top: 0→-16, dock: 0→+24) на `M3SpringCurves.snappy`, opacity — `expressiveDecel`; скрывать `IgnorePointer` уже есть (`:260-263,469-472`) — сохранить. `controlsFadeCurve` удалить/заменить на `M3SpringCurves.snappy`.

**P6. PiP видео: нет снапа и физики**
`F:/Niosmess V2/pulse_flutter/lib/screens/calls/active_video_call_screen.dart:375-390`.
`onPanUpdate` c `setState` и `clamp`, без `onPanEnd`, без прилипания к краю, без инерции; при повороте экрана `_pipInitialized` не пересчитывается (`:190-194`) — PiP может уехать за экран.
Исправление: как P2 — `ValueNotifier` + `SpringSimulation` снап по X на `M3MotionSpatial.fast` с velocity; пересчёт при изменении `MediaQuery.size` в `didChangeDependencies`; `RepaintBoundary` вокруг PiP.

**P7. Полноэкранное изображение: fade вместо container transform; Hero только для одиночного фото**
`F:/Niosmess V2/pulse_flutter/lib/widgets/post_card.dart:705-719,806-807,942-963,967-974`.
- `PageRouteBuilder` c `FadeTransition`/`Curves.easeOut` и дефолтным Hero-курвом; это не M3E container-transform (форма/размер не морфят), а простой кроссфейд.
- В карусели (`PageView`, `:942-963`) изображения **не** обёрнуты в Hero, хотя destination всегда содержит `Hero(tag: post_media_{id})` (`:806`) → для карусели flight не срабатывает, экран появляется только фейдом.
- `AnimatedOpacity` изображения (`:812-816`) без `curve` — linear.
Исправление: использовать `Hero`/`PageRouteBuilder` c `FadeTransition`+`ScaleTransition` (begin 0.92, `M3SpringCurves.spatial`) либо `OpenContainer`-подобный transform; обернуть каждый item карусели в `Hero(tag: 'post_media_${post.id}_$index')` и destination принимать index; `AnimatedOpacity` — `curve: M3SpringCurves.expressiveDecel`.

**P8. Лента: скелетоны статичны, переход к контенту мгновенный**
`F:/Niosmess V2/pulse_flutter/lib/widgets/pulse_skeleton.dart:320-488,508-535`; `lib/widgets/post_card.dart:1508-1520`; `lib/widgets/vector_illustrations.dart:123-166`; `lib/screens/niosgram_screen.dart:130-137`.
`PostFeedSkeleton` заявлен как «coordinated shimmer sweep» (`:508`), но не содержит ни контроллера, ни shimmer; `_MediaPlaceholderShimmer` зовёт `MediaPlaceholderIllustration(animate: true)`, у которого параметр `animate` вообще не используется; `MessageListSkeleton` тоже статичен. `feedAsync.when` меняет скелетон на список без кроссфейда — контент «прыгает».
Исправление: либо один общий shimmer-контроллер (как `ChatListSkeleton:58-90`, но с `M3Durations.extraLong2` и `expressiveStandard`), либо `M3Reveal`/`M3SpringSwitcher(fade)` между состояниями; `PostCardSkeleton` сделать наследником того же пульса; скругление скелетона привести к `AppRadii.lg` (`:339` = 24 vs карточка 16).

**P9. Звонки: появление/исчезновение оверлея без анимации**
`F:/Niosmess V2/pulse_flutter/lib/widgets/calls/call_overlay.dart:95-107`.
Когда сессия заканчивается/idle — `return const SizedBox.shrink()`; когда стартует — оверлей появляется сразу. «Сворачивание в оверлей» — это pop полноэкранного роута и мгновенное появление пилюли, без M3E container-transform/scale-in.
Исправление: обернуть в `AnimatedSwitcher`/`M3SpringSwitcher(type: fadeScale)` c `M3SpringCurves.spatial`, либо отдельный `AnimationController` entrance/exit (scale 0.9→1 + fade decel) и `SlideTransition` от края; при завершении — `reverse()` до `SizedBox.shrink()`.

**P10. Унификация press-отклика отсутствует; 4 разных примитива**
`F:/Niosmess V2/pulse_flutter/lib/widgets/common/touch_container.dart:169-241`; `lib/widgets/settings/pressable_surface.dart:85-150`; `lib/widgets/pulse_button.dart:58-65`; `lib/widgets/motion/m3_pressable.dart:11-174` (не используется).
Разные scale (0.96 / 0.975 / 0.98), разные задержки (90 мс в `TouchContainer:119`, 0 в `PressableSurface:56`), разные кривые (`easeOutCubic` на press в `TouchContainer:180,238`; snappy/spatial в `PressableSurface`), `PulseButton` всегда spatial. Пользователь чувствует «разные кнопки» в разных разделах. В M3E отклик — форма+размер, а не только scale.
Исправление: один примитив (взять `TouchContainer` как базу) с параметрами `M3MotionSpatial.fast`, pressed-scale 0.96–0.98, задержкой 80–90 мс против скролла и shape-morph радиуса на 2–4 dp (через `AnimatedContainer` + `M3SpringCurves.snappy`); удалить `PulseButton`, `PressableSurface`, `M3Pressable` или сделать их адаптерами. `Curves.easeOutCubic` заменить на `M3SpringCurves.snappy`.

**P11. Онбординг: бесконечные Lottie без reduce-motion и с `FrameRate.max`**
`F:/Niosmess V2/pulse_flutter/lib/screens/onboarding_screen.dart:449-455`.
Три Lottie крутятся бесконечно; `disableAnimations` игнорируется, `frameRate: FrameRate.max` на 120 Гц экранах просит максимальный FPS; нет остановки при уходе со слайда, кроме dispose страницы.
Исправление: `Lottie.asset(..., repeat: !MediaQuery.disableAnimationsOf(context), frameRate: FrameRate(60))`; при reduced motion показывать статичный кадр (`animate: false`); при `TickerMode.enabled == false` — `Lottie` и так остановится, но проверку `MediaQuery` добавить обязательно.

**P12. Настройки: шапка профиля клипует всё при скролле**
`F:/Niosmess V2/pulse_flutter/lib/widgets/settings/settings_profile_header.dart:150-153`.
`Material(clipBehavior: Clip.hardEdge)` на pinned-заголовке создаёт save-layer на каждом кадре скролла; плюс `Opacity`-слои пересобираются каждый пиксель. Правило проекта требует `Clip.none` для повторяющихся элементов — здесь формально исключение, но стоимость отрисовки высокая.
Исправление: `Clip.none` + явные `Positioned`/`OverflowBox` без выхода за границы; либо `ClipRect` включать только на время `shrinkOffset > 0` (в `build` по `progress`), а `Opacity` заменить на `AnimatedOpacity`/статичные цвета, где возможно; аватар уже в `RepaintBoundary` (`:218`) — сохранить.

**P13. Значок уведомлений: мёртвая анимация + BoxShadow**
`F:/Niosmess V2/pulse_flutter/lib/screens/niosgram_screen.dart:302-339`.
`AnimatedScale(scale: 1.0)` с `M3SpringCurves.bouncy` — анимация есть, изменения нет (дефект). Плюс `BoxShadow` (`:319-325`) — нарушение «глубина через тональные поверхности, без BoxShadow».
Исправление: `M3AnimatedBadge(count: count)` (готовый виджет `lib/widgets/motion/m3_animated_badge.dart:8-157`) — он даёт bouncy-pop на смене count; `BoxShadow` убрать, обводку сделать `Border.all(color: scheme.surface)`.

**P14. Лайк: кастомная хореография вместо готового M3E и тень-глоу**
`F:/Niosmess V2/pulse_flutter/lib/widgets/post_card.dart:80-105,673-697,1147-1173`.
Double-tap: `TweenSequence` 600 мс на `Curves.easeOut` + `Shadow(blurRadius: 24)` (`:686-690`) — это box-shadow-подобное размытие на каждом лайке, нагружает растеризацию, визуально «дешёвый глоу». Одиночный лайк: свой `_ctrl` с `easeOutCubic` + snappy и spark-painter, хотя в проекте есть `M3ReactionBurst` (`lib/widgets/motion/m3_reaction_burst.dart`) — не используется.
Исправление: собрать один `LikeButton` на `M3ReactionBurst`/`M3SpringCurves.bouncy` (spatial, overshoot допустим), убрать `Shadow`, использовать тональный `Icon` + `M3MorphingIcon` (filled/outline) вместо мгновенной замены `IconData`. Длительность — `M3Durations.medium2`.

**P15. Видео: кнопка затвора без отклика и без индикации съёмки**
`F:/Niosmess V2/pulse_flutter/lib/widgets/quick_camera_capture_screen.dart:225-248`.
Затвор — статичный `Container` + `GestureDetector`; `_isCapturing` выставляется (`:128`), но никак не рисуется. M3E требует press shape/scale и expressive loading.
Исправление: обернуть в `TouchContainer`/`M3Pressable`, добавить кольцо-сжатие (scale 0.9, `M3MotionSpatial.fast`) и `AppLoadingIndicator` в центре на время `_isCapturing`; на вспышку кадра — быстрый `AnimatedOpacity` белого scrim (80 мс, effects-fast).

### MINOR

**P16. OTP-shake и ColorRipple — мёртвый код; OTP-экрана нет**
`F:/Niosmess V2/pulse_flutter/lib/widgets/m3_otp_input_field.dart:52-69`; `lib/widgets/color_ripple_overlay.dart:24-48`. Grep по `lib` показывает 0 использований `M3OtpInputField`, `ColorRippleOverlay` (и `CodePreview`, `M3ResendCountdownTimer`). То есть «shake при ошибке OTP» в проде не существует; login использует device-code flow (`login_screen.dart:656-937`).
Исправление: либо удалить, либо, если планируется OTP-экран, перевести shake на `M3SpringCurves.snappy` (не `easeInOutSine`), убрать `BoxShadow` из ячеек (`:266-282`) и подключить экран.

**P17. MorphingBrandMark: bouncy-кривая зажата**
`F:/Niosmess V2/pulse_flutter/lib/widgets/about/morphing_brand_mark.dart:180-189`.
`t: _shape.value.clamp(0.0, 1.0)` уничтожает overshoot заявленной `M3SpringCurves.bouncy` (`:122`). Морф не пружинит, а просто плавно доезжает.
Исправление: не клампить `t` (painter сам интерполирует радиусы; при t>1 радиусы «перелетят»), либо использовать `SpringSimulation` и `t` без clamp.

**P18. `TouchContainer` использует MD2-кривую на press**
`F:/Niosmess V2/pulse_flutter/lib/widgets/common/touch_container.dart:179-181,237-239`.
`Curves.easeOutCubic` при нажатии, `AppMotion.spring` при отпуске — асимметрично и не по токенам.
Исправление: `_isPressed ? M3SpringCurves.snappy : M3SpringCurves.spatial` (или единая spatial-пружина с velocity).

**P19. `AnimatedCrossFade`/`AnimatedRotation` в login игнорируют reduce-motion**
`F:/Niosmess V2/pulse_flutter/lib/screens/login_screen.dart:544-590`.
Нет проверки `MediaQuery.disableAnimations`, `firstCurve`/`secondCurve` по умолчанию `Curves.linear`, `sizeCurve: spatial` для размера.
Исправление: при reduced motion — `duration: Duration.zero` и `turns` без анимации; заменить `AnimatedCrossFade` на `M3Reveal(type: expandY)`; fade-кривые — `expressiveDecel`.

**P20. Pull-to-refresh — стандартный Material-спиннер**
`F:/Niosmess V2/pulse_flutter/lib/screens/niosgram_screen.dart:139,165`; `lib/screens/profile_screen.dart:537`; `lib/widgets/settings/settings_shell.dart:162`.
`RefreshIndicator` внутри рисует `RefreshProgressIndicator extends CircularProgressIndicator` — по духу это запрещённый круговой индикатор; M3E-спиннер (`AppLoadingIndicator`) не задействован.
Исправление: кастомный refresh-индикатор на `AppLoadingIndicator` (или `loading_indicator_m3e`) с выезжающей каплей/шейпом; либо `RefreshIndicator.noSpinner` + собственный M3E-индикатор.

**P21. Смена палитры в Appearance — мгновенная**
`F:/Niosmess V2/pulse_flutter/lib/screens/settings_appearance_screen.dart:591-600` (цвет/рамка `Material` без анимации), `:319-329` (SwitchListTile).
Исправление: `AnimatedContainer`/`M3MorphingSurface` c `M3Durations.short4` и `expressiveStandard` для рамки и фона; для системных цветов — `M3Reveal`.

**P22. `_ActionChip` может дважды стартовать pop**
`F:/Niosmess V2/pulse_flutter/lib/widgets/post_card.dart:1192-1196` (`_handleTap` → `forward(from:0)`) и `:1177-1183` (`didUpdateWidget` → `forward(from:0)` при `active` false→true). В одном кадре pop перезапускается.
Исправление: убрать `forward` из `_handleTap`, оставить только реакцию на смену `active` (или наоборот), использовать `animateTo`/статус-гард.

**P23. Нет анимации в `AppLockGate`**
`F:/Niosmess V2/pulse_flutter/lib/features/security/presentation/app_lock_gate.dart` — grep не находит ни `AnimationController`, ни `Animated*`; экран блокировки появляется поверх приложения мгновенно.
Исправление: `AnimatedSwitcher(fadeScale)` 300 мс / `M3SpringCurves.spatial` при `isActuallyLocked`, иконка-замок — `M3AnimatedBadge`/shape pop.

**P24. Токены-пустышки в `CallTokens`**
`F:/Niosmess V2/pulse_flutter/lib/core/call_design_tokens.dart:45,51,54,55` — `exitAnimationDuration`, `exitCurve`, `controlsScaleCurve`, `rippleCurve` нигде не используются (grep 0), а `controlsFadeCurve` — `Curves.easeInOutCubic`.
Исправление: удалить неиспользуемые; `controlsFadeCurve` заменить на `M3SpringCurves.expressiveDecel` и завести `spatial`-токен для движения.

**P25. `MediaPlaceholderIllustration.animate` игнорируется; параметр-обманка**
`F:/Niosmess V2/pulse_flutter/lib/widgets/vector_illustrations.dart:123-166`.
Внутри `build` вообще нет анимации, `animate` не читается. Плейсхолдеры медиа в постах и чатах статичны.
Исправление: реализовать shimmer/pulse (один shared-контроллер на список) или удалить флаг, чтобы не создавать ложное впечатление.

**P26. `ChatListSkeleton` не учитывает `TickerMode` и создаёт контроллер лениво**
`F:/Niosmess V2/pulse_flutter/lib/widgets/pulse_skeleton.dart:58-61,79-90`.
Контроллер объявлен `late final` и инициализируется при первом обращении (в `didChangeDependencies`, `:83-88`), а не в `initState` — пограничное нарушение правила «контроллеры только в initState/didUpdateWidget/dispose». `TickerMode` не проверяется.
Исправление: создавать в `initState`, в `didChangeDependencies` только `stop/forward` по `TickerMode && !disableAnimations`.

**P27. `settings_shared_media_tab` игнорирует reduce-motion**
`F:/Niosmess V2/pulse_flutter/lib/widgets/profile/profile_shared_media_tab_view.dart:544-546` — `AnimatedContainer` 250 мс без проверки `disableAnimations`; кривая `spatial` на *цвете* (effects) даёт overshoot-интерполяцию цвета.
Исправление: `duration: disableAnimations ? Duration.zero : M3Durations.short4`, `curve: M3SpringCurves.expressiveStandard` (для цвета).

**P28. `AnimatedSize` c effects-кривой на spatial-свойстве**
`F:/Niosmess V2/pulse_flutter/lib/widgets/post_card.dart:386-390` (`expressiveDecel`), `lib/screens/settings_about_screen.dart:169-171` (`expressiveDecel`), `lib/widgets/settings/ordinary_e2ee_settings.dart:691-695` (`expressiveStandard`), `lib/screens/circle_video_recorder_screen.dart:612-650` (`expressiveDecel` на radius).
Правило M3E: spatial (размер/форма) весной, effects (opacity/цвет) — decel. Здесь наоборот.
Исправление: для размера/формы — `M3SpringCurves.spatial`; для opacity/цвета — `expressiveDecel`.

**P29. `AnimatedOpacity` без кривой**
`F:/Niosmess V2/pulse_flutter/lib/widgets/post_card.dart:812-816`; `lib/widgets/offline_banner.dart:18-20`.
Дефолт linear. Не критично (overshoot отсутствует), но не M3E effects.
Исправление: `curve: M3SpringCurves.expressiveDecel`.

**P30. `M3RouteTabSwitcher` двойное easing и фиксированная длительность**
`F:/Niosmess V2/pulse_flutter/lib/widgets/nav/m3_route_tab_switcher.dart:56-72,144-159`.
Смещение/scale считаются через `gentle.transform(_opacity.value)`, где `_opacity` уже прогнан через `expressiveAccel/Decel` — двойная кривая, из-за чего движение ощущается «ватным»; длительность 320 мс фиксирована сегментами (35%/65%).
Исправление: держать отдельный spatial-контроллер с пружиной (`M3MotionSpatial.default`), opacity — отдельный effects-контроллер с `expressiveDecel`; velocity передавать при перехвате (уже есть `animateTo`, но кривые мешают).

**P31. `legal_viewer` скролл на MD2-кривой**
`F:/Niosmess V2/pulse_flutter/lib/screens/legal_viewer_screen.dart:213-224` — 380 мс + `Curves.easeInOutCubic`.
Исправление: `M3Durations.medium4` + `M3SpringCurves.spatial` (или `expressiveStandard`).

**P32. `NiosMarkBadge` press на MD2-кривой**
`F:/Niosmess V2/pulse_flutter/lib/widgets/nios_mark_badge.dart:38-44` — 250 мс, `Curves.easeOutCubic`, только scale; M3Epress — shape.
Исправление: `M3SpringCurves.snappy` + морф `M3Container` shape при нажатии (уже есть `flutter_m3shapes`), либо `M3Pressable`.

**P33. `MorphingBrandMark` — единственный морф формы, но press-scale нет**
`...morphing_brand_mark.dart:161-192` — тап не даёт тактильного scale/формы, только морф.
Исправление: добавить `AnimatedScale(0.94, M3SpringCurves.snappy)` на tap-down.

**P34. `custom_color_picker` — `ClipRRect` на большой плоскости и нет анимации выбора**
`F:/Niosmess V2/pulse_flutter/lib/widgets/settings/custom_color_picker_sheet.dart:216-217` `ClipRRect` (save-layer на перетаскивании), пресеты без обратной связи.
Исправление: `Clip.none` + `DecoratedBox` с `borderRadius` (если содержимое не вылезает); выбранный цвет — `M3SelectionMotion`.

**P35. `AppBottomNav`: кастомный pill не используется**
`F:/Niosmess V2/pulse_flutter/lib/widgets/app_bottom_nav.dart:18-166` `TravelingNavIndicator` — 0 вызовов (grep). В UI живёт дефолтный индикатор `NavigationBar` (`:264-301`), так что заявленная «squash-and-stretch таблетка на пружине» не работает; `TabMorphIcon` использует `Curves.linear` (`:408`).
Исправление: либо удалить мёртвый виджет, либо подключить его вместо `indicatorColor` и перевести `TabMorphIcon` на `M3SpringCurves.snappy`.

**P36. `call_devices_dialog` пульсирующий уровень без анимации**
`F:/Niosmess V2/pulse_flutter/lib/widgets/calls/call_devices_dialog.dart:128-140,290-311` — 16 сегментов меняются скачком каждые 120 мс, `Timer.periodic` продолжает опрос в фоне/при скрытом диалоге.
Исправление: `AnimatedContainer` на сегментах (`M3Durations.short1`, `expressiveDecel`) или `CustomPaint` с пружинным сглаживанием; останавливать таймер по `TickerMode`/`AppLifecycleState`.

**P37. Нет «shape morph» на press почти нигде**
Кнопки лайка/комментария (`post_card.dart:1205-1212`), кнопки дока (`call_control_dock.dart:206-222`), тайлы настроек (`pressable_surface.dart:137-149`) меняют только scale, форма (radius) остаётся прежней.
Исправление: в общем примитиве анимировать `borderRadius` на +2…+4 dp при нажатии (M3E pressed shape), как уже сделано у кнопки записи `circle_video_recorder_screen.dart:612-650`.

**P38. `MediaHero`/медиавьюер: скролл-анимации без токенов**
`F:/Niosmess V2/pulse_flutter/lib/screens/media_viewer_screen.dart:292-297` — `AnimatedPositioned` 200 мс `spatial`, `scrimAlpha` линейно от drag.
Формально не критично; для M3E верхний бар должен уходить spatial-пружиной, scrim — effects-fast. Исправление: 200 мс → `M3Durations.short4`, кривая — `M3SpringCurves.snappy`.

**P39. `m3_spring_switcher`/`m3_shared_axis` — «пружины» без физики**
`F:/Niosmess V2/pulse_flutter/lib/widgets/motion/m3_spring_switcher.dart:33,61-134`; `m3_shared_axis.dart:14,46-101`. Внутри `AnimatedSwitcher` с duration+curve; перехват невозможен.
Не дефект сам по себе (это готовые блоки проекта), но в аудите важно: они не заменяют physics-переходы. Исправление: переписать на `AnimationController` + `SpringSimulation`/`Interval` по необходимости.

---

## 3. Несогласованности и дубли

1. **4 примитива press-feedback** с разными scale/кривыми/задержками: `touch_container.dart` (0.975, delay 90 мс, easeOutCubic/spatial), `pressable_surface.dart` (0.98, без delay, snappy/spatial), `pulse_button.dart` (0.975, spatial всегда), `m3_pressable.dart` (0.96, snappy, не используется).
2. **3 механизма смены темы**: `CircularThemeSwitcher` (450 мс cubic), `MaterialApp.themeAnimationDuration` 500 мс, локальный `AnimatedTheme` 500 мс в appearance-экране.
3. **5 механизмов раскрытия секций**: `ExpansionTile` по умолчанию (`settings_row.dart:66-72`), `AnimationStyle` (`ordinary_e2ee_settings.dart:682-687`), `AnimationStyle` (`profile_sheet_layout.dart:168-173`), `AnimatedCrossFade` (`login_screen.dart:556-590`), `AnimatedSize`+`AnimatedSwitcher` (`settings_about_screen.dart:169-182`). Разные длительности 200/300/280/300 мс и разные кривые.
4. **3 пульса с разными периодами**: incoming 1800 мс (`incoming_call_overlay.dart:74`), voice ripple 2000 мс (`call_design_tokens.dart:47`), запись кружка 800 мс (`circle_video_recorder_screen.dart:56`). Плюс `M3AnimatedBadge`/`M3StaggeredItem` не используются.
5. **2 типа скелетонов**: анимированный `ChatListSkeleton` vs статичные `PostFeedSkeleton`/`MessageListSkeleton`/`PostCardSkeleton`.
6. **2 навигационных индикатора**: живой M3 `NavigationBar` indicator и мёртвый `TravelingNavIndicator`.
7. **Дубли лоадеров**: `AppLoadingIndicator` (правильно) vs `RefreshIndicator` (круговой спиннер) vs `LinearProgressIndicator` внутри `AppLoadingIndicator` (разрешено).
8. **Spatial/effects перепутаны**: `expressiveDecel` на размере в `post_card.dart:390`, `settings_about_screen.dart:171`, `ordinary_e2ee_settings.dart:695`; `M3SpringCurves.spatial` на цвете в `profile_shared_media_tab_view.dart:546`; `M3MorphingSurface` морфит и цвет, и радиус одной spatial-кривой (`m3_morphing_surface.dart:21,84`) — если его подключат, цвет будет «перелетать».
9. **Мёртвый motion-код**: `m3_pressable`, `m3_staggered_list`, `m3_shared_axis`, `m3_reaction_burst`, `m3_morphing_surface`, `m3_morphing_icon`, `m3_animated_badge` — 0 вызовов (grep по `lib`); `color_ripple_overlay`, `code_preview`, `m3_resend_countdown_timer`, `m3_responsive_auth_layout`, `adaptive_glass`, `m3_otp_input_field` — 0 вызовов.
10. **Токены-пустышки**: `CallTokens.exitAnimationDuration/exitCurve/controlsScaleCurve/rippleCurve` (`call_design_tokens.dart:45,51,54,55`) не используются.
11. **Кривые без токенов в «токен-файле»**: `controlsFadeCurve = Curves.easeInOutCubic` (`call_design_tokens.dart:53`).
12. **`Opacity`-семантика**: `_NotificationsBell` (`niosgram_screen.dart:306`) и `MorphingBrandMark` (`morphing_brand_mark.dart:184`) выглядят как анимации, но фактически ничего не анимируют/не перелетают.

---

## 4. Топ-10 приоритетных переделок по эффекту для пользователя

1. **Оверлей звонка (P2, P9)**: пружинный снап с velocity + entrance/exit container-transform вместо `setState`-снапа и мгновенного появления. Это первый экран, где физика «на ладони».
2. **Видеозвонок: контролы и PiP (P5, P6)**: spatial-слайд верх/низ + effects-fast opacity, пружинный снап PiP — самый заметный экран.
3. **Полноэкранные изображения NiosGram (P7)**: настоящий Hero-container-transform для одиночных и карусельных фото, единая кривая Hero.
4. **Лента: скелетоны и вход карточек (P8 + неиспользуемый `M3StaggeredItem`)**: shimmer + кроссфейд скелетон→контент + stagger первых 8 карточек — воспринимаемая скорость приложения.
5. **Звонки: пульс входящего (P4, P1)**: исправить обрезку кольца, заменить один «дышащий» круг на экспрессивный shape-morph/pop.
6. **Смена темы (P3)**: один механизм, spring-радиус, снимок 2x — самый «вау»-эффект приложения сейчас выглядит мыльно и дёргано.
7. **Единый press-примитив с shape morph (P10, P37)**: убрать 4 разных ощущения кнопок; это ощущается на каждом тапе во всём приложении.
8. **Лайк/реакции (P14)**: `M3ReactionBurst` + `M3MorphingIcon` + bouncy spring вместо кастомного TweenSequence с тенью-глоу.
9. **Камера/кружок (P15, P11)**: затвор с press/loading и правильный flip-spring; Lottie с reduce-motion и 60 FPS.
10. **Auth/онбординг (P19, P22, P11, P13)**: убрать reduce-motion-нарушения, добавить shared-axis/stagger между шагами, починить мёртвый бейдж и BoxShadow.

---

## 5. Что сделано хорошо и трогать не нужно

1. **`M3RouteTabSwitcher`** (`lib/widgets/nav/m3_route_tab_switcher.dart:144-226`): сохраняет прогресс при быстром переключении, `TickerMode(enabled: i == widget.index && _phase == idle)` — образцовая остановка фоновых тикеров. Оставить, только развести spatial/effects-контроллеры (P30).
2. **`CircularThemeSwitcher`** (`circular_theme_reveal.dart:99-102`): `toImageSync(pixelRatio: 1.0)` вместо per-frame `BackdropFilter`/`MaskFilter.blur` — правильное направление по правилу «zero per-frame blur»; нужно лишь поднять pixelRatio и убрать второй AnimatedTheme.
3. **`ChatListSkeleton`** (`pulse_skeleton.dart:53-90`): один контроллер на все ряды, явный ping-pong, остановка по reduce-motion, метрики совпадают с `ChatTile` — хороший эталон, который стоит распространить на post/message-скелетоны.
4. **`CallAudioRipple`** (`call_audio_ripple.dart:29-45`): `RepaintBoundary` вокруг `CustomPaint`, painter рисует только геометрию без blur/shadow — дешёво; нужно только останавливать при неактивном аудио и убрать фиктивность.
5. **Кружок записи** (`circle_video_recorder_screen.dart:612-650`): единственный настоящий M3E shape-morph в зоне (radius 40→26, внутренний 18→7) — сохранить как пример для остальных кнопок.
6. **`SettingsProfileHeader`** (`settings_profile_header.dart:136-148`): scroll-driven геометрия + opacity на M3-кривых без overshoot, без `AnimationController` на скролл — правильно по духу; только убрать `Clip.hardEdge` (P12).
7. **`M3Reveal`/`M3SpringSwitcher`/`M3SelectionMotion`** (`motion/*.dart`): корректно разделяют opacity (`expressiveDecel`) и spatial (`spatial`), уважают `disableAnimations`; `M3SelectionMotion` (`m3_selection_motion.dart:26-34`) — хороший пресс-паттерн, надо тиражировать.
8. **`CallControlDock`/`IncomingCallOverlay`**: 0 elevation, тональные поверхности, `TouchContainer` с haptics, `AppLoadingIndicator` вместо кругового спиннера (`incoming_call_overlay.dart:309-313`, `call_control_dock.dart:146-169`) — визуально правильно, не трогать.
9. **`PostCard`**: `RepaintBoundary` (`post_card.dart:440`), `Card(elevation: 0, clipBehavior: Clip.none)` (`:441-446`), лента с `addRepaintBoundaries: false` и O(1) `idToIndex` (`niosgram_screen.dart:161-172`) — соответствует motion/perf-протоколу; ломать не нужно.
10. **`AppLoadingIndicator` и M3-индикаторы**: централизован, разрешённый `LinearProgressIndicator` только для детерминированного прогресса (`pulse_loading_indicator.dart:34-48`), `M3ResendCountdownTimer` использует именно его (`m3_resend_countdown_timer.dart:121-131`). Все `CircularProgressIndicator`/`LinearProgressIndicator` вне этого — отсутствуют (grep).
11. **`ordinary_e2ee_settings`** (`ordinary_e2ee_settings.dart:677-700`): `AnimationStyle.noAnimation` при reduce-motion и токенные длительности — так и надо делать во всех раскрывашках.
12. **`AppModal`** (`lib/core/modal/app_modal.dart:41-48,129-131,197-208`): единые токенные тайминги для шитов и диалогов, fade `expressiveDecel`, scale `gentle`; можно лишь заменить hardcode длительностей на `M3Durations`.

---

## 6. Что не проверял / ограничения аудита

- Не запускал приложение, не снимал FPS/GPU-профили: оценка «дорого/дёшево» — по коду (наличие `saveLayer`, `Clip`, `Opacity`, частота `setState`), а не измерена.
- Роутер (`lib/router`) и чаты (`lib/screens/chat_*`, `lib/widgets/chat/*`) исключены по условию; их переходы/анимации не аудировались. Упоминания `chat_*` в общих grep-ах — только для полноты перечня `Duration`/`Curves`.
- Не читал построчно `settings_privacy_screen.dart`, `settings_language_region_screen.dart`, `settings_system_device_screen.dart`, `settings_storage_screen.dart`, `settings_wallpaper_screen.dart`, `settings_account_screen.dart`, `settings_app_screen`, `features/sessions/*`, `features/wallpaper/*`, `features/security/*` — по grep в них **нет** `AnimationController`/`Animated*`/`Duration`-анимаций (кроме указанного `app_lock_gate` и `settings_row`). Вывод «анимаций нет» основан на grep, а не на полном чтении.
- Не проверял `flutter_animate` default-кривые по исходникам пакета; в отчёте они помечены как «дефолт пакета», а не как конкретная кривая.
- Точная дефолтная длительность `PageRouteBuilder` в конкретной версии Flutter не измерялась (в тексте — «дефолт ~300 мс»).
- Не проверял поведение на реальных устройствах с `MediaQuery.disableAnimations`/`TickerMode`; выводы об остановке бесконечных анимаций сделаны по наличию проверок в коде.

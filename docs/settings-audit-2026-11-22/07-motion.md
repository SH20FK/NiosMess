# 07. Движение в разделе «Настройки» (аудит 2026-11-22)

Корень: `F:/Niosmess V2/pulse_flutter`. Все пути ниже — от него. Код не менялся, запусков не было.
Прочитаны: `lib/screens/settings/*`, все `lib/screens/settings_*.dart`, `lib/widgets/settings/*`, `lib/widgets/settings_ui.dart`, `lib/features/settings/**`, `lib/widgets/motion/*`, `lib/core/motion/*`, `lib/core/modal/*`, `lib/core/theme/app_theme.dart` (переходы), `lib/router/app_router.dart`, `lib/screens/profile_screen.dart` (реальный хаб), `lib/screens/main_shell_screen.dart` (таб настроек), `lib/features/wallpaper/**`, `lib/features/sessions/**`, `lib/widgets/notifications/notification_settings_section.dart`.
Предыдущий аудит (`docs/motion-audit-2026-11-21/04-other-screens.md`) перечитан, его выводы по настройкам перепроверены по коду (см. §2).

Важно про топологию: «хаб» — это `lib/screens/settings/settings_hub_screen.dart:14-16`, он сразу делегирует в `ProfileScreen`. Именно `ProfileScreen` рисует хаб (мобильный список), десктопный master-detail и веб-вариант.

---

## 1. Главные выводы

1. **Слой токенов починили, но настройки им почти не пользуются для физики.** `M3Spring` теперь реальные M3E-пружины (`m3_spring_constants.dart:12-54`), есть `M3Motion`/`springTo` для перехватываемых переходов (`m3_motion.dart:11-76`), но в зоне настроек **ноль** вызовов `MotionController`, `M3Motion` и `springTo` (grep). Всё движение — implicit-виджеты с фиксированной длительностью, т.е. «пружина как кривая», без сохранения скорости при перехвате.
2. **В настройках нет ни одной анимации, созданной в `build()`.** Все контроллеры живут в `initState` (`circular_theme_reveal.dart:47-66`, `m3_reveal.dart:61-70`, `morphing_brand_mark.dart:117-124`, `wallpaper_studio_screen.dart:42-57`). Правило протокола №6 не нарушено.
3. **Кривые — только из `M3SpringCurves`/`M3Durations`.** Хардкода `Curves.easeInOut`/`Duration(milliseconds: …)` для анимаций в экранах настроек нет (единственный `Duration(400ms)` — `Timer` предпросмотра звука, `settings_preferences_screen.dart:44`, это не анимация). Исключения — дефолты самого motion-кита (`m3_spring_switcher.dart:34`) и Material-виджеты (`ChoiceChip`, `TabBar`).
4. **Reduce-motion уважается почти везде, кроме двух мест:** подсветка найденной строки (`features/settings/presentation/settings_row.dart:120-123` — `AnimatedContainer` с `M3Durations.medium1` без проверки) и `ChoiceChip`/`TabBar`/`Switch`, которые вообще не спрашивают `MediaQuery.disableAnimations` (куда попадает каждое нажатие на варианты темы, языка, шрифта).
5. **Переход «хаб → подэкран» хороший, обратный — нет.** `_page()` даёт `MaterialPage` (`app_router.dart:68-70`), тема подставляет `M3SharedAxisPageTransitionsBuilder` (`app_theme.dart:442-450`) — 500 мс, spatial-кривая, travel `min(width*0.25, 96)`, fade на effects, reduceMotion → travel 0 (`m3_page_transitions.dart:13-157`). Но билдер задаёт только `transitionDuration` (`:30-32`), `reverseTransitionDuration` не переопределён → возврат из подэкрана, скорее всего, тоже 500 мс (не проверено на устройстве), тогда как входные страницы (`_m3eEntryPage:80-81`) выходят за 300 мс.
6. **Веб/десктоп-секции живут на трёх разных переходах.** Десктоп — `AnimatedSwitcher` fade+вертикальный слайд 1.5 % (`profile_screen.dart:571-601`); веб-узкий — `KeyedSubtree` вообще без движения (`profile_screen.dart:788-812`); мобильный нативный — shared axis из роутера. Латеральная навигация master→detail на десктопе едет по Y, хотя должна по X.
7. **Смена акцентного цвета и смена темы ощущаются как разные фичи.** Тема ходит через круговой reveal (`circular_theme_reveal.dart`), а акцент просто лерпится `AnimatedTheme` 500 мс (`settings_appearance_screen.dart:99-106`) + глобальным `themeAnimationDuration` (`main.dart:381-390`). Сам reveal — cubic `expressiveDecel` на радиусе (spatial-свойство, effects-кривая) 450 мс, повторный тап игнорируется (`:85-89`).
8. **Крупнейшая дыра — не «плохие» анимации, а их отсутствие.** Загрузка→данные (`settings_storage_screen.dart:147-152`, `settings_system_device_screen.dart:32-37`), сессии (`features/sessions/presentation/sessions_screen.dart:84-155`), ошибки (`settings_privacy_screen.dart:45-49`), зависимые пункты после переключателя (`settings_energy_saving_screen.dart:142-168`, `notification_settings_section.dart:118-132`), смена значения в строке (`settings_list_item.dart:278-291`) — всё появляется скачком и сдвигает вёрстку.
9. **Отклик на касание формально единый, фактически — нет.** Строки идут через `PressableSurface` → `M3PressScale` (`pressable_surface.dart:87-98,139`; `m3_press_scale.dart:30-41`: сжатие 150 мс effects, отпускание 350 мс spatialFast, 0.98), но: без 90-мс задержки против скролла, которую использует `TouchContainer` (`touch_container.dart:32,122`); кнопки-чипы дают ink-ripple; звук/хаптика есть у строк и у части экранов, но нет у `SettingsChoiceButtons` (`settings_choice_buttons.dart:17-40`), языка (`settings_language_region_screen.dart:52-55`) и фона (`settings_energy_saving_screen.dart:109-119`).
10. **Motion-кит простаивает.** `M3StaggeredItem` в настройках не используется ни разу (единственный вызов — `widgets/message_context_menu_sheet.dart:569`), `M3MorphingIcon` — 0 вызовов, `M3Entrance` — 0. Из 13 экранов настроек анимированное появление контента есть ровно у трёх (`preferences:99-101`, `plus:264-283`, `about:170-183`).

---

## 2. Что было в аудите 2026-11-21 и что с этим стало

| Из отчёта 04 | Статус сейчас | Подтверждение |
|---|---|---|
| P1 «токены пружин не M3E» | **Исправлено**: `M3Spring` 800/0.6, 380/0.8, 200/0.8; effects 3800/1600/800 × 1.0 | `m3_spring_constants.dart:12-54` |
| P3 «три механизма смены темы» | **Частично**: пока идёт reveal, оба `AnimatedTheme` переключаются мгновенно | `main.dart:381-389`, `settings_appearance_screen.dart:101-106`, `circular_theme_reveal.dart:17-20,128` |
| P10 «4 press-примитива» | **Исправлено**: `TouchContainer`, `PressableSurface`, `PulseButton` все через `M3PressScale` | `touch_container.dart:232-237`, `pressable_surface.dart:139`, `pulse_button.dart:57-58` |
| P12 «`Clip.hardEdge` на шапке профиля» | **Не исправлено** | `settings_profile_header.dart:154` |
| P20 «`RefreshIndicator` в настройках» | **Исправлено**: `AppRefreshIndicator` с токенами и reduceMotion | `settings_shell.dart:162-164`, `app_refresh_indicator.dart:65-84` |
| P21 «смена палитры мгновенная» | **Не исправлено**: `Material(color/shape)` без анимации | `settings_appearance_screen.dart:558-568` |
| P28 «`AnimatedSize` с `expressiveDecel`» | **Не исправлено** в about | `settings_about_screen.dart:170-172` |
| P34 «`ClipRRect` в color picker» | **Не исправлено** | `custom_color_picker_sheet.dart:217` |
| P37 «нет shape-morph на press» | **Не исправлено**: только scale, радиус не меняется | `pressable_surface.dart:87-98,139` |
| P39 «spring-switcher без физики» | Подтверждено и усилено: дефолт 300 мс хардкодом | `m3_spring_switcher.dart:34,143-160` |

---

## 3. Реестр анимаций раздела

### 3.1 Навигация и каркас

| Место | Что анимируется | Механизм | Длительность | Кривая | reduceMotion |
|---|---|---|---|---|---|
| `core/motion/m3_page_transitions.dart:13-157` | вход/выход подэкрана, уезд нижней страницы (slide X + fade) | `PageTransitionsBuilder` + `DualTransitionBuilder` | 500 мс forward (const `:16-17`) | позиция `spatialDefault`, fade `effectsDefault` (0…0.4) / `effectsFast` (0…0.3) | да, travel→0 (`:116-125`) |
| `core/theme/app_theme.dart:442-450` | выбор билдера переходов | тема | — | — | — |
| `router/app_router.dart:68-70` | все `settings/*` кроме входа | `MaterialPage` | как у билдера | как у билдера | через билдер |
| `router/app_router.dart:72-107` | вход в приложение (splash/login) для контраста | `CustomTransitionPage` | 500 мс / reverse 300 мс | `effectsDefault` fade + `spatialDefault` scale 0.92 | да (`:83`) |
| `screens/profile_screen.dart:571-601` | смена раздела в двух панелях | `AnimatedSwitcher` + fade + slide Y 1.5 % | 250 мс (`medium1`) / 150 мс (`short3`) | `expressiveDecel` / `expressiveAccel` | да, `Duration.zero` |
| `screens/profile_screen.dart:788-812` | смена раздела в вебе (узкий) | `KeyedSubtree` | — | — | н/д (движения нет) |
| `screens/main_shell_screen.dart:638-659` | вход в таб «Настройки» | `M3RouteTabSwitcher` (shared axis) | 300 мс, tier C — 200 мс | gentle/decel/accel внутри | да (`tabMotion:616`) |
| `widgets/settings/settings_shell.dart:85-119` | свёртывание `SliverAppBar.large` | scroll-driven Flutter | — | M3 default | нет проверки |
| `widgets/settings/settings_profile_header.dart:129-256` | геометрия аватара, два `Opacity`, скролл-прогресс | `SliverPersistentHeader` + `lerpDouble` | 0 (следует за пальцем) | `expressiveStandard` (без overshoot) | да (`:138-140`) |
| `widgets/settings/settings_profile_header.dart:154` | `Material(clipBehavior: Clip.hardEdge)` | clip → save-layer | — | — | — |
| `widgets/settings/settings_shell.dart:162-164` | pull-to-refresh | `AppRefreshIndicator` | effectsFast/effectsDefault | `effectsFast`/`effectsDefault` | да (`app_refresh_indicator.dart:65-84`) |

### 3.2 Отклик на касание и строки

| Место | Что анимируется | Механизм | Длительность | Кривая | reduceMotion |
|---|---|---|---|---|---|
| `widgets/settings/pressable_surface.dart:87-98` | фон/рамка/радиус строки | `AnimatedContainer` | 200 мс (`short4`) | `expressiveStandard` | да |
| `widgets/settings/pressable_surface.dart:139` | сжатие строки | `M3PressScale(scale: 0.98)` | 150/350 мс | `effectsFast` / `spatialFast` | да (в `M3PressScale`) |
| `widgets/motion/m3_press_scale.dart:30-41` | сжатие/отпускание | `AnimatedScale` | `effectsFast` 150 / `spatialFast` 350 | `effectsFast` / `spatialFast` | да, scale→1 |
| `features/settings/presentation/settings_row.dart:120-131` | подсветка найденной строки (фон + радиус) | `AnimatedContainer` | 250 мс (`medium1`) | `expressiveStandard` | **нет** |
| `features/settings/presentation/settings_row.dart:89-99` | скролл к найденному пункту | `Scrollable.ensureVisible` | 300 мс (`medium2`) | `expressiveStandard` | да, 0 |
| `features/settings/presentation/settings_row.dart:67-73` | раскрытие продвинутой группы | `ExpansionTile` (дефолт) | не задано | дефолт Flutter | нет |
| `features/settings/presentation/settings_row.dart:45-54` | авто-раскрытие под поиск | `ExpansibleController.expand()` | дефолт `ExpansionTile` | дефолт | нет |
| `widgets/settings/settings_list_item.dart:188-206` | pending → `AppLoadingIndicator` вместо стрелки/свитча | подмена виджета | — | — | нет (смена скачком) |
| `widgets/settings/settings_list_item.dart:175-181` | звук toggleOn/Off | звук, не движение | — | — | управляется `soundEffects` |
| `widgets/settings/settings_choice_buttons.dart:17-40` | выбор варианта (тема, язык, шрифт, стиль палитры, фон) | `ChoiceChip` (Material) | дефолт Material (не проверено) | дефолт Material | нет |
| `widgets/motion/m3_selection_motion.dart:26-36` | выбранный emoji-чип | `TweenAnimationBuilder` scale | 200 мс (`short4`) | `spatialFast` | да |
| `widgets/settings/settings_group_scope.dart:4-21` | радиус/цвет группы при смене числа строк | `InheritedWidget` | — | — | н/д (скачок) |
| `widgets/settings_ui.dart:214-239` | радиусы углов группы по индексу | вычисление в build | — | — | н/д (скачок) |

### 3.3 Внешний вид, тема, цвет

| Место | Что анимируется | Механизм | Длительность | Кривая | reduceMotion |
|---|---|---|---|---|---|
| `screens/settings_appearance_screen.dart:99-106` | вся палитра экрана | `AnimatedTheme` | 500 мс (`long2`) / 0 при reveal | `expressiveStandard` | да |
| `main.dart:381-390` | тема всего приложения | `MaterialApp.themeAnimationDuration` | 500 мс / 0 | `expressiveStandard` | да (по флагу платформы) |
| `widgets/circular_theme_reveal.dart:47-66` | радиус «дырки» reveal | `AnimationController` + `CustomPaint` | 450 мс (`long1`) | `expressiveDecel` | да, reveal пропускается (`:85-89`) |
| `widgets/circular_theme_reveal.dart:105-119` | снимок старой темы | `toImageSync(pixelRatio: clamp 1…2)` | — | — | — |
| `widgets/circular_theme_reveal.dart:183-241` | `clipPath(evenOdd)` + `drawImageRect` | painter | 450 мс | — | — |
| `screens/settings_appearance_screen.dart:362-373` | пагинация палитр точками | `PageController.animateToPage` | 500 мс (`spatialDefault`) | `M3SpringCurves.spatialDefault` | да, `jumpToPage` |
| `screens/settings_appearance_screen.dart:394-400` | физика перелистывания палитр | `PageScrollPhysics` c `M3Spring.spatialDefault` (`:464-473`) | settle физики | пружина 380/0.8 | да, дефолтная физика |
| `screens/settings_appearance_screen.dart:438-451` | точка активной страницы (20↔8 dp) | `AnimatedContainer` | 300 мс (`medium2`) | `spatialFast` | да |
| `screens/settings_appearance_screen.dart:558-568` | выбор палитры (рамка, фон) | `Material` без анимации | — | — | — |
| `screens/settings_appearance_screen.dart:727-795` | слайдер скругления | `Slider`, состояние локальное | — | Material | — |
| `screens/settings_appearance_screen.dart:798-834` | масштаб шрифта | `SettingsChoiceButtons` | — | — | — |
| `widgets/settings/custom_color_picker_sheet.dart:113-186` | три превью цвета (карточка, свотч, полоса) | 3 × `AnimatedContainer` | 350 мс (`medium3`) | `expressiveStandard` | да |
| `widgets/settings/custom_color_picker_sheet.dart:196-290` | поле HSV (перетаскивание) | `setState` на каждый `onPanUpdate` + `ClipRRect` | на кадр | — | — |

### 3.4 Остальные экраны настроек

| Место | Что анимируется | Механизм | Длительность | Кривая | reduceMotion |
|---|---|---|---|---|---|
| `screens/settings_about_screen.dart:167-183` | смена таба (Новое/Право/Команда) | `AnimatedSize` + `AnimatedSwitcher` | 300 мс (`medium2`) | `expressiveDecel` (size!), `expressiveDecel`/`expressiveAccel` | да, ветка без обёртки |
| `screens/settings_about_screen.dart:280-287` | загрузка чейнджлога → текст | `when` вручную | — | — | — |
| `screens/settings_about_screen.dart:121-127` | логотип-морф | `MorphingBrandMark` | 350 мс (`spatialFast`) | `M3SpringCurves.spatialFast` (без clamp) | да (`morphing_brand_mark.dart:137-141`) |
| `screens/settings_energy_saving_screen.dart:122-141` | описание режима фона | `M3SpringSwitcher(fade)` | 200 мс (`short4`) | `expressiveDecel` | да (внутри) |
| `screens/settings_energy_saving_screen.dart:142-168` | кнопка «отключить оптимизацию» после reliable | появление в списке | — | — | — |
| `screens/settings_preferences_screen.dart:99-146` | громкость/тест звука после включения «Звуки» | `M3Reveal(expandY)` | 300 мс (`medium2`) | `spatialDefault` (settle 650) | да (внутри) |
| `screens/settings_preferences_screen.dart:44-55` | предпросмотр трёх звуков | `Timer.periodic` 400 мс | — | — | — |
| `screens/settings_plus_screen.dart:264-283` | кнопка пробного периода | `M3Reveal` | 300 мс | `spatialDefault` | да |
| `screens/settings_plus_screen.dart:193-209` | pending/ошибка статуса | подмена `SettingsListItem` | — | — | — |
| `screens/settings_chats_screen.dart:65-82` | выбранный emoji быстрой реакции | `M3SelectionMotion` | 200 мс (`short4`) | `spatialFast` | да |
| `screens/settings_storage_screen.dart:147-175` | загрузка/ошибка/данные | `when` | — | — | — |
| `screens/settings_storage_screen.dart:402-457` | полоса занятого места | статичная (`Expanded` по flex) | — | — | — |
| `screens/settings_system_device_screen.dart:32-52` | загрузка/ошибка/спецификация | `when` | — | — | — |
| `widgets/settings/system_resource_meter.dart:61-93` | заполнение шкалы RAM/диска | `TweenAnimationBuilder` 0→ratio | 400 мс (`medium4`) | `expressiveDecel` | да |
| `features/sessions/presentation/sessions_screen.dart:84-155` | loading → ready → revoke | условные ветки | — | — | — |
| `screens/settings_privacy_screen.dart:45-61` | загрузка/ошибка политик | условные ветки | — | — | — |
| `screens/settings_privacy_screen.dart:309-321` | секция спамблока | условная ветка | — | — | — |
| `screens/e2ee_settings_screen.dart:194-199` | loading ↔ ключ устройства | условная ветка | — | — | — |
| `widgets/settings/ordinary_e2ee_settings.dart:678-690` | «Как это работает» | `ExpansionTile` + `AnimationStyle` | 300 мс / мгновенно | `expressiveStandard` / `noAnimation` | да |
| `widgets/settings/ordinary_e2ee_settings.dart:692-701` | появление блоков по мере готовности | `AnimatedSize` | 300 мс | `expressiveStandard` | да |
| `widgets/notifications/notification_settings_section.dart:118-132` | строка «устройство зарегистрировано» | условная ветка | — | — | — |
| `screens/settings_language_region_screen.dart:33-58,63-89` | выбор языка/режима зоны | `ChoiceChip` | Material default | Material default | нет |
| `screens/settings_language_region_screen.dart:147-195` | локальное время (раз в минуту) | `Timer` + `setState` | — | — | пауза по `TickerMode` (`:176-181`) |
| `screens/settings_wallpaper_screen.dart:20-25` → `features/wallpaper/presentation/wallpaper_studio_screen.dart:152-177` | четыре таба и превью | `TabBar`/`TabBarView` (дефолт) | Material default | Material default | нет |
| `screens/profile_screen.dart:438-447` | карточки проблем настроек | появление в списке | — | — | — |

### 3.5 Листы и диалоги из настроек

| Место | Что | Механизм | Длительность | Кривая | reduceMotion |
|---|---|---|---|---|---|
| `core/modal/app_modal.dart:36-52` | шторка (`AppModal.showSheet`) | `showModalBottomSheet` + `AnimationStyle` | 400 мс / 200 мс | `expressiveDecel` / `expressiveAccel` | да, `noAnimation` |
| `core/modal/m3_modal_route.dart:13-46` | диалог: скрим + scale 0.9→1 / 1→0.96 | `RawDialogRoute` + `DualTransitionBuilder` | 500 мс / 200 мс | fade `effectsDefault`, scale `spatialDefault` / exit `expressiveAccel` | да, `Duration.zero` |
| `core/utils/app_toast.dart:34-41` | тост «сохранено/ошибка» | `SnackBar` + `AnimationStyle` | 250 / 150 мс | дефолт SnackBar | да, `noAnimation` |

---

## 4. Находки

Серьёзность: P0 — ломает/вешает, P1 — заметный дефект восприятия, P2 — системная несогласованность, P3 — полировка. P0 в зоне нет.

| # | P | Место | Что не так | Что предлагаю |
|---|---|---|---|---|
| M1 | P1 | `lib/widgets/settings/custom_color_picker_sheet.dart:74-78,113-186,196-290` | На каждый кадр перетаскивания по HSV-полю: `ColorScheme.fromSeed` в `build`, `setState` листа, 3 `AnimatedContainer` с 350 мс (каждый кадр ретаргетит), `ClipRRect` (`:217`) даёт save-layer, градиенты перерисовываются. Это единственное место в настройках с реальным риском джанка | Считать `preview` один раз по `_hue/_selected` с мемоизацией (или `late` в `didUpdateWidget`), тянуть `ValueNotifier<Color>` + `ValueListenableBuilder` только для превью; `ClipRRect` → `Clip.none` + `DecoratedBox`; превью-переход — `M3SpringSwitcher(fade, M3Durations.effectsDefault)` без 350 мс |
| M2 | P1 | `lib/core/motion/m3_page_transitions.dart:16-32`; `lib/router/app_router.dart:68-70` | Выход из подэкрана настроек не короче входа: задан только `transitionDuration` (500 мс), `reverseTransitionDuration` не переопределён. Вход в приложение при этом выходит за 300 мс (`app_router.dart:80-81`) — «назад» из настроек ощущается вязким | Добавить `reverseTransitionDuration = M3Durations.effectsSlow` (или `medium4`) и отдельную fade-out кривую; либо вынести настройки на `CustomTransitionPage` с теми же таймингами, что вход |
| M3 | P1 | `settings_storage_screen.dart:147-175`; `settings_system_device_screen.dart:32-52`; `features/sessions/presentation/sessions_screen.dart:84-155`; `settings_privacy_screen.dart:45-49`; `e2ee_settings_screen.dart:194-199`; `settings_plus_screen.dart:193-209` | `when()`/`if` меняет скелетон на контент одним кадром: нет кроссфейда, высота скачет, скролл-позиция прыгает. При pull-to-refresh данные меняются под пальцем без движения | `M3SpringSwitcher(type: fade, duration: M3Durations.effectsDefault)` вокруг состояний + `RepaintBoundary`; для чисел хранилища — `TweenAnimationBuilder` (как в `system_resource_meter.dart:61-93`) на `_SegmentedProgressBar` (`storage:402-457`), сейчас шкала статична |
| M4 | P2 | `lib/features/settings/presentation/settings_row.dart:120-123` | Единственный `AnimatedContainer` в зоне без `context.reduceMotion`; при включённом reduce-motion подсветка из поиска всё равно едет 250 мс | `duration: context.reduceMotion ? Duration.zero : M3Durations.medium1` |
| M5 | P2 | `lib/screens/settings_about_screen.dart:170-172` | Размер таба анимируется **effects**-кривой `expressiveDecel`; по M3E размер/форма — spatial (`m3_spring_constants.dart:5-11,143-149`) | `curve: M3SpringCurves.spatialDefault`, `duration: M3Durations.spatialDefault`; fade оставить на `expressiveDecel` |
| M6 | P2 | `lib/widgets/circular_theme_reveal.dart:50-53,85-89,161-162` | Радиус «дырки» (spatial) едет cubic `expressiveDecel` 450 мс; повторный тап во время анимации отбрасывается (`if (_isAnimating) return`), скорость не переносится. Физики нет, хотя токены теперь это позволяют | Радиус — `M3Motion.spatialSlow` через `MotionController` + `springTo(1.0, reduceMotion: …)`; повторный тап ретаргетит, а не игнорируется. Снимок уже правильный (`:115-119`) |
| M7 | P2 | `settings_appearance_screen.dart:99-106,558-568`; `circular_theme_reveal.dart` | Смена темы = reveal, смена акцента = лерп `AnimatedTheme` 500 мс. Рамка выбранной палитры появляется мгновенно, а цвета догоняют полсекунды — рассогласование состояния и картинки | Для акцента: тот же `CircularThemeSwitcher.toggleTheme` c `tapOffset` свотча; рамку свотча — `AnimatedContainer`/`M3SelectionMotion` 200 мс `expressiveStandard`; `AnimatedTheme` экрана оставить только для прочих изменений |
| M8 | P2 | `settings_energy_saving_screen.dart:142-168`; `notification_settings_section.dart:118-132`; `settings_privacy_screen.dart:309-321`; `settings_language_region_screen.dart:90-102`; `settings_account_screen.dart:44-59` | Зависимые пункты появляются/исчезают скачком, хотя рядом описание уже фейдится (`M3SpringSwitcher` на `energy:122-141`). Худший случай — «Спамблок» и строка «устройство зарегистрировано»: список прыгает под пальцем | Правило: любой условный блок в настройках — `M3Reveal(type: M3RevealType.expandY, duration: M3Durations.spatialDefault)` с `IgnorePointer` (эталон уже есть: `settings_preferences_screen.dart:99-105`). Для строк внутри `SettingsSection` — `M3Reveal(fadeScale)` |
| M9 | P2 | `widgets/settings/settings_choice_buttons.dart:17-40`; `settings_appearance_screen.dart:713-719`; `language_region:52-55,79-87`; `energy_saving:109-119` | Три семьи отклика: M3-press на строках, ink-ripple на чипах, M3-switch. Чипы не спрашивают reduce-motion, не дают звука/хаптики, длительность у них не токенная. Хаптика есть у темы (`settings_appearance_screen.dart:161-173` → `circular_theme_reveal.dart:130-132`), выбора шрифта/стиля/палитры (`:827,874,313`) и emoji (`settings_chats_screen.dart:76`), нет у языка (`settings_language_region_screen.dart:52-55,79-87`) и режима фона (`settings_energy_saving_screen.dart:109-119`) | Завернуть `ChoiceChip` в `M3SelectionMotion` (как `settings_chats_screen.dart:65-66`) и добавить `HapticService.selection()` + `playUiTick()` в сам `SettingsChoiceButtons`, а не в каждый экран. Для подписи/иконки выбора — `M3MorphingIcon` (сейчас 0 вызовов) |
| M10 | P2 | `widgets/settings/pressable_surface.dart:139`; `widgets/common/touch_container.dart:32,109-124` | Строки настроек сжимаются немедленно (`scale 0.98`), `TouchContainer` в чатах — через 90 мс (`AppMotion.pressTimeout`) и 0.975. Прокрутка списка настроек начинается с «прилипшего» сжатия | Взять задержку и `AppMotion.scalePressed` в `PressableSurface` (или перевести его на `TouchContainer`), чтобы список и чаты ощущались одинаково |
| M11 | P2 | `lib/screens/profile_screen.dart:571-601` | Латеральный переход master→detail едет по Y на 1.5 % + fade; направление не передаётся (нет ощущения «вправо/влево»), в вебе (`:788-812`) движения нет вовсе | Переиспользовать `M3SharedAxisPageTransitionsBuilder`-геометрию: `AnimatedSwitcher` с `SlideTransition` по X (±16 dp) и `spatialDefault`; в вебе — тот же `_animatedDetail` вокруг `KeyedSubtree` (`:805-811`) |
| M12 | P2 | `widgets/motion/m3_reveal.dart:27-28`; `widgets/motion/m3_spring_switcher.dart:34` | Дефолты кита нарушают правило пары «кривая ↔ длительность»: `spatialDefault` имеет settle 650 мс (`m3_spring_constants.dart:206-208`), а `M3Reveal` по умолчанию 300 мс, `M3SpringSwitcher` — хардкод 300 мс. Пружина проигрывается сжатой, перелёт становится резче | Дефолт `M3Reveal.duration = M3Durations.spatialDefault`, `M3SpringSwitcher.duration = M3Durations.spatialDefault`/`effectsDefault` по типу; либо явно документировать сжатие |
| M13 | P2 | `widgets/settings/settings_profile_header.dart:151-154` | `Material(clipBehavior: Clip.hardEdge)` на pinned-шапке = save-layer каждый кадр скролла хаба (было P12, не исправлено) | `Clip.none` + `OverflowBox`/явные `Positioned`; либо включать `ClipRect` только при `shrinkOffset > 0` |
| M14 | P3 | `lib/screens/profile_screen.dart:401-436`; `widgets/motion/m3_staggered_list.dart:12-128` | Хаб настроек — самый «списочный» экран, но `M3StaggeredItem` в нём не используется (единственный вызов — `message_context_menu_sheet.dart:569`). После перехода список просто стоит | Обернуть первые 6–8 строк `_sectionGroups` в `M3StaggeredItem(index:…)` (30 мс шаг, `spatialDefault`), дальше — без анимации (в виджете лимит `maxStaggerIndex` уже есть) |
| M15 | P3 | `profile_screen.dart:438-447`; `features/settings/presentation/settings_issue_card.dart:42-60` | Карточки проблем появляются/исчезают без движения и сдвигают весь список (это первые элементы после поиска) | `M3Reveal(expandY)` по списку `_healthIssues()`; на появление ошибки — `HapticService.reaction()` один раз |
| M16 | P3 | `widgets/settings/settings_list_item.dart:278-291`; `:209-229` | Значение в строке меняется текстом без движения: ни fade, ни морфа иконки, ни «пружины» числа | `M3SpringSwitcher(type: fade, duration: M3Durations.effectsDefault)` на `value`; числа (размеры, проценты) — `TweenAnimationBuilder` на `Text` c `effectsDefault` |
| M17 | P3 | `widgets/settings_ui.dart:214-239`; `settings_account_screen.dart:44-59` | При появлении строки (username/Nios ID) углы и цвет группы пересчитываются мгновенно: радиус «прыгает» с 24/4 на другой индекс | Считать радиус от фактического числа строк (уже так) и обернуть `SettingsGroupScope`-materials в `AnimatedContainer` `short4`/`expressiveStandard` (одна анимация на группу, не на строку) |
| M18 | P3 | `features/wallpaper/presentation/wallpaper_studio_screen.dart:152-177`; `widgets/wallpaper_preview_pane.dart:7` | Экран обоев — единственный раздел настроек вообще без движения: табы на дефолтном `TabBar`, превью меняется мгновенно на каждый тап, reduce-motion не спрашивается | Табы: `TabBar(indicatorAnimation: TabIndicatorAnimation.elastic)` + `M3SpringCurves.snappy`; превью — `AnimatedContainer`/`M3SpringSwitcher(fade, effectsDefault)`; смена пресета — `M3SelectionMotion` |
| M19 | P3 | `lib/widgets/about/morphing_brand_mark.dart:159-190` | Логотип в «О приложении» реагирует только морфом: нет press-scale, тап не даёт «нажатия» | `M3PressScale(pressed:…)` или `AnimatedScale(0.96, M3SpringCurves.snappy)` на tap-down |
| M20 | P3 | `lib/screens/settings_language_region_screen.dart:176-181` | Таймер минуты перезапускается в `didChangeDependencies`; при возврате из шита выбора зоны текст времени меняется без движения | `M3SpringSwitcher(fade)` вокруг `formatFullDateTime` |
| M21 | P3 | l10n: `settingsPredictiveBack*`, `appearancePredictiveBack*` (`lib/l10n/app_localizations.dart:6382-6386,7330-7408`) | В строках обещан «предиктивный жест назад» и «сила анимации возврата», но в UI настроек такого тумблера нет, а `M3SharedAxisPageTransitionsBuilder` предиктивный back не реализует | Либо реализовать (Android 14 predictive back + отдельный builder), либо убрать ключи, чтобы не обещать несуществующее |
| M22 | P3 | `widgets/pulse_loading_indicator.dart:30-63` | Индикатор — looping-морф без проверки `reduceMotion` в обёртке; в настройках он появляется в т.ч. в `pending` строки (`settings_list_item.dart:188-193`), меняя ширину блока | Проверять `context.reduceMotion` и в этом случае показывать статичный прогресс/`LinearProgressIndicator(value)`; появление индикатора — кроссфейдом `short4` |
| M23 | P3 | `widgets/settings/settings_list_item.dart:150-167` | `enabled`/`danger`/`isSelected` меняют цвет текста и иконки мгновенно, а фон строки — за 200 мс: полстроки «догоняет» | `AnimatedDefaultTextStyle`/`TweenAnimationBuilder<Color?>` на `foreground` с `M3Durations.short4` + `expressiveStandard` |

Ответ на вопрос «единый ли отклик на всех экранах»: **нет**. Одинакова только геометрия press-scale у строк. Различаются: задержка против скролла (нет/90 мс), звук и хаптика (есть/нет), тип обратной связи (scale / ink-ripple / M3-switch), анимация изменения значения (нет).

---

## 5. Язык движения для новых настроек

Общие правила раздела: spatial — для размера, положения и формы (может перелетать); effects — для прозрачности и цвета (без перелёта). Любой перехват (повторный тап, ретаргет) — через `M3Motion` + `springTo`, а не новый `forward(from: 0)`.

| Ситуация | Готовый блок / токен | Параметры |
|---|---|---|
| Вход экрана настроек (мобайл) | `M3SharedAxisPageTransitionsBuilder` (`core/motion/m3_page_transitions.dart:13`) | forward `M3Durations.spatialDefault`, reverse `M3Durations.effectsSlow`, travel `min(w*0.25, 96)` |
| Вход экрана (веб/десктоп-секция) | `M3Reveal(type: fadeScale)` (`widgets/motion/m3_reveal.dart:21`) или shared-axis по X | `M3Durations.spatialDefault` + `M3SpringCurves.spatialDefault`; направление по индексу раздела |
| Шапка/иллюстрация экрана | `M3Entrance` (`m3_entrance.dart:10`) | delay 0–80 мс, `offsetY: 8`, fade `effectsDefault` |
| Каскад групп хаба | `M3StaggeredItem` (`m3_staggered_list.dart:12`) | `index`, шаг 30 мс, `maxStaggerIndex: 8`, `spatialDefault` |
| Отклик строки | `PressableSurface` + `M3PressScale` (`pressable_surface.dart:139`, `m3_press_scale.dart:10`) | scale 0.975, press `M3Durations.effectsFast`/`effectsFast`, release `M3Durations.spatialFast`/`spatialFast`, задержка 90 мс (`AppMotion.pressTimeout`) |
| Shape-morph при нажатии (M3E) | `AnimatedContainer` на радиусе | +2…+4 dp, `M3Durations.short3` + `M3SpringCurves.snappy` |
| Раскрытие зависимых пунктов | `M3Reveal(type: expandY)` | `M3Durations.spatialDefault` + `spatialDefault`, внутри `IgnorePointer` |
| Смена выбора (чипы, тема, язык) | `M3SelectionMotion` (`m3_selection_motion.dart:13`) + `M3MorphingIcon` | 200 мс `short4`, `spatialFast`; хаптика `HapticService.selection()` |
| Смена значения в строке | `M3SpringSwitcher(type: fade)` | `M3Durations.effectsDefault` + `effectsDefault`; числа — `TweenAnimationBuilder` |
| Смена описания/подсказки | `M3SpringSwitcher(type: fade)` | `M3Durations.effectsDefault`, вход `effectsDefault`, выход `effectsAccel` |
| Загрузка → данные | `M3SpringSwitcher(type: fade)` вокруг `when()`, скелетон — `AppLoadingIndicator` | `M3Durations.effectsDefault`; числа/шкалы — `TweenAnimationBuilder` `medium4` + `expressiveDecel` |
| Подтверждение сохранения | `M3AnimatedBadge` (`m3_animated_badge.dart:9`) на иконке строки + `M3MorphingIcon` (outline→filled) | pop `spatialFast`, иконка `M3Durations.medium1` |
| Появление ошибки/проблемы | `M3Reveal(fadeScale)` + тост (`AppModal`/`AppToast`) | `M3Durations.medium2`; тост 250/150 мс |
| Смена темы | `CircularThemeSwitcher` + `M3Motion.spatialSlow` на радиусе | радиус `springTo(reduceMotion: …)`, `M3Durations.long1` минимум; повторный тап ретаргетит |
| Смена акцентного цвета | `CircularThemeSwitcher.toggleTheme(tapOffset: свотч)` | как тема, но `M3Motion.spatialFast` (локальный эффект) |
| Смена обоев (превью) | `M3SpringSwitcher(fade)` + `M3SelectionMotion` на пресете | `effectsDefault`, 200 мс |
| Опасное действие (сброс, стирание) | диалог `AppModal.showConfirmation` + `HapticService.destructive()`; после подтверждения — `M3SpringSwitcher(fade)` на списке | без overshoot на прозрачности; строка исчезает с `M3Durations.short4` + `expressiveAccel` |
| Pull-to-refresh | `AppRefreshIndicator` (уже есть) | `effectsFast`/`effectsDefault` |
| Reduce motion | `context.reduceMotion` / `context.motionDuration()` (`m3_motion.dart:51-57`) | любая длительность → 0; spatial-сдвиги → 0; цвет/прозрачность — мгновенно |

Чего в настройках сейчас нет и что стоит завести как примитив: единый `SettingsReveal` (обёртка над `M3Reveal` + `IgnorePointer` + `Semantics`), `SettingsValueText` (анимация значения) и `SettingsPress` (строка с задержкой против скролла и shape-morph) — иначе каждая правка снова будет собирать движение руками.

---

## 6. Не проверено

- Продакшн-профилирования не было: оценки «дорого/дёшево» (M1, M13) сделаны по коду (save-layer, `setState` на кадр, `ColorScheme.fromSeed` в `build`), а не по FPS.
- `reverseTransitionDuration` у `PageTransitionsBuilder` в конкретной версии Flutter не проверял по SDK: вывод M2 опирается на то, что в билдере переопределён только `transitionDuration` (`m3_page_transitions.dart:30-32`).
- Реальные длительности/кривые `ChoiceChip`, `TabBar`/`TabBarView`, `Switch`, `Slider` не сверял с исходниками Flutter — помечены как «Material default».
- Уважает ли `loading_indicator_m3e` (внутри `AppLoadingIndicator`) `MediaQuery.disableAnimations` — не проверял.
- Не проверял на устройстве predictive back, поведение `SliverAppBar.large` при reduce-motion, а также как обои применяются в самом чате после `Navigator.maybePop()` (`wallpaper_studio_screen.dart:71-84`).
- Не проверял визуально `M3StaggeredItem` в настройках — оценка по коду виджета (лимит 8 элементов, таймер задержки).
- Файлы вне зоны (`main_shell_screen` кроме таба настроек, чаты, звонки) читал только там, где они задают движение настроек.

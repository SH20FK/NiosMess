# Аудит motion: переходы и навигация (2026-11-21)

**Корень:** `F:/Niosmess V2/pulse_flutter` (все пути ниже, кроме SDK, относительны ему).
**Читал целиком:** `app_router.dart`, `app_theme.dart`, `pulse_predictive_back_transition.dart`, `m3_spring_constants.dart`, `m3_route_tab_switcher.dart`, `app_bottom_nav.dart`, `m3_shared_axis.dart`, `app_modal.dart`, `app_side_sheet.dart`, `app_bottom_sheets.dart`, `app_dialogs.dart`, `m3_modal_surface.dart`, `nios_motion.dart`, `nios_dismissible.dart`, `media_hero.dart`, все точки `MaterialPageRoute`/`PageRouteBuilder` из задания.
**Дополнительно прочитал исходники Flutter SDK на диске** (`F:/Flutter/flutter/packages/flutter/lib/...`), чтобы подтвердить поведение платформенных переходов, Hero и модальных barrier'ов — ссылки на строки SDK даю отдельно.
**Не проверял вживую:** реальный FPS, поведение на устройстве iOS/Android 14, поведение `go()` при замене стека на web. Такие утверждения помечены «не проверено на устройстве».

---

## 1. Инвентарь переходов

### 1.1 Маршруты go_router

| Маршрут / точка | Файл:строка | Тип перехода | Длительность | Кривая | Уходящий экран |
|---|---|---|---|---|---|
| `/` (Splash), `/login`, `/web`, `/onboarding` | `lib/router/app_router.dart:66-95` | `CustomTransitionPage`: fade + scale 0.98→1 | 280 мс / reverse 220 | fade = `Interval(0, 0.75, easeOut)`, scale = `M3SpringCurves.expressiveDecel` | **Не анимируется вообще** (builder игнорирует `secondaryAnimation`) + `canTransitionTo` для Material-маршрута ниже вернёт `false` (SDK `material/page.dart:161-179`), т.к. `_CustomTransitionPageRoute` не `MaterialRouteTransitionMixin` и без `delegatedTransition` (`go_router-17.5.0/lib/src/pages/custom_transition_page.dart:114,156`) |
| `/chat/:chatId` | `lib/router/app_router.dart:97-133` | `CustomTransitionPage`: slide 3% (≈12 dp) + fade | 240 / 240 | slide = `expressiveDecel`, fade = `easeOutCubic` | Не анимируется; тот же `canTransitionTo == false` (SDK `material/page.dart:161-179`) |
| `/media-viewer` | `lib/router/app_router.dart:432-472` | `CustomTransitionPage`, `opaque:false`, `barrierColor: transparent`: fade + scale 0.90→1 | 320 / 260 | scale = `M3SpringCurves.spatial` / reverse `gentle`, fade = `easeOutCubic` | Не анимируется, но остаётся видимым (non-opaque) и продолжающим жить под вьюером |
| `/main/:tab` (сам маршрут) | `lib/router/app_router.dart:276-294` | `MaterialPage` → theme `PageTransitionsTheme` | Android: 450 мс (`FadeForwards`, SDK `page_transitions_theme.dart:470`); Android с выключенным predictive back / Windows / Linux: 300 мс `ZoomPageTransitionsBuilder`; iOS/macOS: 500 мс Cupertino (`cupertino/route.dart:155`) | FadeForwards: `easeInOutCubicEmphasized` + 25% слайд; Zoom: MD2-зум; Cupertino: параллакс 1/3 | Анимируется (FadeForwards/Zoom/Cupertino) |
| Все `_page`-маршруты: `/chats/search`, `/new-message`, `/new-group/*`, `/new-channel`, `/join`, комментарии, `/chat/:id/members|manage|profile`, `/profile/:u`, `/g/:u`, `/stickers/:id`, весь `/settings/*`, `/help/faq`, `/legal/*`, `/file-viewer`, `/niosgram/create`, `/niosgram/post/:id`, `/niosgram/post/:id/comments`, `/call/*`, 404 | `lib/router/app_router.dart:295-333, 334-340, 475-548, 563-700, 701-732, 733-768, 769-800, 801-843, 844-850` | `MaterialPage` → theme | см. строку выше | см. строку выше | Анимируется |
| `/plus/activate` | `lib/router/app_router.dart:226-230` | `builder:` → дефолтный `MaterialPage` | 450/300/500 | theme | Анимируется |

**Ключевой факт:** в приложении одновременно живут две несовместимые системы переходов — тема (`PageTransitionsTheme`) для `MaterialPage` и три рукописных builder'а в роутере для `CustomTransitionPage`. Они не смешиваются: `CustomTransitionPage` вообще не смотрит в тему (`custom_transition_page.dart:150-156`).

### 1.2 Табы `/main/:tab`

| Что | Файл:строка | Тип | Длительность | Кривая | Уходящий |
|---|---|---|---|---|---|
| Контент табов | `lib/widgets/nav/m3_route_tab_switcher.dart:39-229` | fade + сдвиг 32 dp + scale 0.96 (incoming) / 0.985 (outgoing), через `AnimationController.animateTo` | 320 мс tierA (широкий 300), 300 tierB, 200 tierC — `lib/screens/main_shell_screen.dart:598-604`; дефолт виджета 320 — `m3_route_tab_switcher.dart:65-66` | fade-out 35% времени на `expressiveAccel`, fade-in 65% на `expressiveDecel` (`:148-158`); при этом translate/scale **дополнительно** гоняются через `M3SpringCurves.gentle.transform(_opacity.value)` (`:57-72`) | Уходящий гасится до 0, затем `Offstage` (`:199-201`) |
| Индикатор нижней навигации | `lib/widgets/app_bottom_nav.dart:264-301` + SDK `navigation_bar.dart:845-880` | Встроенный `NavigationBar`: пилюля масштабируется по X от 40% и **проявляется на месте** (fade 100 мс, `:865`), не путешествует | 280 мс tierA/B, 200 tierC (`app_bottom_nav.dart:207-209`); SDK-дефолт 500 мс (`navigation_bar.dart:308`) | `Curves.easeInOutCubicEmphasized` (`navigation_bar.dart:848`) | Старая пилюля исчезает на своём месте |
| Иконка таба | `lib/widgets/app_bottom_nav.dart:349-465` | Кросс-фейд outline/filled + pulse `sin(pi*t)`: scale 1→1.16 и подъём −3.5 dp | 280/200 | `expressiveDecel` / reverse `expressiveAccel` (`:386-390`), controller гонится `Curves.linear` (`:405-409`) | — |
| `TravelingNavIndicator` (путешествующая пилюля со squash&stretch) | `lib/widgets/app_bottom_nav.dart:18-166` | **Не используется нигде** (grep по `lib` — только объявление) | 220 мс | `M3SpringCurves.spatial` (`:57-60`) | — |

### 1.3 Модальные поверхности

| Точка | Файл:строка | Тип входа | Длительность | Кривая | Scrim |
|---|---|---|---|---|---|
| Bottom sheet (`AppModal.showSheet`) | `lib/core/modal/app_modal.dart:34-48` | `showModalBottomSheet` + `AnimationStyle` | 300 / 250 | sheet: `M3SpringCurves.expressiveDecel` / reverse `expressiveAccel` (`:43-48`) | `Colors.black54` по умолчанию (SDK `bottom_sheet.dart:1109`), **`Curves.ease`** (SDK `routes.dart:1869`), анимация барьера 300 мс (SDK `bottom_sheet.dart:1177-1198`) |
| Диалог (`AppModal.showDialog`) | `lib/core/modal/app_modal.dart:124-209` | `showGeneralDialog` + fade + scale 0.96→1 | 280 мс, reverse = 280 (отдельного reverse-параметра у `showGeneralDialog` нет, SDK `routes.dart:2759-2788`) | fade `expressiveDecel`, scale `M3SpringCurves.gentle` (`:197-207`) | `scheme.scrim @45%` (`:128`), `Curves.ease` 280 мс |
| Side sheet (`AppSideSheet.show`) | `lib/core/modal/app_side_sheet.dart:19-69` | `showGeneralDialog` + slide 1→0 по X | 300 / 300 | `expressiveDecel`, **без reverseCurve** (`:55-66`) | `scheme.scrim @45%` (`:25`), `Curves.ease` |
| Подтверждение (`showAppConfirmDialog`) | `lib/widgets/app_dialogs.dart:153-178` → `AppModal.showConfirmation` (`app_modal.dart:277-328`) | как диалог | 280 | как диалог | как диалог |
| `AppDialog` (виджет) через `showAppDialog` | `lib/widgets/app_dialogs.dart:30-55, 106-115` | как диалог, `wrapSurface:false` | 280 | как диалог | как диалог |

Прямых `showDialog(` в обход `AppModal` в `lib` **не найдено**. Прямой `showModalBottomSheet` — один: `lib/widgets/chat/interactive_message_card.dart:136` (без `AnimationStyle`, без темы, `constraints` 520) — не M3E-шит: нет drag-handle поверхности, дефолтная кривая `Easing.legacyDecelerate` (SDK `bottom_sheet.dart:29`).

### 1.4 Обходы роутера

| Точка | Файл:строка | Что получает |
|---|---|---|
| Saved-посты | `lib/screens/niosgram_screen.dart:95-99` | `MaterialPageRoute` → theme |
| Create post (fallback без GoRouter) | `lib/screens/niosgram_screen.dart:372-374` | theme |
| Topics группы | `lib/screens/chat_detail_screen.dart:2707-2712` | theme (вне роутера/URL) |
| Папки чатов (из настроек) | `lib/screens/settings_chats_screen.dart:40-44` | theme |
| Папки чатов (из инбокса) | `lib/widgets/chat_productivity.dart:86-88` | theme |
| Превью вложений | `lib/widgets/m3_file_picker_bottom_sheet.dart:586-598` | theme, **пуш из-под bottom sheet** |
| Быстрая камера | `lib/widgets/quick_camera_capture_screen.dart:14-17` | theme |
| Превью медиа-сетки | `lib/widgets/media_grid_picker.dart:496-524` | theme |
| Активация Plus | `lib/widgets/plus_purchase_options.dart:109-111` | theme |
| Видео Niosgram | `lib/widgets/post_card.dart:735-737` | theme |
| Полноэкранное фото поста | `lib/widgets/post_card.dart:706-718` | `PageRouteBuilder`, fade `Curves.easeOut`, **300 мс по умолчанию**, `barrierLabel` без `barrierColor` |
| Запись кружка | `lib/widgets/chat/chat_input_bar.dart:356-364` | `PageRouteBuilder`, **линейный** `FadeTransition(opacity: a)`, `opaque:false`, barrier прозрачный (color не задан → SDK `routes.dart:2300` строит `ModalBarrier` без цвета) |

### 1.5 Hero / shared element (фактическое состояние)

| Пара | Файл:строка | Работает? |
|---|---|---|
| Аватар чата → профиль (mobile) | target: `lib/widgets/chat/chat_detail_app_bar.dart:126-145` (`chat_avatar_$chatId`); source профиля: `lib/screens/public_profile_screen.dart:371-373`, `lib/screens/group_profile_screen.dart:193-202` | **Да** на mobile-route (`context.push`), **нет** на desktop — профиль открывается `showGeneralDialog` (`lib/widgets/profile/responsive_profile_sheet.dart:20-25, 40-45`), а Hero летает только между `PageRoute` (SDK `heroes.dart:916-919`) |
| Аватар из списка чатов → шапка чата | source **отсутствует**: `lib/widgets/chat_tile.dart:298-315` без `Hero`; target `chat_detail_app_bar.dart:128` | **Нет полёта** — у target нет пары, это мёртвый Hero |
| Медиа сообщения → вьюер | `lib/widgets/media/media_hero.dart:4-25`, `lib/widgets/message_bubble.dart:1057-1064`, `lib/screens/media_viewer_screen.dart:731-733` | Да, но поверх этого вьюер ещё и масштабирует весь экран 0.9→1 (`app_router.dart:441-459`) |
| Медиа поста в ленте → fullscreen | `lib/widgets/post_card.dart:970` ↔ `:806` | Да для одиночного медиа; в карусели source без Hero (`:954-961`) — полёта нет |
| Медиа из «Общих медиа» профиля → вьюер | `lib/widgets/profile/profile_shared_media_tab_view.dart:673-680` — `heroTag` не передаётся | **Нет** (хотя `media_viewer` умеет) |
| Логотип бренда splash/login/onboarding | `lib/screens/splash_screen.dart:96`, `login_screen.dart:386-389`, `onboarding_screen.dart:169-172` | Переходы между ними — `go()` с заменой стека; полёт hero в такой схеме не гарантирован (**не проверено на устройстве**) |

---

## 2. Проблемы

### CRITICAL

**C1. Открытие чата из списка не имеет пространственной иерархии, а список под ним замирает.**
`lib/router/app_router.dart:97-133` — 240 мс, сдвиг всего 3% (≈12 dp) + fade. Хуже: `_CustomTransitionPageRoute` (go_router `custom_transition_page.dart:114`) не является `MaterialRouteTransitionMixin` и не имеет `delegatedTransition`, поэтому `MaterialRouteTransitionMixin.canTransitionTo` возвращает `false` (SDK `material/page.dart:161-179`) — инбокс под чатом **не анимируется ни на вход, ни на выход**. Визуально: «экран просто проявился», список стоит. Для главного действия приложения (открыть чат) это и есть «плохие анимации».
*Исправление:* container transform (карточка чата раскрывается в экран) или shared axis X с параллаксом уходящего списка; технически — либо перейти на `MaterialPage` + собственный `PageTransitionsBuilder` в теме, либо сделать свой `PageRoute`-миксин с `delegatedTransition`.

**C2. На iOS потерян свайп-назад и параллакс на чате и вьюере.**
Жест краевого свайпа ставит **только** `CupertinoPageTransitionsBuilder` (SDK `cupertino/route.dart:249-258`). `CustomTransitionPage` его обходит (`custom_transition_page.dart:150-156`), значит `/chat/:chatId`, `/media-viewer`, `/`, `/login`, `/onboarding`, `/web` на iPhone не имеют интерактивного возврата. Для мессенджера это блокирующий дефект.
*Исправление:* чат и вьюер должны быть `CupertinoPageRoute`-совместимы (MaterialPage/CupertinoPage + кастомный builder в теме), либо обернуть контент в `_CupertinoBackGestureDetector`-эквивалент.

**C3. Predictive back не работает там, где он важнее всего.**
Обработчик системного жеста живёт **внутри** transitions builder'а: `lib/core/motion/pulse_predictive_back_transition.dart:60-84` (детектор), SDK `predictive_back_page_transitions_builder.dart:63-99`. Builder подключается только через тему (`lib/core/theme/app_theme.dart:482-494`), т.е. только к `MaterialPage`. На `CustomTransitionPage` (`/chat/:chatId`, `/media-viewer`, входные экраны) детектора нет → палец не ведёт экран, предпросмотра нет вообще. Дополнительно шелл отключает жест: `PopScope(canPop: false)` в `lib/screens/main_shell_screen.dart:394-395` (на Android `canPop:false` запрещает predictive-анимацию).
Платформа: только Android (SDK `predictive_back_page_transitions_builder.dart:106-108`), манифест это разрешает — `android/app/src/main/AndroidManifest.xml:32` (`enableOnBackInvokedCallback="true"`).
*Исправление:* подключить детектор на всех маршрутах (сделать один `PageTransitionsBuilder` и не использовать `CustomTransitionPage` для полноэкранных экранов), а «назад с вкладки» реализовать анимированным переключением таба, а не `PopScope(canPop:false)`.

### MAJOR

**M1. В навигации нет ни одной настоящей пружины — только `duration + curve`.**
`app_router.dart:74-75, 105-106, 436-437`; `app_modal.dart:43-48, 129-131`; `app_side_sheet.dart:26-28`; `app_bottom_nav.dart:207-209`; `main_shell_screen.dart:598-604`. Настоящая физика в проекте есть — `lib/core/motion/nios_motion.dart:37-50` (`SpringSimulation`) и `:68-86` (`animateWithSpring`), но используется только drag-to-dismiss медиа-вьюера (`lib/core/motion/nios_dismissible.dart:165-173`). M3E требует velocity-based spring с прерыванием; `Curve` этого не даёт.
*Исправление:* единый слой `AppMotion` на `NiosMotion`/`SpringSimulation` для in-page/модальных переходов; для page-переходов — либо нормализованная spring-кривая из M3E-токенов, либо собственный `PageRoute` с simulation.

**M2. `M3SpringCurves`/`M3Spring` не соответствуют M3E-токенам и противоречат друг другу.**
`lib/core/motion/m3_spring_constants.dart:13-18` — `spatial: 220/26` → ζ = 26/(2·√220) ≈ **0.88**, а в комментарии написано 0.75; в M3E spatial default = 380/0.8. `:20-25` emphasized 200/22 (ζ≈0.78), `:28-32` snappy 340/32, `:34-39` bouncy 260/18, `:41-46` gentle 150/22 — ни одно не совпадает со спекой (800/0.6, 380/0.8, 200/0.8; effects 3800/1600/800, ζ=1.0). Плюс второй набор `M3SpringCurves:106-133` с stiffness 32/36/52/58/24 — вообще другой масштаб (ω≈5.6 рад/с, меньше одной осцилляции на [0,1]), из-за чего «spatial» на 300 мс ощущается как медленное всплывание с мелкой рябью, а не как отклик.
*Исправление:* один источник токенов (spatial/effects × fast/default/slow) в терминах M3E; убрать «декоративные» stiffness; effects-токены не применять к spatial-свойствам и наоборот.

**M3. Табы: двойное сглаживание, гибрид fade-through + shared axis и «мигание» при переключении.**
`m3_route_tab_switcher.dart:144-182` — контроллер уже гонится кривой (`expressiveAccel`/`expressiveDecel`, `:151-158`), а затем `_offset`/`_scale` (`:57-72`) ещё раз прогоняют **то же значение** через `M3SpringCurves.gentle.transform`. Fade живёт по одной кривой, движение — по другой, поэтому движение «отстаёт» от прозрачности. Гашение занимает 35% времени (`:148-149`): при 320 мс это **112 мс** — экран уходит почти мгновенно и появляется «пустой» кадр, затем 208 мс проявляется новый. `Offstage` держит целевую вкладку неразложенной до этого момента (`:199-201`), поэтому первый layout тяжёлой вкладки (Niosgram) приходится ровно на старт fade-in — гарантированный хитч.
*Исправление:* M3 fade-through (короткий fade-out на effects, затем fade-in с scale 0.92 на spatial), один контроллер на эффект, без повторного `transform`; убрать slide 32 dp либо сделать честный shared axis X для связанных разделов.

**M4. Нижняя навигация и контент не синхронизированы.**
`app_bottom_nav.dart:207-209` (280/200 мс) против `m3_route_tab_switcher` 320/300/200; кривые разные: SDK-индикатор `easeInOutCubicEmphasized` (`navigation_bar.dart:848`) + fade 100 мс (`:865`), контент — `expressiveDecel` + `gentle`. Пилюля индикатора **не путешествует**, а проявляется на новом месте, тогда как контент уезжает на 32 dp. При этом готовый `TravelingNavIndicator` с squash&stretch (`app_bottom_nav.dart:18-166`) — мёртвый код. Пульс иконки (scale 1.16, −3.5 dp, `:429-461`) в M3E-спеке навигации отсутствует и добавляет третью, независимую анимацию.
*Исправление:* одна синхронизированная ось времени: индикатор (travel + squash) на snappy spatial, контент — fade-through; убрать pulse или заменить на морфинг иконки.

**M5. Модальные окна входят не на spatial-пружине, а выходят с кривой входа.**
Диалог: `app_modal.dart:129-131` — 280 мс на всё; `showGeneralDialog` не имеет reverse-длительности (SDK `routes.dart:2759-2788`), `FadeTransition`/`ScaleTransition` без `reverseCurve` (`:197-207`) → выход тормозит по decelerate вместо accelerate. Side sheet: `app_side_sheet.dart:55-66` — `CurvedAnimation` без `reverseCurve`, 300/300. Bottom sheet: `AnimationStyle` задаёт curve/reverseCurve, но длительность фиксированная и scrim живёт отдельно (см. M6).
*Исправление:* собственный `ModalRoute` с двумя независимыми анимациями: поверхность — spatial spring, scrim — effects spring; reverseCurve = accelerate (effects) для контента.

**M6. Scrim не на effects-пружине и разного цвета в разных модалках.**
`ModalRoute.barrierCurve => Curves.ease` (SDK `routes.dart:1869`), а `showModalBottomSheet` жёстко гоняет барьер тем же маршрутным контроллером (SDK `bottom_sheet.dart:1177-1198`). `sheetAnimationStyle` на barrier не влияет (SDK `bottom_sheet.dart:692-697` — curve применяется только к позиции листа) → scrim и лист имеют разные кривые при одинаковой длительности. Цвет: bottom sheet = `Colors.black54` (SDK `bottom_sheet.dart:1109`; в `app_theme.dart:246-255` `modalBarrierColor` не задан), диалог/side sheet = `scheme.scrim @45%` (`app_modal.dart:128`, `app_side_sheet.dart:25`). Один и тот же слой затемнения выглядит по-разному.
*Исправление:* собственный sheet-route с `barrierColor: scheme.scrim` и отдельным `Animation<double>` для scrim на effects-пружине.

**M7. Media viewer спорит сам с собой: hero + масштаб всего экрана + живые чаты под ним.**
`app_router.dart:432-460`: `opaque:false`, `barrierColor: transparent`, `ScaleTransition 0.90→1` на всём экране при одновременном полёте Hero. Двойное движение (hero летит, весь экран зумится) + под вьюером 320 мс продолжает жить и перерисовываться чат (non-opaque route не снимает нижний маршрут). На закрытии 260 мс с `M3SpringCurves.gentle` в обратную сторону.
*Исправление:* `opaque: true` поверх scrim-слоя (scrim на effects-пружине), убрать общий scale (движение делает hero / shared axis Z), оставить `NiosDismissible`.

**M8. Один и тот же переход выглядит по-разному на разных платформах без замысла.**
`app_theme.dart:482-494`: Android — Pulse/FadeForwards, iOS/macOS — Cupertino, **Windows/Linux — `ZoomPageTransitionsBuilder`** (MD2-зум Android Q, SDK `page_transitions_theme.dart:588-595`; в текущем SDK дефолт для Android уже `PredictiveBackPageTransitionsBuilder`, `:764-771`). А `CustomTransitionPage`-маршруты при этом одинаковы везде. Итог: «Настройки → сессия» на Windows — зум из 2019-го, «чат» — 12 dp fade.
*Исправление:* на Windows/Linux — fade-through/shared axis X на spring; `Zoom` убрать полностью.

**M9. 10 `MaterialPageRoute` и 2 `PageRouteBuilder` вне роутера.**
Список в §1.4. Последствия: (а) новая схема переходов к ним не применится; (б) `ChatFoldersScreen` и `GroupTopicsScreen` не имеют URL/диплинка и ломают browser back; (в) `post_card.dart:706-718` — fade `easeOut` без контроля длительности; (г) `chat_input_bar.dart:356-364` — **линейный** fade, без скрима, без длительности (дефолт 300 мс).
*Исправление:* перевести навигационные экраны в роутер (`/settings/chats/folders`, `/chat/:id/topics`), модальные — на общий `AppModal`-route с M3E-моушном.

**M10. Legacy-фасад `AppBottomSheets.show` используется в 37 местах, в том числе в новом коде.**
`lib/widgets/m3_file_picker_bottom_sheet.dart:75`, `lib/widgets/m3_file_preview_bottom_sheet.dart:436` — прямое нарушение AGENTS.md («AppBottomSheets.show считается legacy»). Поведение идентично `AppModal.showSheet` (`app_bottom_sheets.dart:19-28`), т.е. это чистая несогласованность.

**M11. «Назад» с вкладки — резкий переход, хотя тап по табу анимирован.**
`main_shell_screen.dart:394-404`: `PopScope(canPop:false)` → `context.go('/main/chats')` без анимации. Одно и то же действие (Niosgram → Chats) имеет два разных моушена.

**M12. На web каждая вкладка — отдельный Page/Route.**
`app_router.dart:290-292`: на web `pageKey: state.pageKey`, на нативных — константа `ValueKey('main-shell')`. Значит на web `M3RouteTabSwitcher` пересоздаётся (теряются `_activatedTabs`, скролл, состояние свитчера), а его анимация не запускается. Насколько это заметно — **не проверено на устройстве**, но разница ключей — факт.

**M13. Библиотека M3E-моушена декоративна: половина не подключена.**
`TravelingNavIndicator` (`app_bottom_nav.dart:18-166`) — не используется; `M3SharedAxis` (`lib/widgets/motion/m3_shared_axis.dart:8-103`) — не используется нигде; `M3TabPageSwitcher` (`lib/widgets/nav/m3_tab_page_switcher.dart`) и `tab_shared_axis_switcher.dart` — legacy-обёртки без вызовов; `AdaptiveGlass` — без вызовов; `TabTransitionController.captureOutgoing()` — пустышка (`m3_route_tab_switcher.dart:6-9`).

**M14. Hero на desktop-профиле не летает принципиально.**
`responsive_profile_sheet.dart:20-25` использует `showGeneralDialog` → `RawDialogRoute` — не `PageRoute`, а Hero требует `PageRoute` с обеих сторон (SDK `heroes.dart:916-919`). При этом `group_profile_screen.dart:193` и `public_profile_screen.dart:371` содержат Hero-теги, т.е. код обещает контейнер-трансформ, которого нет.

**M15. Аватар в списке чатов без Hero.**
`chat_tile.dart:298-315` (source) vs `chat_detail_app_bar.dart:128` (target) — полёта нет, потому что нет пары. Самое частое действие лишено shared element.

**M16. Тумблер predictive back показан там, где ничего не делает.**
`settings_appearance_screen.dart:227-260` — секция показывается при `!kIsWeb` (т.е. и на iOS, и на Windows/macOS/Linux), а читается только для Android: `app_theme.dart:484-488`. На iOS/десктопе переключатель и «сила» — мёртвые контролы.

### MINOR

| # | Файл:строка | Проблема | Исправление |
|---|---|---|---|
| m1 | `app_router.dart:78-87, 109-125, 441-452` | `CurvedAnimation`/`Tween` создаются внутри `transitionsBuilder` на каждый build и не диспозятся | Вынести в `StatefulWidget`-обёртку/`AnimatedBuilder` с dispose |
| m2 | `pulse_predictive_back_transition.dart:357-360` | Мутация состояния (`_lastDrag = ...`) прямо в `build`, плюс `_getYShiftPosition` считается в билдере | Перенести расчёт в `_updateAnimations`/listener |
| m3 | `app_router.dart:78-92` | `curvedAnimation` используется только для scale, а fade идёт по другой кривой/интервалу; scale 0.98 практически невидим → фактически простой fade | Один осмысленный эффект: fade-through (0.92) или shared axis Z (0.8) |
| m4 | `app_router.dart:200-207` | `Interval`/`easeOut` вместо effects-токена | Использовать effects-пружину |
| m5 | `post_card.dart:806, 970`; `group_profile_screen.dart:193`; `chat_detail_app_bar.dart:128` | Hero без проверки `MediaQuery.disableAnimations` (в `MediaHero` проверка есть — `media_hero.dart:15`) | Добавить guard |
| m6 | `main_shell_screen.dart:612` + `m3_route_tab_switcher.dart:210` | Двойной `RepaintBoundary` вокруг страниц таба | Оставить один |
| m7 | `m3_route_tab_switcher.dart:202-203` | `TickerMode(enabled: ... && _phase == idle)` замораживает анимации входящей вкладки на время перехода | Включать по `i == widget.index` |
| m8 | `media_viewer_screen.dart:292-297` | `AnimatedPositioned` 200 мс `M3SpringCurves.spatial` вне токенов | Привести к effects/spatial токенам |
| m9 | `pulse_predictive_back_transition.dart:200-207` | Commit-интервал 400/450 → визуально коммит завершается на ~89% pop-анимации; остаток маршрут невидим, но перехватывает ввод | Согласовать константу с `kTransitionMilliseconds` |
| m10 | `outgoing_call_screen.dart:143` | `pushReplacement('/call/$id')` — смена outgoing→active без согласованного перехода | Явный fade-through поверх call-overlay |
| m11 | `media_viewer_screen.dart:120-126` | Fallback закрытия — `context.go('/main/chats')` (замена стека) | `Navigator.maybePop`/явный `go` только для диплинка |
| m12 | `m3_file_preview_bottom_sheet.dart:436-449` | Пустая строка и `isScrollControlled:true` при дефолтном `true`; вызов legacy-фасада | Перейти на `AppModal.showSheet` |
| m13 | `interactive_message_card.dart:136-164` | Прямой `showModalBottomSheet` без `AnimationStyle`/M3-поверхности | `AppModal.showActions` |
| m14 | `app_router.dart` (все три builder'а) | Три разных набора длительностей/кривых для однотипных экранов (280/220, 240/240, 320/260) | Единые токены |
| m15 | `m3_spring_constants.dart:147-163` | `M3Durations` — это M3 **baseline** durations, не M3E spring-токены; используются как «моушен-система» | Не использовать для переходов |

---

## 3. Несогласованности и дубли

1. **Две параллельные системы пружин:** `M3Spring`/`NiosMotion` (`m3_spring_constants.dart:12-47`, `nios_motion.dart:11-60`) и `M3SpringCurves` (`m3_spring_constants.dart:104-144`) с разными числами и разной семантикой; «spatial» определён дважды.
2. **Пять мест, где задаётся вход экрана:** `_m3eEntryPage`, `_chatDetailPage`, inline builder `/media-viewer` (`app_router.dart:66, 97, 432`), `PageTransitionsTheme` (`app_theme.dart:482`), модальные route'ы (`app_modal.dart`, `app_side_sheet.dart`).
3. **Три реализации переключения контента:** самописный `M3RouteTabSwitcher`, неиспользуемый `M3SharedAxis`, почти неиспользуемый `M3SpringSwitcher` (один вызов — `settings_energy_saving_screen.dart:122`) + рукописный `AnimatedSwitcher` в `main_shell_screen.dart:503-524`.
4. **Четыре стратегии «назад»:** `Navigator.pop(context)` (`chat_detail_screen.dart:150`), `context.pop()` (`media_viewer_screen.dart:122`), `context.go('/main/chats')` (`chat_manage_screen.dart:190, 243, 264`; `join_chat_screen.dart:128`), `PopScope`-хендлеры (`main_shell_screen.dart:396-417`).
5. **Дубли фасадов модалок:** `AppModal.showSheet` ↔ `AppBottomSheets.show` (37 вызовов), `AppDialog`-виджет + `showAppDialog` + `AppModal.showDialog` + `showAppConfirmDialog`.
6. **Мёртвый моушен-код:** `TravelingNavIndicator`, `M3SharedAxis`, `M3TabPageSwitcher`, `TabSharedAxisSwitcher`, `AdaptiveGlass`, `TabTransitionController.captureOutgoing`.
7. **Разные scrim'ы:** `Colors.black54` (sheets) vs `scheme.scrim@0.45` (dialogs/side sheet).
8. **Комментарии расходятся с кодом:** `m3_spring_constants.dart:13` («damping ratio 0.75» при фактических 0.88), `:6-11` («Based on Google M3 Expressive motion specifications») при полном несовпадении чисел.

---

## 4. Целевая схема

Принцип: **два типа токенов** — spatial (позиция/размер/форма, допускает overshoot) и effects (прозрачность/цвет, без overshoot). Все переходы строятся на M3E-числах: spatial fast 800/0.6, default 380/0.8, slow 200/0.8; effects fast 3800/1.0, default 1600/1.0, slow 800/1.0. Полноэкранные переходы — default/slow spatial.

| Группа | Паттерн | Обоснование |
|---|---|---|
| Splash → login/onboarding → main | fade through (effects default на fade, spatial slow на scale 0.92 у входящего) | Несвязанные корневые состояния; сейчас 280 мс fade+0.98 |
| Список чатов → чат | **container transform** (аватар+карточка → шапка/фон чата), fallback — shared axis X с параллаксом уходящего списка | Иерархия вглубь + прямой источник в списке; сейчас 12 dp fade и мёртвый список |
| Чат → профиль/инфо группы | container transform (Hero-аватар), на desktop — side sheet как PageRoute (иначе Hero невозможен) | Сейчас mobile hero работает, desktop — нет |
| Настройки → подраздел, профиль → серия, правовые документы, help | shared axis X (forward/backward с параллаксом) | Иерархия одного раздела; сейчас зум/450 мс fade-forwards |
| Табы Chats / Niosgram / Settings | **fade through** (90/210 мс эквивалент) + индикатор-путешественник на snappy spatial | Несвязанные разделы, M3 прямо предписывает fade-through для табов |
| Внутри Contacts: Calls/Contacts | shared axis X (соседние разделы), 30 dp | Сейчас `M3RouteTabSwitcher` с 10 dp (`contacts_screen.dart:438-442`) |
| Мастер `/new-group/members → /new-group/details` | shared axis X forward | Сейчас theme-переход; `M3SharedAxis` уже написан |
| Niosgram: пост → деталка | container transform (карточка поста раскрывается) | Сейчас MaterialPage zoom/fade-forwards |
| Niosgram: медиа → fullscreen | контейнер-трансформ через `MediaHero` + shared axis Z (0.8), без общего scale | Сейчас hero + zoom всего экрана |
| `/media-viewer` из чата | shared axis Z / container transform, `opaque:true`, scrim effects | Сейчас non-opaque + 0.9 scale |
| Модалки: bottom sheet | поверхность — spatial default (spring), scrim — effects default; reverse — effects accelerate | Сейчас кривые, scrim на `Curves.ease` |
| Модалки: dialog / side sheet | spatial fast для scale/position, effects для scrim; отдельные reverse-кривые | Сейчас 280/300 мс, reverse = вход |
| Calls (outgoing/active/incoming) | fade through из FAB/аватара, без слайда | Сейчас theme-зум на Windows, fade-forwards на Android |
| Внешние входы (`/join`, `/u/:slug`, `/w/:code`, `/legal/*` из ссылок) | fade through | «Откуда пришли — неизвестно» |
| Predictive back | один общий `PageTransitionsBuilder`, подключённый ко **всем** полноэкранным маршрутам; «назад с вкладки» — анимированный fade-through к Chats | Сейчас работает только на MaterialPage |

**Технические заметки к реализации (важно, чтобы не обещать невозможного):**
- Flutter `PageRoute` не принимает `Simulation`; настоящий spring на переходе страницы делается либо нормализованной M3E-кривой (приемлемая аппроксимация, но без velocity handoff), либо собственным `PageRoute`/`AnimationController.animateWith` (в проекте уже есть `NiosMotion.animateWithSpring`).
- Hero физически не летает в `PopupRoute` (SDK `heroes.dart:916-919`) → side sheet для контейнер-трансформа нужно делать `PageRoute`-ом (например, `PageRouteBuilder` с правым слайдом), а не `showGeneralDialog`.
- Scrim стандартных маршрутов всегда `Curves.ease` (SDK `routes.dart:1869`) → для effects-пружины нужен свой route, а не `showModalBottomSheet`/`showGeneralDialog`.
- Краевой свайп на iOS ставится только Cupertino-builder'ом (SDK `cupertino/route.dart:253-258`) → полноэкранные экраны не должны быть `CustomTransitionPage`.

---

## 5. Топ-10 переделок по пользовательскому эффекту

1. **Чат из списка: container transform + Hero-аватар + анимировать уходящий список.** `app_router.dart:97-133`, `chat_tile.dart:298`, `chat_detail_app_bar.dart:128`. Самое частое действие, сейчас выглядит как «проявилось».
2. **Вернуть iOS-свайп и Android-predictive на чат/вьюер.** `custom_transition_page.dart`-маршруты → PageRoute с `delegatedTransition`/Cupertino-детектором (`heroes.dart`, `cupertino/route.dart:253`). Иначе на iPhone чат «не листается назад».
3. **Единые M3E-токены и настоящие пружины вместо duration+easing.** `m3_spring_constants.dart`, `nios_motion.dart`, все вызовы `M3SpringCurves` в переходах.
4. **Табы: fade-through + путешествующий индикатор (оживить `TravelingNavIndicator`), синхронные длительности и кривые.** `m3_route_tab_switcher.dart:144-182`, `app_bottom_nav.dart:18-166, 207-209`.
5. **Свой модальный route: spatial для поверхности, effects для scrim, корректные reverse-кривые.** `app_modal.dart:34-48, 124-209`, `app_side_sheet.dart:19-69`.
6. **Убрать `ZoomPageTransitionsBuilder` (Windows/Linux и Android с выключенным predictive) → fade-through/shared axis на spring.** `app_theme.dart:488, 491-492`.
7. **Predictive back на всех маршрутах + «назад с вкладки» как анимированный переход вместо `PopScope(canPop:false)`+`go`.** `main_shell_screen.dart:394-404`.
8. **Media viewer: убрать общий zoom 0.9, сделать `opaque:true` со scrim на effects, оставить drag-to-dismiss.** `app_router.dart:432-460`.
9. **Niosgram: пост→деталка как container transform, медиа→fullscreen через hero + shared axis Z; заменить `PageRouteBuilder`-линейный fade и `MaterialPageRoute`.** `post_card.dart:706-718, 735-737`, `niosgram_screen.dart:95-99, 372-374`.
10. **Свести всё в один API переходов (`AppTransitions`/`M3PageRoute`) и убрать обходы роутера + legacy-фасады; удалить мёртвый моушен-код.** 10 `MaterialPageRoute` + 2 `PageRouteBuilder` + 37 `AppBottomSheets.show` + `TravelingNavIndicator`/`M3SharedAxis`.

---

## 6. Что сделано хорошо (трогать не нужно)

1. **`MediaHero`** (`lib/widgets/media/media_hero.dart:4-27`) — правильный shared-element: per-message тег (`chatMediaHeroTag`), `transitionOnUserGestures`, `flightShuttleBuilder`, который держит превью, пока грузится полноразмер, и отключение при `disableAnimations`. Это эталон, который стоит расширить на аватар чата и медиа поста.
2. **Drag-to-dismiss вьюера с передачей скорости** — `lib/core/motion/nios_dismissible.dart:135-183` (velocity handoff в `SpringSimulation`), плюс scrim, привязанный к прогрессу жеста (`media_viewer_screen.dart:273-279`). Это настоящий M3E-подход: жест ведёт, анимация можно отменить.
3. **Сам `PulsePredictiveBackPageTransitionsBuilder`** — `lib/core/motion/pulse_predictive_back_transition.dart:233-258, 346-377`: корректный сдвиг по Y за пальцем, device corner radii (`MediaQuery.displayCornerRadiiOf`), commit 400 мс, scrim-fallback на FadeForwards. Механизм правильный — проблема только в охвате маршрутов (C3). Виджет сохранить и переподключить.
4. **Platform-aware тема** — `app_theme.dart:482-494`: Cupertino на iOS/macOS — правильное решение; менять нужно только fallback для Android-off/desktop.
5. **Учёт reduced motion** — `app_router.dart:77, 108, 440` (ранний `return child`), `app_modal.dart:41-42` (`AnimationStyle.noAnimation`), `media_hero.dart:15`, `m3_route_tab_switcher.dart:63-64`. Паттерн выдержан, просто не на всех путях.
6. **Тесная интеграция с производительностью** — тиры меняют длительности (`main_shell_screen.dart:598-604`, `app_bottom_nav.dart:207-209`), `RepaintBoundary` вокруг навбара (`main_shell_screen.dart:648`) и страниц табов (`:612`), `TickerMode` по активному табу (`:610-611`), прогрев вкладок (`:172-188`). Идея верная — не хватает только перевода длительностей в параметры пружин и устранения «холодного» первого layout входящей вкладки.
7. **Адаптивность модалок** (`app_modal.dart:239-273`): на широких экранах действия — диалог, на узких — bottom sheet; `M3ModalSurface` без живого блюра и теней (`m3_modal_surface.dart:9, 111-117`) — соответствует правилам проекта.
8. **`HeroMode(enabled: !isDesktopSplit)`** в шапке чата (`chat_detail_app_bar.dart:126-127`) — корректно отключает полёт в split-режиме, где он был бы дублем.

---

### Ограничения этого аудита

- Всё выше — статический анализ кода + чтение исходников Flutter 3.x SDK на диске (`F:/Flutter/flutter`). Реальные замеры кадров, поведение `go()` при замене page-стека на web, работа predictive back на конкретном Android-устройстве и Hero-полёт на splash→login **не проверялись** — эти пункты помечены в тексте.
- Не аудировал: контентные анимации внутри экранов (pressable, reaction burst, morphing icons вне навбара), `CircularThemeSwitcher`, `CallOverlay`-анимации, клавиатурные панели ввода — они вне заявленной зоны.

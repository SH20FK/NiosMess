# Аудит motion: сквозной аудит lib/ (2026-11-21)

Аудит завершён. Ниже — полный отчёт по всей `lib/` (552 `.dart`-файла).

---

# 0. Что я прочитал как эталон

- `F:/Niosmess V2/pulse_flutter/lib/core/motion/m3_spring_constants.dart` — `M3Spring` (5 `SpringDescription`), `SpringCurve`, `M3SpringCurves` (8 кривых), `M3Durations` (12 длительностей, строки 148–162).
- `lib/core/motion/nios_motion.dart` — `NiosMotion` + `animateWithSpring` (требует `AnimationController.unbounded`).
- `lib/core/motion/tri_sync.dart`, `lib/widgets/motion/*` (10 блоков + `motion.dart`).

**Ключевой архитектурный факт (влияет на все 11 пунктов):** в приложении почти нет *настоящей* физики. `M3SpringCurves.*` — это `SpringCurve extends Curve` (стр. 50–100), т.е. затухающий осциллятор, **растянутый на фиксированный `Duration`** через `transformInternal`, а не `SpringSimulation`. Реальный `SpringSimulation` вызывается **ровно в одном месте** — `lib/core/motion/nios_dismissible.dart:167` (`NiosMotion.simulate`), и этот виджет используется **один раз**: `lib/screens/media_viewer_screen.dart:265`. `animateWithSpring` (nios_motion.dart:68) не вызывается нигде — 0 ссылок.

Итого: заявленный «motion-physics system» существует, но 99% UI живёт по схеме «duration + spring-подобная кривая», что и есть корень проблемы владельца.

---

# 1. Сводная таблица метрик

| # | Пункт | Количество | Доля на токенах |
|---|---|---|---|
| 1 | `Duration(milliseconds:)` всего | **180** | — |
| 1a | — из них определения токенов | 12 (`m3_spring_constants.dart:148–162`) | — |
| 1b | — таймеры / debounce / сеть / TTL | **35** | — |
| 1c | — **в анимационном контексте** | **≈133** | 80 на `M3Durations` → **37.6 %** |
| 1d | `Duration(seconds:)` всего | **133** | 0 анимационных (все таймауты/таймеры/TTL, кроме 4 display-длительностей тостов и `controlsAutoHideDuration`) |
| 2 | `Curves.*` (Flutter) + `M3SpringCurves.*` | 239 | **206 → 86 %** на токенах |
| 2a | — plain Flutter `Curves.*` (не токены) | **33** (реальных, без док-комментов) | 14 % |
| 2b | — overshoot-кривые (`easeOutBack`/`elastic*`/`bounce*`) | **0** | — |
| 3 | `M3SpringCurves.*` | **206** (−6 алиасов = 200 реальных) | — |
| 3a | `M3Durations.*` | **80** | 9 из 12 токенов используются; `short1`, `extraLong1`, `extraLong2` — **0** |
| 3b | `M3Spring.*` (SpringDescription) | 6 (все в `nios_motion.dart`, из них 5 — алиасы) | реальных потребителей 1 |
| 4 | Неявные анимации | **84** | смешанно (см. §4) |
| 5 | `flutter_animate` | **8 файлов, ~40 цепочек эффектов** | 0 токенов внутри (только `M3SpringCurves` в 3 местах) |
| 6 | `Hero` / пакет `animations` | **10 `Hero` + 1 обёртка `MediaHero`** / `animations` не подключён (0) | — |
| 7 | Тяжёлые эффекты | `BackdropFilter` **1**, `MaskFilter.blur` **0**, `ShaderMask` **1**, `saveLayer` **1**, `Opacity(` **20**, `Clip.antiAlias` **14** | — |
| 8 | `AnimationController(` | **35** | 100 % в `initState`/поле; **0** в `build()`; dispose **35/35** |
| 9 | Учёт `disableAnimations` | **178** упоминаний в **86** файлах; **14 анимационных сайтов без учёта** в 12 файлах | 84 % сайтов |
| 10 | `TriSync` | **10 вызовов в 6 файлах**; `HapticService` — **311**, `appSoundProvider` — **38** | 3 % |
| 11 | `withOpacity` / `CircularProgressIndicator` / `LinearProgressIndicator` / `shrinkWrap: true` | **0 / 0 / 1 (разрешённый) / 10** | — |

---

# 2. Детально по пунктам

## 2.1. Жёстко заданные длительности

Гистограмма всех 180 `Duration(milliseconds: N)` (значение → количество):

```
  16→1   30→2   50→1   60→1   80→3   90→1  100→5  120→2  140→6  150→3  160→4
 180→3  200→16  220→5  240→6  250→15 260→6  280→11 300→25 320→10 350→6  360→1
 380→3  400→7   450→2  500→7  600→4  650→2  700→2  800→2  900→1 1000→5 1200→1
1500→1 1600→1  1800→1 2000→1 4500→1
```

### НЕ анимация (35 сайтов, для чистоты)

- Таймеры/debounce/TTL: `providers/search_provider.dart:109` (300), `providers/inline_query_provider.dart:139` (300), `providers/ui_settings_provider.dart:570` (250), `providers/typing_provider.dart:16` (4500), `providers/upload_queue_provider.dart:101` (80), `providers/websocket_dispatcher_provider.dart:283` (500), `providers/custom_emoji_provider.dart:185` (30), `features/settings/application/settings_anchor_controller.dart:28` (1000), `models/api/upload_models.dart:73,74` (1000/600), `screens/create_post_screen.dart:222` (350), `screens/settings_preferences_screen.dart:44` (400), `screens/main_shell_screen.dart:174,193,225` (400/600/800), `screens/chat_detail_screen.dart:435` (500), `screens/circle_video_recorder_screen.dart:148` (350), `screens/splash_screen.dart:41` (350 min-display), `widgets/chat/chat_message_list.dart:260,429,587` (180/160/1600), `widgets/chat/chat_input_bar.dart:180,195` (140×2), `widgets/chat/inline_keyboard_view.dart:251` (700), `widgets/chat/unicode_emoji_picker_view.dart:67` (100), `widgets/calls/call_devices_dialog.dart:128` (120), `core/utils/voice_recorder_service.dart:51` (100), `core/network/web_socket_client.dart:557` (`60*attempts`), `core/services/desktop_window_service.dart:146` (500), `core/motion/smooth_text_streamer.dart:69` (16-тик), `providers/backend_chat_provider.dart:3331` (500), `services/calls/output_tone_stub.dart:10`, `services/calls/output_tone_web.dart:25` (650), `services/calls/quic_transport.dart:28` (100), `services/bluetooth_mesh/bluetooth_mesh_service.dart:599` (250).

### Анимация — длительности > 500 мс (все — магические)

| файл:строка | значение | назначение |
|---|---|---|
| `widgets/message_bubble.dart:639` | 1500 | `TweenAnimationBuilder<Color?>` подсветка баббла, `Curves.easeOut` |
| `widgets/pulse_skeleton.dart:60` | 1200 | пульс скелетона |
| `widgets/chat/voice_recording_panel.dart:38` | 1000 | пульс записи (`repeat(reverse: true)`) |
| `widgets/chat_tile.dart:780` | 1000 | цикл «печатает…» (`_cycle`, рестарт через status-listener) |
| `screens/calls/incoming_call_overlay.dart:74` | 1800 | пульс входящего звонка |
| `screens/circle_video_recorder_screen.dart:56` | 800 | пульс записи |
| `core/call_design_tokens.dart:47` | 2000 | `rippleAnimationDuration` (не из `M3Durations`) |
| `widgets/color_ripple_overlay.dart:34` | 600 | ripple темы (создаётся в `triggerRipple`) |
| `widgets/post_card.dart:82` | 600 | «сердце» лайка (`TweenSequence`) |
| `core/call_design_tokens.dart:46` | 4 s | `controlsAutoHideDuration` (display) |
| `core/utils/app_toast.dart:138,175,253` | 4 s / 4 s / 3 s | длительность показа тоста |

### Анимация — 200–400 мс (самая массовая зона долга)

`200` (16): `router:105/106` (240 нет — см. ниже), `features/chats/presentation/create_group_members_screen.dart:403`, `screens/chat_detail_screen.dart:3171`, `screens/help_faq_screen.dart:321,347`, `screens/main_shell_screen.dart:599`, `screens/media_viewer_screen.dart:295`, `screens/niosgram_screen.dart:308`, `widgets/chat/add_sticker_dialog.dart:410`, `widgets/chat/chat_filter_bar.dart:286`, `widgets/chat/e2ee_status_card.dart:80`, `widgets/chat/ordinary_e2ee_notice.dart:25`, `widgets/code_preview.dart:20`(240), `widgets/empty_feed_widget.dart:69`, `widgets/app_bottom_nav.dart:208`, `core/utils/smooth_scroll.dart:32`.
`250` (15): `core/modal/app_modal.dart:47`(reverse), `features/chats/presentation/create_group_members_screen.dart:92`, `widgets/chat/bubble/bubble_gestures.dart:44`, `widgets/chat/bubble/media_album_bubble.dart:234,251`, `widgets/chat/chat_list_header.dart:39`, `widgets/nios_mark_badge.dart:40`, `widgets/offline_banner.dart:16`, `widgets/auth/auth_scaffold.dart:285`(200), `screens/login_screen.dart:466`(250), … (полный per-file список — в §2.1-таблице ниже).
`300` (25): доминирует в `router/app_router.dart:74`, `core/modal/app_modal.dart:46`, `core/modal/app_side_sheet.dart:28`, и во всех `flutter_animate`-каскадах `login_screen/splash_screen/onboarding_screen/auth_scaffold`.
`320` (10): `core/call_design_tokens.dart:41`(320), `features/settings/presentation/settings_row.dart:94`, `router/app_router.dart:436`, `widgets/auth/auth_scaffold.dart:218`, `widgets/calls/call_overlay.dart:40`, `widgets/nav/m3_route_tab_switcher.dart:66`, `widgets/quick_camera_capture_screen.dart:43`, `screens/main_shell_screen.dart:603`, `core/illustration/app_illustration.dart:103`, `screens/splash_screen.dart:101`(380).

Полный файловый рейтинг по числу магических `Duration(milliseconds:)`:

```
18 login_screen.dart | 12 m3_spring_constants.dart(tokens) | 10 splash_screen.dart
 8 main_shell_screen.dart | 6 app_router.dart | 6 auth_scaffold.dart | 6 onboarding_screen.dart
 3 main.dart | 3 chat_message_list.dart | 3 expressive_tokens.dart | 3 call_design_tokens.dart | 3 app_modal.dart
 2 × 12 файлов | 1 × 50 файлов
```

Отдельно: `Duration(seconds:)` — **133** вхождения, и **ни одно** не является motion-кривой. UI-смысл имеют только `core/utils/app_toast.dart:138,175,253`, `core/call_design_tokens.dart:46`, `widgets/post_card.dart:167` (5 s) и `screens/circle_video_recorder_screen.dart:67` (лимит записи).

## 2.2. Кривые

| Кривая | Кол-во | Комментарий |
|---|---|---|
| `M3SpringCurves.expressiveDecel` | 62 | в основном fade/opacity — корректно |
| `M3SpringCurves.spatial` | 54 | позиция/размер/скейл — корректно по типу |
| `M3SpringCurves.expressiveStandard` | 23 | цвет/размер |
| `M3SpringCurves.gentle` | 20 | |
| `M3SpringCurves.snappy` | 19 | |
| `M3SpringCurves.expressiveAccel` | 17 | |
| `M3SpringCurves.bouncy` | 10 | **только на scale/spatial**, на opacity не встречается — правило соблюдено |
| `M3SpringCurves.emphasized` | 1 (алиас в `expressive_tokens.dart:256`) | |

**Overshoot-кривые: 0.** Grep `easeOutBack|easeInBack|easeInOutBack|elasticOut|elasticIn|elasticInOut|bounceOut|bounceIn` по `lib/**/*.dart` → **0 совпадений**. Правило «без overshoot на прозрачности» формально не нарушено нигде; риск только у `M3SpringCurves.spatial` (`dampingRatio: 0.75` — формально underdamped, `m3_spring_constants.dart:106-109`), но он применяется только к spatial-свойствам.

Plain Flutter `Curves.*` (33 реальных вхождения):

```
10 Curves.easeOutCubic | 7 Curves.easeOut | 5 Curves.linear | 4 Curves.easeInCubic
 2 Curves.easeInOutCubic | 1 easeIn | 1 easeInOut | 1 easeInOutSine
 1 fastLinearToSlowEaseIn | 1 easeInOutCubicEmphasized | 1 fastOutSlowIn
```

Места:
- `router/app_router.dart:81,86,117,123,124,450,451` — `easeInCubic`/`easeOut`/`easeOutCubic` в page-transition рядом с `M3SpringCurves.expressiveDecel`. **Смешение систем в одном transitionsBuilder.**
- `core/call_design_tokens.dart:53` `Curves.easeInOutCubic` (комментарий «нормализованная кривая для Opacity» — но это не M3E-токен).
- `widgets/chat/m3_shared_axis.dart:48,49` и `widgets/motion/m3_spring_switcher.dart:149,150` — `Curves.linear` осознанно (кривые навешиваются в `transitionBuilder`) — **не дефект**.
- `widgets/app_bottom_nav.dart:408` `Curves.linear` в `animateTo` + `M3SpringCurves.expressiveDecel` в `CurvedAnimation` (стр. 386–390) — двойное сглаживание, фактически линейный `animateTo`.
- `widgets/common/touch_container.dart:180,238` `Curves.easeOutCubic` на **press-in** при `M3SpringCurves` на release — асимметрия.
- `widgets/post_card.dart:99,103,713,1163`, `widgets/vector_illustrations.dart:84,88`, `widgets/pulse_skeleton.dart:66`, `widgets/offline_banner.dart:17`, `widgets/code_preview.dart:21`, `widgets/message_bubble.dart:640`, `widgets/m3_otp_input_field.dart:67`, `widgets/color_ripple_overlay.dart:68`, `screens/legal_viewer_screen.dart:220`, `features/chats/presentation/create_group_members_screen.dart:93`, `core/utils/smooth_scroll.dart:33`, `core/illustration/app_illustration.dart:116`, `core/motion/pulse_predictive_back_transition.dart:201,251`.

## 2.3. Использование токенов

`M3Durations.*` — **80** вхождений:

| токен | значение | кол-во |
|---|---|---|
| `short4` | 200 | 28 |
| `medium2` | 300 | 17 |
| `medium1` | 250 | 13 |
| `short3` | 150 | 12 |
| `medium3` | 350 | 4 |
| `short2` | 100 | 2 |
| `long2` | 500 | 2 |
| `medium4` | 400 | 1 |
| `long1` | 450 | 1 |
| `short1` (50), `extraLong1` (700), `extraLong2` (1000) | — | **0** |

`M3SpringCurves.*` — **206** (−6 «алиасов» в `core/utils/app_curves.dart:8,11,14,17` и `core/theme/expressive_tokens.dart:256,262` → **200** реальных сайтов).

**Доля:** из ≈213 motion-сайтов с явной длительностью 80 на токенах = **37.6 %**; 133 — магические числа. По кривым — 200/233 = **86 %**.

Файлов, вообще ссылающихся на токены: **91 из 552** (16.5 %).

## 2.4. Неявные анимации — 84 сайта

### `AnimatedContainer` (29)

| файл:строка | duration | curve | guard |
|---|---|---|---|
| `features/chats/presentation/create_group_members_screen.dart:402` | 200 | — (default) | **нет** |
| `features/settings/presentation/settings_row.dart:119` | 260 | `expressiveStandard` | **нет** |
| `screens/circle_video_recorder_screen.dart:612` | `short3`/0 | `expressiveDecel` | да |
| `screens/circle_video_recorder_screen.dart:629` | `short3`/0 | (в контексте) | да |
| `screens/main_shell_screen.dart:882` | **150** | — | **нет** |
| `screens/onboarding_screen.dart:272` | `short4`/0 | `spatial` | да |
| `screens/settings_appearance_screen.dart:471` | `medium2`/0 | `snappy` | да |
| `widgets/chat_tile.dart:249` | `short3`/0 (`surfaceDuration`) | `gentle` | да (`:175`) |
| `widgets/code_preview.dart:19` | **240** | **`Curves.easeOutCubic`** | **нет** |
| `widgets/create_chat_wizard_view.dart:463` | **240** | `spatial` | **нет** |
| `widgets/create_chat_wizard_view.dart:1293` | **180** | `spatial` | **нет** |
| `widgets/m3_otp_input_field.dart:313` | `short4`/0 | `expressiveStandard` | да |
| `widgets/media_grid_picker.dart:672` | `short4`/0 | `expressiveStandard` | да |
| `widgets/post_card.dart:1049` | `short4`/0 | `expressiveStandard` | да |
| `widgets/chat/add_sticker_dialog.dart:410` | **160** | — | **нет** |
| `widgets/chat/chat_filter_bar.dart:283` | 200/0 | `gentle` | да (`:261`) |
| `widgets/chat/chat_input_bar.dart:688` | `short4`/0 | `expressiveStandard` | да |
| `widgets/chat/chat_input_bar.dart:1003` | `medium1`/0 | `gentle` | да |
| `widgets/chat/chat_input_bar.dart:1180` | `short4`/0 | `spatial` | да |
| `widgets/chat/desktop_drag_drop_area.dart:55` | `short4` | `expressiveStandard` | **нет** |
| `widgets/chat/voice_recording_panel.dart:80` | 1000 | `expressiveDecel` | да |
| `widgets/chat/voice_recording_panel.dart:180` | `short2`/0 | `expressiveDecel` | да |
| `widgets/common/touch_container.dart:169` | `durationPress`/`Release` | `easeOutCubic`/`spring` | да (`:164`) |
| `widgets/motion/m3_morphing_surface.dart:82` | 260 (default) | `spatial` | да |
| `widgets/profile/profile_shared_media_tab_view.dart:544` | `medium1` | `spatial` | **нет** |
| `widgets/settings/custom_color_picker_sheet.dart:112,133,168` | `medium3`/0 | `expressiveStandard` | да |
| `widgets/settings/pressable_surface.dart:85` | `short4`/0 | `expressiveStandard` | да |

### `AnimatedOpacity` (9)

`main_shell_screen.dart:820` (`short4`, `expressiveDecel`, guard) · `chat_tile.dart:371` (`short3`, **без curve**, guard) · `offline_banner.dart:18` (**200**, без curve, **без guard**) · `post_card.dart:812` (`medium1`, без curve, guard) · `post_card.dart:848` (`short3`, `expressiveDecel`, guard) · `chat/chat_detail_fab.dart:25` (`short4`, guard) · `chat/inbox_compose_button.dart:27` (guard) · `chat/m3_speed_dial_fab.dart:391` (`short4`, `expressiveStandard`, guard) · `media/m3_video_controls.dart:236` (`short3`, `expressiveDecel`, guard).

### `AnimatedSwitcher` (17)

Все, кроме двух, — на `M3Durations` + `expressiveDecel/Accel`. Проблемные:
- `widgets/motion/m3_shared_axis.dart:46` и `m3_spring_switcher.dart:146` — `Curves.linear` осознанно (ок).
- **`widgets/chat/chat_input_bar.dart:1191,1253,1303` — без `switchInCurve/switchOutCurve`, `transitionBuilder` = `ScaleTransition(scale: anim)` → линейный скейл иконки, без curve вообще.**
- `screens/login_screen.dart:556`, `screens/help_faq_screen.dart:331` — `AnimatedCrossFade` **200** мс, `spatial` на обеих ветках, **без guard**.
- `screens/blocked_users_screen.dart:133` — `short3`, guard.
- `screens/main_shell_screen.dart:503` — `medium1` + `expressiveDecel/Accel`, guard.
- `screens/profile_screen.dart:571` — `medium1`/`short3`, guard.
- `screens/settings_about_screen.dart:173` — `medium2`, guard.
- `widgets/chat_tile.dart:729` — `short4`, guard.
- `widgets/create_chat_wizard_view.dart:347` — `medium1`, guard.
- `widgets/voice_message_player.dart:293` — `short3`, guard.
- `widgets/chat/chat_input_bar.dart:727,963` — `medium1`/`short4`, guard.
- `widgets/chat/bubble/bubble_footer.dart:138` — `short3`, guard.
- `widgets/media/m3_video_controls.dart:53` — `short2`, guard.
- `widgets/profile/profile_shared_media_tab_view.dart:398` — `short4`, guard.

### `AnimatedSize` (12)

`create_group_members_screen.dart:91` (**250**, **`Curves.fastOutSlowIn`**, без guard) · `settings_about_screen.dart:169` (`medium2`, `expressiveDecel`) · `offline_banner.dart:15` (**250**, **`easeOutCubic`**, без guard) · `post_card.dart:386` (**260**, `expressiveDecel`, guard) · `chat_input_bar.dart:514,584` (`short4`, `expressiveDecel`, guard) · `chat/chat_overlay_layer.dart:44` (`short4`, guard) · `chat/e2ee_status_card.dart:77` (**250**, `spatial`, guard) · `chat/e2ee_verification_sheet.dart:151` (**280**, `spatial`, guard) · `chat/ordinary_e2ee_notice.dart:21` (**200**, `gentle`, guard) · `profile/working_hours_planner_dialog.dart:323` (`medium2`, `expressiveDecel`) · `settings/ordinary_e2ee_settings.dart:691` (`medium2`, `expressiveStandard`, guard).

### `AnimatedScale` (10)

`niosgram_screen.dart:306` (**200**, `bouncy`, **без guard**, но `scale: 1.0` — **анимация-пустышка, ничего не делает**) · `chat_creation_surfaces.dart:332` (**140**, `spatial`, без guard) · `m3_otp_input_field.dart:309` (`short4`, `snappy`, guard) · `pulse_button.dart:58` (`durationPress`/`Release`, `spatial`, guard) · `chat/chat_detail_fab.dart:30` (`medium1`, `spatial`, guard) · `chat/inline_keyboard_view.dart:252` (`short3`, `gentle`, guard) · `chat/m3_speed_dial_fab.dart:385` (`short4`, `spatial`, guard) · `chat/sticker_picker_view.dart:371` (`short4`, `snappy`, guard) · `common/touch_container.dart:228` (`durationPress`/`Release`, `easeOutCubic`/`spring`, guard) · `settings/pressable_surface.dart:137` (`durationPress`/`Release`, `snappy`/`spatial`, guard).

### Остальные

- `AnimatedPositioned`: 1 — `media_viewer_screen.dart:292`, **200**, `spatial`, guard.
- `AnimatedSlide`: 1 — `chat/inbox_compose_button.dart:23`, `motionDuration`, `gentle`, guard.
- `AnimatedRotation`: 2 — `help_faq_screen.dart:319` (**200**, `spatial`, без guard), `login_screen.dart:544` (**280**, `spatial`, без guard).
- `AnimatedCrossFade`: 2 — см. выше.
- `AnimatedDefaultTextStyle`: 1 — `chat_tile.dart:501`, `short3`, `gentle`, guard.
- `TweenAnimationBuilder`: **10** — `chat/chat_empty_state.dart:129`, `chat/chat_list_header.dart:89`, `chat/interactive_message_card.dart:736,848`, `feed_poll_card.dart:184` (**400**, `spatial`, guard), `message_bubble.dart:565,634` (**1500**, `easeOut`, без guard), `motion/m3_selection_motion.dart:26` (`short4`, `snappy`, guard), `profile/ai_usage_card.dart:103`, `settings/system_resource_meter.dart:62`.
- `AnimatedAlign`, `AnimatedPadding`, `AnimatedList`: **0**.
- `AnimatedTheme`: 1 — `settings_appearance_screen.dart:104` (`long2`, `expressiveStandard`, guard) + глобальный `main.dart:372-380` (**500**, `expressiveStandard`, guard через `accessibilityFeatures.disableAnimations`).

## 2.5. `flutter_animate`

Подключён в **8 файлах**. Всего цепочек `.animate(` ≈ 40 (остальные 30 из 70 вхождений `.animate(` — это `Tween.animate(...)`, не пакет).

| файл:строка | цепочка | параметры | guard |
|---|---|---|---|
| `screens/login_screen.dart:390` | `.scale(begin 0.85)` | **380**, `spatial` | да |
| `:397,412` | `.fade` | **300** | да |
| `:426,475,491,597` | `.fade(delay)` | **80/120/160/200/240** + **300** | да |
| `:466` | `.fade` | **250** | да |
| `:931` | `.scale` | (300) | да |
| `:934,936` | `.fade` | **300** / **250** | да |
| `screens/splash_screen.dart:97` | `.scale(0.82)` | **380**, `spatial` | да |
| `:104` | `.fade` | **300** | да |
| `:113` | `.fade(delay 80)` | **280** | да |
| `:125` | `.fade(delay 140)` | **280** | да |
| `:187` | `.fade` | **250** | да |
| `:192` | `.fade(delay 500)` | **300** | да |
| `screens/onboarding_screen.dart:173` | `.scale(0.85)` | **400**, `spatial` | да |
| `:180` | `.fade` | **300** | да |
| `:215` | `.fade(delay 150)` | **300** | да |
| `widgets/auth/auth_scaffold.dart:214` | `.scale` | **360**, `spatial` | да |
| `:221` | `.fadeIn` | **280** | да |
| `:234,244,285` | `.fadeIn`/`.fade` | **300/300/200** | да |
| `widgets/empty_feed_widget.dart:59` | `.scale(0.92)` | **250**, `expressiveDecel` | да |
| `:69` | `.fade` | **200** | да |
| `widgets/m3_responsive_auth_layout.dart:109` | `.scale` | — | да |
| `:168` | `.fade(duration: 400.ms)` | **400** | да |
| `widgets/vector_illustrations.dart:79` | `.scaleXY(0.94)` | **320**, **`Curves.easeOutCubic`** | **НЕТ** |
| `:86` | `.fadeIn` | **260**, **`Curves.easeOut`** | **НЕТ** |
| `widgets/profile/profile_shared_media_tab_view.dart:1139` | `.animate().fade(250.ms)` | **250** | **НЕТ** |

**Дублирование с `lib/widgets/motion/`:** `flutter_animate`-каскады полностью дублируют `M3Reveal`/`M3SpringSwitcher` (`fadeScale`-паттерн) — при этом сам `M3Reveal` используется всего 2 раза, а `M3SpringSwitcher` — 1 раз (см. §2.12).

**Вывод по п.5:** ни одна из 40 цепочек не использует ни `M3Durations`, ни `M3Spring-curve` (кроме трёх исключений), т.е. `flutter_animate` — второй, параллельный motion-стек на голых числах.

## 2.6. Пакет `animations` / `Hero`

- Пакет `animations` **не подключён**; `OpenContainer`/`SharedAxisTransition`/`FadeThroughTransition`/`PageTransitionSwitcher` — **0** вхождений.
- Свои аналоги: `M3SharedAxis` (`widgets/motion/m3_shared_axis.dart`) — **0 использований**; `M3RouteTabSwitcher` (`widgets/nav/m3_route_tab_switcher.dart`) — используется в `main_shell_screen.dart:593`.
- `Hero` — **10 вызовов**:
  `screens/group_profile_screen.dart:193`, `screens/login_screen.dart:386`, `screens/onboarding_screen.dart:169`, `screens/splash_screen.dart:96`, `widgets/post_card.dart:806,970`, `widgets/profile_header_delegate.dart:100`, `widgets/chat/chat_detail_app_bar.dart:128` (+`HeroMode` :126), `widgets/chat/m3_speed_dial_fab.dart:400`.
  Только `MediaHero` (`widgets/media/media_hero.dart:15`) проверяет `MediaQuery.disableAnimations`. Остальные 8 `Hero` полагаются на системное поведение Navigator → **несогласованность с reduce-motion**.
- `PageRouteBuilder` вручную: `widgets/post_card.dart:706-710` (`_openFullScreen`, без кастомных duration/curve — default 300 мс).

## 2.7. Производительность

| Место | Что | Контекст | Оценка |
|---|---|---|---|
| `widgets/adaptive/adaptive_glass.dart:79-82` | `BackdropFilter` + `ImageFilter.blur` | **единственный** в `lib/`; гейтится `tier==A && isStaticPanel && !inScrollable && !Windows`, sigma ≤ 10 | **ОК** — правило соблюдено |
| `widgets/chat/chat_filter_bar.dart:159-168` | `ShaderMask` (`BlendMode.dstIn`) | горизонтальный скролл-бар фильтров — **в скроллабельном виджете**, но шейдер статичен (не пер-кадровый) | minor |
| `widgets/chat/chat_filter_bar.dart:157` | `ClipRRect` вокруг скролла | — | minor |
| `widgets/wallpaper/chat_wallpaper_painter.dart:519` | `canvas.saveLayer` | кастомный painter обоев (не в списке) | minor |
| `widgets/motion/m3_route_tab_switcher` — `nav/m3_route_tab_switcher.dart:210-211` | `RepaintBoundary` → `Opacity` вокруг **всей страницы таба** | самый большой `Opacity`-поддерево в приложении | **major** |
| `widgets/chat_tile.dart:298` | `Opacity(0.9)` на аватаре | **строчный тайл списка**, значение константное | minor |
| `widgets/chat_tile.dart:832` | `Opacity` ×3 (точки «печатает») | **строчный тайл**, анимируется каждые 1/60 с в каждом видимом тайле | **major** |
| `workers` `chat_detail_screen.dart:3199` | `Opacity` на каждом входящем баббле | **в списке сообщений** (только на входе, но всё равно saveLayer) | major |
| `widgets/post_card.dart:680` | `Opacity` на «сердце» | **элемент фида** (100×100 иконка) | minor |
| `screens/calls/active_video_call_screen.dart:258,467` | `Opacity` | видео-оверлеи (большие поддеревья) | minor |
| `screens/calls/incoming_call_overlay.dart:438`, `widgets/app_bottom_nav.dart:441,449`, `widgets/chat/m3_speed_dial_fab.dart:272`, `widgets/m3_otp_input_field.dart:189`, `widgets/profile_header_delegate.dart:43`, `widgets/chat/chat_empty_state.dart:136`, `widgets/motion/m3_morphing_icon.dart:134,147`, `widgets/motion/m3_staggered_list.dart:117`, `widgets/settings/settings_profile_header.dart:172,246,271` | `Opacity` | локальные, мелкие | ок |
| `core/modal/m3_modal_surface.dart:114`, `screens/group_profile_screen.dart:175`, `screens/native_file_viewer_screen.dart:740`, `screens/sticker_set_screen.dart:225,380`, `screens/calls/outgoing_call_screen.dart:369`, `widgets/feed_poll_card.dart:160`, `widgets/media_grid_picker.dart:592`, `widgets/message_bubble.dart:1481`, `widgets/chat/add_sticker_dialog.dart:561`, `widgets/chat/create_sticker_set_dialog.dart:291`, `widgets/chat/inline_query_overlay.dart:47`, `widgets/chat/sticker_set_details_sheet.dart:285` | `Clip.antiAlias` (13 реальных) | — | 1 критичный: `widgets/message_bubble.dart:1481` — **единственный `Clip.antiAlias` в баббле списка сообщений** |
| `widgets/common/touch_container.dart:75` | док-комментарий «defaults to `Clip.antiAlias`» | фактический дефолт — `Clip.none` (`:26`) | **дефект документации** |

`MaskFilter.blur` — **0**. `Clip.antiAliasWithSaveLayer` — **0**. `saveLayer` — 1 (паинтер обоев).

## 2.8. `AnimationController` — 35 штук, все проверены

| файл:строка | создан в | duration | dispose | repeat | замечания |
|---|---|---|---|---|---|
| `core/illustration/app_illustration.dart:101` | `initState` | **320** магия | `:125` ✔ | — | `Curves.easeOut` на fade (`:116`) |
| `screens/chat_detail_screen.dart:3169` | **`initState`** (не build!) | **200** магия | `:3187` ✔ | — | в `build()` — только `AnimatedBuilder` (`:3196`) ✔ |
| `screens/circle_video_recorder_screen.dart:54` | `initState` | **800** магия | `:296` ✔ | `:102` guarded (`_isRecording && _motionAllowed`, stop при выкл.) ✔ | |
| `…:65` | `initState` | `_kMaxRecordSeconds` | `:297` ✔ | — | |
| `…:70` | `initState` | — | `:298` ✔ | — | |
| `…:79` | `initState` | — | `:299` ✔ | — | |
| `screens/calls/active_video_call_screen.dart:54` | `initState` | `CallTokens.controlsFadeDuration` (**220**) | `:104` ✔ | — | `Curves.easeInOutCubic` (`call_design_tokens.dart:53`) |
| `screens/calls/active_voice_call_screen.dart:39` | `initState` | `CallTokens.rippleAnimationDuration` (**2000**) | `:98` ✔ | `:52` guarded ✔ | |
| `screens/calls/incoming_call_overlay.dart:56` | `initState` | **320** магия | `:185` ✔ | — | |
| `…:72` | `initState` | **1800** магия | `:186` ✔ | `:117` guarded (`_reducedMotion`, `_tickerEnabled`) ✔ | |
| `widgets/app_bottom_nav.dart:55` | `initState` | `widget.duration` (220) | `:102` ✔ | — | |
| `widgets/app_bottom_nav.dart:381` | `initState` | `widget.duration` | `:419` ✔ | — | `animateTo(..., curve: Curves.linear)` (`:405-409`) |
| `widgets/chat_tile.dart:783` | `late final` поле + `..addStatusListener` | **1000** магия | `:815` ✔ | **не `repeat()`**, а рестарт в `_onStatus` (`:791-795`) — guarded ✔ | обход правила, но безопасный |
| `widgets/circular_theme_reveal.dart:43` | `initState` | **450** магия | `:62` ✔ | — | guard `:74` ✔, `RepaintBoundary` ✔ |
| `widgets/color_ripple_overlay.dart:32` | **обычный метод** `triggerRipple` (`:24`) | **600** магия | `:52` ✔ (+пересоздание с dispose `:31`) | — | **без reduce-motion guard**; `Curves.fastLinearToSlowEaseIn` (`:68`) |
| `widgets/m3_otp_input_field.dart:52` | `initState` | **400** магия | `:129` ✔ | — | **shake запускается без проверки `disableAnimations`** (`:74`, `:87`) |
| `widgets/nios_mark_badge.dart:38` | `initState` | **250** магия | `:49` ✔ | — (проверить `_pulseController` — конечный forward) | `Curves.easeOutCubic` (`:43`) |
| `widgets/post_card.dart:80` | `initState` | **600** магия | `:119` ✔ | — | `TweenSequence` + `Curves.easeOut`/`easeIn` (`:99,103`) |
| `widgets/post_card.dart:1154` | `initState` | `medium1` ✔ | `:1188` ✔ | — | `easeOutCubic` + `snappy` (`:1163,1170`) |
| `widgets/pulse_skeleton.dart:58` | `late final` | **1200** магия | `:94` ✔ | — | guard `:83` ✔ |
| `widgets/quick_camera_capture_screen.dart:41` | `initState` | **320** магия | `:143` ✔ | — | |
| `widgets/about/morphing_brand_mark.dart:116` | `late final` | — | `:150` ✔ | — | `M3SpringCurves.bouncy` (`:122`) |
| `widgets/calls/call_overlay.dart:38` | `initState` | **320** магия | `:51` ✔ | — | **`addListener(() => setState(...))` пер-кадрово (`:41-45`) вместо `AnimatedBuilder` — дефект** |
| `widgets/chat/m3_speed_dial_fab.dart:50` | `initState` | `medium2`/`short4` ✔ | `:88` ✔ | — | `bouncy` на expand, `expressiveDecel` на fade ✔ |
| `widgets/chat/noto_message_emoji.dart:139` | `initState` | **нет duration** (ведёт Lottie) | `:318` ✔ | — | |
| `…:140` | `initState` | `medium1` ✔ | `:319` ✔ | — | |
| `widgets/chat/voice_recording_panel.dart:36` | `initState` | **1000** магия | `:64` ✔ | `:55` guarded ✔ | |
| `widgets/chat/bubble/bubble_gestures.dart:42` | `initState` | **250** магия | `:56` ✔ | — | `addListener` → ValueNotifier ✔ |
| `widgets/motion/m3_animated_badge.dart:73` | `initState` | 320 (default) | `:107` ✔ | — | `bouncy` на scale ✔ |
| `widgets/motion/m3_morphing_icon.dart:55` | `initState` | 260 | `:102` ✔ | — | |
| `widgets/motion/m3_pressable.dart:70` | `initState` | 140 | `:109` ✔ | — | **компонент не используется ни разу** |
| `widgets/motion/m3_reaction_burst.dart:52` | `initState` | 400 | `:84` ✔ | — | без guard, но **не используется** |
| `widgets/motion/m3_reveal.dart:63` | `initState` | 280 | `:123` ✔ | — | guard `:88-95` ✔ |
| `widgets/motion/m3_staggered_list.dart:61` | `initState` (nullable) | 280 + delay 30 | `:98` ✔ | — | **не используется** |
| `widgets/nav/m3_route_tab_switcher.dart:78` | `initState` (`value: 1`) | через `animateTo` | `:188` ✔ | — | guard `:63-64,112` ✔ |

**Итог п.8:** ни один контроллер не создаётся в `build()` (в т.ч. подозреваемый `chat_detail_screen.dart:3169` — это `initState`). Dispose — 35/35. `repeat()` — 4 вызова, **все** с `stop()`/сбросом при `disableAnimations`/`TickerMode`. **Единственный дефект по критерию `addListener`+`setState`** — `widgets/calls/call_overlay.dart:41`.

## 2.9. Доступность (reduce motion)

- `disableAnimations*` — **178** вхождений в **86** файлах.
- `MediaQuery.accessibleNavigation` — **0**; `timeDilation` — **0**; собственный «motion scale» — **0**. Учитывается только `disableAnimations` (бинарно, без градаций интенсивности).
- **14 анимационных сайтов без учёта** (файлы без единого `disableAnimations`):

| файл | сайты |
|---|---|
| `features/chats/presentation/create_group_members_screen.dart` | `:91` AnimatedSize, `:402` AnimatedContainer |
| `screens/help_faq_screen.dart` | `:319` AnimatedRotation, `:347` AnimatedCrossFade |
| `widgets/offline_banner.dart` | `:15` AnimatedSize, `:18` AnimatedOpacity |
| `widgets/color_ripple_overlay.dart` | `:32` контроллер 600 мс |
| `widgets/motion/m3_reaction_burst.dart` | `:52` (мёртвый код) |
| `widgets/chat/desktop_drag_drop_area.dart` | `:55` AnimatedContainer |
| `widgets/chat/add_sticker_dialog.dart` | `:410` AnimatedContainer 160 |
| `screens/chat_detail_screen.dart` | `:3169` контроллер 200 (в файле **есть** guards в других местах, но не для входа сообщения) |
| `widgets/code_preview.dart` | `:19` AnimatedContainer 240 |
| `widgets/chat_creation_surfaces.dart` | `:332` AnimatedScale 140 |
| `core/illustration/app_illustration.dart` | ложное срабатывание: guard через `motionPolicy.shouldAnimate` (`illustration_motion_policy.dart:8-15`) ✔ |

Плюс точечные: `widgets/m3_otp_input_field.dart:74,87` (shake игнорирует reduce-motion при наличии 4 guards в файле), `widgets/vector_illustrations.dart:79`, `widgets/profile/profile_shared_media_tab_view.dart:1139`, `screens/main_shell_screen.dart:883`, `screens/niosgram_screen.dart:306`, `widgets/message_bubble.dart:639`, `widgets/chat_tile.dart:298` (hover-переход строки).

## 2.10. Синхронизация: haptics + звук + моушн

- `TriSync` — **10 вызовов в 6 файлах**: `core/modal/app_modal.dart:102,104`; `core/motion/nios_dismissible.dart:129,161`; `widgets/message_bubble.dart:428,593,698,1558`; `widgets/message_context_menu_sheet.dart:515,540`; `widgets/nios_mark_badge.dart:56,132,150`.
- `HapticService.*` — **311** вызовов (по файлам), `appSoundProvider`/`soundServiceProvider` — **38**.
- Прямые пары «анимация + haptic» без `TriSync`:
  - `widgets/motion/m3_pressable.dart:116` `HapticService.tap()` перед `_controller.forward()` — но **компонент не используется**.
  - `widgets/common/touch_container.dart:119,135,213` — `tap`/`confirm` вокруг `AnimatedScale` (самый массовый путь: все тайлы и кнопки).
  - `widgets/pulse_button.dart:71` `HapticService.tap()` + `AnimatedScale` (`:58`).
  - `widgets/settings/pressable_surface.dart:72-75` — звук + haptic (`playUiTick` + `HapticService.tap`), без `TriSync`.
  - `widgets/m3_otp_input_field.dart:86-87` — `HapticService.destructive()` + shake (единственный «правильный» пример синхронизации), но `:74` — shake без haptic.
  - `widgets/chat/m3_speed_dial_fab.dart:58` (`bouncy`) — haptic не смотрят в контекст анимации.
  - `widgets/circular_theme_reveal.dart:111` `HapticService.lightImpact()` + контроллер (`:122`) ✔.
- **Вывод:** `TriSync` охватывает ~3 % интеракций (10 из ~320); остальные — «голые» haptics, звук подключается отдельно и не синхронизирован с фазой анимации (нет ни одного keyframe-хука «в момент завершения/порога»). 45-мс throttle из `tri_sync.dart:40` фактически применяется только к 6 файлам.

## 2.11. Прямо запрещённое

| Правило | Нарушения |
|---|---|
| `withOpacity(` | **0** ✔ (`withValues(` — 622) |
| `CircularProgressIndicator` | **0** ✔ |
| `LinearProgressIndicator` вне `pulse_loading_indicator.dart` | **0** ✔ (единственный — `widgets/pulse_loading_indicator.dart:37`, разрешён для детерминированного прогресса) |
| `shrinkWrap: true` | **10** — `features/chats/presentation/create_group_details_screen.dart:235`, `features/wallpaper/presentation/widgets/tabs/presets_tab.dart:58`, `screens/chat_members_screen.dart:123`, `screens/onboarding_screen.dart:798`, `widgets/create_chat_wizard_view.dart:917,1035`, `widgets/media_grid_picker.dart:579`, `widgets/chat/interactive_composer.dart:337`, `widgets/chat/interactive_message_card.dart:141,251` |

Я не смог подтвердить/опровергнуть «вложенность в скролл без ограничения высоты» для всех 10 без чтения каждого родителя — проверены `interactive_message_card.dart:141,251` и `interactive_composer.dart:337` (внутри `Column` с bounded-контейнером, не скролл) → толерантно; остальные 7 требуют отдельного ревью.

## 2.12. Бонус: готовые блоки `lib/widgets/motion/` почти не используются

| блок | использований |
|---|---|
| `M3Pressable` | **0** |
| `M3SharedAxis` | **0** |
| `M3MorphingIcon` | **0** |
| `M3MorphingSurface` | **0** |
| `M3AnimatedBadge` | **0** |
| `M3ReactionBurst` | **0** |
| `M3StaggeredItem` | **0** |
| `M3Reveal` | 2 (`screens/settings_plus_screen.dart:264`, `screens/settings_preferences_screen.dart:99`) |
| `M3SpringSwitcher` | 1 (`screens/settings_energy_saving_screen.dart:122`) |
| `M3SelectionMotion` | 2 (`features/chats/presentation/inbox_search_screen.dart:266`, `screens/settings_chats_screen.dart:69`) |

Импортов `widgets/motion/...` — **5** (в 5 файлах). `M3SelectionMotion` **не экспортируется** из `motion.dart` (файл 1–10) — приходится импортировать напрямую.

---

# 3. Нарушения правил проекта

| # | файл:строка | Правило | Серьёзность | Исправление |
|---|---|---|---|---|
| 1 | `lib/router/app_router.dart:74-92,105-131,436-459` | «токены вместо магии»: 6 хардкод-duration + 7 plain `Curves` рядом с токенами | **critical** | Переписать page-transitions на 6 M3E-токенов: `transitionDuration` из spatial-token, `reverseCurve` → `M3SpringCurves.expressiveAccel` (сейчас `Curves.easeInCubic`) |
| 2 | `lib/core/motion/m3_spring_constants.dart:104-144` | «единая система M3E-токенов» — фактические stiffness 24/32/36/52/58 и zeta .55–.90 **не совпадают** ни с одним M3E-токеном (800/.6, 380/.8, 200/.8, 3800/1, 1600/1, 800/1) | **critical** | Добавить 6 токенов `spatialFast/Default/Slow`, `effectsFast/Default/Slow` как `SpringDescription` + `Curve`-обёртки; старые 5 объявить legacy |
| 3 | `lib/core/motion/nios_motion.dart:68` | физика не используется: `animateWithSpring` — **0** вызовов, `SpringSimulation` — 1 место (`nios_dismissible.dart:167`) | **critical** | Каждый `AnimationController` с `duration:` перевести на `AnimationController.unbounded` + `animateWithSpring` |
| 4 | `lib/widgets/chat/chat_input_bar.dart:1191,1253,1303` | «использовать готовые блоки / curve обязателен»: `ScaleTransition` на сырой линейной анимации | major | → `M3SpringSwitcher(type: fadeScale)` |
| 5 | `lib/widgets/calls/call_overlay.dart:41-45` | «`addListener`+`setState` вместо `AnimatedBuilder`» (пер-кадровый `setState`) | **critical** | `AnimatedBuilder(animation: _snapController)` |
| 6 | `lib/widgets/motion/*` (10 файлов, 0–2 использования) | «использовать блоки из `lib/widgets/motion/`» | major | Либо внедрять (замена 84 Animated* на M3-блоки), либо удалить мёртвый код (`M3StaggeredItem`, `M3Pressable`, `M3ReactionBurst`) |
| 7 | `lib/widgets/vector_illustrations.dart:79-89` | «уважение reduce motion» | major | `.animate(value: disableAnimations ? 1 : null, autoPlay: !disableAnimations)` + `M3SpringCurves` вместо `Curves.easeOutCubic` |
| 8 | `lib/widgets/profile/profile_shared_media_tab_view.dart:1139` | то же | major | idem |
| 9 | `lib/widgets/m3_otp_input_field.dart:74,87` | то же (shake при `hasError` без проверки) | major | `if (!MediaQuery.disableAnimationsOf(context)) _shakeController.forward(from: 0)` |
| 10 | `lib/widgets/offline_banner.dart:15,18`; `lib/features/chats/presentation/create_group_members_screen.dart:91,402`; `lib/screens/help_faq_screen.dart:319,347`; `lib/widgets/code_preview.dart:19`; `lib/widgets/chat/add_sticker_dialog.dart:410`; `lib/widgets/chat/desktop_drag_drop_area.dart:55`; `lib/widgets/chat_creation_surfaces.dart:332` | то же + магия (`fastOutSlowIn`, `easeOutCubic`, 160/200/240) | major | duration+curve → токены + guard |
| 11 | `lib/widgets/message_bubble.dart:1481` | `Clip.antiAlias` в баббле списка сообщений | major | `Clip.none` + `foregroundDecoration`/`ShapeDecoration` |
| 12 | `lib/widgets/chat/chat_tile.dart:832` | `Opacity` в повторяющемся тайле (3 на тайл, анимируется) | major | `FadeTransition` внутри `RepaintBoundary`, или `CustomPaint` с alpha |
| 13 | `lib/nav/m3_route_tab_switcher.dart:211` | `Opacity` вокруг всей страницы таба | major | `FadeTransition` (нет saveLayer) или перенести alpha в `ColorFiltered`/`shader` |
| 14 | `lib/screens/chat_detail_screen.dart:3199` | `Opacity` на каждом баббле в списке (entrance) | major | `FadeTransition` (тип `Animation<double>` уже есть) |
| 15 | `lib/widgets/post_card.dart:99,103,1163`; `lib/widgets/chat/bubble/bubble_gestures.dart:44`; `lib/widgets/app_bottom_nav.dart:405-409`; `lib/widgets/common/touch_container.dart:180,238`; `lib/core/call_design_tokens.dart:53` | plain `Curves`/`linear` в моушн-контексте | minor | → `M3SpringCurves.*` |
| 16 | `lib/widgets/app_bottom_nav.dart:208` (`tier.isTierC ? 200 : 280`), `lib/screens/main_shell_screen.dart:598-604` (200/300/320/300 по tier) | магические числа, зависящие от tier — 4 значения вместо одного токена | major | один spatial-токен + `Duration.zero` для Tier C |
| 17 | `lib/core/call_design_tokens.dart:41-47` | собственные 220/280/2000 мимо `M3Durations` | minor | `M3Durations.short4/medium2` + новый `ambientLoop` |
| 18 | `lib/core/theme/expressive_tokens.dart:268,271,274` | `pressTimeout` 90 / `durationPress` 140 / `durationRelease` 240 — второй параллельный motion-словарь | major | Свести в `M3Durations`/`M3SpringCurves` (90 ≈ short2, 140 ≈ short3, 240 ≈ medium1) |
| 19 | `lib/core/utils/app_curves.dart:19-25` | 4 собственных `Cubic` (`easeOutSnap`, `easeOutSmooth`, `easeInSmooth`, `entrance`) | minor | Удалить, если `AppCurves.` используется 1 раз (см. ниже) |
| 20 | `lib/screens/niosgram_screen.dart:306` | `AnimatedScale(scale: 1.0)` — анимация-пустышка + `bouncy` + нет guard | minor | Удалить или задать реальный `scale` |
| 21 | `lib/widgets/common/touch_container.dart:75` | док-комментарий противоречит коду (`Clip.antiAlias` vs `Clip.none` `:26`) | minor | Поправить доку |
| 22 | `lib/widgets/settings/pressable_surface.dart:143-147` | `Duration(milliseconds: X.inMilliseconds)` — бессмысленная реконструкция | minor | Передавать `AppMotion.durationPress` напрямую |
| 23 | `lib/widgets/common/touch_container.dart:91` (`boxShadow`) | «запрещены drop-shadow; глубина — тональными поверхностями» — API позволяет | minor | Удалить поле или задепрекейтить |
| 24 | `lib/widgets/motion/motion.dart:1-10` | `M3SelectionMotion` не экспортируется | minor | Добавить export |
| 25 | `lib/core/motion/nios_motion.dart:25` / `m3_spring_constants.dart:124` | `bouncy` разрешён на scale, но в `M3SpringCurves` zeta 0.55 → overshoot 1.3+ на `SizeTransition` (`m3_reveal.dart` использует `spatial`, ок) — документированный риск | minor | Добавить assert/док-запрет на opacity |
| 26 | Hero ×8 (`screens/group_profile_screen.dart:193`, `login_screen.dart:386`, `onboarding_screen.dart:169`, `splash_screen.dart:96`, `post_card.dart:806,970`, `profile_header_delegate.dart:100`, `chat_detail_app_bar.dart:128`) | нет проверки `disableAnimations` (в отличие от `MediaHero`) | minor | Обернуть в `MediaHero`-подобный helper |

---

# 4. Рейтинг 15 файлов по моушн-долгу

Скоринг: `2×(магические duration) + 2×(plain Curves) − (ссылки на токены)` + вес нарушений.

| # | файл | магия | plain Curves | токены | Долг |
|---|---|---|---|---|---|
| 1 | `lib/screens/login_screen.dart` | **18** | 0 | 4 | **32** — 40+ `flutter_animate`-цепочек на 250/280/300/380 + hero; ни одного `M3Durations` |
| 2 | `lib/core/motion/m3_spring_constants.dart` | 12 (дефиниции) | 0 | 0 | сам токен-слой не соответствует M3E physics |
| 3 | `lib/router/app_router.dart` | 6 | 7 | 4 | 22 — page-transitions на duration+easing |
| 4 | `lib/screens/splash_screen.dart` | **10** (9 motion) | 0 | 1 | 19 |
| 5 | `lib/screens/main_shell_screen.dart` | 8 (5 motion) | 0 | 5 | 11 + tier-магия (200/300/320/300) |
| 6 | `lib/widgets/auth/auth_scaffold.dart` | 6 | 0 | 1 | 11 |
| 7 | `lib/widgets/vector_illustrations.dart` | 2 (320, 260) | 2 (`easeOutCubic`, `easeOut`) | 0 | 8 + **нет reduce-motion** |
| 8 | `lib/features/chats/presentation/create_group_members_screen.dart` | 2 (250, 200) | 1 (`fastOutSlowIn`) | 0 | 6 + нет guard |
| 9 | `lib/widgets/offline_banner.dart` | 2 (250, 200) | 1 (`easeOutCubic`) | 0 | 6 + нет guard |
| 10 | `lib/screens/onboarding_screen.dart` | 6 | 0 | 7 | 5 (магия в `flutter_animate` 350/400/300 + delays 150) |
| 11 | `lib/core/call_design_tokens.dart` | 3 (220/280/2000) | 1 (`easeInOutCubic`) | 4 | 4 — параллельный токен-слой |
| 12 | `lib/widgets/chat/chat_input_bar.dart` | 2 (140×2) | 0 | 9 | 3 `AnimatedSwitcher` с линейным `ScaleTransition` + 10 anim-сайтов |
| 13 | `lib/widgets/post_card.dart` | 2 (600, 260) | 4 | 9 | `TweenSequence` + 1500-мс сосед + `Opacity` в фиде |
| 14 | `lib/widgets/message_bubble.dart` | 1 (1500) | 1 (`easeOut`) | 2 | `Clip.antiAlias` в списке + 2 `TweenAnimationBuilder` |
| 15 | `lib/widgets/chat_tile.dart` | 1 (1000) | 0 | 4 | 2 `Opacity` + `AnimatedContainer` + `AnimatedDefaultTextStyle` **на каждый тайл списка** |

Почти-в-топе: `lib/core/theme/expressive_tokens.dart` (3 magia, второй motion-словарь), `lib/widgets/settings/pressable_surface.dart`, `lib/widgets/common/touch_container.dart`, `lib/widgets/code_preview.dart`, `lib/screens/help_faq_screen.dart`.

---

# 5. Таблица миграции

Эталонные токены, которых сейчас **нет** в коде (нужно добавить в `m3_spring_constants.dart`):

```
spatialFast    stiffness 800,  ζ 0.60  → damping ≈ 33.9
spatialDefault stiffness 380,  ζ 0.80  → damping ≈ 31.2
spatialSlow    stiffness 200,  ζ 0.80  → damping ≈ 22.6
effectsFast    stiffness 3800, ζ 1.00  → damping ≈ 123.3
effectsDefault stiffness 1600, ζ 1.00  → damping ≈ 80.0
effectsSlow    stiffness 800,  ζ 1.00  → damping ≈ 56.6
```

| Сейчас (duration + curve) | Где | Заменить на |
|---|---|---|
| `200 ms` + `Curves.easeOutCubic` / без curve (hover, color, border) | `chat_tile.dart:249` (region), `post_card.dart:1049`, `chat_input_bar.dart:688`, `settings/pressable_surface.dart:85`, `common/touch_container.dart:169` | **spatialFast** (800/0.6) для размера/формы; **effectsFast** (3800/1.0) если только цвет/opacity |
| `140–200 ms` + `M3SpringCurves.spatial` (press-down / press-release scale) | `motion/m3_pressable.dart:19`, `pulse_button.dart:58`, `touch_container.dart:228`, `pressable_surface.dart:137`, `chat_creation_surfaces.dart:332` | **spatialFast** (800/0.6), press-in/out — один и тот же спринг, без смены curve |
| `250–300 ms` + `M3SpringCurves.gentle` / `easeOutCubic` (expand/collapse, AnimatedSize) | `create_group_members_screen.dart:91`, `offline_banner.dart:15`, `chat/e2ee_status_card.dart:77`, `chat/e2ee_verification_sheet.dart:151`, `chat/ordinary_e2ee_notice.dart:21` | **spatialDefault** (380/0.8) |
| `280–320 ms` + `M3SpringCurves.spatial` / `expressiveDecel` (route, modal, tab) | `app_router.dart:74,105,436`, `app_modal.dart:46`, `app_side_sheet.dart:28`, `main_shell/*:599-604`, `nav/m3_route_tab_switcher.dart:66` | **spatialSlow** (200/0.8) для позиции; **effectsDefault** (1600/1.0) для fade-слоя |
| `240–400 ms` + `M3SpringCurves.expressiveStandard` (цвет поверхности, тема) | `settings_row.dart:119`, `settings_appearance_screen.dart:471`, `AnimatedTheme main.dart:372` / `settings_appearance_screen.dart:104` | **effectsDefault** (1600/1.0), для `AnimatedTheme` — **effectsSlow** (800/1.0) |
| `200–300 ms` + `flutter_animate .fade/.fadeIn` | `login_screen`, `splash_screen`, `onboarding_screen`, `auth_scaffold`, `empty_feed_widget`, `vector_illustrations` | **effectsDefault** (1600/1.0); каскад — единый **stagger-token** (30 мс как в `m3_staggered_list.dart:17`, но вынести в `M3Durations`) |
| `250–400 ms` + `flutter_animate .scale` | idem | **spatialDefault** (380/0.8), overshoot — только если нужен экспрессивный вход (**spatialFast**) |
| `600 ms` + `TweenSequence` + `Curves.easeOut` (like-сердце) | `post_card.dart:80-105` | **spatialFast** (800/0.6, ζ 0.6 → естественный overshoot 1.15) — `TweenSequence` не нужен |
| `1000–1200 ms` бесконечный пульс | `pulse_skeleton.dart:58-60`, `chat_tile.dart:780`, `voice_recording_panel.dart:38` | **effectsSlow** (800/1.0) + цикл через `AnimationController.repeat(reverse: true)` под `TickerMode` |
| `1800–2000 ms` ambient-пульс (звонок, ripple темы) | `incoming_call_overlay.dart:74`, `active_voice_call_screen.dart:41`, `call_design_tokens.dart:47` | Выделить **`M3Durations.ambientLoop = 2000 ms`** в токенах + **effectsSlow**; сейчас — 4 разных числа |
| `1500 ms` + `Curves.easeOut` (подсветка сообщения) | `message_bubble.dart:634-640` | **effectsSlow** (800/1.0) — цвет не должен жить дольше 800 мс |
| `450–500 ms` + линейный `ColorTween`/`themeAnimation` | `circular_theme_reveal.dart:45` | **spatialSlow** (200/0.8) + `M3Durations.long2` |
| `Curves.linear` + `animateTo` (двойное сглаживание) | `app_bottom_nav.dart:405-409` | Убрать внешний `CurvedAnimation`, оставить **effectsDefault** один раз |
| `M3SpringCurves.expressiveDecel` на Opacity | корректно (62 сайта) | Оставить как есть — единственное, что уже соответствует M3E-effects (нормализованная кривая без overshoot) |

---

# 6. Что я НЕ проверил (честно)

1. Все 10 `shrinkWrap: true` — проверил только 3 (`interactive_message_card.dart:141,251`, `interactive_composer.dart:337`); остальные 7 требуют чтения родительских скроллов.
2. Не измерял runtime-FPS/jank — все выводы §2.7 статические (по типу виджета и контексту), а не по профайлеру.
3. Не проверял поведение `Hero` под `disableAnimations` в рантайме — утверждение «полагается на системное поведение Navigator» основано на отсутствии явной проверки в коде.
4. Не верифицировал, что все 35 контроллеров действительно «живут» в рантайме (некоторые виджеты могут быть мёртвым кодом — подтверждено для `M3Pressable`, `M3ReactionBurst`, `M3StaggeredItem`).
5. Заявленное «около 35 `AnimationController`» подтвердилось ровно: **35**.

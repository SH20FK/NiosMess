# Аудит motion: чаты (2026-11-21)

> Режим: только чтение. Все утверждения — со ссылками `файл:строка` из прочитанного кода. В конце — раздел «что не проверял».

## 0. Что реально прочитано

Полностью: `lib/screens/chat_detail_screen.dart` (1–3346), `lib/widgets/chat/chat_message_list.dart`, `chat_input_bar.dart`, `chat_detail_input_area.dart`, `voice_recording_panel.dart`, `m3_speed_dial_fab.dart`, `chat_detail_fab.dart`, `chat_scroll_coordinator.dart`, `chat_viewport.dart`, `chat_message_edge_fade.dart`, `chat_search_bar.dart`, `chat_filter_bar.dart`, `chat_list_header.dart`, `chat_overlay_layer.dart`, `noto_message_emoji.dart`, `chat_detail_app_bar.dart`, `chat_actions_modal.dart`, `chat_empty_state.dart`, `chat_state_surface.dart`, `spamblock_banner.dart`, `e2ee_status_card.dart`, `ordinary_e2ee_notice.dart`, `ordinary_peer_key_notice.dart`, `desktop_drag_drop_area.dart`, `bubble/*` (все 12 файлов), `lib/widgets/message_bubble.dart` (1–1657), `lib/widgets/chat_tile.dart`, `lib/widgets/message_context_menu_sheet.dart`, `lib/widgets/motion/m3_reaction_burst.dart`, `m3_animated_badge.dart`, `m3_selection_motion.dart`, `m3_staggered_list.dart`, `m3_pressable.dart`, `lib/core/motion/m3_spring_constants.dart`, `nios_motion.dart`, `nios_dismissible.dart`, `lib/widgets/common/touch_container.dart`, `lib/widgets/voice_message_player.dart` (ключевые части), `lib/widgets/pulse_skeleton.dart`, `lib/widgets/media/media_hero.dart`, `lib/features/chats/**` (все presentation + application/domain), `lib/screens/chat_list_screen.dart`, частично `lib/screens/circle_video_recorder_screen.dart`, `lib/router/app_router.dart` (фрагменты про `/chat/:chatId` и `/media-viewer`), `lib/core/modal/app_modal.dart`.

Проверено по SDK (для точности утверждений про дефолты): `F:\Flutter\flutter\...\dismissible.dart`, `animated_switcher.dart`, `pages.dart`.

---

## 1. Инвентарь анимаций зоны

### 1.1 Появление сообщений и лента

| Файл:строка | Что анимируется | Механизм | Длительность | Кривая/пружина |
|---|---|---|---|---|
| `chat_detail_screen.dart:3169-3181` | Вход нового пузыря: fade 0→1, scale 0.98→1, translate Y 10→0 | `AnimationController` + `CurvedAnimation` + `AnimatedBuilder` + `Opacity/Transform` | `200 ms` (хардкод) | `M3SpringCurves.gentle` |
| `chat_detail_screen.dart:2938-2951`, `chat_message_list.dart:841-849` | Обёртка `_AnimatedMessage` вокруг каждой строки | StatefulWidget на строку | — | — |
| `chat_message_list.dart:691-699` | Условие анимации: `index == 0 && !_animatedMessageIds.contains(id) && (now - sentAt) < 4 s` | логика | — | — |
| `chat_message_list.dart:491` | Все стартовые сообщения помечаются «анимированными» | логика | — | — |
| `chat_message_list.dart:289-319` (`_moveToLoadedTail`) | Скролл к хвосту после отправки | `controller.animateTo` | `M3Durations.medium2` (300 ms) | `expressiveDecel` (Cubic) |
| `chat_scroll_coordinator.dart:95-105` | Скролл вниз по FAB | `animateTo` | `medium2` | `expressiveDecel` |
| `chat_message_list.dart:568-585` (`_scrollToMessage`) | Переход к найденному сообщению | `Scrollable.ensureVisible` | `medium2` | `expressiveDecel` |
| `chat_message_list.dart:587-593` | Снятие подсветки | `Timer` 1600 ms | — | — |
| `message_bubble.dart:633-649` | Подсветка пузыря при переходе: цвет `secondaryContainer@0.4 → transparent` | `TweenAnimationBuilder<Color?>` | `1500 ms` (хардкод) | `Curves.easeOut` |
| `chat_message_list.dart:321-370` (`_rebaseAnchor`, `correctBy`) | Пересчёт якоря при вставке сообщений (без анимации) | `ScrollPosition.correctBy` | 0 | — |
| `chat_detail_screen.dart:2954` → `pulse_skeleton.dart:252-315` | Скелетон загрузки сообщений | статика (ноль анимации) | — | — |

### 1.2 Жесты пузыря, реакции, вложения

| Файл:строка | Что анимируется | Механизм | Длительность | Кривая/пружина |
|---|---|---|---|---|
| `bubble_gestures.dart:21-137` | Свайп-ответ: сдвиг `Transform.translate`, появление иконки ответа | `AnimationController` + `ValueNotifier` + `ValueListenableBuilder` | `250 ms` (хардкод) | `expressiveDecel.transform()` вручную (стр. 49) |
| `bubble_gestures.dart:71-78` | «Трение» за порогом: `delta *= 0.3`, clamp `-76.8..0` | ручная математика | — | — |
| `bubble_gestures.dart:81-87` | Хаптик на пороге `-64`, гистерезис 12 px | — | — | — |
| `message_bubble.dart:433-444` | Долгое нажатие / вторичный клик → `HapticService.confirm()` + панель действий | — | — | — |
| `chat_detail_screen.dart:1574-1594` | Панель действий = `AppBottomSheets.show` (легаси-фасад → `AppModal.showSheet`) | `showModalBottomSheet` | 300 / 250 ms (`app_modal.dart:43-48`) | `expressiveDecel/accel` (Cubic) |
| `message_context_menu_sheet.dart:38-118` | Содержимое панели: превью, ряд реакций, список | без собственной анимации | — | — |
| `message_bubble.dart:565-623` | Появление пилюли реакции: scale 0.90→1, key=`react_${emoji}_${count}` | `TweenAnimationBuilder` | `M3Durations.medium1` (250 ms) | `M3SpringCurves.snappy` |
| `message_bubble.dart:587-590` | Нажатие на пилюлю реакции | `TouchContainer(scaleDown: 0.96)` | 140/240 ms (`expressive_tokens.dart:271,274`) | press `Curves.easeOutCubic`, release `snappy` |
| — | Исчезновение реакции / изменение счётчика | нет анимации (Wrap пересобирается) | — | — |
| — | `M3ReactionBurst` | **не используется нигде** (grep по `lib`) | — | — |
| `noto_message_emoji.dart:285-297, 336-343` | Реплей анимированного эмодзи: scale 1.12→1 | `AnimationController` (`_spring`) + `AnimatedBuilder` | `M3Durations.medium1` | `M3SpringCurves.snappy` |
| `bubble_footer.dart:138-154` | Статус доставки (clock→check→done_all) | `AnimatedSwitcher` | `M3Durations.short3` | `expressiveDecel` |
| `voice_message_player.dart:293-309` | Play/Pause в голосовом | `AnimatedSwitcher` + `ScaleTransition(anim)` | `short3` | `expressiveDecel` |
| `bubble_circle_player.dart:258-275` | Play/Pause оверлей кружка | мгновенная замена (нет анимации) | — | — |
| `bubble_upload_overlay.dart:61` | Оверлей загрузки (scrim `Colors.black`, стр. 62) | появляется мгновенно | — | — |
| `media_album_bubble.dart:102-188` | Появление сетки альбома после декода | нет (FutureBuilder → готовое дерево) | — | — |
| `media_album_bubble.dart:230-255` | Листание альбома | `PageController.next/previousPage` | `250 ms` | `gentle` |
| `bubble_sticker_player.dart` | Анимированный стикер | VideoPlayer + пул контроллеров | — | — |

### 1.3 Панель ввода

| Файл:строка | Что анимируется | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `chat_input_bar.dart:514-581` | Появление панели «Редактирование» | `AnimatedSize` | `short4` (200 ms) | `expressiveDecel` |
| `chat_input_bar.dart:584-634` | Появление панели «Ответ» | `AnimatedSize` | `short4` | `expressiveDecel` |
| `chat_input_bar.dart:688-711` | Цвет/рамка поля ввода при фокусе | `AnimatedContainer` | `short4` | `expressiveStandard` |
| `chat_input_bar.dart:727-767` | Иконка emoji↔keyboard: fade + scale 0.85→1 | `AnimatedSwitcher` | `medium1` | in `expressiveDecel`, out `expressiveAccel` |
| `chat_input_bar.dart:963-992` | Mic ↔ Send: fade + scale 0.8→1 | `AnimatedSwitcher` | `short4` | in `expressiveDecel`, out `expressiveAccel` |
| `chat_input_bar.dart:1180-1190` | Кнопка записи: цвет `primary↔tertiary` (форма круг) | `AnimatedContainer` | `short4` | **`M3SpringCurves.spatial`** |
| `chat_input_bar.dart:1191-1204` | Иконка mic↔videocam | `AnimatedSwitcher` + `ScaleTransition(anim)` | `short4` | **дефолт `Curves.linear`** |
| `chat_input_bar.dart:1253-1318` | Send ↔ Commit-edit + иконка внутри | 2 вложенных `AnimatedSwitcher` | `short4` | **дефолт `Curves.linear`** |
| `chat_input_bar.dart:1001-1069` | Раскрытие/закрытие emoji-панели: `height` | `AnimatedContainer` + `Clip.hardEdge` | `medium1` (250 ms) | `gentle` |
| `chat_input_bar.dart:180-201` | Хак «передача клавиатура↔панель»: `Future.delayed(140 ms)` | таймер | — | — |
| `expression_picker_panel.dart:73-88` | Смена вкладки Emoji/Custom/Stickers | `PageController.animateToPage` | `medium2` | `snappy` |
| `expression_picker_panel.dart:108-119` | Drag-to-expand: только порог на `onVerticalDragEnd`, без следования за пальцем | ручная логика | — | — |
| `chat_input_bar.dart:355-373` | Переход в запись кружка | `PageRouteBuilder` + `FadeTransition(opacity: a)` | дефолт `300 ms` (`PageRouteBuilder`) | **линейно**, без curve |
| `voice_recording_panel.dart:36-45` | Пульс микрофона: scale 1→1.1 `repeat(reverse)` | `AnimationController` + `AnimatedBuilder` | `1000 ms` | `expressiveStandard` |
| `voice_recording_panel.dart:80-87` | Фон панели при «свайп на отмену» | `AnimatedContainer` | `short3` | `expressiveDecel` |
| `voice_recording_panel.dart:180-191` | 24 бара waveform | 24 × `AnimatedContainer` | `short2` (100 ms) | `expressiveDecel` |
| `circle_video_recorder_screen.dart:58-63` | Пульс кнопки записи | `AnimationController.repeat` | `800 ms` | `expressiveStandard` |
| `circle_video_recorder_screen.dart:612-649` | Морф кнопки записи: радиус 40→26, внутренний квадрат 36→26 / r18→r7 | 2 × `AnimatedContainer` | `short3` | `expressiveDecel` |

### 1.4 FAB и список чатов

| Файл:строка | Что | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `m3_speed_dial_fab.dart:50-74` | Раскрытие speed dial (общий контроллер) | `AnimationController` | forward `medium2`, reverse `short4` | expand `bouncy`/rev `snappy`; fade `expressiveDecel/accel`; rotation `bouncy` |
| `m3_speed_dial_fab.dart:180-246, 269-273` | Стаггер пунктов через `(progress-0.3)/0.7`, `Transform.scale`, `Opacity` | ручной сдвиг по одной кривой | — | та же `bouncy` |
| `m3_speed_dial_fab.dart:351-366` | Иконка edit→close: rotate до π, подмена иконки при `t > 0.25` | `AnimatedBuilder` | — | `bouncy` |
| `m3_speed_dial_fab.dart:385-402` | Показ/скрытие FAB на скролле | `AnimatedScale` + `AnimatedOpacity` | `short4` | `spatial` / `expressiveStandard` |
| `chat_detail_fab.dart:25-35` | FAB «вниз» | `AnimatedOpacity` + `AnimatedScale(0.7→1)` | 200 ms / `medium1` | **нет curve (linear)** / `spatial` |
| `chat_viewport.dart:169-174` | Позиция FAB = `composerHeight + 16` | `Positioned` без анимации | — | — |
| `chat_tile.dart:249-262` | Фон/рамка строки (hover/selected/keyMismatch) | `AnimatedContainer` | `short3` | `gentle` |
| `chat_tile.dart:371-385` | Индикатор выбранной строки | `AnimatedOpacity` | `short3` | **нет curve (linear)** |
| `chat_tile.dart:501-512` | Толщина шрифта заголовка (600↔700) | `AnimatedDefaultTextStyle` | `short3` | `gentle` |
| `chat_tile.dart:729-760` | Бейдж непрочитанного | `AnimatedSwitcher` + `ScaleTransition(anim)` | `short4` | `expressiveDecel/accel` |
| `chat_tile.dart:776-867` (`_TypingDots`) | Три точки «печатает» | `AnimationController` + `AnimatedBuilder`, cos-волна | 1000 ms | без кривой (математика) |
| `chat_list_screen.dart:415-436` | Свайп «Прочитано» | `Dismissible` (`confirmDismiss → false`) | movement `200 ms` (SDK), snap-back — линейный reverse | **линейно** (дефолт Dismissible) |
| `chat_list_screen.dart:403-405, 563-567` | Перестановка чатов при новом сообщении | `SliverList` + `findChildIndexCallback` (O(1) карта) | **без анимации** | — |
| `chat_filter_bar.dart:283-298` | Пилюля фильтра: фон + высота | `AnimatedContainer` | 200 ms (хардкод) | `gentle` |
| `chat_filter_bar.dart:159-168` | Маска правого края | `ShaderMask` (статика, `Colors.white`) | — | — |
| `chat_list_header.dart:89-105` | Scrim шапки инбокса | `TweenAnimationBuilder<double>` | 200 ms (хардкод) | `gentle` |
| `pulse_skeleton.dart:58-66, 161` | Пульс скелетонов инбокса | `AnimationController` + `FadeTransition` | 1200 ms | `Curves.easeInOut` |

### 1.5 Шапка чата, поиск, переходы

| Файл:строка | Что | Механизм | Длительность | Кривая |
|---|---|---|---|---|
| `chat_detail_app_bar.dart:126-145` | Hero аватара `chat_avatar_$chatId` | `Hero` (совпадение только в `group_profile_screen.dart:194`, `public_profile_screen.dart:372`) | Hero-дефолт | Hero-дефолт |
| `chat_detail_screen.dart:3218-3300` (`_TypingSubtitle`) | «печатает» / «онлайн» / фолбэк | **мгновенная замена Text** | — | — |
| `ordinary_peer_key_notice.dart:56-67` | «Ключ изменился» | **мгновенная замена** | — | — |
| `chat_overlay_layer.dart:44-55` | Спиннер подгрузки истории | `AnimatedSize` | `short4` | `expressiveDecel` |
| `e2ee_status_card.dart:77-81` | Появление E2EE-плашки | `AnimatedSize` | 250 ms (хардкод) | `spatial` |
| `ordinary_e2ee_notice.dart:21-27` | Плашка «жду ключи» | `AnimatedSize` | 200 ms (хардкод) | `gentle` |
| `chat_search_bar.dart:134-190` | `SearchAnchor.bar` (открытие/закрытие вью) | Material-дефолт | Material-дефолт | Material-дефолт |
| `chat_search_bar.dart:223-256` | Ряд категорий (`FilterChip`), дублируется `setChipState`+`setState` | — | — | — |
| `inbox_search_screen.dart:87-90` | Дебаунс поиска | `Timer` 220 ms | — | — |
| `inbox_search_screen.dart:266-291` | Пилюля категории | `M3SelectionMotion` (единственное использование готового блока в зоне) | `short4` | `snappy` |
| `inbox_search_screen.dart:391-520` | Результаты поиска появляются/меняются | **мгновенно**, без fade/stagger | — | — |
| `create_group_members_screen.dart:91-125` | Полоса выбранных участников | `AnimatedSize` | 250 ms (хардкод) | **`Curves.fastOutSlowIn`** |
| `create_group_members_screen.dart:402-421` | Кружок выбора участника | `AnimatedContainer` | 200 ms (хардкод) | **нет curve (linear)** |
| `app_router.dart:97-133` | Открытие/закрытие экрана чата | `CustomTransitionPage`: slide `Offset(0.03,0)`→0 + fade | 240/240 ms | `expressiveDecel`, reverse `easeInCubic`, fade `easeOutCubic` |
| `app_router.dart:432-460` | Открытие медиа-вьювера (из чата) | scale 0.90→1 + fade | 320/260 ms | `spatial` (rev `gentle`), fade `easeOutCubic` |
| `media_hero.dart:16-26` | Hero вложения | `Hero` c `flightShuttleBuilder` (держит миниатюру) | Hero-дефолт | Hero-дефолт |

---

## 2. Проблемы

### CRITICAL

**C1. Раскрытие emoji-панели перестраивает и пере-раскладывает всю ленту сообщений каждый кадр** — `chat_input_bar.dart:1001-1009` (`AnimatedContainer` высоты, 250 ms) → `chat_viewport.dart:6-23, 99-109, 128, 146, 156-165` (`_MeasureSize` → `setState` на каждое изменение размера) → `messagesBuilder(context, _composerHeight)` создаёт новый `_ChatMessagesScope`/`ChatMessageList` → `chat_message_list.dart:597-968` пересобирает все видимые строки + `SliverToBoxAdapter(SizedBox(height: widget.bottomPadding))` (`chat_message_list.dart:1001-1003`) меняет layout. Итог: 250 мс «дёргания» при каждом открытии/закрытии панели, плюс то же при появлении панелей «ответ»/«редактирование» (`chat_input_bar.dart:514, 584`) и при росте поля ввода.
Почему плохо: прямое нарушение правила «Поле ввода … не вызывает перерисовку ленты сообщений», плюс физически это не анимация ленты, а побочный эффект — сообщения «прыгают» ступеньками панели.
Исправление: вынести высоту композера в `ValueNotifier<double>`; на него подписать только (а) `Positioned.bottom` FAB, (б) градиент, (в) `bottomPadding` — через отдельный `ValueListenableBuilder`/`AnimatedPadding`/`SizedBox` sliver, не пересобирая `messagesBuilder`. `messagesBuilder` вызывать один раз и кэшировать поддерево (`child:` у `ValueListenableBuilder`), а `ChatMessageList` получать `bottomPadding` через `ValueListenableBuilder` внутри. Ключ — поддерево ленты не должно получать новые widget-инстансы.

**C2. Ни одна анимация чата не является физикой с переносом скорости: `animateWithSpring` — мёртвый код** — `core/motion/nios_motion.dart:63-86` (есть корректный метод с `velocity`), но grep по `lib` даёт **ноль** вызовов; `NiosDismissible` используется только в `media_viewer_screen.dart:265`. В чатах всё построено на «пружина-как-Curve + фиксированный Duration» (`chat_detail_screen.dart:3169-3181`, `bubble_gestures.dart:42-50`, `m3_speed_dial_fab.dart:50-74`, `chat_input_bar.dart:1003-1009` и т. д.). `SpringCurve` — это нормированный easing, а не симуляция (`m3_spring_constants.dart:49-100`), поэтому: нет прерываемости с сохранением скорости, нет «дожима» жеста, все переходы заканчиваются принудительно за N мс.
Исправление: для интерактивных элементов (свайп-ответ, speed dial, раскрытие панелей, drag-to-expand) перейти на `AnimationController.unbounded` + `animateWithSpring(spring: NiosMotion.spatial, velocity: …)`, целевые пружины — из M3E-набора (spatial fast 800/0.6, default 380/0.8, slow 200/0.8; effects fast 3800/1.0, default 1600/1.0, slow 800/1.0).

**C3. Токены «пружин» в проекте описывают две разные физики под одними именами и не совпадают с M3E** — `m3_spring_constants.dart:12-47` (`M3Spring.spatial = stiffness 220, damping 26` → ζ≈0.88) и `m3_spring_constants.dart:104-133` (`M3SpringCurves.spatial = ζ 0.75, stiffness 32`, `emphasized = ζ 0.70, stiffness 36`, `snappy = ζ 0.85, stiffness 52`, `bouncy = 0.55/58`, `gentle = 0.90/24`). То есть «spatial» — это либо (220, ζ 0.88), либо (ζ 0.75, k 32) в зависимости от того, какой символ взяли. Плюс все они сжимаются в 150–300 мс, что делает «пружину» неотличимой от обычного easing.
Почему плохо: владелец просит «настоящий M3E motion-physics», а фундамент содержит произвольные значения; любая «правильная» замена кривой ничего не изменит.
Исправление: один источник истины — `SpringDescription` из M3E-таблицы (mass 1, stiffness 800/380/200 spatial, damping из ζ 0.6/0.8/0.8; effects 3800/1600/800 при ζ 1.0), а `M3SpringCurves` оставить только для редких случаев, где нужен готовый `Curve` (например, `AnimatedSwitcher`), и вывести их из тех же чисел.

### MAJOR

**M1. Свайп-ответ — фиксированный твин на 250 мс без скорости и без формы** — `bubble_gestures.dart:29-51, 89-99`. На `onHorizontalDragEnd` скорость `details.velocity` игнорируется, всегда `_controller.forward(from: 0)`; «пружина» = `expressiveDecel.transform()` (эффект-кривая) на пространственном сдвиге (стр. 49). Иконка ответа — круг, скейлится линейно от |drag| (`bubble_gestures.dart:107-130`), исчезает при `dragX > -8` скачком.
Что не так: нет velocity handoff, нет прерывания «поймал обратно» с сохранением движения; на M3E отклик должен быть shape/scale morph с пружиной.
Фикс: `AnimationController.unbounded` + `_dragNotifier` как источник значения; на release — `animateWithSpring(NiosMotion.snappy, target: 0, velocity: normalizeVelocity(details.velocity.pixelsPerSecond.dx, width))`. Порог 64 px даёт «провал» — добавить rubber-band (`pow(fraction,0.7)*…`, как в `nios_dismissible.dart:95-102`). Иконку превратить в squircle-пилюлю с пружинным появлением (`M3SpringCurves.emphasized`), заменить `Container(shape: BoxShape.circle)` на форму из `flutter_m3shapes`/`RoundedSuperellipseBorder` как в `e2ee_status_card.dart:90`.

**M2. Появление одного сообщения: `Opacity` на весь пузырь + `gentle` на fade + фиксированные 200 мс; пачка сообщений «выпадает» без анимации** — `chat_detail_screen.dart:3169-3181, 3199-3211`, триггер `chat_message_list.dart:691-694`. `M3SpringCurves.gentle` — пространственная пружина ζ 0.9, применённая к `Opacity` (эффект-свойство). По правилам проекта overshoot-кривые на `Opacity` запрещены; формально gentle не перелетает 1.0 (проверил численно: ζ=0.9, k=24, при t≤1 `raw(t) ≤ raw(1)`), но семантика неверная и fade получается «плывущим».
Дополнительно: `index == 0` — значит при пачке из N сообщений анимируется только последнее (остальные появляются мгновенно), при этом счётчик непрочитанных инкрементируется на всю пачку (`chat_scroll_coordinator.dart:72-76`).
Фикс: разделить spatial/effects: translate+scale — spatial-пружина (default 380/0.8) через `Transform` без `Opacity`; fade — отдельный effects-твин (`expressiveDecel` 150–200 мс) либо `FadeTransition` с `M3SpringCurves.expressiveDecel`. Для пачки — стаггер по индексу, ограниченный 3–5 элементами (`M3StaggeredItem` уже есть в `widgets/motion/m3_staggered_list.dart`, но в чате не используется). Убрать `Opacity` из дерева пузыря (заменить на `FadeTransition` поверх `RepaintBoundary`, чтобы не было save-layer на всём пузыре).

**M3. Speed dial FAB: один контроллер на всё, стаггер — кламп-хак, морфинг иконки — подмена по порогу** — `m3_speed_dial_fab.dart:50-74` (один `_controller` + три `CurvedAnimation`), `:193, :209, :225` (`(progress - 0.3).clamp(0,0.7)/0.7` — не стаггер, а обрезка одной кривой: все пункты «доезжают» одновременно), `:351-366` (`showClose ? close : edit` при `t > 0.25` — иконка щёлкает, хотя в проекте есть `M3MorphingIcon` (`widgets/motion/m3_morphing_icon.dart:8-130`), не используемый нигде).
Плюс `Opacity` пунктов с `bouncy`-кривой (`:272-273`) — эффект-свойство на spatial-пружине.
Фикс: на каждый пункт свой `unbounded` контроллер + `animateWithSpring(NiosMotion.emphasized)` со стаггером по индексу (delay через `TickerFuture` или `Interval`-порог только для старта, а не для формы); `M3MorphingIcon(edit ↔ close)`; `Opacity` — только `expressiveDecel`. Также переключение `_isOpen` → `SizedBox.shrink()` в базовой позиции (`:397-401`) даёт «прыжок» FAB: оставить Hero-копию постоянной и анимировать её форму.

**M4. Панель действий по долгому нажатию — обычный `showModalBottomSheet` без M3E-хореографии** — `chat_detail_screen.dart:1580-1594` → `app_modal.dart:19-48` (300/250 мс translate, без shape morph и без «якоря»). Ряд быстрых реакций (`message_context_menu_sheet.dart:487-558`) появляется целиком, без stagger/пружин; отмена — просто pop.
Почему плохо для M3E: контекстное меню — витринный элемент expressive-схемы (морфинг из пузыря, scale-from-anchor). Сейчас панель «съезжает снизу» как обычный sheet, реакции не «выстреливают».
Фикс: `MenuAnchor`/собственный anchored-popup с `Transform.scale` от точки нажатия + пружина `emphasized`; реакции — `M3StaggeredItem` (или per-item spring) + `M3ReactionBurst` на выбранной; на закрытии — reverse с сохранением скорости.

**M5. Реакции: нет вспышки, нет exit-анимации, счётчик анимируется заменой всего пилюля** — `message_bubble.dart:556-627`. Ключ `react_${emoji}_${count}` (стр. 566-568) означает, что при каждом +1 пересоздаётся пилюля и проигрывается scale 0.90→1 (250 мс, `snappy`); убрать реакцию (в т.ч. чужую) — исчезает мгновенно; `M3ReactionBurst` (`m3_reaction_burst.dart`) не используется, хотя это ровно тот компонент.
Фикс: `M3AnimatedBadge` (есть, не используется, `m3_animated_badge.dart`) для счётчика, `M3ReactionBurst` по тапу/двойному тапу (`message_bubble.dart:422-432`), `AnimatedSwitcher` с effects-кривой для исчезновения, и анимировать только число, а не всю пилюлю.

**M6. Список чатов: свайп «Прочитано» — линейный snap-back, перестановка чатов при новом сообщении — мгновенная** — `chat_list_screen.dart:415-436` использует `Dismissible` c `confirmDismiss: … return false`; в SDK `movementDuration = 200 ms`, `_moveAnimation` — линейный `Tween` по значению контроллера, snap-back — `_moveController.reverse()` без curve/velocity (`.../widgets/dismissible.dart:112-114, 456-466, 530-533`). Значит после неудачного/успешного свайпа строка возвращается «роботом», без пружины и без учёта скорости.
Перестановка: `SliverList` + `findChildIndexCallback` (`chat_list_screen.dart:563-567`) — карта O(1) (правило соблюдено), но move-анимации нет: чат с новым сообщением телепортируется наверх.
Фикс: заменить `Dismissible` на `NiosDismissible`-механику (сейчас `nios_dismissible.dart` умеет только вертикаль — расширить на horizontal) или собственный `AnimationController.unbounded` + `animateWithSpring(velocity: …)`; для перестановки — `SliverAnimatedList`/`AnimatedList` либо явная анимация «переезда» по ключу (M3E: spatial default).

**M7. Шапка чата не анимирует «печатает» и «ключ изменился»** — `_TypingSubtitle` (`chat_detail_screen.dart:3237-3298`) просто отдаёт другой `Text`; `OrdinaryPeerKeyNotice` (`ordinary_peer_key_notice.dart:56-67`) — то же. При переключении «онлайн ↔ @username ↔ печатает» текст прыгает, а строка может менять ширину (разные стили/иконка-точка).
Фикс: `AnimatedSwitcher` c `M3SpringCurves.expressiveDecel`/`expressiveAccel` (или готовый `M3SpringSwitcher`, `widgets/motion/m3_spring_switcher.dart`), фиксированная высота строки, чтобы не дёргать layout шапки; для статуса «печатает» — мини-точки по аналогии с `chat_tile.dart:776-867`, но без `cos`-волны на 1 с (M3E использует короткий spring-цикл).

**M8. Переход «список → чат» и «чат → медиа» — фиксированные твины на M2-кривых, без predictive-back и без shared-axis** — `app_router.dart:97-133` (240 мс, slide 0.03 + `easeOutCubic`, reverse `easeInCubic`), `app_router.dart:432-460` (scale 0.90 + `easeOutCubic`). При этом в проекте есть `custom_transition`-каркас с пружинами (`core/motion/pulse_predictive_back_transition.dart`, `widgets/motion/m3_shared_axis.dart`) — в чатах не используется.
Дополнительно: при открытии медиа работают одновременно Hero-флайт (`media_hero.dart:16-26`) и page-scale 0.90→1 → «двойная» анимация картинки.
Фикс: shared-axis (X для «в чат», fade-through для медиа) на `NiosMotion.spatial/emphasized` через `PageRouteBuilder` c симуляцией (пружина), reverse — с перехватом жеста (`transitionOnUserGestures` уже включён в Hero); для медиа — оставить только Hero + fade, убрать scale страницы.

**M9. `ChatViewport` пересобирает FAB-позицию и градиент без анимации** — `chat_viewport.dart:144-149, 169-174`: FAB «телепортируется» при изменении высоты композера/клавиатуры, градиент меняет высоту скачком на каждом шаге. Мелочь по сравнению с C1, но при открытии панели это заметно как «дребезг» кнопки.
Фикс: `AnimatedPositioned`/`TweenAnimationBuilder` c spatial-пружиной на `bottom`, градиент — `AnimatedContainer`-аналог вне пути ленты.

### MINOR

- **m1. Кнопка записи: spatial-кривая на цвете** — `chat_input_bar.dart:1180-1190` (`AnimatedContainer`, меняется только `color`). Для цветов — effects-пружина/`expressiveStandard`.
- **m2. Mic↔videocam и Send↔Commit: `AnimatedSwitcher` без curve → `Curves.linear`, `ScaleTransition(scale: anim)` = рост из нуля** — `chat_input_bar.dart:1191-1197, 1253-1258, 1303-1308`. Проверено по SDK: дефолт `Curves.linear` (`animated_switcher.dart:117-118`). Заменить на `M3MorphingIcon`/`M3SpringSwitcher` либо, как минимум, задать пары `expressiveDecel/expressiveAccel` и scale 0.8→1.
- **m3. Тройная вложенность `AnimatedSwitcher` в панели ввода** — внешний `chat_input_bar.dart:963` + внутренние `:1191` и `:1253`, плюс `:1303` внутри — при смене «пусто → текст» играют 2–3 анимации одновременно (двойной scale). Свести к одной.
- **m4. Emoji-панель: `Clip.hardEdge` + `AnimatedContainer(height)` + `OverflowBox`** — `chat_input_bar.dart:1003-1038`. Панель не следует за пальцем (drag только распознаётся в `expression_picker_panel.dart:108-119`), а «раскрытие в библиотеку» — `Offstage`/`Positioned.fill` (`:249-275`) без перехода.
- **m5. `Future.delayed(140 ms)` для передачи клавиатура↔панель** — `chat_input_bar.dart:180-201`. Это не анимация, а хак тайминга; приводит к рассинхрону с системной анимацией IME. Правильнее — `AnimatedSize`/`M3SharedAxis` вокруг панели и не закрывать её при фокусе на 140 мс.
- **m6. Переход в запись кружка — линейный fade на 300 мс** — `chat_input_bar.dart:355-373` (`FadeTransition(opacity: a)` без `CurvedAnimation`; дефолт `PageRouteBuilder` 300 мс подтверждён SDK `pages.dart:96`). M3E-ожидание: морф круглой кнопки в круглый видоискатель (shared-axis X + radius morph).
- **m7. Круглая кнопка записи (recorder) морфит форму `AnimatedContainer` c effects-кривой** — `circle_video_recorder_screen.dart:612-649` (радиус 40→26, квадрат 36→26, r18→r7 за 150 мс `expressiveDecel`). Намерение верное (shape morph), но не пружина и кривая «эффектов» на форме.
- **m8. `AnimatedSize` в шапке/баннерах с «чужой» кривой** — `ordinary_e2ee_notice.dart:26` (spatial-размер + `gentle` + 200 мс = резко), `e2ee_status_card.dart:80-81` (spatial на 250 мс — ок), `chat_overlay_layer.dart:44-48` (spatial на 200 мс). Для размера/формы — spatial-пружина, не короче 250–300 мс.
- **m9. Подсветка перехода к сообщению: 1500 мс `Curves.easeOut`** — `message_bubble.dart:633-649`, таймер снятия 1600 мс (`chat_message_list.dart:587`). Цвет — effects-свойство, но кривая M2; кроме того, подсветка — просто подложка `Container` под пузырём, без морфа формы пузыря. Заменить на effects-пружину (1600/1.0) и/или анимированный «halo» по контуру пузыря.
- **m10. `MessageListSkeleton` без анимации, а `ChatListSkeleton` пульсирует** — `pulse_skeleton.dart:252-315` (нет ни одного `Animated*`) vs `:58-66, 161` (1200 мс, `Curves.easeInOut`). При загрузке чата выглядит «мёртво» и несогласованно с инбоксом. Плюс `Curves.easeInOut` вместо токена.
- **m11. `_TypingDots` — cos-волна 1 с, контроллер создаётся лениво через `late final`** — `chat_tile.dart:783-786` (первый доступ в `didChangeDependencies`, формально не в `build()` — правило не нарушено), но `AnimatedBuilder` пересобирает 3 точки каждый кадр, и цикл реализован костылём «перезапуск из status-listener» (`:791-795`). Для M3E — короткий spring-пульс (или `loading_indicator_m3e`-подобная волна), с `TickerMode`-гейтом (он есть).
- **m12. `_FilterPill` / `_PillBadge`** — `chat_filter_bar.dart:283-298` цвет + высота за 200 мс `gentle` (эффект-свойство на spatial-кривой); бейдж папки появляется мгновенно (`:320-352`), хотя для этого есть `M3AnimatedBadge`. Сегментированный контрол M3E ожидает «переезжающую» пилюлю, а не перекраску двух отдельных пилюль.
- **m13. `chat_filter_bar.dart:165` — `Colors.white` в градиенте `ShaderMask`** — нарушение правила «No `Colors.white`/`Colors.black`». Плюс сам `ShaderMask` — save-layer на полосе (статичный, но живой слой).
- **m14. `bubble_upload_overlay.dart:62` — `Colors.black.withValues(alpha: 0.38)`** — то же нарушение; оверлей загрузки появляется мгновенно без fade (нет `AnimatedOpacity`/`AnimatedSwitcher`).
- **m15. `spamblock_banner.dart:79-85` — `BoxShadow(blurRadius: 10)`** — прямое нарушение правила «глубина только тональными поверхностями, без drop-shadows».
- **m16. `chat_detail_fab.dart:25-35` — `AnimatedOpacity` без curve (linear) при `AnimatedScale` с `spatial`** — несогласованная пара; и scale 0.7 — не M3E-значение (обычно 0.8–0.9 + spatial default).
- **m17. `chat_tile.dart:371-385` — `AnimatedOpacity` без curve (linear)** для индикатора выбранной строки, при том что фон строки — `gentle`.
- **m18. `_AnimatedBadge` в тайле масштабируется из 0** — `chat_tile.dart:735-740` (`ScaleTransition(scale: animation)`, animation 0→1). M3E-бейдж «выщёлкивается» пружиной от 0.6–0.8, не из точки.
- **m19. `interactive_message_card.dart:736-737` — прогресс-poll анимируется `Tween(begin: percentage, end: percentage)`**, т.е. анимации нет вообще (баг «задуманной» анимации). Второй прогресс (`:848-857`) — `Tween(0 → percentage)` 180 мс без curve (`:785-787`), т.е. linear.
- **m20. Модалка «назначить ответственного» использует `showModalBottomSheet` напрямую** — `interactive_message_card.dart:136-164`, минуя `AppModal.showSheet` (другая анимация, другой стиль, `shrinkWrap` внутри sheet). Нарушение конвенции проекта.
- **m21. `desktop_drag_drop_area.dart:52-104`** — оверлей создаётся `if (_isDragging)`, поэтому вложенный `AnimatedContainer` (200 мс) ничего не анимирует: дроп-зона появляется кадром.
- **m22. `create_group_members_screen.dart:93` — `Curves.fastOutSlowIn` (M2)**, `:402-421` — `AnimatedContainer` без curve (linear) для кружка выбора; галочка появляется мгновенно (нет scale/морфа). Это же место дублирует `M3SelectionMotion`-логику.
- **m23. `inbox_search_screen.dart:391-520`** — результаты поиска (и переход loading→data) меняются без перехода; при этом скелетон/спиннер — `AppLoadingIndicator` (ок).
- **m24. `chat_search_bar.dart:223-256`** — `FilterChip` + `StatefulBuilder` с двойным `setChipState`/`setState`; нет M3E-морфа выбора, нет единого индикатора. Плюс `SearchAnchor.bar` даёт дефолтную Material-анимацию (не токены проекта).
- **m25. Жёсткие `Duration(milliseconds: …)`** (полный список по зоне — см. §3.3).

### Производительность (сводно)

| Файл:строка | Проблема |
|---|---|
| `chat_viewport.dart:99-109` + `chat_input_bar.dart:1001-1009` | `setState` на каждое изменение размера композера → пересборка ленты каждый кадр 250 мс (C1) |
| `chat_detail_screen.dart:258-261` | `_inputFocusNode.addListener(… setState((){}))` — пересборка **всего экрана** (включая `_ChatMessagesScope` и композер) на каждый фокус/анфокус. Экран при этом `_isFocused` нигде не читает — слушатель не нужен |
| `chat_detail_screen.dart:260`, `chat_input_bar.dart:173-188` | Двойная обработка фокуса (экран + бар) |
| `_AnimatedMessage` (`chat_detail_screen.dart:3196-3214`) | `AnimatedBuilder` + `Opacity` на весь пузырь (save-layer на 200 мс). Контроллер живёт только у анимируемого пузыря и корректно `dispose` (`:3186-3189`) — ок, но `Opacity` лучше заменить |
| `SelfDestructCountdownPill` (`bubble_footer.dart:179-193`) | `Timer.periodic(1 s)` + `setState` **на каждый пузырь** с TTL: N таймеров и N перестроений в секунду. Лучше один общий тикер/`ValueNotifier` секунды на экран |
| `chat_message_list.dart:811-839` | `ValueListenableBuilder` на каждую строку, слушающий глобальный `_highlightedIdNotifier` — при подсветке перестраиваются все видимые строки (дёшево, но дублируется с bubble wire) |
| `chat_message_list.dart:715` | `ref.read(bluetoothMeshProvider)?.deliveryStatus(...)` в `buildRow` для каждой своей строки — синхронный расчёт на каждый rebuild строки |
| `chat_tile.dart:776-867` | Один `AnimatedBuilder` на тайл в 60 fps при «печатает» (перестраивает 3 `Opacity`+`Container` каждый кадр) |
| `voice_recording_panel.dart:166-197` | 24 `AnimatedContainer` перезапускаются на каждый сэмпл амплитуды; ок потому что панель в `RepaintBoundary` (`:78`) |
| `bubble_sticker_player.dart`, `noto_message_emoji.dart`, `bubble_circle_player.dart` | Пул контроллеров, видимость, бюджеты — **образцово**, нарушений не нашёл |

---

## 3. Несогласованности и дубли

### 3.1 Готовые M3E-блоки почти не используются в чатах

Проверено grep по `lib` + импортам (`import 'package:pulse_flutter/widgets/motion/…'` встречается только в 5 файлах вне чатов — `settings_preferences_screen.dart:12`, `settings_plus_screen.dart:13`, `settings_chats_screen.dart:9`, `inbox_search_screen.dart:20`, `settings_energy_saving_screen.dart:14`):

| Блок | Где определён | Используется в зоне? |
|---|---|---|
| `M3ReactionBurst` | `m3_reaction_burst.dart:9` | **нет нигде** |
| `M3AnimatedBadge` | `m3_animated_badge.dart:8` | **нет** (в тайлах свой `_AnimatedBadge`, `chat_tile.dart:708-762`) |
| `M3MorphingIcon` | `m3_morphing_icon.dart:8` | **нет** (морф edit↔close вручную, `m3_speed_dial_fab.dart:351-366`) |
| `M3Pressable` | `m3_pressable.dart:11` | **нет** (везде `TouchContainer`) |
| `M3StaggeredItem` | `m3_staggered_list.dart:11` | **нет** (нет entrance-стаггера ни в списке чатов, ни в результатах поиска) |
| `M3SelectionMotion` | `m3_selection_motion.dart:12` | только `inbox_search_screen.dart:266` |
| `M3SpringSwitcher` | `m3_spring_switcher.dart:28` | нет (все switcher’ы — сырой `AnimatedSwitcher`) |
| `M3SharedAxis` / `M3Reveal` | `m3_shared_axis.dart:8`, `m3_reveal.dart:20` | нет |
| `NiosMotion.animateWithSpring` | `nios_motion.dart:68` | **0 вызовов** |

### 3.2 Дубли одной и той же логики

1. **Вход нового сообщения**: `_AnimatedMessage` (`chat_detail_screen.dart:3142-3216`) — свой контроллер, тогда как `M3StaggeredItem`/`M3Reveal` решают то же.
2. **Fade+scale switcher**: вручную в `chat_input_bar.dart:738-753, 969-981`, `chat_tile.dart:735-740`, `voice_message_player.dart:299-300`, `m3_speed_dial_fab.dart:385-402` — вместо `M3SpringSwitcher`.
3. **Press-feedback**: `TouchContainer` (`touch_container.dart:169-241`), `M3Pressable`, локальные `AnimatedScale` в `sticker_picker_view.dart:371-376`, `inline_keyboard_view.dart:252-257` — три параллельные реализации.
4. **Бейджи**: `_AnimatedBadge` (`chat_tile.dart:708-762`), `_PillBadge` (`chat_filter_bar.dart:321-352`), `M3AnimatedBadge` — три разных поведения (pop fade, мгновенный, spring pop).
5. **Морф иконки**: mic↔video (`chat_input_bar.dart:1191-1204`), play↔pause (`voice_message_player.dart:293-309`), edit↔close (`m3_speed_dial_fab.dart:351-366`) — все «подмена + scale из 0», при наличии `M3MorphingIcon`.
6. **Кривые одного класса**: `expressiveDecel` используется и на страницах/скролле (`chat_message_list.dart:299, 577`; `chat_scroll_coordinator.dart:100`) — то есть effects-кривая на пространственном движении; одновременно `gentle` (spatial) используется на прозрачности/цвете (`chat_detail_screen.dart:3176`, `chat_list_header.dart:92`, `chat_tile.dart:252, 503`, `chat_filter_bar.dart:287`). Классы перепутаны в обе стороны.
7. **Длительности**: часть через `M3Durations` (`chat_input_bar.dart:518, 588, 733…`, `chat_tile.dart:178`, `chat_detail_fab.dart:29`), часть хардкодом тех же чисел (`chat_detail_screen.dart:3171`, `chat_filter_bar.dart:286`, `chat_list_header.dart:39`, `e2ee_status_card.dart:80`, `e2ee_verification_sheet.dart:154`, `ordinary_e2ee_notice.dart:25`, `media_album_bubble.dart:234, 251`, `bubble_gestures.dart:44`, `pulse_skeleton.dart:60`, `create_group_members_screen.dart:92, 403`, `interactive_message_card.dart:650, 787`, `add_sticker_dialog.dart:411`, `chat_tile.dart:780`, `voice_recording_panel.dart:38`, `app_router.dart:74, 105, 436`, `circle_video_recorder_screen.dart:56, 148`).

### 3.3 Полный список жёстких `Duration(milliseconds:)` и `Curves.*` в зоне

**Duration (не токены):** `chat_detail_screen.dart:3171` (200), `chat_message_list.dart:260` (180, дебаунс), `:429` (160), `:587` (1600), `chat_input_bar.dart:180` (140), `:195` (140), `chat_list_header.dart:39` (200), `bubble_gestures.dart:44` (250), `media_album_bubble.dart:234` (250), `:251` (250), `e2ee_status_card.dart:80` (250), `e2ee_verification_sheet.dart:154` (280), `ordinary_e2ee_notice.dart:25` (200), `chat_filter_bar.dart:286` (200), `interactive_message_card.dart:650` (160), `:787` (180), `add_sticker_dialog.dart:411` (160), `chat_tile.dart:780` (1000), `voice_recording_panel.dart:38` (1000), `pulse_skeleton.dart:60` (1200), `app_router.dart:74` (280), `:105` (240), `:436` (320), `circle_video_recorder_screen.dart:56` (800), `:148` (350), `create_group_members_screen.dart:92` (250), `:403` (200), `chat_search_bar.dart` (дефолты `SearchAnchor`), `chat_detail_screen.dart:435` (500, дебаунс черновика), `inbox_search_screen.dart:87` (220, дебаунс).

**`Curves.*` (M2 / не токены):** `message_bubble.dart:640` (`easeOut`), `touch_container.dart:180` и `:238` (`easeOutCubic`, влияет на все нажатия в чатах), `create_group_members_screen.dart:93` (`fastOutSlowIn`), `pulse_skeleton.dart:66` (`easeInOut`), `app_router.dart:81, 86, 117, 123, 124` (`easeInCubic`, `Interval(…, easeOut)`, `easeOutCubic`), `app_router.dart:450-451` (`easeOutCubic`/`easeInCubic`), плюс неявный `Curves.linear` в `AnimatedSwitcher` без curve (`chat_input_bar.dart:1191-1197, 1253-1258, 1303-1308`) и в `AnimatedOpacity` без curve (`chat_detail_fab.dart:25-29`, `chat_tile.dart:371-376`).

---

## 4. Топ-10 приоритетных переделок (по эффекту для пользователя)

1. **Развязать композер и ленту** (C1) — самый заметный «дребезг»: открытие эмодзи/ответа/редактирования сейчас пересобирает и пере-раскладывает сообщения 250 мс. Эффект: мгновенная плавность на всех устройствах, −перерисовки.
2. **Перевести интерактивные жесты на настоящие пружины с velocity handoff** (C2 + M1 + M6): свайп-ответ и свайп «прочитано» — первые места, где пользователь чувствует «резину/мёртвый стоп». Инфраструктура уже есть (`animateWithSpring`, `NiosMotion`).
3. **Появление сообщений: spatial-пружина без `Opacity` на пузыре + стаггер пачки** (M2). Эффект: «дорогой» вход сообщений, живая пачка, отсутствие save-layer.
4. **Speed dial FAB: per-item springs + `M3MorphingIcon`** (M3). Самый «витринный» элемент expressive-схемы; сейчас стаггер-хак и щёлкающая иконка.
5. **Панель действий по долгому нажатию: anchored-popup + spring + `M3ReactionBurst`/stagger реакций** (M4). Долгое нажатие — самый частый жест в чате.
6. **Реакции: burst, exit-анимация, анимация только счётчика** (M5), подключить `M3ReactionBurst` и `M3AnimatedBadge`.
7. **Переписать раскрытие emoji-панели и передачу клавиатура↔панель** (m4 + m5): drag-следование за пальцем, spring-settle, `M3SharedAxis`, убрать `Future.delayed(140)`.
8. **Анимация перестановки чатов при новом сообщении + spring snap-back свайпа** (M6), с сохранением O(1) `idToIndex` (`chat_list_screen.dart:403-405`).
9. **Шапка чата: анимировать «печатает»/статус/«ключ изменился»** (M7) — маленькая правка, но убирает «прыгающий» subtitle в самом верху экрана.
10. **Переходы роутов чатов: shared-axis на пружинах + убрать двойную анимацию медиа** (M8) и **переход в запись кружка как morph, а не линейный fade** (m6).

Далее по убыванию: подсветка перехода к сообщению (m9), скелетон ленты (m10), фильтр-бар/бейджи (m12, m13), заголовок инбокса (scrim на `gentle` — m11/§3.2), дроп-зона десктопа (m21).

---

## 5. Что сделано хорошо и трогать не нужно

1. **`noto_message_emoji.dart`** (1–376): бюджеты проигрывания по тирам (`_NotoPlaybackBudget`, 74–101), кэш композиций с ограничением (15–72), гейт по скроллу/видимости (`163-178, 212-254`), отключение по `disableAnimations`/`animateEmoji`, `RepaintBoundary` (335), `animate: false` у Lottie (351) — образец.
2. **`bubble_sticker_player.dart`** и **`bubble_circle_player.dart`**: пул `AnimatedMediaControllerPool`, `MediaPlaybackVisibility`, захват постера через `RenderRepaintBoundary.toImage` без `BackdropFilter` (206–243), корректные `generation`-гарды и `dispose`.
3. **`chat_message_list.dart`**: O(1) карта для `findChildIndexCallback` (1016–1021, 1034–1039, `_rowIndexes` 118–148) — правило соблюдено; `addRepaintBoundaries: false` + ручные `RepaintBoundary` на строках (852, 896); адаптивный `cacheExtent` по тирам (607–611); fast-scroll детект (388–433) и остановка анимаций при быстром скролле.
4. **Якорь и стабильность скролла** (`_HistoryAnchor`/`_HistoryAnchorBox` 1056–1100, `_rebaseAnchor` 321–370, `correctBy` вместо `jumpTo`): список не прыгает при вставке пачки сообщений и при восстановлении позиции — то, что чаще всего ломается в чатах.
5. **Изоляция скролла от экрана**: `ChatScrollCoordinator` (`chat_scroll_coordinator.dart`) с `ValueNotifier` для FAB/счётчика — экран не перестраивается на скролл.
6. **`chat_message_edge_fade.dart`**: чистые тональные градиенты, `IgnorePointer`, ноль live-блюров — правильная альтернатива BackdropFilter.
7. **Исполнение правил в ленте**: нет `BackdropFilter`/`MaskFilter` в пути сообщений (grep по `lib`: только `adaptive_glass.dart:79-80`, который в чатах не используется), нет `indexWhere` в `lib/widgets/chat` (grep: 0), нет `shrinkWrap` внутри ленты (все три случая — внутри bottom sheet’ов: `interactive_message_card.dart:141, 251`, `interactive_composer.dart:337`), тайлы — `TouchContainer(clipBehavior: Clip.none)` по умолчанию (`touch_container.dart:26`).
8. **Композер изолирован от перерисовки** (`chat_detail_input_area.dart:245`, `chat_viewport.dart:158`, `voice_recording_panel.dart:78-79`) — по перерисовке правило выполнено; нарушено только по перестройке (C1).
9. **Все `AnimationController` в зоне, которые я проверил, корректно создаются в `initState`/`late final` и освобождаются** (`chat_detail_screen.dart:3166-3189`, `voice_recording_panel.dart:34-66`, `m3_speed_dial_fab.dart:47-90`, `noto_message_emoji.dart:136-160, 308-321`, `chat_tile.dart:814-817`, `pulse_skeleton.dart:79-96`). В `build()` контроллеры не создаются.
10. **Уважение `disableAnimations`**: почти везде есть `MediaQuery.disableAnimationsOf(context)` (`chat_input_bar.dart:516, 964, 1004…`, `chat_tile.dart:175-178`, `chat_detail_fab.dart:27`, `noto_message_emoji.dart:165`, `m3_speed_dial_fab.dart:107-128`, `bubble_gestures.dart:30`) — редкое и ценное качество.
11. **Отключённый wallpaper** (`chat_wallpaper_background.dart:4-12` — просто `ColoredBox`) и `MediaHero` c `flightShuttleBuilder` (держит миниатюру, `media_hero.dart:19-24`) — осознанные решения.

---

## 6. Что не проверял / оговорки

- **Закреплённое сообщение в чате**: компонента «pinned message bar» в `chat_detail_screen.dart` и `lib/widgets/chat/` **не нашёл**; `isPinned` встречается только как иконка в `chat_tile.dart:73, 193, 538-544`. Значит либо фича не реализована, либо живёт в другой зоне — тогда пункт «закреплённое сообщение» из задания закрывать нечем.
- **Поиск внутри чата**: в самом `chat_detail_screen` поиска нет (в шапке только звонки + overflow, `chat_detail_app_bar.dart:286-410`). Глобальный поиск — `/chats/search` → `InboxSearchScreen` + `ChatSearchBar` (проверены). Отдельный «поиск по чату» не проверял за пределами этих файлов.
- **Мультивыделение сообщений**: в чате отсутствует (в `chat_detail_screen.dart` нет ни `selectionMode`, ни набора выбранных id — grep по `select|Selection|multi` дал только текстовые selection/`provider.select`). Значит «выделение сообщений» из задания — нечего аудировать; удаление/пересылка идут через bottom sheet.
- Не читал целиком (только grep): `custom_emoji_picker.dart`, `unicode_emoji_picker_view.dart`, `m3_emoji_search_view.dart`, `custom_emoji_text.dart`, `sticker_set_details_sheet.dart`, `create_sticker_set_dialog.dart`, `moderation_bottom_sheet.dart`, `e2ee_verification_sheet.dart` (кроме `:151-155`), `auto_delete_bottom_sheet.dart`, `live_location_card.dart`, `video_message_preview.dart`, `interactive_composer.dart`, `chat_manage_screen.dart`, `chat_members_screen.dart`, `join_chat_screen.dart`, `saved_messages_search.dart`, `people_picker_screen.dart`, `create_group_details_screen.dart`, `create_channel_screen.dart`. Анимаций по grep там либо нет, либо это `AnimatedContainer` с хардкод-длительностью (`add_sticker_dialog.dart:410-411`).
- Не запускал приложение и не профилировал — все оценки производительности статические (по дереву и по вызовам `setState`), без замеров FPS.
- Численные оценки пружин (`raw(t) ≤ 1` для `gentle`) получены ручным расчётом формулы `SpringCurve._rawResponse` (`m3_spring_constants.dart:69-84`), не измерением.

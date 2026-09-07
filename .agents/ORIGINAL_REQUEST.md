# Original User Request

## 2026-09-01T11:30:45Z

Implementation of the unified Nios ID OAuth 2.0 PKCE authentication flow and premium Material 3 Expressive authentication screen for NiosMess in accordance with NIOSMESS_FRONTEND_LOGIN.md.

Working directory: f:\Niosmess V2\pulse_flutter
Integrity mode: development

Specification reference: f:\Niosmess V2\NIOSMESS_FRONTEND_LOGIN.md

## Requirements

### R1. Unified Nios ID Auth Screen (Material 3 Expressive)
- Eliminate all local username and password input fields and separate registration screens from NiosMess in strict compliance with NIOSMESS_FRONTEND_LOGIN.md.
- Consolidate /login and /register into a unified, responsive Material 3 Expressive authentication hub centered around the primary action «Войти через Nios ID».
- Responsive desktop and mobile centering with maxWidth: 480dp.

### R2. Expressive Hub Visual Design & Hierarchy
- Hero Header: Brand NiosMess logo squircle alongside official Nios ID badge, expressive typography using GoogleFonts.unbounded and GoogleFonts.inter.
- Ecosystem Benefits Card: Elevated tonal container (surfaceContainerLow) with 3 highlighted pillars:
  1. Unified Nios ID Account (Icons.badge_outlined)
  2. End-to-End E2EE Encryption (Icons.lock_outline_rounded)
  3. Zero Password Transmission to Client App (Icons.shield_outlined)
- Primary Action Block: Full-width 56dp pill button (FilledButton.icon with 28dp radius) labeled «Войти через Nios ID» with branded icon and haptic feedback. Secondary action «Создать Nios ID» leading to Nios ID account registration.
- Legal Footer: High-contrast, responsive links to «Политика конфиденциальности» and «Условия использования» invoking the Material 3 Expressive Legal Reader (/legal/privacy and /legal/terms).

### R3. OAuth 2.0 PKCE & Token Exchange Flow
- PKCE Generation: Standard S256 code verifier (64-byte random base64url) and code challenge (SHA-256 base64url without padding) with cryptographic randomness.
- Ephemeral State Storage: Store verifier and state strictly in ephemeral storage (sessionStorage on Web) prior to redirect.
- Authorization Redirect:
  - Web: Perform clean navigation to /oauth/authorize?response_type=code&client_id=niosmess_web&redirect_uri=...&scope=openid+profile+email&state=...&code_challenge=...&code_challenge_method=S256.
  - Non-web (Mobile/Desktop): Launch system browser / Custom Tabs with deep link callback (app_links).
- Callback Interception & Exchange:
  - Intercept return parameters (code, state, error) before app initialization.
  - Sanitize the browser address bar via history.replaceState or GoRouter redirect to prevent code leakage.
  - Validate received state against stored state.
  - Exchange authorization code for short-lived access token via POST /oauth/token (grant_type=authorization_code).

### R4. WebSocket login_nios_id Action & Local Session Setup
- Connect WebSocket client (wss://ni-os.ru/ws).
- Dispatch action login_nios_id with payload { "oauth_access_token": token, "device_info": ... }.
- Save returned local NiosMess session (access_token, user_id, nios_id, username, display_name) to client storage.
- Initialize E2EE encryption without ever storing the temporary oauth_access_token.

### R5. Loading States, Error Handling & Consent Cancellation UX
- Inline Loading: Transition primary button into a compact spinner with disabled tap state upon initiating authorization.
- Exchange Transition Overlay: Display an elegant tonal loading overlay with status text «Авторизация в Nios ID...» during callback processing.
- Error & Cancellation Handling: If user denies consent on Nios ID (error=access_denied), dismiss overlay, re-enable the button, and show a clear error toast via AppToast.showError(...) without breaking app state.

### R6. Session Verification on Cold Start & Logout Flow
- Cold Start: On application launch / refresh, if a stored NiosMess session exists, verify central Nios ID session via GET /id/api/v1/account. If 401, clear local session and prompt re-authentication.
- Clean Logout: Tapping «Выйти» in settings triggers POST /id/api/v1/logout, terminates WebSocket and local storage, and redirects to /id/login?next=/web.
- No periodic background polling timers (per user preference).

## Acceptance Criteria

### Security & Contract Compliance
- [ ] Zero password or username input fields exist in NiosMess client code.
- [ ] No direct access or usage of nios_session cookies from JavaScript / client.
- [ ] PKCE S256 verifier and state are stored strictly in ephemeral storage and removed upon callback.
- [ ] Authorization code and state are cleared from URL address bar immediately upon return.
- [ ] oauth_access_token is never persisted to long-term storage or exposed in logs.

### Visual & Architecture Quality
- [ ] Auth screen uses semantic Material 3 Expressive tokens (colorScheme.surface, colorScheme.surfaceContainerLow, colorScheme.onPrimary, etc.) with zero hardcoded Colors.white/Colors.black or legacy withOpacity().
- [ ] Primary button uses 56dp height and 28dp pill radius with high contrast in both light and dark themes.
- [ ] Layout is responsive across mobile and desktop (maxWidth: 480dp centering).

### Automated Verification
- [ ] All unit and widget tests covering the Nios ID auth screen, PKCE generation, callback handling, and error states pass (flutter test).
- [ ] All pre-existing test suites pass without regression.
- [ ] flutter analyze reports 0 errors and 0 warnings.
- [ ] Semantic version automatically bumped in pubspec.yaml following SemVer protocol.

## 2026-09-02T18:38:20Z

Complete Material 3 Expressive redesign and responsive web adaptivity for NiosGram social feed (720-800dp wide adaptive feed with floating controls and rich media cards) and all Settings screens (responsive 2-pane Master-Detail layout on desktop/web, fully conforming to Material 3 Expressive components, tonal grouping, and crisp SVG iconography).

Working directory: f:\Niosmess V2\pulse_flutter
Integrity mode: development

## Requirements

### R1. NiosGram Expressive Feed & Responsive Web Adaptation
- Expand NiosGram layout on wide screens/desktop to an adaptive centered 720-800dp canvas, removing awkward side voids while keeping optimal reading line lengths.
- Redesign post cards with Material 3 Expressive tokens:
  - Tonal container surfaces (surfaceContainerLow / surfaceContainer), subtle borders (outlineVariant), and 20-24dp smooth corners.
  - Expressive typography: author names in bold with handle, relative time badge, and verified tick.
  - Full-width aspect-ratio media viewports with smooth blur/shimmer loaders and rounded inner corners (16dp).
  - Floating and inline action controls: heart/like button with reactive animation, comment trigger with counter, share, and bookmark.
  - Polished quick-creation FAB/bar with expressive shape (flutter_m3shapes).

### R2. Settings Master-Detail Architecture & Pure M3 Overhaul
- Transform Settings on desktop/wide screens into an ergonomic 2-pane (Master-Detail) layout:
  - Left pane (320-360dp): expressive list of settings sections (Аккаунт, Внешний вид, Приватность и безопасность, Хранилище, Язык и регион, Уведомления, О приложении, E2EE) with active highlight indicator (secondaryContainer).
  - Right pane (expanded): direct in-place rendering of the selected settings sub-screen without forcing deep navigation.
  - On mobile: seamless fallback to classic full-screen stacked navigation.
- Overhaul ALL individual settings screens (settings_account_screen.dart, settings_appearance_screen.dart, settings_privacy_screen.dart, settings_storage_screen.dart, settings_language_region_screen.dart, settings_preferences_screen.dart, settings_about_screen.dart, e2ee_settings_screen.dart, profile_screen.dart):
  - Standardize on M3 Expressive grouped cards (surfaceContainerLow, 20dp radius).
  - Use Switch.adaptive, segmented buttons, and tonal sliders.
  - Expressive leading icons wrapped in distinct tonal squircle containers.

### R3. SVG & Vector Illustrations Integration
- Eliminate empty or flat placeholder elements across NiosGram and Settings.
- Embed crisp SVG/vector icons and illustrations for:
  - Empty feed states ("Лента пуста", "Здесь появятся ваши публикации").
  - Media placeholder states with soft tinted vector graphics.
  - Settings section headers and visual indicators.

### R4. Responsive Polish & Quality
- Eliminate all layout overflow errors across screen resize events (from 360dp mobile to 1920dp+ 4K).
- Zero flutter analyze errors or warnings.
- Build and verify for Web (flutter build web --profile).

## Acceptance Criteria

### Visual & Interactive Quality
- [ ] NiosGram feed on desktop expands to an expressive 720-800dp card layout with zero awkward dead margins.
- [ ] Settings on desktop displays as a 2-pane Master-Detail layout with instant switching.
- [ ] All 8+ settings screens strictly use Material 3 Expressive surfaces (surfaceContainerLow), switches, sliders, and tonal icon containers.
- [ ] Empty feed and loading placeholders feature rich vector/SVG assets instead of plain grey boxes.
- [ ] flutter analyze reports 0 issues (zero warnings, zero errors).
- [ ] Application compiles and runs cleanly in web (flutter build web --profile).

## 2026-09-04T09:54:05Z

Execute the complete end-to-end multi-agent performance optimization of the graphics pipeline, message lists, and media caching for NiosMess (pulse_flutter) for stable and smooth 60/120 FPS adaptive frame rate performance across both budget and flagship devices.

Requirements:
- R1. Smart Adaptive Performance Engine (jank detection, adaptive degradation/enhancement of shaders, MeshGradient, BackdropFilter, M3 Expressive)
- R2. List Virtualization Optimization & Dynamic Memory Management (smooth 60/120 FPS scroll in chat_detail_screen, chat_list_screen, NiosGram post_card, adaptive image decoding with memCacheWidth/Height, RepaintBoundary, viewport eviction, Riverpod select rebuild prevention)
- R3. Background Energy Efficiency & Resource Leak Elimination (controllers, websockets, timers audit and cleanup)

Strictly adhere to f:\Niosmess V2\AGENTS.md, maintain your plan.md, progress.md, and BRIEFING.md in f:\Niosmess V2\.agents\orchestrator_5.
Dispatch specialized subagents (explorers, workers, reviewers, challengers, etc.). NOTE: when invoking subagents, specify Model: 'flash' to preserve quota.
Ensure all tests pass and flutter analyze reports 0 issues. Update pubspec.yaml following SemVer protocol.
When work is complete and verified by your team, report completion to the Sentinel via send_message.

## 2026-09-07T10:10:53Z

Реализация первой фазы масштабного обновления NiosMess — Базовое ядро мессенджера (Phase 1: Core Messenger Suite) в строгом соответствии со спецификацией NIOSMESS_NEW_FEATURES_API.md и согласованными архитектурными решениями.

Working directory: f:\Niosmess V2\pulse_flutter
Integrity mode: development
Specification reference: f:\Niosmess V2\NIOSMESS_NEW_FEATURES_API.md

## Архитектурные требования Фазы 1

### R1. Полноценная экосистема стикеров и стикерпаков (Full Sticker Suite)
- Сетевой слой и WebSocket (/ws/gateway):
  - list_sticker_sets: получение коллекции наборов стикеров пользователя (id, name, title, is_public, stickers).
  - create_sticker_set: создание набора (name, title, is_public). Первый добавленный стикер автоматически выступает обложкой набора.
  - add_sticker: загрузка стикера (set_id, filename, data_base64, width, height, duration_seconds, emoji). Поддержка статических изображений (PNG, WebP до 5 МБ) и анимированных/видео (WebM, MP4, GIF до 10 сек и 25 МБ).
  - send_sticker: отправка стикера (chat_id, sticker_id). Сообщение сохраняется и передается с msg_type: "sticker" и вложенным объектом sticker.
  - save_sticker_set / remove_sticker_set: сохранение публичного набора в коллекцию пользователя и удаление из неё (delete_permanently: true доступно только автору пака).
  - delete_sticker: удаление конкретного стикера автором.
- Интерфейс и UX (Material 3 Expressive):
  - Интерактивная панель выбора стикеров в строке ввода сообщений (рядом с эмодзи) с вкладками установленных паков и плавной сеткой предварительного просмотра.
  - Модальный просмотр стикерпака (Sticker Set Modal) по тапу на любой стикер в чате с возможностью установки пака в 1 клик («Добавить стикерпак») либо удаления из коллекции.
  - Диалог/экран создания собственного стикерпака и добавления файлов с привязкой к эмодзи.
  - Оптимизированный рендеринг стикеров в MessageBubble без лишних рамок бабла, с поддержкой плавной зацикленной анимации/видео и кэширования.

### R2. Профиль, рабочее время и бейджи (Profile, Schedule & Badges)
- Сетевой слой:
  - update_profile: расширенные поля phone_number, birthday, bio, display_name, username, а также working_hours (объект с timezone и массивами временных интервалов по дням mon–sun).
  - get_my_badges, set_visible_badges: получение списка доступных бейджей и закрепление до двух видимых в профиле (badge_ids).
  - upload_avatar: поддержка видеоаватаров длительностью до 5 секунд (клиентская обрезка до квадрата 1:1 перед отправкой, до 8 МБ).
- Интерфейс и UX:
  - Интерактивный недельный планировщик рабочих часов в настройках профиля с удобным добавлением интервалов (через Material 3 TimePicker).
  - Динамический бейдж статуса в профиле пользователя («Открыто до 18:00», «Закрыто», «Откроется в пн 09:00») и раскрывающийся график на неделю.
  - Селектор закрепленных бейджей пользователя.

### R3. Конфиденциальность и черный список (Privacy Policies & Blocklist)
- Сетевой слой:
  - get_privacy, set_privacy для 12 ключей: phone, last_seen, profile_photos, forwards, calls, voice_messages, messages, birthday, gifts, bio, saved_music, invites.
  - Политики: everyone, contacts, nobody с явными исключениями always_allow и never_allow (до 500 ID в каждом).
  - block_user, unblock_user, list_blocked_users. Защита Support от блокировки.
- Интерфейс и UX:
  - Редизайн settings_privacy_screen.dart: группировка по категориям («Связь», «Личные данные», «Активность»).
  - Отдельный экран настройки каждого правила с селектором политики и управлением белыми/черными списками исключений.
  - Раздел «Заблокированные пользователи» с мгновенным поиском и кнопкой быстрой разблокировки.
  - Пункт «Заблокировать» в профиле и контекстном меню диалогов.

### R4. Группы, ссылки-приглашения, автоудаление и модерация (Groups & Moderation)
- Сетевой слой:
  - Поддержка is_private: true при создании и редактировании чатов, приватные ссылки /u/+TOKEN.
  - update_chat: настройка auto_delete_seconds (от 60 секунд до 365 дней, null — отключено).
  - mute_member, ban_member: с указанием duration_seconds и обязательной причины reason. Защита создателя и старших администраторов от действий младших.
- Интерфейс и UX:
  - Генерация, копирование и шеринг ссылки /u/+TOKEN в информации о частной группе/канале.
  - Настройка срока автоудаления сообщений с пресетами (24 часа, 7 дней, 1 месяц, свой срок) и отображение иконки таймера в заголовке чата.
  - Bottom Sheet модерации участника («Замутить», «Заблокировать в группе») с быстрыми сроками (1ч, 24ч, 7д, навсегда) и полем ввода причины.

### R5. Жалобы, поддержка и спамблок (Reports, Support & Spamblock UI)
- Сетевой слой:
  - report: поддержка новых причин жалоб: copyright, doxing, swatting.
  - create_support_ticket: создание тикетов поддержки (support, copyright).
  - Системный чат Support: верифицированный статус, специальная обработка сообщений /copyright.
- Интерфейс и UX:
  - Расширение диалога отправки жалоб новыми категориями.
  - При получении временного ограничения аккаунта (спамблок): информационный баннер над полем ввода чатов с указанием причины, точного таймера окончания блокировки и блокировкой отправки.

## Acceptance Criteria (Критерии приёмки)
- [ ] Все WebSocket actions для стикеров, профиля, приватности, модерации и жалоб протестированы и точно соответствуют протоколу NIOSMESS_NEW_FEATURES_API.md.
- [ ] Стикеры корректно отправляются, принимаются и отображаются в MessageBubble для всех типов чатов.
- [ ] Заблокированные пользователи не могут взаимодействовать с инициатором блокировки.
- [ ] Приватные ссылки /u/+TOKEN корректно генерируются и обрабатываются роутером.
- [ ] Таймер автоудаления и ограничения модерации сохраняются и передаются на сервер.
- [ ] Шторка стикеров и эмодзи работает плавно с кэшированием и быстрой пагинацией.
- [ ] Экран приватности и списков исключений адаптирован под мобильные и десктопные/веб экраны.
- [ ] Планировщик рабочих часов интуитивен и валидирует корректность интервалов времени.
- [ ] Баннер спамблока отображает точный обратный отсчет в локальном часовом поясе пользователя.
- [ ] flutter analyze выполняется с 0 ошибок и 0 предупреждений.
- [ ] Все существующие и новые unit/widget тесты успешно проходят (flutter test).
- [ ] Производительность скролла чатов сохраняет 60/120 FPS без просадок при появлении стикеров.
- [ ] Версия приложения в pubspec.yaml повышена в соответствии с SemVer Protocol.

## 2026-09-07T11:47:12Z

Реализация второй фазы масштабного обновления NiosMess — Боты, NiosGram Мультимедиа, Глобальный поиск, WebRTC Звонки и E2EE v1 (Phase 2: Ecosystem & Media Suite) в строгом соответствии со спецификацией NIOSMESS_NEW_FEATURES_API.md.

Working directory: f:\Niosmess V2\pulse_flutter
Integrity mode: development
Specification reference: f:\Niosmess V2\NIOSMESS_NEW_FEATURES_API.md

## Архитектурные требования Фазы 2

### R1. Боты, цветные инлайн-кнопки и инлайн-режим (Bots & Inline Queries)
- Сетевой слой и WebSocket (/ws/gateway):
  - inline_query: отправка поискового запроса боту (chat_id, bot_username, query). Обработка первого ответа (inline_query_id, expires_in).
  - Прием серверного push-события inline_query_results (inline_query_id, chat_id, results: массив с id, type, title, description, message_text).
- Интерфейс и UX (Material 3 Expressive):
  - Инлайн-ввод в строке чата: при наборе текста вида @bot_username <запрос> автоматически отправляется запрос с debounce (300 мс).
  - Всплывающая плашка результатов (Floating Results Overlay) над строкой ввода с плавным списком найденных вариантов.
  - Тап по результату мгновенно отправляет message_text в текущий чат как обычное сообщение без открытия диалога с ботом.
  - Инлайн-кнопки под сообщениями ботов с поддержкой стилей style: default, primary, success, warning, danger и url-ссылок.
  - Блокировка звонков ботам и ограничение первого сообщения для не-verified ботов.

### R2. NiosGram: мультимедиа-посты и реактивные реакции (Feed & Reactions)
- Сетевой слой:
  - create_post: поддержка массива upload_ids (до 5 изображений по 5 МБ либо одно видео до 10 сек и 25 МБ). Внутренние AI-теги сохраняются отдельно и не выводятся в тексте поста.
  - react_post: отправка реакции (post_id, reaction: like / dislike). Ответ сервера возвращает likes, dislikes, my_reaction.
- Интерфейс и UX:
  - Карусель изображений в карточке поста (post_card.dart) с точечным индикатором страниц (page indicator) и плавным свайпом.
  - Реактивное обновление счетчиков лайков и дизлайков на месте без перезагрузки всей ленты. Повторный тап снимает реакцию. Дизлайк понижает приоритет в рекомендациях.

### R3. 4-секционный глобальный поиск и диплинки (Global Search & Deep Linking)
- Сетевой слой:
  - search: запрос глобального поиска по ключевому слову. Разбор 4 категорий в ответе: users, chats, messages, posts.
- Интерфейс и UX:
  - Экран глобального поиска с фильтрацией по категориям (Сегментированные кнопки / Табы M3: Все, Люди, Чаты, Сообщения, Посты).
  - Deep-linking маршрутизация в app_router.dart:
    - /u/:username — переход в личный диалог с пользователем;
    - /u/:groupname — открытие публичной группы или канала;
    - /u/+TOKEN — автоматическое принятие приватного инвайта;
    - /g/:username — переход в профиль NiosGram;
    - Обработка URL-схемы niosmess://.

### R4. WebRTC Звонки: шлюз, сигнализация и лимиты (Calls Gateway & Signaling)
- Сетевой слой:
  - start_call и join_call: разбор параметров шлюза (call_access_token, signal_url, ice_servers, max_video_height, max_duration_seconds).
  - Учёт тарифов: 480p и 30 минут для обычных пользователей; 720p и безлимитная длительность для пользователей с ролью Calls Tester.
  - Автоматическое завершение звонка при 3-минутном одиночном ожидании.
  - Обработка входящего звонка через событие WebSocket new_call и системное сообщение system_event_type: "call".
  - Режим «слушатель» при отсутствии камеры или микрофона.

### R5. Секретные чаты: 12 цветных слов безопасности (E2EE v1 Safety Words)
- Интерфейс и безопасность:
  - Детерминированная генерация 12 цветных слов для сверки ключа безопасности между собеседниками в окне информации о секретном чате.
  - Явное обозначение совместимого протокола как E2EE v1 в интерфейсе.

## Критерии приёмки (Acceptance Criteria)

### Functional & Protocol Quality
- [ ] Инлайн-запросы @bot_username query отправляют action: inline_query и отображают результаты в плавающей плашке над вводом.
- [ ] Сообщения ботов поддерживают кнопки со всеми пятью стилями (default, primary, success, warning, danger) и url.
- [ ] Карточки NiosGram поддерживают карусель до 5 изображений, скрывают AI-теги и обновляют реакции (like/dislike) на месте без мерцания.
- [ ] Глобальный поиск возвращает и корректно группирует результаты по 4 категориям (users, chats, messages, posts).
- [ ] Deep-link роуты (/u/..., /u/+TOKEN, /g/..., niosmess://) перенаправляют пользователя в целевой экран.
- [ ] Звонки учитывают ограничения разрешения (480p / 720p) и длительности (30 мин / безлимит), а также 3-минутный таймаут ожидания.
- [ ] В деталях секретного чата отображаются 12 цветных слов безопасности E2EE v1.

### Code Quality & Static Analysis
- [ ] flutter analyze выполняется с 0 ошибок и 0 предупреждений.
- [ ] Все существующие и новые unit/widget тесты успешно проходят (flutter test).
- [ ] Строгое соблюдение Material 3 Expressive (никаких hardcoded Colors.white/Colors.black или withOpacity()).
- [ ] Отсутствие прямых импортов dart:io (использование package:universal_io/io.dart).
- [ ] Версия приложения в pubspec.yaml повышена в соответствии с SemVer Protocol.


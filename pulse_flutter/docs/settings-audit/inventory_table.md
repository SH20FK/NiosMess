# NiosMess — Инвентаризация настроек (Фаза 0)

| # | Поле в `UiSettingsState` | Ключ SharedPreferences | Где читается в UI настроек | Реальные потребители в приложении | Статус | Примечание |
|---|---|---|---|---|---|---|
| 1 | `themeMode` | `ui.themeMode` | `settings_appearance_screen.dart`, `profile_screen.dart` | `app_theme.dart`, `main.dart` | **Живой** | В `settings_appearance_screen.dart` переключатель был бинарным (Light/Dark), делая `ThemeMode.system` недостижимым (баг C3). |
| 2 | `seedColor` | `ui.seedColor` | `settings_appearance_screen.dart`, `profile_screen.dart` | `app_theme.dart`, `main.dart` | **Живой** | Генерирует тональные палитры Material 3. |
| 3 | `notifications` | `ui.notifications` | `settings_preferences_screen.dart` | `backend_chat_provider.dart:831, 1378`, `in_app_notification_provider.dart:43` | **Частичный** | Блокирует локальные in-app всплывашки и звук сообщений при открытом приложении, но не отписывает топики FCM/APNs на уровне системы (C6). |
| 4 | `compactMode` | `ui.compact` | `settings_preferences_screen.dart` | `chat_list_screen.dart:451`, `contacts_screen.dart:187` | **Частичный** | Уменьшает паддинги только в списке чатов и контактов; в остальных списках не работает (C10). |
| 5 | `haptics` | `ui.haptics` | `settings_preferences_screen.dart` | `haptic_service.dart:14`, `settings_ui.dart` | **Живой** | Глобально отключает виброотклик `HapticService`. |
| 6 | `hideOnline` | `ui.hideOnline` | `settings_preferences_screen.dart`, `settings_privacy_screen.dart:175` | *Нет потребителей вне настроек* | **Мёртвый / Дубликат** | Дублирует и ломает серверное правило `last_seen` (B6, C8). Подлежит удалению в пользу серверного правила. |
| 7 | `soundEffects` | `ui.soundEffects` | `settings_preferences_screen.dart` | `app_sound.dart:55` | **Живой** | Глобально отключает звук кликов и реакций в `AppSoundService`. |
| 8 | `soundVolume` | `ui.soundVolume` | `settings_preferences_screen.dart` | `app_sound.dart:58` | **Живой** | Управляет громкостью аудиоэффектов интерфейса. |
| 9 | `localeCode` | `ui.localeCode` | `settings_language_region_screen.dart`, `profile_screen.dart` | `main.dart` | **Живой** | Принудительно задает русскую или английскую локаль. |
| 10 | `timeZoneMode` | `ui.timeZoneMode` | `settings_language_region_screen.dart`, `profile_screen.dart` | `profile_repository.dart` | **Живой** | Определяет автоматический или ручной расчет часового пояса для рабочих часов. |
| 11 | `timeZoneId` | `ui.timeZoneId` | `settings_language_region_screen.dart`, `profile_screen.dart` | `profile_repository.dart` | **Живой** | Идентификатор часового пояса (IANA). |
| 12 | `optimizeForWeakDevices` | `ui.optimizeWeak` | `settings_preferences_screen.dart` | `adaptive_performance_provider.dart` | **Частичный** | Конфликтует с автоматическим определением производительности устройства (C11). |
| 13 | `predictiveBackEnabled` | `ui.predictiveBack` | `settings_appearance_screen.dart` | `app_router.dart`, `predictive_back_wrapper.dart` | **Живой** | Активирует предиктивный жест возврата Android 14+. |
| 14 | `predictiveBackStrength` | `ui.predictiveBackStrength` | `settings_appearance_screen.dart` | `predictive_back_wrapper.dart` | **Живой** | Коэффициент пружинной трансформации предиктивного жеста. |
| 15 | `backgroundMode` | `ui.backgroundMode` | `settings_privacy_screen.dart` | `background_service.dart` | **Живой, но плохой UI** | Включает фоновый сервис `BackgroundService.startReliable()`, но в UI был нарисован двумя независимыми противоречащими тумблерами (B7, B8). |
| 16 | `useSystemDynamic` | `ui.useSystemDynamic` | `settings_appearance_screen.dart` | `app_theme.dart` | **Живой** | Включает динамические системные цвета Monet (Android 12+). |
| 17 | `fontScale` | `ui.fontScale` | `settings_appearance_screen.dart` | `main.dart` | **Живой** | Масштабирует системный `textScaleFactor`. |
| 18 | `navBarFloating` | `ui.navBarFloating` | `settings_appearance_screen.dart` | `main_shell_screen.dart` | **Живой** | Переключает режим нижней панели навигации (прикрепленная / парящая). |
| 19 | `pureBlackOled` | `ui.pureBlackOled` | `settings_appearance_screen.dart` | `app_theme.dart` | **Живой** | Устанавливает глубокий черный `#000000` для OLED экранов в темной теме. |
| 20 | `sendOnEnter` | `ui.sendOnEnter` | `settings_chats_screen.dart` | `chat_detail_input_area.dart:676` | **Живой** | Обрабатывает нажатие Enter для отправки на физической клавиатуре. |
| 21 | `doubleTapReactionEmoji` | `ui.doubleTapReactionEmoji` | `settings_chats_screen.dart` | `chat_message_list.dart:344` | **Живой** | Эмодзи для быстрой реакции двойным тапом по сообщению. |
| 22 | `autoDownloadWifi` | `ui.autoDownloadWifi` | `settings_chats_screen.dart` | *Нет потребителей в загрузчике медиа* | **Мёртвый** | Значение сохраняется в `prefs`, но сетевой слой и кэш медиа его не используют (C2). |
| 23 | `autoDownloadCellular` | `ui.autoDownloadCellular` | `settings_chats_screen.dart` | *Нет потребителей в загрузчике медиа* | **Мёртвый** | Значение сохраняется в `prefs`, но сетевой слой и кэш медиа его не используют (C2). |
| 24 | `messageBubbleRadius` | `ui.messageBubbleRadius` | `settings_appearance_screen.dart` | `message_bubble.dart:150` | **Живой** | Задает радиус скругления пузырей сообщений в чате. |
| 25 | `uiCornerRadius` | `ui.cornerRadius` | `settings_appearance_screen.dart` | *Нет потребителей в приложении* | **Мёртвый** | Ни один компонент или тема не читает этот радиус (C1). |
| 26 | `camera2Api` | `ui.camera2Api` | `settings_chats_screen.dart` | `circle_video_recorder_screen.dart:207`, `quick_camera_capture_screen.dart:97` | **Частичный** | Переключает быстрый вызов `setDescription` вместо полного `_reinitializeController`, но название в UI («Camera2 API») вводит в заблуждение (C7). |

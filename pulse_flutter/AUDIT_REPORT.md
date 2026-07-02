# Аудит приложения pulse_flutter

━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 СТРУКТУРА
━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Какие экраны есть в приложении?**
В приложении реализовано 34 экрана (находятся в `lib/screens/`). Среди них:
- **Авторизация/Регистрация:** `LoginScreen`, `RegisterScreen`, `VerifyEmailScreen`, `TwoFaScreen`, `OnboardingScreen`, `SetupOnboardingScreen`, `ResetPasswordRequestScreen`, `ResetPasswordConfirmScreen`.
- **Чаты и Контакты:** `ChatListScreen`, `ChatDetailScreen` (а также дублирующий его `ChatDetailScreenFixed`), `ChatManageScreen`, `ChatMembersScreen`, `ContactsScreen`, `ContactDetailScreen`, `CreateChatScreen`, `DirectChatResolverScreen`, `JoinChatScreen`.
- **Профиль и Настройки:** `ProfileScreen`, `PublicProfileScreen`, `SettingsHomeScreen`, `SettingsAppearanceScreen`, `SettingsAccountScreen`, `SettingsStorageScreen`, `SettingsPrivacyScreen`, `SettingsLanguageRegionScreen`, `SettingsAboutScreen`, `SettingsDebugScreen`.
- **Прочее:** `MainShellScreen`, `SplashScreen`, `SessionsScreen`, `DevelopersScreen`, `MediaViewerScreen`, `PostCommentsScreen`.

**Какие виджеты есть и где они используются?**
В папке `lib/widgets/` находится 41 виджет. Основные категории:
- **Переиспользуемые UI-элементы:** `AppBottomNav`, `PulseButton`, `PulseAvatar`, `BadgeChip`, `PulseLoadingIndicator`, `GlassCard`. Используются повсеместно для соблюдения единого дизайн-кода.
- **Компоненты чатов:** `ChatTile`, `MessageBubble`, `CallBubble`, `FileAttachmentChip`, `FileUploadProgressWidget`.
- **Вспомогательные экраны/Обертки (Bottom Sheets):** `M3FilePickerBottomSheet`, `M3FilePreviewBottomSheet`.
- **Структура и состояния:** `PulseScaffoldBody` (кастомный скролл/фон), `PulseSkeleton` (состояния загрузки, например, `ChatListSkeleton`, `MessageListSkeleton`), `SettingsUi` компоненты (секции и плитки для экранов настроек).

**Какой state management используется и как устроен?**
Используется **Riverpod** (`flutter_riverpod`).
- Управление состоянием реализовано через `Notifier` и `AsyncNotifier`.
- Провайдеры лежат в `lib/providers/`: `authProvider` (AuthNotifier), `chatsProvider` (ChatsNotifier), `chatMessagesProvider`, `uiSettingsProvider` и другие.
- В UI активно используются `ConsumerStatefulWidget` и `ConsumerWidget` для прослушивания состояния.

**Как устроена работа с сетью?**
- Сетевой слой реализован через собственный класс `ApiClient` (в `lib/core/network/api_client.dart`), который оборачивает стандартный `package:http/http.dart`.
- Клиент поддерживает `GET`, `POST`, `PATCH`, `DELETE` и `postMultipart` для отправки файлов. 
- Имплементированы таймауты (10 секунд), автоматическое прокидывание токенов (Bearer), парсинг JSON в изоляте (через `compute`), а также перехват 401 ошибки через callback.
- Запросы инкапсулированы в репозиториях в `lib/repositories/` (`chat_repository.dart`, `auth_repository.dart`, `call_repository.dart`, `search_repository.dart`).

**Какие модели данных есть?**
Модели лежат в `lib/models/api/`. Все они являются дата-классами для API:
- `message_model.dart` (ApiMessage)
- `auth_models.dart` 
- `chat_summary_model.dart` (ApiChatSummary)
- `chat_member_model.dart`
- `profile_model.dart`
- `session_model.dart`
- `call_models.dart`, `search_models.dart`, `badge_model.dart`, `invite_models.dart`, `chat_actions_models.dart`, `upload_models.dart`.

━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 ЧТО НАЙТИ
━━━━━━━━━━━━━━━━━━━━━━━━━━━

- **Дублирующийся код:** Файлы `chat_detail_screen.dart` и `chat_detail_screen_fixed.dart` полностью дублируют функционал одного и того же экрана.
- **Мёртвый код:** Дублирующийся `chat_detail_screen_fixed.dart` является кандидатом на удаление (или наоборот, основной файл, если `fixed` — это правильная версия).
- **Захардкоженные строки и цвета:** В коде много прямого использования `Text("...")` и `Color(...)` в обход системы локализации `l10n` и `Theme.of(context)`. Например, захардкоженные цвета есть в `badge_chip.dart`, `call_bubble.dart`, `developers_screen.dart`, `settings_appearance_screen.dart`. Захардкоженные строки присутствуют в `chat_detail_screen.dart`, `chat_list_screen.dart`, `profile_screen.dart`, `message_bubble.dart` и многих других файлах.
- **Пустые catch:** Найдены блоки `catch (e) {}` без обработки (или логирования) в файлах:
  - `core/sound/app_sound.dart`
  - `core/storage/local_storage_service.dart`
  - `providers/auth_provider.dart`
  - `providers/backend_chat_provider.dart`
- **Места без loading state:** При отправке запроса на создание чата (`create_chat_screen.dart` -> `_submit`) кнопка меняет текст, но полноценного визуального лоадера (крутилки) нет. Аналогично в `post_comments_screen.dart` метод `_send` не показывает индикатор загрузки, а только блокирует поле ввода.
- **Места без empty state:** В основных экранах (список чатов, список комментариев) состояния пустого списка (`isEmpty`) обрабатываются и показывают виджеты-плейсхолдеры (`_CenteredNote`). Однако, если детально исследовать весь апп, то в некоторых побочных списках или при ошибках могут отсутствовать заглушки (ограничиваются только текстом ошибки).
- **Экраны без обработки back button на Android:** Почти везде отсутствует `PopScope` / `WillPopScope` для перехвата системной кнопки "Назад" или свайпа назад. 32 экрана не имеют этой обработки, в том числе критические экраны типа `chat_detail_screen.dart`, `create_chat_screen.dart`, `post_comments_screen.dart`.
- **TODO и FIXME комментарии:** Настоящих комментариев TODO/FIXME в коде не найдено (поиск обнаружил только метод `toDouble()`).

━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 ФОРМАТ ОТЧЁТА 
━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 1. КАРТУ ПРИЛОЖЕНИЯ
- **Сплэш / Вход:** `SplashScreen` -> `OnboardingScreen` / `LoginScreen` / `RegisterScreen`.
- **Main Shell (AppBottomNav):** 
  - вкладка "Чаты" -> `ChatListScreen` -> `ChatDetailScreen` -> `ChatManageScreen` / `ChatMembersScreen` / `MediaViewerScreen`.
  - вкладка "Контакты" -> `ContactsScreen` -> `ContactDetailScreen`.
  - вкладка "Настройки" -> `SettingsHomeScreen` -> `SettingsAccountScreen` / `SettingsAppearanceScreen` / `SettingsStorageScreen` / `ProfileScreen` и др.
- **Отдельные пути:** Создание чата (`CreateChatScreen`), Вступление по ссылке (`JoinChatScreen`), Комментарии (`PostCommentsScreen`).

### 2. ЧТО РЕАЛИЗОВАНО
- Полноценная аутентификация, профиль, сессии, Two-Factor Auth.
- Получение списка чатов, фильтрация (группы, каналы, боты).
- Чат 1-1, групповой чат, комментарии в каналах.
- Скелетон-загрузки (Skeleton UI) в списках и деталях чатов.
- Поддержка прикрепления файлов (M3FilePickerBottomSheet).
- Настройки: темизация (светлая/темная, выбор цвета), хранилище, приватность, локализация.
- Riverpod с кэшированием (AsyncValue) для отображения UI.

### 3. ЧТО СЛОМАНО
- **Обработка кнопки "Назад" (Android):** Отсутствие `PopScope` может привести к неожиданному закрытию критичных модальных окон или экранов (например, при загрузке файлов или записи аудио).
- **Дубликаты экранов:** Наличие `chat_detail_screen_fixed.dart` говорит о "забытом" коде после рефакторинга. Приводит к рассинхрону в случае правок.
- **Пропущенные исключения (пустые catch):** Ошибки со звуком или хранилищем могут происходить тихо, что усложнит дебаг для пользователей.

### 4. ЧТО ОТСУТСТВУЕТ
- Индикаторы загрузки (spinners) на некоторых активных действиях (отправка сообщения, создание чата).
- Явная обработка потери соединения (SocketException/TimeoutException) в самом UI (приложение может просто зависнуть или молча выдать Snackbar, но не имеет отдельного Offline-state виджета).
- Архитектурная поддержка WebSocket в просмотренных файлах (только Http polling и Future запросы), что может быть проблемой для мессенджера (требуется Real-time).

### 5. ТЕХНИЧЕСКИЙ ДОЛГ
- **Захардкоженные стили и тексты:** Строки вне файлов локализации (`l10n`) сделают мучительным процесс перевода приложения на новые языки. Использование `Color(0x...)` вместо `Theme.of(context).colorScheme` ломает поддержку динамических тем (Material You / Dynamic Color).
- **Polling:** В `chat_list_screen.dart` используется `AdaptivePoller` для опроса сервера вместо Socket/SSE, что неэффективно для сети и батареи.
- **Очистка мёртвого кода:** Требуется удалить `chat_detail_screen_fixed.dart` (или объединить его с оригиналом).
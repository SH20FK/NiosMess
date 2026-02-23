# NiosMess — Полное техническое описание

## 📋 Содержание
1. [Общая информация](#общая-информация)
2. [Дизайн-система](#дизайн-система)
3. [Архитектура приложения](#архитектура-приложения)
4. [Модели данных](#модели-данных)
5. [API и бэкенд](#api-и-бэкенд)
6. [State Management](#state-management)
7. [Навигация](#навигация)
8. [Уникальные фичи](#уникальные-фичи)
9. [Технический стек](#технический-стек)

---

## Общая информация

**Название:** NiosMess  
**Тип:** Мессенджер (кроссплатформенное приложение)  
**Платформы:** Android, iOS, Windows, macOS, Linux, Web  
**Архитектура:** Clean Architecture + Riverpod  
**Язык:** Dart (Flutter)  
**Версия:** 0.1.0  

---

## Дизайн-система

### Цветовая палитра (NiosPalette)

```dart
// Основные цвета
background: Color(0xFF0E1621)      // Тёмный фон
surface: Color(0xFF17212B)         // Карточки, панели
surfaceAlt: Color(0xFF1E2A36)      // Альтернативный фон
surfaceHover: Color(0xFF2B3A4A)    // Hover состояния

// Акценты
accent: Color(0xFF2B7AE8)          // Основной акцент (синий)
accentHover: Color(0xFF3A8CE8)     // Hover акцента
accentLight: Color(0xFF5BA3F0)     // Светлый акцент

// Текст
text: Color(0xFFFFFFFF)            // Основной текст
textSecondary: Color(0xFF8A9AA8)  // Вторичный текст
textMuted: Color(0xFF6C7A89)       // Приглушённый текст

// Статусы
online: Color(0xFF4CAF50)          // Онлайн (зелёный)
unread: Color(0xFF2B7AE8)          // Непрочитанные
error: Color(0xFFE53935)           // Ошибки
```

### Типографика

```dart
// Шрифт: Inter (Google Fonts)
displayLarge: 57px, w700, -0.5 letter  // Заголовки
displayMedium: 45px, w600              // Подзаголовки
headlineLarge: 32px, w600               // Названия экранов
titleLarge: 22px, w600                  // Заголовки секций
bodyLarge: 16px, w400                   // Основной текст
bodyMedium: 14px, w400                   // Вторичный текст
labelLarge: 14px, w500                   // Кнопки, лейблы
```

### Компоненты UI

#### 1. NiosCard
```dart
NiosCard(
  padding: EdgeInsets.all(16),
  child: Widget,
)
// Скругление: 16px
// Фон: surface
// Тень: subtle
```

#### 2. NiosButton
```dart
NiosButton(
  text: 'Отправить',
  onPressed: () {},
  variant: NiosButtonVariant.primary, // primary/secondary/ghost
)
// Скругление: 12px
// Высота: 48px
```

#### 3. NiosInput
```dart
NiosInput(
  hint: 'Сообщение',
  controller: _controller,
  multiline: true,
)
// Скругление: 20-24px
// Фон: surfaceAlt
```

### Размеры и отступы

```dart
// 8px grid system
xs: 4px   // Микро-отступы
sm: 8px   // Маленькие
md: 16px  // Средние
lg: 24px  // Большие
xl: 32px  // Экстра большие
xxl: 48px // Секции

// Скругления
radiusSm: 8px
radiusMd: 12px
radiusLg: 16px
radiusXl: 24px  // Для input полей
radiusFull: 999px // Круглые элементы
```

---

## Архитектура приложения

### Структура папок

```
lib/
├── core/                    # Ядро приложения
│   ├── models/             # Модели данных
│   ├── repositories/       # API репозитории
│   ├── providers/          # Riverpod провайдеры
│   ├── services/           # Сервисы (notifications, etc.)
│   ├── storage/            # Локальное хранилище
│   ├── theme.dart          # Тема приложения
│   ├── constants.dart      # Константы
│   └── app_router.dart     # Навигация
├── features/               # Фичи (экраны)
│   ├── auth/              # Авторизация
│   ├── chats/             # Список чатов
│   ├── chat/              # Экран чата
│   ├── settings/          # Настройки
│   ├── profile/           # Профиль
│   ├── groups/            # Группы
│   └── onboarding/        # Онбординг
├── ui/                     # UI компоненты
│   ├── widgets/           # Переиспользуемые виджеты
│   └── nios_ui.dart       # Базовые компоненты
└── main.dart              # Точка входа
```

### Clean Architecture

```
Presentation Layer (UI)
    ↓
State Layer (Riverpod Providers)
    ↓
Domain Layer (Models, Use Cases)
    ↓
Data Layer (Repositories, API)
    ↓
External Layer (Backend API)
```

---

## Модели данных

### MessageItem (Сообщение)

```dart
class MessageItem {
  final String id;           // Уникальный ID
  final String sender;       // Отправитель (username)
  final String text;         // Текст сообщения
  final String time;         // Время отправки
  final String? type;        // Тип: text, image, file, voice, location, contact, poll
  final String? replyToId;   // ID сообщения для ответа
  final Map<String, dynamic>? meta; // Метаданные (файлы, локация и т.д.)
  final bool isPinned;       // Закреплено ли
  final bool isRead;         // Прочитано ли
  final bool isOutgoing;     // Исходящее ли (от меня)
}
```

### ChatItem (Чат)

```dart
class ChatItem {
  final String id;           // ID чата
  final String name;         // Название/имя
  final String type;         // Тип: private, group, channel
  final int unread;          // Количество непрочитанных
  final String? username;    // Username (для private)
  final bool? isOnline;      // Онлайн статус
  final String? lastSeenText; // "был 5 минут назад"
  final String? avatarUrl;   // URL аватара
  final String? badgeTitle;  // Заголовок бейджа
  final String? badgeText;   // Текст бейджа
  final String? badgeIcon;   // Иконка бейджа
  final bool isPinned;       // Закреплён ли чат
}
```

### Reaction (Реакция)

```dart
class Reaction {
  final String emoji;        // Emoji код
  final String userId;       // Кто поставил
  final DateTime timestamp;  // Когда
}
```

### LinkPreview (Превью ссылки)

```dart
class LinkPreview {
  final String url;          // URL
  final String? title;       // Заголовок
  final String? description; // Описание
  final String? imageUrl;    // Картинка
  final String? siteName;    // Название сайта
}
```

### DisappearingMessage (Исчезающее сообщение)

```dart
class DisappearingMessage {
  final String messageId;    // ID сообщения
  final int ttlSeconds;      // Время жизни в секундах
  final DateTime createdAt;  // Время создания
  final DateTime? expiresAt; // Время удаления
}
```

---

## API и бэкенд

### Базовый URL
```dart
const String apiBaseUrl = 'http://your-server:8000';
```

### Аутентификация

#### Регистрация (2 шага)
```http
POST /register
Body: {
  "email": "user@example.com",
  "password": "password",
  "username": "user123",
  "name": "User Name"
}
→ Отправляет код на email

POST /register (с кодом)
Body: {
  ... + "code": "123456"
}
→ Создаёт аккаунт, возвращает token
```

#### Вход
```http
POST /login
Form: username, password
→ Возвращает token, user_id
```

#### Проверка сессии
```http
POST /check_session
Body: username, token
→ Возвращает активна ли сессия
```

### Сообщения

#### Отправить сообщение
```http
POST /send_message
Body: {
  "token": "...",
  "sender": "user1",
  "receiver": "user2",
  "text": "Привет!",
  "reply_to": 123,        // опционально
  "ttl_seconds": 60,      // опционально (исчезающее)
  "lat": 55.7558,         // опционально (локация)
  "lon": 37.6173
}
```

#### Получить сообщения
```http
GET /get_messages?me=user1&other=user2&token=...
→ Возвращает массив сообщений
```

#### Редактировать сообщение
```http
POST /edit_message
Form: token, username, message_id, text
```

#### Удалить сообщение
```http
POST /delete_message
Form: token, username, message_id
```

#### Отметить прочитанным
```http
POST /mark_read
Form: chat_id, username, token
```

### Коллективные чаты (Группы/Каналы)

#### Создать группу
```http
POST /groups/create
Form: name, owner, token
→ Возвращает chat_id
```

#### Отправить в группу
```http
POST /collective/send
Form: chat_id, sender, token, text, [reply_to], [attachments], [ttl_seconds]
```

#### Получить сообщения группы
```http
GET /collective/messages?chat_id=...&username=...&token=...&limit=50
```

#### Управление участниками
```http
POST /groups/{chat_id}/members
Body: token, operator, action (add/remove), [members], [target]
```

### Пользователи

#### Получить информацию
```http
GET /get_user_info?username=...&token=...&my_username=...
```

#### Установить описание
```http
POST /set_about
Form: token, username, about
```

#### Получить список чатов
```http
GET /get_chats?username=...&token=...
```

#### Поиск пользователей
```http
GET /search_users?q=query&token=...&my_username=...
```

#### Установить аватар
```http
POST /set_av
Form: token, username, file (multipart)
```

### Реакции

#### Добавить/удалить реакцию (личный чат)
```http
POST /messages/react
Body: token, username, message_id, emoji, action (add/remove)
```

#### Добавить/удалить реакцию (группа)
```http
POST /collective/react
Body: token, username, message_id, emoji, chat_id, action
```

### Опросы

#### Создать опрос
```http
POST /polls/create
Form: token, username, chat_id, question, options (JSON массив)
```

### WebSocket (Realtime)

#### Подключение
```
ws://server/ws?token=...&username=...
```

#### События (отправка)
```json
// Печатает
{"type": "typing", "receiver": "user2"}

// Начало загрузки файла
{"type": "file_start", "filename": "photo.jpg"}

// Чанк файла (base64)
{"type": "file_chunk", "chunk": "base64data..."}

// Конец загрузки
{"type": "file_end"}

// Начало скачивания
{"type": "download_start", "filename": "photo.jpg"}
```

#### События (получение)
```json
// Новое сообщение
{"type": "message", "data": {...}}

// Собеседник печатает
{"type": "typing", "sender": "user2"}

// Файл готов
{"type": "file_ready", "filename": "...", "url": "..."}

// Файл сохранён
{"type": "file_saved", "filename": "..."}

// Ошибка
{"type": "error", "message": "..."}
```

---

## State Management

### Riverpod Провайдеры

#### Тема
```dart
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

class ThemeState {
  final NiosThemePreset preset;  // dark, light, blue
  final bool isDark;
}

// Использование
final theme = ref.watch(themeProvider);
ref.read(themeProvider.notifier).setTheme('dark');
```

#### Сессия пользователя
```dart
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});

class SessionState {
  final String? username;
  final String? token;
  final bool isAuthed;
  final String? userId;
}
```

#### Стиль пузырей
```dart
final bubbleStyleProvider = StateNotifierProvider<BubbleStyleNotifier, BubbleStyleState>((ref) {
  return BubbleStyleNotifier();
});

class BubbleStyleState {
  final double cornerRadius;      // 8-24
  final double bubblePadding;     // 8-20
  final bool useGradient;         // Градиент для исходящих
  final bool showTail;            // Показывать "хвостик"
}
```

#### Обои чата
```dart
final wallpaperProvider = StateNotifierProvider<WallpaperNotifier, WallpaperState>((ref) {
  return WallpaperNotifier();
});

class WallpaperState {
  final String? wallpaperUrl;     // URL или local path
  final double opacity;           // 0.0-1.0
  final double blurAmount;        // 0-20
  final bool useParallax;         // Параллакс эффект
}
```

#### Ghost Mode
```dart
final ghostModeProvider = StateNotifierProvider<GhostModeNotifier, GhostModeState>((ref) {
  return GhostModeNotifier();
});

class GhostModeState {
  final bool isActive;            // Активен ли режим
  final DateTime? activatedAt;    // Когда активирован
}
```

#### Focus Mode
```dart
final focusModeProvider = StateNotifierProvider<FocusModeNotifier, FocusModeState>((ref) {
  return FocusModeNotifier();
});

class FocusModeState {
  final bool isActive;
  final List<String> allowedChats; // Только эти чаты видны
}
```

#### AI Summary
```dart
final aiSummaryProvider = StateNotifierProvider<AiSummaryNotifier, AiSummaryState>((ref) {
  return AiSummaryNotifier();
});

class AiSummaryState {
  final bool isLoading;
  final String? summary;
  final bool hasSummary;
}
```

---

## Навигация

### AppRouter (навигация на основе состояния)

```dart
class AppRouter extends StatefulWidget {
  @override
  _AppRouterState createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  String screen = 'main';           // main, settings, profile, createGroup
  ChatItem? currentChat;            // Открытый чат
  String? profileTarget;            // Чей профиль открыт
  
  // Навигация
  void openChat(ChatItem chat) => setState(() => currentChat = chat);
  void closeChat() => setState(() => currentChat = null);
  void openSettings() => setState(() => screen = 'settings');
  void openProfile(String username) {
    setState(() {
      profileTarget = username;
      screen = 'profile';
    });
  }
}
```

### Экраны приложения

| Экран | Путь | Описание |
|-------|------|----------|
| Onboarding | `/onboarding` | Первый запуск, регистрация/вход |
| Chat List | `/` | Список всех чатов |
| Chat | `/chat/{id}` | Конкретный чат |
| Settings | `/settings` | Главный экран настроек |
| Profile | `/profile/{username}` | Профиль пользователя |
| Appearance | `/settings/appearance` | Настройки внешнего вида |
| Notifications | `/settings/notifications` | Уведомления |
| Privacy | `/settings/privacy` | Конфиденциальность |
| Data | `/settings/data` | Данные и память |
| Advanced | `/settings/advanced` | Дополнительно |
| Create Group | `/groups/create` | Создание группы |

### Переходы (Animations)

```dart
// Telegram-style переходы
TelegramPageRoute(
  child: ChatScreen(),
  direction: TransitionDirection.right,
)

// Fade с масштабом
TelegramFadeTransition(
  child: widget,
  duration: Duration(milliseconds: 250),
)

// Slide с эластичностью
TelegramSlideTransition(
  child: widget,
  direction: AxisDirection.up,
)
```

---

## Уникальные фичи

### 1. Ghost Mode (Призрачный режим)

**Описание:** Пользователь становится "невидимым" — не обновляет last_seen, не показывает статус "online".

**Реализация:**
```dart
// Включается через провайдер
ref.read(ghostModeProvider.notifier).activate();

// Проверка в UI
if (ghostMode.isActive) {
  // Не отправлять ping
  // Показывать индикатор "Призрачный режим"
}
```

**UI:** Индикатор в правом верхнем углу списка чатов.

### 2. Focus Mode (Режим концентрации)

**Описание:** Показывает только выбранные чаты, скрывает остальные.

**Реализация:**
```dart
// Включается с выбором чатов
ref.read(focusModeProvider.notifier).activate(['chat1', 'chat2']);

// Фильтрация в списке чатов
final filteredChats = focusMode.isActive
  ? allChats.where((c) => focusMode.allowedChats.contains(c.id))
  : allChats;
```

**UI:** Модальное окно выбора чатов при активации.

### 3. AI Summary

**Описание:** AI анализирует последние сообщения и генерирует краткое содержание.

**Реализация:**
```dart
// Кнопка в header чата (показывается при 10+ сообщениях)
AiSummaryButton(
  isLoading: aiSummary.isLoading,
  hasSummary: aiSummary.hasSummary,
  onTap: () => _showSummaryBottomSheet(),
)

// Bottom sheet с summary
showModalBottomSheet(
  builder: (_) => AiSummaryContent(summary: aiSummary.summary),
);
```

### 4. Elastic Scroll Physics

**Описание:** Физика прокрутки с "пружинным" эффектом как в iOS.

**Реализация:**
```dart
ListView.builder(
  physics: ElasticScrollPhysics(
    springDescription: SpringDescription(
      mass: 1.0,
      stiffness: 100.0,
      damping: 15.0,
    ),
  ),
)
```

### 5. Force Touch Preview

**Описание:** Предпросмотр чата при долгом нажатии (как 3D Touch).

**Реализация:**
```dart
ForceTouchPreview(
  onPreview: () => ChatPreviewCard(chat: chat),
  onCommit: () => openChat(chat),
  child: ChatListItem(chat: chat),
)
```

### 6. Dynamic Island Integration

**Описание:** Интеграция с Dynamic Island на iPhone 14 Pro+.

**Реализация:**
```dart
DynamicIsland(
  leading: Avatar(url: avatarUrl),
  title: chat.name,
  subtitle: '3 новых сообщения',
  trailing: Icon(Icons.message),
)
```

### 7. Waveform Scrubber

**Описание:** Визуализация аудио с возможностью перемотки.

**Реализация:**
```dart
WaveformScrubber(
  audioUrl: message.audioUrl,
  waveformData: message.meta['waveform'],
  onPositionChanged: (position) => _seek(position),
)
```

### 8. Disappearing Messages

**Описание:** Сообщения автоматически удаляются через заданное время.

**Реализация:**
```dart
// Отправка с TTL
sendMessage(
  text: 'Секретное сообщение',
  ttlSeconds: 60, // Удалится через минуту
);

// Таймер в UI
DisappearingTimer(
  expiresAt: message.expiresAt,
  onExpired: () => deleteMessage(message.id),
)
```

### 9. Poll Widget

**Описание:** Интерактивные опросы в чатах.

**Реализация:**
```dart
PollWidget(
  question: poll.question,
  options: poll.options,
  votes: poll.votes,
  hasVoted: poll.hasVoted,
  onVote: (optionId) => _vote(optionId),
)
```

### 10. Live Location

**Описание:** Поделиться местоположением в реальном времени.

**Реализация:**
```dart
LiveLocationMap(
  initialPosition: LatLng(lat, lon),
  duration: Duration(minutes: 15),
  onLocationUpdate: (position) => _sendLocationUpdate(position),
)
```

---

## Технический стек

### Основные зависимости

| Пакет | Версия | Назначение |
|-------|--------|----------|
| flutter | SDK | Фреймворк |
| flutter_riverpod | ^2.5.1 | State management |
| dio | ^5.7.0 | HTTP клиент |
| web_socket_channel | ^2.4.0 | WebSocket |
| shared_preferences | ^2.3.2 | Локальное хранилище |
| cached_network_image | ^3.4.1 | Кэширование изображений |
| just_audio | ^0.9.38 | Аудио плеер |
| record | ^5.1.2 | Запись аудио |
| google_fonts | ^6.2.1 | Шрифты |
| animations | ^2.0.11 | Анимации Material |
| flutter_slidable | ^3.0.1 | Свайп действия |
| audio_waveforms | ^1.2.0 | Визуализация аудио |
| drift | ^2.21.0 | ORM для SQLite |
| hive | ^2.2.3 | NoSQL хранилище |
| connectivity_plus | ^6.1.0 | Проверка сети |
| intl | ^0.19.0 | Интернационализация |

### Dev зависимости

| Пакет | Назначение |
|-------|----------|
| flutter_launcher_icons | Генерация иконок |
| flutter_lints | Линтер |
| hive_generator | Генератор Hive адаптеров |
| build_runner | Генерация кода |

### Firebase (опционально)

| Пакет | Назначение |
|-------|----------|
| firebase_core | Core Firebase |
| firebase_messaging | Push уведомления |

---

## Бэкенд (Python)

### Структура

```
backend/
├── api.py              # Основной API (FastAPI/Flask)
├── messenger.py        # Логика мессенджера
├── handlers.py         # Обработчики событий
├── login.py            # Аутентификация
├── users.db            # SQLite база данных
└── avatars/            # Хранилище аватаров
```

### Технологии

- **Framework:** FastAPI (async) или Flask
- **База данных:** SQLite (users.db)
- **WebSocket:** Для realtime сообщений
- **Хранение файлов:** Локальная файловая система (uploads/)
- **Аутентификация:** JWT токены

### Основные таблицы БД

```sql
-- Пользователи
users (
  id INTEGER PRIMARY KEY,
  username TEXT UNIQUE,
  email TEXT UNIQUE,
  password_hash TEXT,
  name TEXT,
  about TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP,
  last_seen TIMESTAMP,
  is_online BOOLEAN
)

-- Сессии
sessions (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  token TEXT UNIQUE,
  device_info TEXT,
  created_at TIMESTAMP,
  expires_at TIMESTAMP,
  is_active BOOLEAN
)

-- Сообщения
messages (
  id INTEGER PRIMARY KEY,
  sender_id INTEGER,
  receiver_id INTEGER,
  chat_id TEXT,
  text TEXT,
  type TEXT,
  reply_to_id INTEGER,
  meta JSON,
  is_pinned BOOLEAN,
  is_read BOOLEAN,
  created_at TIMESTAMP,
  expires_at TIMESTAMP  -- для исчезающих
)

-- Чаты (группы/каналы)
chats (
  id TEXT PRIMARY KEY,
  name TEXT,
  type TEXT,  -- group, channel
  owner_id INTEGER,
  avatar_url TEXT,
  created_at TIMESTAMP
)

-- Участники чатов
chat_members (
  chat_id TEXT,
  user_id INTEGER,
  role TEXT,  -- admin, member
  joined_at TIMESTAMP
)

-- Реакции
reactions (
  id INTEGER PRIMARY KEY,
  message_id INTEGER,
  user_id INTEGER,
  emoji TEXT,
  created_at TIMESTAMP
)
```

---

## Заключение

NiosMess — это современный мессенджер с:

- **Telegram-style дизайном** (тёмная тема, glassmorphism, анимации 120Hz)
- **Уникальными фичами** (Ghost Mode, Focus Mode, AI Summary)
- **Полной кроссплатформенностью** (Android, iOS, Windows, macOS, Linux)
- **Чистой архитектурой** (Riverpod, Clean Architecture)
- **Realtime коммуникацией** (WebSocket)
- **Высокой кастомизацией** (темы, стиль пузырей, обои)

Приложение готово к production после устранения технического долга (deprecated API, тесты).

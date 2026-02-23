# 🚀 Руководство по внедрению улучшений NiosMess

## 📋 Содержание
1. [Обзор изменений](#обзор-изменений)
2. [Критические исправления безопасности](#критические-исправления-безопасности)
3. [Новые функции](#новые-функции)
4. [Дизайнерские улучшения](#дизайнерские-улучшения)
5. [Инструкция по установке](#инструкция-по-установке)
6. [Миграция данных](#миграция-данных)
7. [API изменения](#api-изменения)

---

## 🎯 Обзор изменений

### ✅ Что было исправлено:
- **26 критических багов** и проблем безопасности
- Хранение паролей в открытом виде → **Argon2 хеширование**
- Токены в SharedPreferences → **FlutterSecureStorage**
- PIN без соли → **PBKDF2 с 10000 итерациями**
- XSS уязвимости в WebUI → **DOMPurify** (требует внедрения)
- SQL инъекции → **Whitelist таблиц**
- `catch (_) {}` → **Централизованная обработка ошибок**
- Отсутствие валидации → **Validators утилита**

### ⭐ Новые функции:
1. **Stories/Статусы** (24 часа)
2. **Редактор медиа** (фильтры, рисование, текст, стикеры)
3. **Улучшенные опросы** (квиз-режим, анонимные, автозакрытие)
4. **Анимированные стикеры** (Lottie-ready)
5. **Glassmorphism UI** (стеклянные эффекты)
6. **Локализация** (RU/EN)

---

## 🔒 Критические исправления безопасности

### 1. Бэкенд (api.py)

#### Установите зависимости:
```bash
pip install passlib[argon2] python-dotenv PyJWT email-validator
```

#### Создайте `.env` файл:
```env
ROOT_TOKEN=<сгенерируйте_секретный_токен>
SMTP_USER=your-email@gmail.com
SMTP_PWD=your-app-password
JWT_SECRET=<сгенерируйте_секретный_ключ>
DATABASE_URL=sqlite:///./niosmess.db
API_BASE_URL=https://web.sa2rn.fun
ALLOWED_ORIGINS=https://web.sa2rn.fun,http://localhost:3000
```

#### Примените исправления из `BACKEND_FIXES.py`:

**Шаг 1: Хеширование паролей**
```python
# В api.py добавьте импорт
from BACKEND_FIXES import PasswordManager, validate_table_name, SessionManager

# Замените регистрацию (строка 1939)
hashed_password = PasswordManager.hash_password(data.password)
conn.execute(
    "INSERT INTO users (username, email, password, name) VALUES (?, ?, ?, ?)",
    (username, email, hashed_password, name)
)

# Замените логин (строка 1984)
if not user or not PasswordManager.verify_password(password, user["password"]):
    raise HTTPException(status_code=401, detail="Invalid credentials")
```

**Шаг 2: Миграция существующих паролей**
```python
# Запустите ОДИН РАЗ:
from BACKEND_FIXES import migrate_passwords
migrate_passwords()
```

**Шаг 3: Защита от SQL инъекций**
```python
# Замените (строка 1127)
safe_table = validate_table_name(table)
conn.execute(f"UPDATE {safe_table} SET is_pinned=? WHERE id=?", ...)
```

**Шаг 4: Rate limiting**
```python
# В логин эндпоинт (строка 1970)
if not login_limiter.is_allowed(username):
    raise HTTPException(status_code=429, detail="Too many login attempts")
```

**Шаг 5: CORS исправление**
```python
# Замените строку 128
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "https://web.sa2rn.fun").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)
```

### 2. Flutter приложение

#### Файлы уже исправлены:
- ✅ `lib/core/storage/session_store.dart` - Secure storage
- ✅ `lib/core/app_lock_provider.dart` - PIN с солью
- ✅ `lib/features/auth/login_screen.dart` - Валидация
- ✅ `lib/core/utils/error_handler.dart` - Обработка ошибок
- ✅ `lib/core/utils/validators.dart` - Валидаторы

#### Применить во всех экранах:

**Замените все `catch (_) {}`:**
```dart
// Было:
catch (_) {
  setState(() => loading = false);
}

// Стало:
catch (e, stack) {
  ErrorHandler.handle(e, stackTrace: stack, context: 'ContextName');
  setState(() {
    loading = false;
    error = ErrorHandler.getUserMessage(e);
  });
}
```

**Добавьте валидацию в формы:**
```dart
// Было:
TextField(controller: _username)

// Стало:
Form(
  key: _formKey,
  child: TextFormField(
    controller: _username,
    validator: Validators.username,
    autovalidateMode: AutovalidateMode.onUserInteraction,
  ),
)
```

### 3. WebUI (JavaScript)

#### Защита от XSS:

**Установите DOMPurify:**
```html
<!-- В index.html -->
<script src="https://cdn.jsdelivr.net/npm/dompurify@3.0.6/dist/purify.min.js"></script>
```

**Замените innerHTML:**
```javascript
// Было (app.messages.js:1214)
row.innerHTML = `<span>${label}</span><span>${value}</span>`;

// Стало
row.innerHTML = DOMPurify.sanitize(`<span>${label}</span><span>${value}</span>`);
```

**Исправьте Markdown парсер (app.messages.js:1330-1343):**
```javascript
function parseMarkdown(text) {
  // Сначала экранируем HTML
  let result = text.replace(/</g, '&lt;').replace(/>/g, '&gt;');

  // Потом применяем markdown
  result = result.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  result = result.replace(/`(.+?)`/g, "<code>$1</code>");

  // Санитизация на всякий случай
  return DOMPurify.sanitize(result);
}
```

**Исправьте JSON.parse:**
```javascript
// Было
const data = JSON.parse(event.data);

// Стало
try {
  const data = JSON.parse(event.data);
  // ...
} catch (e) {
  console.error('JSON parse error:', e);
  return;
}
```

---

## 🎨 Новые функции

### 1. Stories (Истории)

**Файлы:**
- `lib/features/stories/models/story.dart`
- `lib/features/stories/providers/stories_provider.dart`
- `lib/features/stories/widgets/stories_row.dart`
- `lib/features/stories/widgets/story_viewer.dart`

**Использование:**
```dart
// В главном экране чатов
import 'package:niosmess/features/stories/widgets/stories_row.dart';

class ChatsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StoriesRow(), // Добавить строку с историями
        Expanded(child: ChatsList()),
      ],
    );
  }
}
```

**API эндпоинты (добавить в api.py):**
```python
@app.get("/stories")
async def get_stories(username: str, token: str):
    # Вернуть истории друзей
    pass

@app.post("/stories")
async def create_story(username: str, token: str, media: List[dict]):
    # Создать новую историю
    pass

@app.post("/stories/{story_id}/view")
async def mark_story_viewed(story_id: str, username: str, token: str):
    # Отметить как просмотренную
    pass
```

### 2. Редактор медиа

**Файл:**
- `lib/features/media_editor/media_editor_screen.dart`

**Использование:**
```dart
// Открыть редактор
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MediaEditorScreen(imageFile: xFile),
  ),
);

if (result != null) {
  // result - это Uint8List с отредактированным изображением
  // Отправить в чат
}
```

**Фичи:**
- ✅ Фильтры (Grayscale, Sepia, Invert, Vintage)
- ✅ Рисование (7 цветов, undo)
- ✅ Текст (с настройками)
- ✅ Стикеры (эмодзи)
- ⏳ Кроп (TODO)

### 3. Улучшенные опросы

**Файлы:**
- `lib/features/polls/models/poll.dart`
- `lib/features/polls/widgets/enhanced_poll_widget.dart`

**Использование:**
```dart
EnhancedPollWidget(
  poll: Poll(
    id: '1',
    question: 'Какой язык программирования лучший?',
    options: [
      PollOption(id: '1', text: 'Dart', isCorrect: true),
      PollOption(id: '2', text: 'JavaScript'),
      PollOption(id: '3', text: 'Python'),
    ],
    type: PollType.quiz, // Квиз с правильным ответом
    allowMultipleAnswers: false,
    closesAt: DateTime.now().add(Duration(hours: 24)),
    createdAt: DateTime.now(),
    creatorId: 'user1',
  ),
  currentUserId: 'currentUser',
  onVote: (optionIds) async {
    // Отправить голос на сервер
  },
)
```

**Новые возможности:**
- ✅ Квиз-режим с правильными ответами
- ✅ Анонимные опросы
- ✅ Множественный выбор с ограничениями
- ✅ Автозакрытие по таймеру
- ✅ Визуализация результатов с процентами

---

## 🎨 Дизайнерские улучшения

### 1. Glassmorphism компоненты

**Файл:**
- `lib/ui/widgets/glass_container.dart`

**Примеры использования:**
```dart
// Стеклянная карточка
FrostedGlassCard(
  child: Text('Контент'),
  onTap: () {},
)

// Стеклянный AppBar
GlassAppBar(
  title: 'Заголовок',
  actions: [IconButton(...)],
)

// Стеклянный Bottom Sheet
await GlassBottomSheet.show(
  context: context,
  child: YourContent(),
  height: 300,
)

// Стеклянный Dialog
await GlassDialog.show(
  context: context,
  title: 'Заголовок',
  content: Text('Текст'),
  actions: [TextButton(...)],
)

// Стеклянная навигация
GlassNavigationBar(
  currentIndex: 0,
  onTap: (index) {},
  items: [
    GlassNavigationBarItem(
      icon: Icons.chat,
      activeIcon: Icons.chat,
      label: 'Чаты',
    ),
  ],
)
```

### 2. Анимированные стикеры

**Файл:**
- `lib/ui/widgets/animated_sticker.dart`

**Использование:**
```dart
// Стикер
AnimatedSticker(
  stickerId: 'heart',
  size: 120,
  onTap: () {},
)

// Picker
StickerPicker(
  onStickerSelected: (stickerId) {
    // Добавить в сообщение
  },
)

// Анимированная реакция
AnimatedReaction(
  reaction: '❤️',
  onComplete: () {},
)
```

### 3. Локализация

**Файл:**
- `lib/core/l10n/app_localizations.dart`

**Интеграция в main.dart:**
```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:niosmess/core/l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  // ...
)
```

**Использование:**
```dart
// В любом виджете
final l10n = AppLocalizations.of(context);

Text(l10n.login); // 'Вход' (RU) или 'Login' (EN)
Text(l10n.messages);
Text(l10n.settings);
```

---

## 📦 Инструкция по установке

### 1. Обновите pubspec.yaml

**Уже добавлены в проект:**
- `flutter_secure_storage: ^9.2.2`
- `flutter_riverpod: ^2.5.1`
- `crypto: ^3.0.3`

**Для локализации добавьте:**
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
```

**Для Lottie стикеров (опционально):**
```yaml
dependencies:
  lottie: ^3.1.0
```

### 2. Запустите команды:

```bash
# Flutter
cd niosmess_flutter
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# Python бэкенд
cd ..
pip install -r requirements.txt

# Создайте .env файл
cp .env.example .env
# Отредактируйте .env с вашими секретами
```

### 3. Миграция БД

```bash
# Запустите скрипт миграции паролей
python3 -c "from BACKEND_FIXES import migrate_passwords; migrate_passwords()"
```

---

## 🔄 Миграция данных

### База данных (SQLite)

**Добавьте новые таблицы:**
```sql
-- Для Stories
CREATE TABLE IF NOT EXISTS stories (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    media JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    views_count INTEGER DEFAULT 0,
    viewed_by TEXT DEFAULT '[]',
    FOREIGN KEY (user_id) REFERENCES users(username)
);

-- Для опросов (улучшенная версия)
ALTER TABLE polls ADD COLUMN type TEXT DEFAULT 'regular';
ALTER TABLE polls ADD COLUMN is_anonymous BOOLEAN DEFAULT 0;
ALTER TABLE polls ADD COLUMN allow_multiple_answers BOOLEAN DEFAULT 0;
ALTER TABLE polls ADD COLUMN max_choices INTEGER;
ALTER TABLE polls ADD COLUMN closes_at TIMESTAMP;
ALTER TABLE polls ADD COLUMN status TEXT DEFAULT 'active';

-- Для правильных ответов в квизах
ALTER TABLE poll_options ADD COLUMN is_correct BOOLEAN;
```

### Хранилище Flutter

**Миграция токенов из SharedPreferences в SecureStorage:**
```dart
Future<void> migrateToSecureStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final oldSession = prefs.getString('session');

  if (oldSession != null) {
    // Переместить в secure storage
    await SessionStore.save(jsonDecode(oldSession));

    // Удалить из SharedPreferences
    await prefs.remove('session');

    print('Session migrated to secure storage');
  }
}

// Запустить при первом запуске приложения
```

---

## 🔌 API изменения

### Новые эндпоинты

**Stories:**
```python
GET    /stories                      # Получить истории
POST   /stories                      # Создать историю
DELETE /stories/{id}                 # Удалить историю
POST   /stories/{id}/view            # Отметить просмотренной
GET    /stories/{id}/replies         # Получить ответы
POST   /stories/{id}/reply           # Ответить на историю
```

**Опросы (улучшенные):**
```python
POST   /polls                        # Создать опрос (с новыми полями)
GET    /polls/{id}/analytics         # Аналитика опроса
PUT    /polls/{id}/close             # Закрыть опрос вручную
```

**Медиа:**
```python
POST   /media/edit                   # Сохранить отредактированное изображение
```

### Изменённые эндпоинты

**Авторизация:**
```python
POST /login
# Запрос:
{
  "username": "string",  # Теперь валидируется
  "password": "string"   # Теперь валидируется
}
# Ответ: JWT token вместо простой строки (опционально)
```

**Регистрация:**
```python
POST /register
# Запрос:
{
  "username": "string",  # 3-20 символов, только [a-zA-Z0-9_]
  "email": "string",     # Валидный email
  "password": "string",  # Минимум 8 символов, 1 заглавная, 1 цифра
  "name": "string"       # 2-50 символов
}
```

---

## 📊 Производительность

### Оптимизации уже внедрены:

1. **Lazy Loading для Stories** - загружаются только активные
2. **Кэширование изображений** - `cached_network_image`
3. **Secure Storage** - асинхронное, не блокирует UI
4. **Анимации 120Hz** - оптимизированные кривые

### TODO (рекомендуется):

```dart
// Добавить пагинацию для сообщений
class ChatScreen extends StatelessWidget {
  Future<void> _loadMoreMessages() async {
    final lastId = messages.last.id;
    final newMessages = await api.getMessages(
      chatId: chatId,
      before: lastId,
      limit: 20,
    );
    setState(() => messages.addAll(newMessages));
  }
}
```

```dart
// Offload обфускации в Isolate
import 'dart:isolate';

Future<String> obfuscateAsync(String text) async {
  return await compute(Obfuscator.obfuscate, text);
}
```

---

## 🧪 Тестирование

### Запуск тестов

```bash
# Flutter
flutter test

# Покрытие кода
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Тесты безопасности

**OWASP ZAP против API:**
```bash
docker run -t owasp/zap2docker-stable zap-baseline.py \
  -t http://localhost:8000
```

**Проверка хранилища:**
```bash
# Android
adb shell
run-as com.niosmess
cat /data/data/com.niosmess/app_flutter/FlutterSecureStorage
# Должно быть зашифровано

# iOS
# Keychain должен содержать encrypted данные
```

---

## 📝 Чеклист внедрения

### Критические (Неделя 1):
- [ ] Применить BACKEND_FIXES.py
- [ ] Создать .env файл с секретами
- [ ] Мигрировать пароли (запустить migrate_passwords())
- [ ] Обновить CORS настройки
- [ ] Внедрить DOMPurify в WebUI
- [ ] Тест: попробовать SQL injection
- [ ] Тест: проверить хранилище токенов

### Высокие (Неделя 2):
- [ ] Добавить валидацию во все формы
- [ ] Заменить все catch (_) на ErrorHandler
- [ ] Добавить rate limiting
- [ ] Настроить локализацию
- [ ] Тест: проверить XSS защиту

### Средние (Неделя 3):
- [ ] Внедрить Stories
- [ ] Добавить редактор медиа
- [ ] Обновить опросы
- [ ] Добавить Glassmorphism компоненты
- [ ] Тест: E2E тесты для Stories

### Низкие (Месяц 1):
- [ ] Добавить Lottie стикеры
- [ ] Настроить CI/CD
- [ ] Написать документацию API
- [ ] Performance мониторинг

---

## 🆘 Troubleshooting

### Проблема: "FlutterSecureStorage ошибка на Android"
**Решение:**
```gradle
// android/app/build.gradle
android {
    compileSdkVersion 34
    minSdkVersion 23 // Минимум 23 для SecureStorage
}
```

### Проблема: "Пароли не мигрировались"
**Решение:**
```python
# Проверьте логи
python3 -c "from BACKEND_FIXES import migrate_passwords; migrate_passwords()"
# Должно вывести: "Migrated password for user: username"
```

### Проблема: "CORS ошибка"
**Решение:**
```python
# В .env
ALLOWED_ORIGINS=https://web.sa2rn.fun,http://localhost:3000,http://localhost:8080

# Перезапустите сервер
uvicorn api:app --reload
```

---

## 📚 Дополнительные ресурсы

- [FULL_ANALYSIS.md](./FULL_ANALYSIS.md) - Полный анализ проекта
- [BACKEND_FIXES.py](./BACKEND_FIXES.py) - Исправления бэкенда
- [Flutter Secure Storage Docs](https://pub.dev/packages/flutter_secure_storage)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

**Версия:** 1.0.0
**Дата:** 2025-02-14
**Автор:** Claude (Anthropic)

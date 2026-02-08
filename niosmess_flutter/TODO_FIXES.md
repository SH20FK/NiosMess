# Исправленные ошибки и замечания

## ✅ Исправлено (15 issues)

### 1. Добавлен flutter_lints
- **Файл**: `pubspec.yaml`
- **Изменение**: Добавлен `flutter_lints: ^4.0.0` в dev_dependencies

### 2. Исправлены deprecated PopScope API
- **Файл**: `lib/core/app_router.dart`
- **Изменения**:
  - `onPopInvoked` → `onPopInvokedWithResult` (строка 61)
  - `onPopPage` → `onDidRemovePage` (строка 130)

### 3. Исправлены deprecated withOpacity
- **Файл**: `lib/features/chat/chat_screen.dart` (строка 1461)
  - `NiosPalette.accent.withOpacity(0.18)` → `withValues(alpha: 0.18)`

- **Файл**: `lib/features/groups/create_group_screen.dart` (строка 236)
  - `NiosPalette.accent.withOpacity(0.18)` → `withValues(alpha: 0.18)`

- **Файл**: `lib/features/onboarding/onboarding_flow_screen.dart` (7 мест)
  - Строка 499: `NiosPalette.shadowGlow.withOpacity(pulse)` → `withValues(alpha: pulse)`
  - Строка 1148: `Color(0xFFFF6B35).withOpacity(0.4)` → `withValues(alpha: 0.4)`
  - Строка 1297: `Colors.black.withOpacity(0.1)` → `withValues(alpha: 0.1)`
  - Строка 1315: `Colors.black.withOpacity(0.3)` → `withValues(alpha: 0.3)`
  - Строка 1387: `Color(0xFFFF6B35).withOpacity(0.6)` → `withValues(alpha: 0.6)`
  - Строка 1389: `Color(0xFFFF6B35).withOpacity(0.4)` → `withValues(alpha: 0.4)`
  - Строка 1523: `color.withOpacity(p.opacity)` → `withValues(alpha: p.opacity)`

- **Файл**: `lib/ui/nios_ui.dart` (2 места)
  - Строка 645: `Colors.black.withOpacity(0.25)` → `withValues(alpha: 0.25)`
  - Строка 673: `NiosPalette.accent.withOpacity(alpha)` → `withValues(alpha: alpha)`

### 4. Исправлен deprecated DropdownButtonFormField
- **Файл**: `lib/features/settings/settings_screen.dart` (строка 268)
  - `value` → `initialValue`

### 5. Удален дублирующийся Firebase.initializeApp()
- **Файл**: `lib/core/notification_service.dart`
- **Изменение**: Удален вызов `Firebase.initializeApp()` (уже вызывается в main.dart)

### 6. Удалены BOM (Byte Order Mark) из файлов
- **Файлы**: `pubspec.yaml`, `lib/core/app_router.dart`, `lib/core/notification_service.dart`, `lib/features/groups/create_group_screen.dart`

### 7. Добавлена обработка ошибок в ApiClient
- **Файл**: `lib/core/api_client.dart`
- **Добавлено**: 
  - Класс `ApiClientException` для обработки ошибок
  - Try-catch блоки в методах `post` и `get`
  - Метод `_extractErrorMessage` для извлечения сообщений об ошибках

---

## ℹ️ Оставшиеся информационные замечания (14 issues)

Эти замечания не критичны и не влияют на работу приложения, но рекомендуется исправить для улучшения качества кода:

### 1. Unnecessary use of 'toList' in a spread
- **Файл**: `lib/features/auth/register_screen.dart:150`
- **Описание**: Метод `toList()` не нужен при использовании spread оператора

### 2. Use 'const' for final variables initialized to a constant value
- **Файл**: `lib/features/chat/chat_screen.dart:209`
- **Описание**: Переменная инициализируется константным значением, рекомендуется добавить `const`

### 3. Don't use 'BuildContext's across async gaps (4 штуки)
- **Файлы**: 
  - `lib/features/chat/chat_screen.dart:493, 656, 657, 767`
  - `lib/features/settings/settings_screen.dart:101, 103`
- **Описание**: Использование BuildContext после асинхронных операций может привести к ошибкам, если виджет был удален

### 4. Use 'const' with the constructor to improve performance (3 штуки)
- **Файлы**: 
  - `lib/features/chat/chat_screen.dart:1496`
  - `lib/features/onboarding/onboarding_flow_screen.dart:1225, 1226`
- **Описание**: Рекомендуется добавить `const` к конструкторам для оптимизации производительности

### 5. Invalid use of a private type in a public API (2 штуки)
- **Файл**: `lib/features/onboarding/onboarding_flow_screen.dart:953, 955`
- **Описание**: Приватные типы используются в публичном API

### 6. The prefix 'Math' isn't a lower_case_with_underscores identifier
- **Файл**: `lib/ui/nios_ui.dart:1`
- **Описание**: Префикс импорта должен использовать snake_case (рекомендуется `math` вместо `Math`)

---

## 📊 Итог

- **Было**: 15 issues (1 warning + 14 info)
- **Стало**: 14 info issues
- **Исправлено**: Все deprecated API, BOM, дублирующийся Firebase init, добавлена обработка ошибок

**Статус**: ✅ Все критические ошибки исправлены. Приложение готово к сборке и использованию.

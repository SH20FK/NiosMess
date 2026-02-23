# Flutter Desktop (ПК) — Полное руководство

## ✅ Да, Flutter отлично работает на ПК!

Ваш проект **уже поддерживает Windows, macOS и Linux** — папки `windows/`, `linux/`, `macos/` уже созданы.

---

## 🖥️ Поддерживаемые платформы

| Платформа | Статус | Папка в проекте |
|-----------|--------|-----------------|
| Windows | ✅ Стабильно | `windows/` |
| macOS | ✅ Стабильно | `macos/` |
| Linux | ✅ Стабильно | `linux/` |

---

## 🚀 Быстрый старт (Windows)

### 1. Проверка требований
```powershell
# PowerShell от имени администратора
flutter doctor
```

Должно показать:
```
[✓] Visual Studio - develop for Windows
[✓] Windows Version (Installed version of Windows is version 10 or higher)
```

### 2. Сборка EXE для Windows
```powershell
cd niosmess_flutter

# Debug версия (быстрая сборка)
flutter run -d windows

# Release версия (для распространения)
flutter build windows --release
```

### 3. Где найти собранное приложение
```
niosmess_flutter/build/windows/x64/runner/Release/
├── niosmess.exe          ← Главный файл
├── flutter_windows.dll   ← Flutter движок
├── data/                 ← Ресурсы
└── ...                   ← Другие DLL
```

---

## 📦 Создание установщика (Windows)

### Опция 1: Простой ZIP-архив
```powershell
# Собрать release
flutter build windows --release

# Создать архив для распространения
Compress-Archive -Path "build/windows/x64/runner/Release/*" -DestinationPath "NiosMess-Windows.zip"
```

### Опция 2: MSI установщик (рекомендуется)
```powershell
# Установить msix
flutter pub add --dev msix

# Добавить в pubspec.yaml:
msix_config:
  display_name: NiosMess
  publisher_display_name: Nios Team
  identity_name: com.nios.messenger
  msix_version: 1.0.0.0
  logo_path: assets/icon/app_icon.png

# Собрать
flutter pub run msix:create
```

### Опция 3: Inno Setup (профессиональный установщик)
Создать скрипт `installer.iss`:
```pascal
[Setup]
AppName=NiosMess
AppVersion=1.0
DefaultDirName={autopf}\NiosMess
OutputDir=installer

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
```

---

## 🎨 Адаптация UI для ПК

### 1. Адаптивный layout
```dart
// lib/core/responsive.dart
class Responsive {
  static bool isMobile(BuildContext context) => 
    MediaQuery.of(context).size.width < 600;
  
  static bool isTablet(BuildContext context) => 
    MediaQuery.of(context).size.width >= 600 && 
    MediaQuery.of(context).size.width < 1200;
  
  static bool isDesktop(BuildContext context) => 
    MediaQuery.of(context).size.width >= 1200;
}
```

### 2. Использование в экранах
```dart
class ChatListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    
    return Scaffold(
      body: Row(
        children: [
          // Список чатов (фиксированная ширина на ПК)
          SizedBox(
            width: isDesktop ? 350 : null,
            child: ChatList(),
          ),
          
          // Разделитель (только на ПК)
          if (isDesktop) VerticalDivider(),
          
          // Область чата
          Expanded(
            child: isDesktop 
              ? ChatScreen() 
              : (selectedChat != null ? ChatScreen() : EmptyState()),
          ),
        ],
      ),
    );
  }
}
```

### 3. Keyboard shortcuts (горячие клавиши)
```dart
// lib/core/shortcuts.dart
class AppShortcuts {
  static final Map<ShortcutActivator, Intent> shortcuts = {
    // Ctrl+N — новый чат
    SingleActivator(LogicalKeyboardKey.keyN, control: true): 
      NewChatIntent(),
    
    // Ctrl+F — поиск
    SingleActivator(LogicalKeyboardKey.keyF, control: true): 
      SearchIntent(),
    
    // Escape — назад
    SingleActivator(LogicalKeyboardKey.escape): 
      GoBackIntent(),
    
    // Ctrl+Enter — отправить
    SingleActivator(LogicalKeyboardKey.enter, control: true): 
      SendMessageIntent(),
  };
}
```

---

## 🔧 Специфичные для ПК фичи

### 1. Окно с фиксированным размером (мин/макс)
```dart
// windows/runner/main.cpp (уже настроено)
// Можно изменить в win32_window.cpp:
constexpr int kMinWidth = 800;
constexpr int kMinHeight = 600;
```

### 2. Системный трей (Windows)
```dart
// Использовать пакет system_tray
flutter pub add system_tray

// Пример:
final SystemTray systemTray = SystemTray();
await systemTray.initSystemTray(
  title: "NiosMess",
  iconPath: 'assets/icon/tray_icon.ico',
);
```

### 3. Нативное меню (macOS/Windows)
```dart
// Использовать пакет menubar
flutter pub add menubar

// Или platform_menu_bar для macOS
```

### 4. Drag & Drop файлов
```dart
// Использовать пакет desktop_drop
flutter pub add desktop_drop

DesktopDrop(
  onDragDone: (details) {
    final files = details.files;
    // Отправить файлы
  },
  child: ChatScreen(),
)
```

---

## 📋 Чеклист перед сборкой

### Обязательно проверить:
- [ ] Все плагины поддерживают desktop
- [ ] Нет mobile-only зависимостей (camera, sensors)
- [ ] Адаптивная верстка работает
- [ ] Keyboard navigation работает
- [ ] Размер окна адекватный

### Плагины, которые НЕ работают на desktop:
| Плагин | Альтернатива |
|--------|-------------|
| `flutter_contacts` | `win32` + native code |
| `geolocator` | `geolocator` ✅ работает |
| `local_auth` | `local_auth` ✅ работает |
| `firebase_messaging` | REST API fallback |

---

## 🐛 Известные проблемы и решения

### Проблема 1: Шрифты не загружаются
**Решение:** Использовать локальные шрифты вместо Google Fonts
```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
```

### Проблема 2: Кэш изображений
**Решение:** Увеличить кэш для desktop
```dart
// main.dart
PaintingBinding.instance.imageCache.maximumSizeBytes = 1024 * 1024 * 100; // 100MB
```

### Проблема 3: Размер окна при старте
**Решение:** Использовать `window_manager`
```dart
flutter pub add window_manager

WindowOptions windowOptions = WindowOptions(
  size: Size(1200, 800),
  minimumSize: Size(800, 600),
  center: true,
);
```

---

## 🎯 Команды для разных платформ

### Windows
```powershell
# Запуск
flutter run -d windows

# Release сборка
flutter build windows --release

# С профилем
flutter build windows --profile
```

### macOS
```bash
# Запуск
flutter run -d macos

# Release сборка
flutter build macos --release

# Создать DMG
flutter build macos --release
hdiutil create -fs HFS+ -srcfolder build/macos/Build/Products/Release/niosmess.app NiosMess.dmg
```

### Linux
```bash
# Запуск
flutter run -d linux

# Release сборка
flutter build linux --release

# Создать AppImage (требуется доп. настройка)
```

---

## 📊 Сравнение размеров

| Платформа | Размер | Формат |
|-----------|--------|--------|
| Android APK | 60 MB | .apk |
| Windows | 45 MB | .exe + .dll |
| macOS | 50 MB | .app |
| Linux | 40 MB | бинарник |

---

## ✅ Итог

**Flutter Desktop полностью готов для production!**

Ваше приложение можно собрать для Windows прямо сейчас:
```powershell
cd niosmess_flutter
flutter build windows --release
```

Готовый EXE будет в:
```
build/windows/x64/runner/Release/niosmess.exe
```

**Рекомендации:**
1. Добавить адаптивный layout для планшетов/ПК
2. Добавить keyboard shortcuts
3. Создать MSI установщик для Windows
4. Протестировать на разных разрешениях экрана

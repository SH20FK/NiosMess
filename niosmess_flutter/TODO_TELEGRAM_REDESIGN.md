# Telegram-Style Redesign - Implementation TODO

## ✅ Completed

### Core Components
- [x] `ChatHeaderWidget` - Telegram-style header с аватаром, статусом, действиями
- [x] `ChatInputWidget` - Новая панель ввода с большим скруглением
- [x] `AiSummaryButton` - Компактная плавающая кнопка AI
- [x] `telegram_animations.dart` - Кастомные анимации переходов

### Screens
- [x] `chat_screen.dart` - Обновлен с новыми виджетами
- [x] `chat_list_screen.dart` - Telegram-style список чатов
- [x] `settings_main_screen.dart` - Главный экран настроек (список секций)
- [x] `settings_profile_screen.dart` - Профиль пользователя
- [x] `settings_appearance_screen_new.dart` - Внешний вид (темы, стиль, фон)
- [x] `settings_notifications_screen.dart` - Уведомления
- [x] `settings_privacy_screen.dart` - Конфиденциальность
- [x] `settings_data_screen.dart` - Данные и память
- [x] `settings_advanced_screen.dart` - Дополнительно

### Navigation
- [x] `app_router.dart` - Обновлен с новыми экранами и переходами

## 🔄 In Progress

### Testing
- [ ] Тестирование на Android устройствах
- [ ] Тестирование на iOS устройствах
- [ ] Проверка анимаций на 120Hz экранах
- [ ] Accessibility testing (VoiceOver/TalkBack)

## ⏳ Pending

### Enhancements
- [ ] Добавить haptic feedback для кнопок
- [ ] Реализовать свайп для ответа на сообщения
- [ ] Добавить реакции (emoji) на сообщения
- [ ] Pull-to-refresh для списка чатов
- [ ] Поиск по чатам (глобальный)

### Polish
- [ ] Оптимизация производительности списков
- [ ] Кэширование аватаров
- [ ] Lazy loading для сообщений
- [ ] Skeleton screens для загрузки

### Features
- [ ] Voice messages waveform visualization
- [ ] Photo gallery viewer
- [ ] Video player
- [ ] File preview
- [ ] Location sharing map

## Known Issues

1. **chat_screen_complete.dart** - Старый файл с ошибками, нужно удалить или исправить
2. **settings_appearance_screen.dart** - Старый файл с несовместимым API
3. **settings_appearance_screen_fixed.dart** - Старый файл с несовместимым API

## API Changes

### ThemeProvider
```dart
// Было
ref.read(themeProvider.notifier).setTheme(id)

// Стало (тот же API)
ref.read(themeProvider.notifier).setTheme(id)
// Но state теперь ThemeState с полем preset
```

### BubbleStyleProvider
```dart
// Было
ref.read(bubbleStyleProvider.notifier).setPadding(value)

// Стало
ref.read(bubbleStyleProvider.notifier).setBubblePadding(value)
```

### WallpaperProvider
```dart
// Было
ref.read(wallpaperProvider.notifier).setBlur(value)
ref.read(wallpaperProvider.notifier).setParallax(value)

// Стало
ref.read(wallpaperProvider.notifier).setBlurAmount(value)
ref.read(wallpaperProvider.notifier).setUseParallax(value)
```

## Commands

```bash
# Build APK для тестирования
flutter build apk --release

# Run с hot reload
flutter run

# Analyze code
flutter analyze

# Format code
flutter format lib/
```

## Resources

- [Telegram Design Guidelines](https://core.telegram.org/bots/webapps#design)
- [Material 3 Design Kit](https://m3.material.io/)
- [Flutter Animation Guide](https://flutter.dev/docs/development/ui/animations)

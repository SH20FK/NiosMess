# TODO: Реализация 15 уникальных фич NiosMess

## Статус: В процессе ⏳

### Фича 1: Liquid Pull-to-Refresh ✅ (Создано, нужно исправить типы)
- **Файл:** `lib/ui/widgets/liquid_pull_refresh.dart`
- **Проблема:** Ошибки приведения типов `num` к `double` в методе `quadraticBezierTo`
- **Решение:** Явное приведение всех координат к `double`

### Фича 2: Haptic Keyboard ⏳
- **Файл:** `lib/ui/widgets/haptic_keyboard.dart` (создать)
- **Описание:** Вибрация при нажатии клавиш с разной интенсивностью
- **Зависимости:** `haptic_feedback` или `flutter_haptic_feedback`

### Фича 4: Morphing AppBar ⏳
- **Файл:** `lib/ui/widgets/morphing_appbar.dart` (создать)
- **Описание:** AppBar меняет borderRadius при скролле (20→0)
- **Интеграция:** Заменить AppBar в chat_list_screen.dart

### Фича 5: 3D Touch Preview ⏳
- **Файл:** `lib/ui/widgets/force_touch_preview.dart` (создать)
- **Описание:** Предпросмотр чата при сильном нажатии (Peek & Pop)
- **Платформы:** iOS (Force Touch), Android (Long Press)

### Фича 8: Elastic List Physics ⏳
- **Файл:** `lib/ui/widgets/elastic_scroll_physics.dart` (создать)
- **Описание:** Пружинная физика при достижении конца списка
- **Аналог:** iOS Bounce эффект, но кастомизированный

### Фича 9: Contextual Quick Actions ⏳
- **Файл:** `lib/ui/widgets/radial_menu.dart` (создать)
- **Описание:** Radial menu при долгом нажатии на сообщение
- **Действия:** Reply, Forward, Delete, Copy, React

### Фича 10: Dynamic Island Notifications ⏳
- **Файл:** `lib/ui/widgets/dynamic_island.dart` (создать)
- **Описание:** Уведомления в стиле iPhone Dynamic Island
- **Анимации:** Expand, Contract, Bounce

### Фича 11: Voice Message Waveform Scrubbing ⏳
- **Файл:** `lib/ui/widgets/waveform_scrubber.dart` (создать)
- **Описание:** Тянуть по waveform для навигации по голосовому
- **Интеграция:** Обновить audio_waveform.dart

### Фича 16: Disappearing Message Timer Visual ⏳
- **Файл:** Обновить `lib/ui/widgets/disappearing_timer.dart`
- **Описание:** Круговой таймер на исчезающих сообщениях
- **UI:** Circular progress indicator вокруг сообщения

### Фича 18: Message Translation Inline ⏳
- **Файл:** `lib/ui/widgets/inline_translation.dart` (создать)
- **Описание:** Перевод сообщения без перехода в другой экран
- **API:** Google Translate или аналог

### Фича 33: Location Sharing Live ⏳
- **Файл:** `lib/ui/widgets/live_location.dart` (создать)
- **Описание:** Live location с мини-картой в чате
- **Зависимости:** `google_maps_flutter`

### Фича 34: Polls with Live Updates ⏳
- **Файл:** `lib/ui/widgets/poll_widget.dart` (создать)
- **Описание:** Опросы с real-time обновлением результатов
- **Backend:** WebSocket для live updates

### Фича 36: Offline-First Architecture ⏳
- **Файл:** `lib/core/offline_manager.dart` (создать)
- **Описание:** Полная функциональность без интернета
- **Технологии:** Hive/SQLite, Sync стратегия

### Фича 39: Multi-Account Support ⏳
- **Файл:** `lib/core/account_manager.dart` (создать)
- **Описание:** Несколько аккаунтов с быстрым переключением
- **UI:** Account switcher в drawer

### Фича 40: Custom Themes with Editor ⏳
- **Файл:** `lib/features/settings/theme_editor.dart` (создать)
- **Описание:** Редактор тем с live preview
- **Функции:** Color picker, Font selector, Preview

## Приоритет реализации:

### Фаза 1 (Критические):
1. Исправить Liquid Pull-to-Refresh
2. Elastic List Physics
3. Morphing AppBar
4. Disappearing Message Timer

### Фаза 2 (Важные):
5. Haptic Keyboard
6. Contextual Quick Actions
7. Waveform Scrubbing
8. Dynamic Island Notifications

### Фаза 3 (Продвинутые):
9. Offline-First Architecture
10. Multi-Account Support
11. Custom Themes Editor
12. Live Location
13. Polls
14. Inline Translation
15. 3D Touch Preview

## Заметки:
- Все виджеты должны быть в `lib/ui/widgets/`
- Каждая фича должна иметь пример использования в комментариях
- Тестировать на реальном устройстве для haptic/force touch


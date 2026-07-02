# Идеи по улучшению NiosMess

> Сгенерировано на основе анализа всего кода приложения (37 экранов, 33 виджета, провайдеры, репозитории).

---

## 1. Единый компонент ошибок (Error Banner)

**Проблема:** В 15+ экранах ошибки показываются по-разному: где-то SnackBar, где-то `Text(_error!)`, где-то `Center(child: Text(...))`. Нет единого визуала.

**Решение:** Создать переиспользуемый виджет `AppErrorBanner` с:
- Иконкой ошибки + текстом
- Кнопкой "Повторить" (onRetry)
- Анимацией появления
- Вариантами: inline (в списке), centered (на весь экран), snackbar

**Файлы:** Все экраны с `_error` состояниями (~20 файлов)

---

## 2. Pull-to-Refresh на всех скроллируемых экранах

**Проблема:** `RefreshIndicator` есть только на `ChatListScreen` и `NiosgramScreen`. Контакты, сессии, бейджи, боты, админ-панель — без pull-to-refresh.

**Решение:** Обернуть все скроллируемые экраны в `RefreshIndicator` с единым паттерном обновления.

**Файлы:** `contacts_screen.dart`, `sessions_screen.dart`, `badge_screen.dart`, `bot_screen.dart`, `admin_screen.dart`, `chat_members_screen.dart`

---

## 3. Унифицированные skeleton-загрузки

**Проблема:** `PulseSkeleton` используется в одних экранах, `CircularProgressIndicator` — в других, а где-то вообще нет индикатора загрузки.

**Решение:** Ввести единый паттерн:
- Списки → `PulseSkeleton` (уже есть)
- Формы/детали → `PulseLoadingIndicator` (уже есть)
- Кнопки → `isLoading` параметр (уже есть в PulseButton)
- Убрать голый `CircularProgressIndicator()` везде, заменить на `PulseLoadingIndicator`

**Файлы:** `admin_screen.dart`, `badge_screen.dart`, `bot_screen.dart`, `chat_detail_screen.dart`

---

## 4. PopScope для Android Back Button

**Проблема:** 32 экрана не обрабатывают системную кнопку "Назад" на Android. Это критично для:
- `chat_detail_screen.dart` — может закрыться во время записи аудио/отправки файла
- `create_chat_screen.dart` — уже имеет PopScope (хорошо)
- `chat_manage_screen.dart` — изменения могут потеряться
- `e2ee_settings_screen.dart` — генерация ключа может прерваться

**Решение:** Добавить `PopScope` на все экраны с формами/загрузкой:
- `chat_detail_screen.dart`
- `chat_manage_screen.dart`
- `e2ee_settings_screen.dart`
- `create_post_screen.dart`
- `profile_screen.dart` (диалог редактирования)

---

## 5. Offline-состояние (Offline Banner)

**Проблема:** `OfflineBanner` виджет уже существует, но используется только в `ChatListScreen`. Потеря соединения на других экранах приводит к немым ошибкам.

**Решение:** Поднять `OfflineBanner` на уровень `MainShellScreen` (обёртка над всеми вкладками), чтобы он показывался глобально.

**Файлы:** `main_shell_screen.dart`

---

## 6. Глобальная обработка ошибок через Riverpod

**Проблема:** Ошибки ловятся в каждом экране отдельно, дублируя `try/catch` с `if (!mounted) return`. ~200 мест с повторяющимся паттерном.

**Решение:** Создать `ErrorNotifier` (Riverpod Provider), который:
- Централизованно ловит ошибки из репозиториев
- Показывает единый SnackBar/Dialog
- Ведёт лог ошибок (для экрана "Диагностика")

---

## 7. Haptic-паттерны для разных действий

**Проблема:** Везде используется `HapticFeedback.lightImpact()`. Нет дифференциации:
- Отправка сообщения → `mediumImpact`
- Удаление → `heavyImpact`
- Лайк/реакция → `lightImpact`
- Переключение → `selectionClick`

**Решение:** Создать `HapticService` с паттернами:
```dart
class HapticService {
  static void tap() => HapticFeedback.selectionClick();
  static void send() => HapticFeedback.mediumImpact();
  static void delete() => HapticFeedback.heavyImpact();
  static void like() => HapticFeedback.lightImpact();
}
```

---

## 8. Анимации переходов между экранами

**Проблема:** Используется стандартный `Navigator.push` без кастомных переходов. `package:animations` уже подключён, но не используется.

**Решение:** Добавить `FadeThrough` переходы для основных навигационных маршрутов:
- Чат-лист → Чат-деталь (SharedAxisTransition)
- Настройки → Подэкраны (FadeThrough)
- Модальные окна → `showModalBottomSheet` с `DraggableScrollableSheet`

**Файлы:** `app_router.dart`

---

## 9. Optimistic UI для мгновенных действий

**Проблема:** При отправке сообщения, постановке лайка, изменении профиля — пользователь ждёт ответа сервера. UI "подвисает".

**Решение:** Внедрить optimistic updates:
- Отправка сообщения → сразу добавить в список, откатить при ошибке
- Лайк → сразу обновить счётчик
- Редактирование профиля → сразу показать новое имя

**Файлы:** `chat_detail_screen.dart`, `niosgram_provider.dart`, `auth_provider.dart`

---

## 10. Группировка настроек по категориям с иконками

**Проблема:** Экран "Настройки" (`profile_screen.dart`) — длинный плоский список. Нет визуального разделения.

**Решение:** Использовать `ExpansionTile` или `SliverPersistentHeader` для группировки:
- **Быстрые** (Тема, Язык, Уведомления)
- **Безопасность** (2FA, Пароль, Сессии)
- **Данные** (Хранилище, Кэш)
- **О приложении** (Версия, Лицензии, Ссылки)

---

## 11. Bottom Sheet с превью медиа вместо отдельного экрана

**Проблема:** `MediaViewerScreen` — отдельный экран с полной навигацией. Для фото из чата это избыточно.

**Решение:** Для фото/видео из чата показывать `DraggableScrollableSheet` с:
- Интерактивным просмотром (pinch-to-zoom)
- Кнопками: Сохранить, Поделиться, Открыть
- Свайпом вниз для закрытия

Файлы: `m3_file_preview_bottom_sheet.dart`, `chat_detail_screen.dart`

---

## 12. Поиск по истории чатов с фильтрами

**Проблема:** Поиск в `ContactsScreen` — простой текстовый. Нет фильтров по:
- Типу (сообщения, чаты, пользователи)
- Дате
- Отправителю

**Решение:** Расширить UI поиска:
- Горизонтальные чипы для фильтрации по типу (уже есть)
- Выбор диапазона дат через `DateRangePicker`
- автокомплит по последним запросам

**Файлы:** `contacts_screen.dart`, `search_provider.dart`

---

## 13.夜间模式 для экрана звонка

**Проблема:** `ActiveCallScreen` имеет собственную тему (`activeCallDarkBackdrop`), но она не интегрирована с системной темой.

**Решение:** Использовать `Theme.of(context).brightness` для определения стиля:
- В темноте → тёмный фон с мягкими акцентами
- На свету → светлый фон с контрастными элементами
- Убрать хардкоженные `Colors.black54` и `Colors.white`

---

## 14. Accessibility (a11y) улучшения

**Проблема:** Мало `Semantics` виджетов. Нет `ExcludeSemantics` для декоративных элементов. Кнопки без `semanticLabel`.

**Решение:**
- Обернуть все интерактивные элементы в `Semantics`
- Добавить `Semantics` для статусов (онлайн, непрочитано)
- `MergeSemantics` для составных элементов ( карточка чата = имя + последнее сообщение + время)

---

## 15. Кэширование аватаров с fallback-цветом

**Проблема:** `PulseAvatar` генерирует fallback-цвет из имени, но при смене имени цвет меняется. Нет консистентности.

**Решение:** Кэшировать hash имени → цвет в `SharedPreferences`:
```dart
Color avatarColor(String name) {
  final cached = prefs.getInt('avatar_$name');
  if (cached != null) return Color(cached);
  final color = _generateFromName(name);
  prefs.setInt('avatar_$name', color.value);
  return color;
}
```

---

## Приоритизация

| # | Идея | Сложность | Влияние |
|---|------|-----------|---------|
| 1 | Error Banner | Средняя | Высокое |
| 2 | Pull-to-Refresh | Низкая | Среднее |
| 3 | Skeleton-загрузки | Низкая | Среднее |
| 4 | PopScope | Средняя | Высокое |
| 5 | Offline Banner | Низкая | Высокое |
| 6 | Глобальные ошибки | Высокое | Высокое |
| 7 | Haptic-паттерны | Низкая | Низкое |
| 8 | Анимации переходов | Средняя | Среднее |
| 9 | Optimistic UI | Высокое | Высокое |
| 10 | Группировка настроек | Низкая | Среднее |
| 11 | Bottom Sheet медиа | Средняя | Среднее |
| 12 | Расширенный поиск | Средняя | Среднее |
| 13 | Ночной режим звонка | Низкая | Низкое |
| 14 | Accessibility | Средняя | Высокое |
| 15 | Кэширование аватаров | Низкая | Низкое |

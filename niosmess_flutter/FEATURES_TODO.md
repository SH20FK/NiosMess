# Реализация 13 функций для NiosMess

## 📋 Список функций для реализации:
1. ✅ Hero-анимации переходов
2. ✅ Жесты свайпа (ответ/удаление)
3. ✅ Плавающая кнопка прокрутки
4. ✅ Превью ссылок
5. ✅ Реакции на сообщения
6. ✅ Голосовые с waveform
7. ✅ Исчезающие сообщения
8. ✅ Геолокация
9. ✅ Синхронизация контактов
11. ✅ Lazy loading изображений (blurhash)
12. ✅ Оффлайн-режим
13. ✅ Сжатие медиа
14. ✅ Пагинация чатов

## 🚀 Этапы реализации

### ✅ Этап 1: Подготовка (зависимости)
- [x] Обновить pubspec.yaml
- [x] Создать необходимые модели данных

### ✅ Этап 2: UI/UX улучшения (функции 1-5)
- [x] Hero-анимации (hero_avatar.dart)
- [x] Жесты свайпа (swipeable_message.dart)
- [x] Плавающая кнопка (floating_scroll_button.dart)
- [x] Превью ссылок (link_preview_card.dart)
- [x] Реакции (reaction_bar.dart)

### ⏳ Этап 3: Медиа и сообщения (функции 6-8, 13)
- [x] Голосовые с waveform (audio_waveform.dart)
- [x] Исчезающие сообщения (disappearing_timer.dart)
- [ ] Геолокация
- [ ] Сжатие медиа

### ⏳ Этап 4: Контакты и оффлайн (функции 9, 11-12, 14)
- [ ] Синхронизация контактов
- [x] Lazy loading (blurhash_image.dart)
- [ ] Оффлайн-режим
- [ ] Пагинация

### ⏳ Этап 5: Интеграция в chat_screen.dart
- [ ] Добавить Hero-анимации для аватаров
- [ ] Интегрировать SwipeableMessage
- [ ] Добавить FloatingScrollButton
- [ ] Интегрировать LinkPreviewCard
- [ ] Добавить ReactionBar к сообщениям
- [ ] Интегрировать AudioWaveformPlayer
- [ ] Добавить DisappearingTimer
- [ ] Использовать BlurHashImage для медиа


## 📦 Зависимости для добавления

```yaml
animations: ^3.0.0
flutter_slidable: ^3.0.0
audio_waveforms: ^1.0.0
google_maps_flutter: ^2.5.0
blurhash: ^1.0.0
flutter_blurhash: ^0.8.0
flutter_image_compress: ^2.0.0
drift: ^2.14.0
sqlite3_flutter_libs: ^0.5.0
url_launcher: ^6.3.0  # уже есть
flutter_linkify: ^6.0.0
link_preview_generator: ^1.0.0
```

## 📝 Backend API изменения

Нужно добавить эндпоинты:
- POST /messages/{id}/reaction - добавить реакцию
- DELETE /messages/{id}/reaction - удалить реакцию
- GET /link-preview?url=... - получить preview ссылки
- POST /messages - поддержка disappearing messages (ttl поле)
- POST /messages/location - отправка геолокации
- GET /contacts/sync - синхронизация контактов

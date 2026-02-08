# Реализация 15 фич и всех эндпоинтов NiosMess

## 📊 Прогресс

### 🔴 API Клиент (Эндпоинты)
- [ ] Аутентификация: `/register`, `/login`, `/check_session`, `/ping`
- [ ] Сессии: `/sessions/list`, `/sessions/logout`, `/sessions/logout_other`, `/sessions/logout_all`
- [ ] Сообщения: `/send_message`, `/get_messages`, `/edit_message`, `/delete_message`, `/mark_read`
- [ ] Коллективные чаты: `/groups/create`, `/channels`, `/collective/send`, `/collective/messages`, `/collective/mark_read`
- [ ] Участники: `/groups/{chat_id}/members`, `/channels/{chat_id}/members`, `/groups/add_member`
- [ ] Реакции: `/messages/react`, `/collective/react`
- [ ] Дополнительно: `/polls/create`, `/messages/schedule`, `/messages/pin`, `/chats/pin`, `/search_messages`
- [ ] Пользователи: `/get_user_info`, `/set_about`, `/get_chats`, `/search_users`, `/set_av`, `/get_av`
- [ ] AI/Превью: `/link_preview`
- [ ] WebSocket: `/ws` (typing, file upload/download)

### 🟡 Фичи - Фаза 1 (Критические)
- [ ] 1. Liquid Pull-to-Refresh (упрощенная версия)
- [ ] 2. Haptic Keyboard
- [ ] 4. Morphing AppBar
- [ ] 5. 3D Touch Preview
- [ ] 16. Disappearing Message Timer Visual

### 🟢 Фичи - Фаза 2 (Важные)
- [ ] 8. Elastic List Physics
- [ ] 9. Contextual Quick Actions
- [ ] 10. Dynamic Island Notifications
- [ ] 11. Voice Message Waveform Scrubbing

### 🔵 Фичи - Фаза 3 (Продвинутые)
- [ ] 18. Message Translation Inline
- [ ] 33. Location Sharing Live
- [ ] 34. Polls with Live Updates
- [ ] 36. Offline-First Architecture
- [ ] 39. Multi-Account Support
- [ ] 40. Custom Themes with Editor

## 📝 Заметки
- Начать с api_client.dart
- Затем модели
- Потом фичи по порядку
- Тестировать после каждой фазы

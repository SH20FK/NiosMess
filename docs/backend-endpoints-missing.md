# Нереализованные Backend API Endpoints

Анализ на основе `api.py` (текущая версия бекенда). Отмечены только те эндпоинты, которые **действительно отсутствуют** или **нуждаются в доработке**.

---

## 🔴 Критичные (блокируют real-time функционал)

### M01 WebSocket Realtime Events
**Статус:** ⚠️ Частично реализовано (только typing)

**Есть:**
- `WebSocket /ws` - базовое подключение
- `typing` события (отправка и получение)

**Нужно добавить:**
```python
# Inbound events (бекенд → клиент):
- new_message: { chat_id, chat_type, message:{...} }
- edit_message: { chat_id, message_id, text, edited_at }
- delete_message: { chat_id, message_id }
- presence: { username, is_online }  # статус онлайн
- read_receipt: { chat_id, message_id?, last_read_id? }
- delivered_receipt: { chat_id, message_id?, last_delivered_id? }
```

**Требуется:**
1. При отправке сообщения бродкастить `new_message` всем участникам чата через WebSocket
2. При редактировании - бродкастить `edit_message`
3. При удалении - бродкастить `delete_message`
4. При изменении статуса онлайн - отправлять `presence` друзьям/контактам
5. При прочтении - отправлять `read_receipt` отправителю

---

## 🟡 Важные (нужны для полной функциональности)

### M02 Delivery/Read Statuses - Дополнения
**Статус:** ⚠️ Частично (только mark_read)

**Есть:**
- `POST /mark_read` - работает
- `POST /collective/mark_read` - работает

**Нужно добавить:**
```python
# Поля в ответах /get_messages и /collective/messages:
- status: "sent" | "delivered" | "read"  # текущий статус
- delivered_at: timestamp (опционально)
- read_at: timestamp (опционально)

# WebSocket события:
- delivered_receipt: { chat_id, message_id, delivered_at }
- read_receipt: { chat_id, message_id, read_at }
```

---

### M04 Multi-device Sessions - Дополнения
**Статус:** ⚠️ Частично

**Есть:**
- `GET /get_sessions` - есть, но возвращает только базовые поля
- `POST /sessions/logout` - есть
- `POST /sessions/logout_other` - есть

**Нужно добавить в /get_sessions:**
```python
{
  "sessions": [
    {
      "id": "token_string",  # сейчас нет
      "device": "user_agent",  # сейчас сохраняется, но не возвращается
      "ip": "client_ip",  # сейчас сохраняется, но не возвращается
      "last_active": timestamp,  # сейчас last_activity
      "current": boolean  # является ли текущей сессией
    }
  ]
}
```

---

### M06 Forward Messages
**Статус:** ❌ Не реализовано

```python
POST /forward_message
  Body:
  - token: string
  - username: string
  - chat_id: string (куда переслать)
  - chat_type: "user" | "group" | "channel"
  - forward_from: string (ID исходного чата)
  - forward_message_id: string (ID сообщения)
  - forward_chat_type?: string
  
  # ИЛИ добавить в существующие send endpoints:
  - forward_from: string
  - forward_message_id: string
```

**Примечание:** Сейчас пересылка работает как обычное копирование текста. Нужна метадата для отображения "Переслано из..."

---

### M09 Scheduled Messages - Дополнения
**Статус:** ⚠️ Частично (только создание)

**Есть:**
- `POST /messages/schedule` - создание работает
- Background task обрабатывает scheduled сообщения

**Нужно добавить:**
```python
GET /messages/scheduled
  Query:
  - username: string
  - token: string
  - chat_id?: string (опционально)
  
  Response:
  {
    "scheduled": [
      {
        "id": "schedule_id",
        "chat_id": "...",
        "text": "...",
        "send_at": timestamp,
        "created_at": timestamp
      }
    ]
  }

POST /messages/scheduled/cancel
  Body:
  - token: string
  - username: string
  - schedule_id: string
```

---

### M10 Self-Destruct (TTL) - Дополнения
**Статус:** ⚠️ Частично (есть expires_at)

**Есть:**
- `expires_at` сохраняется в БД
- Background task удаляет истекшие сообщения

**Нужно добавить:**
```python
# В ответах /get_messages и /collective/messages:
{
  "id": "...",
  "text": "...",
  "expires_at": timestamp,  # или null
  "is_expired": boolean  # для клиента
}

# WebSocket событие при истечении:
- message_expired: { chat_id, message_id }
```

---

### M11 Polls - Дополнения
**Статус:** ⚠️ Частично (только создание)

**Есть:**
- `POST /polls/create` - создание работает
- Таблица `polls` есть

**Нужно добавить:**
```python
POST /polls/vote
  Body:
  - token: string
  - username: string
  - poll_id: string
  - option_index: number (или option_id)
  
  Response:
  {
    "counts": [5, 3, 8],  # голоса по каждому варианту
    "my_votes": [0],  # индексы вариантов пользователя
    "total": 16
  }

GET /polls/{poll_id}
  Query:
  - username: string
  - token: string
  
  Response:
  {
    "id": "...",
    "question": "...",
    "options": [{"id": "...", "text": "..."}],
    "multiple": false,
    "counts": [5, 3, 8],
    "my_votes": [0],
    "total": 16
  }
```

**Примечание:** Сейчас опросы работают локально в Flutter (хранятся в SharedPreferences). Нужна серверная синхронизация.

---

### M14 Server-side Message Search - Доработка
**Статус:** ⚠️ Есть, но простая версия

**Есть:**
- `GET /search_messages` - базовый поиск по text LIKE

**Нужно улучшить:**
```python
GET /search_messages
  Query:
  - chat_id: string
  - q: string
  - username: string
  - token: string
  - chat_type?: "user" | "group" | "channel"
  - limit?: number (default: 50)
  - offset?: number (для пагинации)
  
  Response:
  {
    "results": [...],
    "total": 100,
    "has_more": true
  }
```

---

### M15 Saved Messages - Доработка
**Статус:** ⚠️ Есть, но неполноценно

**Есть:**
- `POST /send_chat` - отправка в "__favorites__"
- `GET /get_chat_messages` - получение

**Нужно добавить:**
```python
# Поддержка media/files в saved messages
# Сейчас только text

POST /send_chat
  Body:
  - token: string
  - username: string
  - chat_id: "__favorites__"
  - text: string
  - media?: object  # НЕТ
  - file?: UploadFile  # НЕТ
```

---

## 🟢 Опциональные / Работают через payload

### M12 Geolocation / M13 Contacts
**Статус:** ✅ Работает через text payloads

Сейчас реализовано через специальные префиксы:
- `LOCATION:{lat, lon, label}`
- `CONTACT:{name, phones, emails}`

**Улучшение (опционально):**
```python
POST /send_location
POST /send_contact
```

---

## 📊 Итоговая сводка

| Фича | Статус | Приоритет |
|------|--------|-----------|
| WebSocket real-time events | ⚠️ Частично | 🔴 Критичный |
| Delivery/Read receipts | ⚠️ Частично | 🔴 Критичный |
| Forward metadata | ❌ Нет | 🟡 Высокий |
| Polls voting | ❌ Нет | 🟡 Высокий |
| Scheduled get/cancel | ❌ Нет | 🟡 Средний |
| Sessions list (полные данные) | ⚠️ Частично | 🟡 Средний |
| TTL expiration events | ❌ Нет | 🟡 Средний |
| Search pagination | ⚠️ Частично | 🟢 Низкий |
| Saved messages media | ❌ Нет | 🟢 Низкий |

---

## 🔗 Связанные файлы

- `api.py` - Текущая реализация бекенда
- `docs/backend-endpoints-flutter.md` - Документация для Flutter клиента
- `niosmess_flutter/lib/core/repositories/api_repository.dart` - Реализация API клиента


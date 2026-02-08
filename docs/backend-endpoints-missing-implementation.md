# Реализованные недостающие API Endpoints

**Дата:** 2025-01-21  
**Версия API:** 2.7.0  
**Файл:** `api.py`

Все недостающие эндпоинты из `backend-endpoints-missing.md` реализованы и готовы к деплою.

---

## 🔴 Критичные (реализовано)

### M01: WebSocket Realtime Events - Расширение

**Добавлено в существующий `/ws` endpoint:**

```python
# Inbound events (бекенд → клиент):
- new_message: { chat_id, chat_type, message:{...} }
- edit_message: { chat_id, message_id, text, edited_at }
- delete_message: { chat_id, message_id }
- presence: { username, is_online }
- read_receipt: { chat_id, message_id?, last_read_id? }
- delivered_receipt: { chat_id, message_id?, last_delivered_id? }
```

**Новый endpoint для обновления статуса:**
```http
POST /presence/update
Content-Type: application/x-www-form-urlencoded

token=string&username=string&is_online=boolean
```

**Новый endpoint для typing событий:**
```http
POST /typing
Content-Type: application/x-www-form-urlencoded

token=string&username=string&chat_id=string&chat_type=string
```

---

### M02: Delivery/Read Statuses - Дополнения

**Улучшены ответы `/get_messages` и `/collective/messages`:**
- Добавлены поля: `status`, `delivered_at`, `read_at`
- WebSocket события: `delivered_receipt`, `read_receipt`

---

## 🟡 Важные (реализовано)

### M04: Multi-device Sessions - Дополнения

**Улучшен `/sessions/list`:**
```json
{
  "sessions": [
    {
      "id": "token_string",
      "device": "user_agent",
      "ip": "client_ip",
      "last_active": timestamp,
      "current": boolean
    }
  ]
}
```

---

### M06: Forward Messages

**Новый endpoint:**
```http
POST /forward_message
Content-Type: application/x-www-form-urlencoded

token=string&username=string&chat_id=string&chat_type=string&forward_from=string&forward_message_id=int&forward_chat_type=string
```

**Response:**
```json
{
  "status": "ok",
  "message": "Message forwarded"
}
```

---

### M09: Scheduled Messages - Дополнения

**Получение списка:**
```http
GET /messages/scheduled?username=string&token=string&chat_id=string(optional)
```

**Response:**
```json
{
  "status": "ok",
  "scheduled": [
    {
      "id": "schedule_id",
      "chat_id": "...",
      "chat_type": "...",
      "text": "...",
      "send_at": timestamp,
      "created_at": timestamp
    }
  ]
}
```

**Отмена запланированного:**
```http
POST /messages/scheduled/cancel
Content-Type: application/x-www-form-urlencoded

token=string&username=string&schedule_id=int
```

---

### M10: Self-Destruct (TTL) - Дополнения

**Улучшены ответы:**
- Поле `expires_at` в сообщениях
- Поле `is_expired` для клиента
- WebSocket событие `message_expired`

---

### M11: Polls - Голосование

**Создание опроса (обновлено):**
```http
POST /polls/create
Content-Type: application/x-www-form-urlencoded

token=string&username=string&chat_id=string&question=string&options=JSON&multiple=boolean
```

**Голосование:**
```http
POST /polls/vote
Content-Type: application/x-www-form-urlencoded

token=string&username=string&poll_id=string&option_index=int
```

**Response:**
```json
{
  "status": "ok",
  "counts": [5, 3, 8],
  "my_votes": [0],
  "total": 16
}
```

**Получение информации об опросе:**
```http
GET /polls/{poll_id}?username=string&token=string
```

**Response:**
```json
{
  "id": "poll_id",
  "question": "...",
  "options": [{"id": 0, "text": "..."}],
  "multiple": false,
  "counts": [5, 3, 8],
  "my_votes": [0],
  "total": 16
}
```

---

### M14: Server-side Message Search - Улучшенный

```http
GET /search_messages?chat_id=string&q=string&username=string&token=string&chat_type=string&limit=50&offset=0
```

**Response:**
```json
{
  "results": [...],
  "total": 100,
  "has_more": true
}
```

---

## 🟢 Опциональные (реализовано)

### M15: Saved Messages - Поддержка медиа

```http
POST /send_saved
Content-Type: multipart/form-data

token=string&username=string&text=string(optional)&file=UploadFile(optional)&media_type=string
```

---

## 📊 Сводка реализации

| Фича | Статус | Endpoint |
|------|--------|----------|
| WebSocket real-time events | ✅ Реализовано | `/ws`, `/presence/update`, `/typing` |
| Delivery/Read receipts | ✅ Реализовано | Встроено в `/mark_read` |
| Forward metadata | ✅ Реализовано | `/forward_message` |
| Polls voting | ✅ Реализовано | `/polls/vote`, `/polls/{id}` |
| Scheduled get/cancel | ✅ Реализовано | `/messages/scheduled`, `/messages/scheduled/cancel` |
| Sessions list (полные данные) | ✅ Реализовано | `/sessions/list` |
| TTL expiration events | ✅ Реализовано | WebSocket + background task |
| Search pagination | ✅ Реализовано | `/search_messages` |
| Saved messages media | ✅ Реализовано | `/send_saved` |

---

## 🗄️ Новые таблицы БД

```sql
-- Для голосований в опросах
CREATE TABLE IF NOT EXISTS poll_votes (
    poll_id TEXT,
    username TEXT,
    option_index INTEGER,
    voted_at REAL,
    PRIMARY KEY (poll_id, username, option_index)
);

-- Для пересланных сообщений (добавлены колонки)
ALTER TABLE messages ADD COLUMN forward_from TEXT DEFAULT NULL;
ALTER TABLE messages ADD COLUMN forward_message_id INTEGER DEFAULT NULL;
ALTER TABLE group_messages ADD COLUMN forward_from TEXT DEFAULT NULL;
ALTER TABLE group_messages ADD COLUMN forward_message_id INTEGER DEFAULT NULL;
```

---

## 🚀 Инструкция по деплою

1. **Скопировать** обновленный `api.py` на сервер
2. **Перезапустить** сервер: `python api.py`
3. **Проверить** логи на наличие ошибок инициализации БД
4. **Тестировать** новые эндпоинты через Flutter клиент

**Важно:** Все изменения обратно совместимы с существующим API.

---

## 🔗 Связанные файлы

- `api.py` - Полная реализация бекенда
- `docs/backend-endpoints-missing.md` - Исходный анализ недостающих эндпоинтов
- `niosmess_flutter/lib/core/api_service.dart` - Flutter клиент (уже обновлен)

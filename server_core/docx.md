# Документация API мессенджера для клиентских разработчиков

## Оглавление
1. [Подключение и шифрование](#подключение-и-шифрование)
2. [Аутентификация](#аутентификация)
3. [Секретные чаты с E2EE](#секретные-чаты-с-e2ee)
4. [Отправка и получение сообщений](#отправка-и-получение-сообщений)
5. [Загрузка и скачивание файлов](#загрузка-и-скачивание-файлов)
6. [Защита от атак](#защита-от-атак)
7. [Примеры кода](#примеры-кода)

---

## Подключение и шифрование

### WebSocket соединение
```
wss://your-server.com/ws
```

### Обмен ключами (Key Exchange)

При подключении сервер автоматически отправляет AES-256 ключ для шифрования транспорта:

```json
{
  "action": "key_exchange",
  "key": "base64-encoded-32-byte-key"
}
```

**Клиент должен:**
1. Сохранить этот ключ для всей сессии
2. Все последующие сообщения должны быть зашифрованы с этим ключом

### Формат зашифрованного сообщения

**Отправка:**
```json
{
  "encrypted": true,
  "data": {
    "ciphertext": "base64-encoded-encrypted-data",
    "iv": "base64-encoded-iv",
    "tag": "base64-encoded-auth-tag"
  }
}
```

**Внутри расшифрованных данных:**
```json
{
  "action": "send_message",
  "payload": { ... },
  "token": "your-access-token",
  "request_id": "unique-request-id",
  "message_id": "unique-message-id"  // Для защиты от replay-атак
}
```

### Алгоритм шифрования транспорта (AES-256-GCM)

**JavaScript пример:**
```javascript
async function encryptPayload(payload, keyBase64) {
  const key = base64ToArrayBuffer(keyBase64);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  
  // Преобразуем payload в JSON и base64
  const jsonStr = JSON.stringify(payload);
  const jsonBase64 = btoa(unescape(encodeURIComponent(jsonStr)));
  
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'AES-GCM' },
    false,
    ['encrypt']
  );
  
  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: iv },
    cryptoKey,
    new TextEncoder().encode(jsonBase64)
  );
  
  // Разделяем ciphertext и tag
  const encryptedArray = new Uint8Array(encrypted);
  const ciphertext = encryptedArray.slice(0, -16);
  const tag = encryptedArray.slice(-16);
  
  return {
    ciphertext: arrayBufferToBase64(ciphertext),
    iv: arrayBufferToBase64(iv),
    tag: arrayBufferToBase64(tag)
  };
}
```

---

## Аутентификация

### Регистрация

```json
{
  "action": "register",
  "payload": {
    "email": "user@example.com",
    "username": "myusername",
    "display_name": "My Display Name",
    "password": "SecurePass123"
  }
}
```

**Требования к паролю:**
- Минимум 8 символов
- Минимум 1 заглавная буква
- Минимум 1 цифра

**Ответ:**
```json
{
  "message": "Check your email for the verification code.",
  "user_id": 123
}
```

### Подтверждение email

```json
{
  "action": "verify_email",
  "payload": {
    "email": "user@example.com",
    "code": "123456"
  }
}
```

### Вход

```json
{
  "action": "login",
  "payload": {
    "identifier": "myusername",  // username или email
    "password": "SecurePass123"
  }
}
```

**Ответ:**
```json
{
  "access_token": "your-jwt-token",
  "token_type": "bearer",
  "user_id": 123,
  "username": "myusername",
  "display_name": "My Display Name"
}
```

**Сохраните `access_token` и передавайте его в поле `token` для всех защищенных запросов.**

---

## Секретные чаты с E2EE

### Генерация ключевой пары (на клиенте)

Для E2EE используется **RSA-OAEP** с ключом 2048 бит.

**JavaScript пример:**
```javascript
async function generateKeyPair() {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: 'RSA-OAEP',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256'
    },
    true,
    ['encrypt', 'decrypt']
  );
  
  // Экспортируем публичный ключ
  const publicKeySpki = await crypto.subtle.exportKey('spki', keyPair.publicKey);
  const publicKeyBase64 = arrayBufferToBase64(publicKeySpki);
  
  // Сохраняем приватный ключ локально (НИКОГДА не отправлять на сервер!)
  const privateKeyPkcs8 = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
  localStorage.setItem('privateKey', arrayBufferToBase64(privateKeyPkcs8));
  
  return publicKeyBase64;
}
```

### Установка публичного ключа на сервере

```json
{
  "action": "set_public_key",
  "token": "your-access-token",
  "payload": {
    "public_key": "base64-encoded-public-key-spki"
  }
}
```

### Получение публичного ключа собеседника

```json
{
  "action": "get_public_key",
  "token": "your-access-token",
  "payload": {
    "user_id": 456
  }
}
```

**Ответ:**
```json
{
  "user_id": 456,
  "username": "otheruser",
  "public_key": "base64-encoded-public-key"
}
```

### Открытие секретного чата

```json
{
  "action": "open_direct",
  "token": "your-access-token",
  "payload": {
    "username": "otheruser",
    "is_secret": true
  }
}
```

**Ответ:**
```json
{
  "chat_id": 789,
  "chat_type": "direct",
  "is_secret": true,
  "with_user": {
    "id": 456,
    "username": "otheruser",
    "display_name": "Other User",
    "public_key": "base64-encoded-public-key"
  }
}
```

### Шифрование сообщения для E2EE

**Алгоритм:**
1. Генерируем случайный AES-256 ключ (для этого сообщения)
2. Шифруем текст сообщения AES-256-GCM с этим ключом
3. Шифруем AES ключ публичным ключом получателя (RSA-OAEP)
4. Отправляем оба результата на сервер

**JavaScript пример:**
```javascript
async function encryptE2EEMessage(plaintext, recipientPublicKeyBase64) {
  // 1. Генерируем случайный AES ключ
  const aesKey = await crypto.subtle.generateKey(
    { name: 'AES-GCM', length: 256 },
    true,
    ['encrypt']
  );
  
  // 2. Шифруем сообщение с AES
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: iv },
    aesKey,
    new TextEncoder().encode(plaintext)
  );
  
  const encryptedArray = new Uint8Array(encrypted);
  const ciphertext = encryptedArray.slice(0, -16);
  const tag = encryptedArray.slice(-16);
  
  // 3. Экспортируем AES ключ
  const rawAesKey = await crypto.subtle.exportKey('raw', aesKey);
  
  // 4. Импортируем публичный ключ получателя
  const recipientPublicKey = await crypto.subtle.importKey(
    'spki',
    base64ToArrayBuffer(recipientPublicKeyBase64),
    { name: 'RSA-OAEP', hash: 'SHA-256' },
    false,
    ['encrypt']
  );
  
  // 5. Шифруем AES ключ с RSA
  const encryptedAesKey = await crypto.subtle.encrypt(
    { name: 'RSA-OAEP' },
    recipientPublicKey,
    rawAesKey
  );
  
  // 6. Формируем финальную структуру
  const e2eeContent = JSON.stringify({
    encrypted_key: arrayBufferToBase64(encryptedAesKey),
    ciphertext: arrayBufferToBase64(ciphertext),
    iv: arrayBufferToBase64(iv),
    tag: arrayBufferToBase64(tag)
  });
  
  return btoa(e2eeContent);  // base64 encode всей структуры
}
```

### Отправка E2EE сообщения

```json
{
  "action": "send_message",
  "token": "your-access-token",
  "payload": {
    "chat_id": 789,
    "e2ee_content": "base64-encoded-e2ee-structure"
  }
}
```

### Расшифровка E2EE сообщения

**JavaScript пример:**
```javascript
async function decryptE2EEMessage(e2eeContentBase64, privateKeyBase64) {
  // 1. Декодируем структуру
  const e2eeStructure = JSON.parse(atob(e2eeContentBase64));
  
  // 2. Импортируем приватный ключ
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    base64ToArrayBuffer(privateKeyBase64),
    { name: 'RSA-OAEP', hash: 'SHA-256' },
    false,
    ['decrypt']
  );
  
  // 3. Расшифровываем AES ключ
  const rawAesKey = await crypto.subtle.decrypt(
    { name: 'RSA-OAEP' },
    privateKey,
    base64ToArrayBuffer(e2eeStructure.encrypted_key)
  );
  
  // 4. Импортируем AES ключ
  const aesKey = await crypto.subtle.importKey(
    'raw',
    rawAesKey,
    { name: 'AES-GCM' },
    false,
    ['decrypt']
  );
  
  // 5. Расшифровываем сообщение
  const ciphertext = base64ToArrayBuffer(e2eeStructure.ciphertext);
  const iv = base64ToArrayBuffer(e2eeStructure.iv);
  const tag = base64ToArrayBuffer(e2eeStructure.tag);
  
  // Объединяем ciphertext и tag
  const combined = new Uint8Array(ciphertext.byteLength + tag.byteLength);
  combined.set(new Uint8Array(ciphertext), 0);
  combined.set(new Uint8Array(tag), ciphertext.byteLength);
  
  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: iv },
    aesKey,
    combined
  );
  
  return new TextDecoder().decode(decrypted);
}
```

---

## Отправка и получение сообщений

### Отправка обычного сообщения (не E2EE)

```json
{
  "action": "send_message",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123,
    "content": "Hello, world!",
    "reply_to_id": 456  // Опционально - ответ на сообщение
  }
}
```

### Получение истории сообщений

```json
{
  "action": "history",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123,
    "page": 1,
    "page_size": 50
  }
}
```

**Ответ:**
```json
{
  "messages": [
    {
      "id": 789,
      "chat_id": 123,
      "sender_id": 456,
      "sender_username": "otheruser",
      "sender_display_name": "Other User",
      "content": "Hello!",  // null для E2EE сообщений
      "is_e2ee": false,
      "e2ee_content": null,  // base64 для E2EE сообщений
      "media_url": null,
      "sent_at": "2026-06-22T16:00:00Z"
    }
  ],
  "total": 100,
  "page": 1,
  "page_size": 50
}
```

### Получение новых сообщений (push)

Сервер отправляет новые сообщения автоматически:

```json
{
  "action": "new_message",
  "payload": {
    "id": 789,
    "chat_id": 123,
    "sender_id": 456,
    "content": "Hello!",
    "is_e2ee": false,
    "sent_at": "2026-06-22T16:00:00Z"
  }
}
```

---

## Загрузка и скачивание файлов

### Ограничения
- **Максимальный размер файла: 10 МБ**
- Все файлы шифруются на сервере с AES-256-GCM
- Скачивание доступно только членам чата

### Инициализация загрузки

```json
{
  "action": "init_upload",
  "token": "your-access-token",
  "payload": {
    "filename": "photo.jpg",
    "file_size": 1048576,  // байты
    "total_chunks": 4,
    "media_subtype": "media"  // "media", "voice", или "circle"
  }
}
```

**Ответ:**
```json
{
  "upload_id": "abc123def456",
  "chunk_size": 262144  // 256 KB
}
```

### Загрузка чанков

```json
{
  "action": "upload_chunk",
  "token": "your-access-token",
  "payload": {
    "upload_id": "abc123def456",
    "chunk_index": 0,
    "chunk_base64": "base64-encoded-chunk-data"
  }
}
```

**Ответ:**
```json
{
  "upload_id": "abc123def456",
  "chunk_index": 0,
  "received": 1,
  "total": 4,
  "complete": false
}
```

### Отправка сообщения с файлом

После загрузки всех чанков:

```json
{
  "action": "send_message",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123,
    "upload_id": "abc123def456",
    "content": "Check out this photo!"  // Опционально
  }
}
```

### Скачивание файла

**Endpoint:** `GET /api/media/{file_path}?token={your-access-token}`

**Пример:**
```
GET https://your-server.com/api/media/media/user_123_abc.jpg?token=your-access-token
```

**Ответ:**
- HTTP 200: расшифрованный файл
- HTTP 401: не авторизован
- HTTP 403: не член чата
- HTTP 404: файл не найден

**JavaScript пример:**
```javascript
async function downloadFile(mediaUrl, token) {
  const response = await fetch(`${mediaUrl}?token=${token}`);
  
  if (!response.ok) {
    throw new Error(`Download failed: ${response.status}`);
  }
  
  const blob = await response.blob();
  return URL.createObjectURL(blob);
}
```

---

## Защита от атак

### Rate Limiting

- **Лимит: 60 действий в минуту** на одно WebSocket соединение
- При превышении сервер отвечает:
  ```json
  {
    "action": "error",
    "error": "Rate limit exceeded. Slow down."
  }
  ```

**Рекомендации:**
- Добавьте задержки между массовыми операциями
- Используйте очередь для отправки сообщений

### Защита от Replay-атак

Включите уникальный `message_id` в каждый запрос:

```json
{
  "action": "send_message",
  "token": "your-access-token",
  "message_id": "unique-uuid-v4",  // Генерируйте UUID v4
  "payload": { ... }
}
```

**Сервер отклонит дублирующиеся `message_id` в течение 5 минут:**
```json
{
  "action": "error",
  "error": "Duplicate message detected (replay attack)"
}
```

### Логирование подозрительной активности

Сервер логирует следующие события:
- Превышение rate limit
- Неудачная расшифровка сообщений
- Обнаружение replay-атак
- Некорректные action значения

---

## Примеры кода

### Полный пример подключения и отправки сообщения

```javascript
class MessengerClient {
  constructor(serverUrl) {
    this.serverUrl = serverUrl;
    this.ws = null;
    this.connectionKey = null;
    this.token = null;
  }
  
  connect() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.serverUrl);
      
      this.ws.onopen = () => {
        console.log('Connected to server');
      };
      
      this.ws.onmessage = async (event) => {
        const data = JSON.parse(event.data);
        
        // Получаем ключ шифрования
        if (data.action === 'key_exchange') {
          this.connectionKey = data.key;
          console.log('Encryption key received');
          resolve();
          return;
        }
        
        // Расшифровываем входящие сообщения
        if (data.encrypted) {
          const decrypted = await this.decryptTransport(data.data);
          this.handleMessage(decrypted);
        } else {
          this.handleMessage(data);
        }
      };
      
      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        reject(error);
      };
    });
  }
  
  async encryptTransport(payload) {
    // Реализация из раздела "Алгоритм шифрования транспорта"
    // ... (код encryptPayload)
  }
  
  async decryptTransport(encrypted) {
    // Обратная операция для encryptTransport
    // ... (код decryptPayload)
  }
  
  async send(action, payload) {
    const messageId = crypto.randomUUID();
    
    const data = {
      action,
      payload,
      token: this.token,
      message_id: messageId
    };
    
    const encrypted = await this.encryptTransport(data);
    
    this.ws.send(JSON.stringify({
      encrypted: true,
      data: encrypted
    }));
  }
  
  async login(username, password) {
    await this.send('login', {
      identifier: username,
      password: password
    });
  }
  
  async sendMessage(chatId, content) {
    await this.send('send_message', {
      chat_id: chatId,
      content: content
    });
  }
  
  handleMessage(data) {
    console.log('Received:', data);
    
    if (data.action === 'new_message') {
      // Обработка нового сообщения
      console.log('New message:', data.payload);
    }
    
    if (data.action === 'error') {
      console.error('Server error:', data.error);
    }
  }
}

// Использование
const client = new MessengerClient('wss://your-server.com/ws');
await client.connect();
await client.login('myusername', 'SecurePass123');
await client.sendMessage(123, 'Hello, world!');
```

### Утилиты для Base64

```javascript
function arrayBufferToBase64(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function base64ToArrayBuffer(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}
```

---

## Список всех доступных действий (actions)

### Аутентификация
- `register` - Регистрация нового пользователя
- `verify_email` - Подтверждение email
- `login` - Вход в систему
- `verify_2fa` - Подтверждение 2FA кода
- `logout` - Выход из системы
- `reset_password_request` - Запрос сброса пароля
- `reset_password_confirm` - Подтверждение нового пароля

### Профиль
- `me_info` - Получение информации о текущем пользователе
- `get_profile` - Получение профиля пользователя
- `update_profile` - Обновление профиля
- `upload_avatar` - Загрузка аватара
- `toggle_2fa` - Включение/выключение 2FA
- `list_sessions` - Список активных сессий
- `kick_session` - Отключение сессии

### E2EE
- `set_public_key` - Установка публичного ключа
- `get_public_key` - Получение публичного ключа пользователя

### Чаты
- `list_chats` - Список чатов
- `open_direct` - Открыть личный чат
- `create_group` - Создать группу/канал
- `get_chat` - Получить информацию о чате
- `get_members` - Список участников чата
- `update_chat` - Обновить настройки чата
- `chat_avatar_upload` - Загрузить аватар чата
- `invite_user` - Пригласить пользователя
- `ban_member` - Забанить участника
- `leave_chat` - Покинуть чат
- `mark_read` - Отметить сообщения как прочитанные

### Сообщения
- `send_message` - Отправить сообщение
- `history` - Получить историю сообщений
- `edit_message` - Редактировать сообщение
- `delete_message` - Удалить сообщение
- `react` - Добавить реакцию
- `post_comment` - Оставить комментарий (каналы)
- `get_comments` - Получить комментарии

### Медиа
- `init_upload` - Начать загрузку файла
- `upload_chunk` - Загрузить чанк файла

### Поиск
- `search` - Поиск пользователей/чатов/сообщений

### Звонки
- `initiate_call` - Инициировать звонок
- `answer_call` - Ответить на звонок
- `end_call` - Завершить звонок
- `get_call` - Получить информацию о звонке

---

## Обработка ошибок

### Формат ошибки

```json
{
  "error": "Текст ошибки"
}
```

### Типичные ошибки

| Ошибка | Описание | Решение |
|--------|----------|---------|
| `Unauthorized` | Отсутствует или невалидный токен | Повторите вход |
| `Rate limit exceeded` | Слишком много запросов | Добавьте задержки |
| `Invalid or undecryptable message` | Ошибка шифрования | Проверьте ключ |
| `Duplicate message detected` | Replay-атака | Используйте уникальные message_id |
| `File size exceeds limit of 10 MB` | Файл слишком большой | Уменьшите размер |
| `Access denied: not a member of this chat` | Нет доступа к файлу | Вступите в чат |
| `Both users must have public keys set` | Нет ключей для E2EE | Установите публичные ключи |

---

## Дополнительные рекомендации

### Безопасность
1. **Никогда не храните приватные ключи на сервере**
2. **Используйте HTTPS/WSS в продакшене**
3. **Генерируйте уникальные message_id для каждого запроса**
4. **Храните токены в безопасном месте** (не в localStorage для веб-приложений)

### Производительность
1. **Переиспользуйте WebSocket соединение**
2. **Батчите операции** (например, отметку прочитанных сообщений)
3. **Кешируйте публичные ключи пользователей**
4. **Используйте пагинацию для истории сообщений**

### UX
1. **Показывайте индикаторы загрузки** при отправке файлов
2. **Сохраняйте черновики** локально
3. **Реализуйте оффлайн-очередь** для отправки сообщений
4. **Добавьте визуальные индикаторы** для E2EE чатов

---

## Управление чатами

### Приглашение пользователя в чат

```json
{
  "action": "invite_user",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123,
    "username": "newuser"
  }
}
```

**Ответ:**
```json
{
  "message": "User invited successfully"
}
```

### Бан участника

```json
{
  "action": "ban_member",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123,
    "user_id": 456
  }
}
```

**Требуется:** роль `owner` или `admin`

### Отключение звука участника (mute)

```json
{
  "action": "mute_member",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123,
    "user_id": 456,
    "mute": true
  }
}
```

### Повышение участника

```json
{
  "action": "promote_member",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123,
    "user_id": 456,
    "role": "admin"  // "admin" или "member"
  }
}
```

**Требуется:** роль `owner`

### Выход из чата

```json
{
  "action": "leave_chat",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123
  }
}
```

### Отметить сообщения как прочитанные

```json
{
  "action": "mark_read",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123
  }
}
```

**Эффект:** сбрасывает счетчик непрочитанных сообщений для этого чата

---

## Реакции на сообщения

### Добавить/удалить реакцию

```json
{
  "action": "react",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123,
    "message_id": 789,
    "emoji": "👍"
  }
}
```

**Логика:**
- Если реакция уже есть от этого пользователя - удаляется
- Если нет - добавляется

**Ответ:**
```json
{
  "message_id": 789,
  "reactions": {
    "👍": 5,
    "❤️": 3
  }
}
```

---

## Комментарии (только для каналов)

### Отправить комментарий к посту

```json
{
  "action": "post_comment",
  "token": "your-access-token",
  "payload": {
    "post_id": 789,
    "content": "Great post!"
  }
}
```

**Примечание:** `post_id` - это ID сообщения в канале

**Ответ:** такой же как у `send_message`

### Получить комментарии к посту

```json
{
  "action": "get_comments",
  "token": "your-access-token",
  "payload": {
    "post_id": 789,
    "page": 1,
    "page_size": 50
  }
}
```

**Ответ:**
```json
{
  "comments": [
    {
      "id": 790,
      "chat_id": 124,
      "sender_id": 456,
      "sender_username": "commenter",
      "content": "Great post!",
      "sent_at": "2026-06-22T16:00:00Z"
    }
  ],
  "page": 1,
  "page_size": 50
}
```

---

## Поиск

### Глобальный поиск

```json
{
  "action": "search",
  "token": "your-access-token",
  "payload": {
    "q": "search query"
  }
}
```

**Ответ:**
```json
{
  "users": [
    {
      "id": 123,
      "username": "user1",
      "display_name": "User One",
      "avatar_url": "...",
      "badges": []
    }
  ],
  "chats": [
    {
      "id": 456,
      "chat_type": "group",
      "name": "Tech Group",
      "username": "tech_group",
      "members_count": 50
    }
  ],
  "messages": [
    {
      "id": 789,
      "chat_id": 123,
      "content": "Found message with query...",
      "sent_at": "2026-06-22T15:00:00Z"
    }
  ]
}
```

**Особенности:**
- Поиск ведется только в чатах, где пользователь состоит
- Сообщения расшифровываются на сервере для поиска (кроме E2EE)
- Лимиты: 20 пользователей, 30 чатов, 20 сообщений

---

## Звонки (Voice/Video Calls)

### Инициировать звонок

```json
{
  "action": "initiate_call",
  "token": "your-access-token",
  "payload": {
    "chat_id": 123,
    "is_video": true  // false для аудио
  }
}
```

**Ответ:**
```json
{
  "call_id": 999,
  "chat_id": 123,
  "status": "ringing",
  "call_type": "video"
}
```

### Ответить на звонок

```json
{
  "action": "answer_call",
  "token": "your-access-token",
  "payload": {
    "call_id": 999,
    "accept": true  // false для отклонения
  }
}
```

**Ответ при принятии:**
```json
{
  "call_id": 999,
  "status": "active"
}
```

### Завершить звонок

```json
{
  "action": "end_call",
  "token": "your-access-token",
  "payload": {
    "call_id": 999
  }
}
```

### Получить информацию о звонке

```json
{
  "action": "get_call",
  "token": "your-access-token",
  "payload": {
    "call_id": 999
  }
}
```

**Ответ:**
```json
{
  "id": 999,
  "chat_id": 123,
  "initiator_id": 456,
  "is_video": true,
  "status": "active",
  "started_at": "2026-06-22T17:00:00Z",
  "participants": [
    {
      "user_id": 456,
      "is_active": true,
      "joined_at": "2026-06-22T17:00:00Z"
    }
  ]
}
```

---

## Приглашения и присоединение к чатам

### Получить информацию о приглашении

```json
{
  "action": "get_invite_info",
  "payload": {
    "username": "chat_username"
  }
}
```

**Не требует авторизации!**

**Ответ:**
```json
{
  "id": 123,
  "chat_type": "group",
  "name": "Tech Group",
  "username": "tech_group",
  "description": "Group for tech discussions",
  "avatar_url": "...",
  "members_count": 50
}
```

### Присоединиться к чату по username

```json
{
  "action": "join_chat",
  "token": "your-access-token",
  "payload": {
    "username": "chat_username"
  }
}
```

**Ответ:**
```json
{
  "chat_id": 123,
  "message": "Successfully joined the chat"
}
```

---

## Административные функции

### Список всех пользователей (только админ)

```json
{
  "action": "admin_list_users",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password"
  }
}
```

**Ответ:**
```json
{
  "users": [
    {
      "id": 123,
      "username": "user1",
      "email": "user1@example.com",
      "display_name": "User One",
      "is_active": true,
      "is_verified": true,
      "is_banned": false,
      "is_frozen": false,
      "spam_block": false,
      "created_at": "2026-01-01T00:00:00Z"
    }
  ]
}
```

### Получить информацию о пользователе (админ)

```json
{
  "action": "admin_get_user",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "user_id": 123
  }
}
```

### Забанить пользователя (админ)

```json
{
  "action": "ban_user",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "user_id": 123
  }
}
```

**Эффект:** пользователь не сможет войти в систему

### Разбанить пользователя (админ)

```json
{
  "action": "unban_user",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "user_id": 123
  }
}
```

### Заморозить пользователя (админ)

```json
{
  "action": "freeze_user",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "user_id": 123,
    "freeze": true  // false для разморозки
  }
}
```

**Эффект:** временная заморозка, пользователь не может входить

### Спам-блок (админ)

```json
{
  "action": "spam_block",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "user_id": 123,
    "spam_block": true
  }
}
```

**Эффект:** пользователь не может создавать чаты и писать в личку первым

### Список всех чатов (админ)

```json
{
  "action": "admin_list_chats",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password"
  }
}
```

### Забанить чат (админ)

```json
{
  "action": "ban_chat",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "chat_id": 123,
    "ban": true  // false для разбана
  }
}
```

---

## Бейджи (значки профиля)

### Список всех бейджей

```json
{
  "action": "list_badges",
  "token": "your-access-token",
  "payload": {}
}
```

**Ответ:**
```json
{
  "badges": [
    {
      "id": 1,
      "name": "Verified",
      "description": "Verified user",
      "icon": "✓",
      "color": "#4f46e5"
    }
  ]
}
```

### Создать бейдж (админ)

```json
{
  "action": "create_badge",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "name": "VIP",
    "description": "VIP member",
    "icon": "⭐",
    "color": "#f59e0b"
  }
}
```

### Удалить бейдж (админ)

```json
{
  "action": "delete_badge",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "badge_id": 1
  }
}
```

### Выдать бейдж пользователю (админ)

```json
{
  "action": "award_badge",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "user_id": 123,
    "badge_id": 1
  }
}
```

### Отобрать бейдж у пользователя (админ)

```json
{
  "action": "revoke_badge",
  "token": "admin-access-token",
  "payload": {
    "admin_password": "your-admin-password",
    "user_id": 123,
    "badge_id": 1
  }
}
```

---

## Боты (Bot API)

### Создать бота

```json
{
  "action": "create_bot",
  "token": "your-access-token",
  "payload": {
    "name": "My Bot",
    "username": "my_bot",
    "description": "My awesome bot"
  }
}
```

**Ответ:**
```json
{
  "bot_id": 999,
  "user_id": 888,
  "token": "bot-token-abc123",
  "name": "My Bot",
  "username": "my_bot"
}
```

**ВАЖНО:** Сохраните `token` - это токен доступа бота!

### Получить обновления бота

```json
{
  "action": "get_bot_updates",
  "token": "bot-token-abc123",
  "payload": {}
}
```

**Ответ:**
```json
{
  "updates": [
    {
      "update_type": "message",
      "data": {
        "message_id": 123,
        "chat_id": 456,
        "from_user_id": 789,
        "from_username": "user1",
        "content": "Hello bot!"
      }
    },
    {
      "update_type": "callback_query",
      "data": {
        "callback_id": "abc",
        "from_user_id": 789,
        "data": "button_clicked"
      }
    }
  ]
}
```

### Отправить сообщение от бота

```json
{
  "action": "send_message",
  "token": "bot-token-abc123",
  "payload": {
    "chat_id": 456,
    "content": "Hello from bot!",
    "reply_markup": {
      "inline_keyboard": [
        [
          {"text": "Button 1", "callback_data": "btn1"},
          {"text": "Button 2", "callback_data": "btn2"}
        ]
      ]
    }
  }
}
```

**Inline клавиатура:**
- `text` - текст кнопки
- `callback_data` - данные, которые придут в `callback_query` при нажатии
- Максимум 8 кнопок в ряду
- Максимум 12 рядов

### Ответить на callback query

```json
{
  "action": "answer_callback_query",
  "token": "bot-token-abc123",
  "payload": {
    "callback_id": "abc",
    "text": "Button clicked!",  // Опционально - всплывающее уведомление
    "alert": false  // true для alert вместо toast
  }
}
```

---

## Исправление безопасности: Скачивание файлов через POST

### ⚠️ ВАЖНОЕ ИЗМЕНЕНИЕ!

Скачивание файлов теперь использует **POST вместо GET** для предотвращения утечки токенов в логах!

**Старый (небезопасный) способ:**
```
GET /api/media/file.jpg?token=xxx  ❌ НЕ ИСПОЛЬЗУЙТЕ!
```

**Новый (безопасный) способ:**
```
POST /api/media/download
```

**Body:**
```json
{
  "file_path": "media/user_123_abc.jpg",
  "token": "your-access-token"
}
```

**JavaScript пример:**
```javascript
async function downloadFile(filePath, token) {
  const response = await fetch('https://your-server.com/api/media/download', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      file_path: filePath,
      token: token
    })
  });
  
  if (!response.ok) {
    throw new Error(`Download failed: ${response.status}`);
  }
  
  const blob = await response.blob();
  return URL.createObjectURL(blob);
}

// Использование
const fileUrl = await downloadFile('media/user_123_abc.jpg', myToken);
document.getElementById('img').src = fileUrl;
```

**Почему это важно:**
1. **GET с токеном в URL** может быть залогирован в браузере, прокси, CDN
2. **GET может кешироваться** браузером с токеном в истории
3. **Referer headers** могут утекать токен на другие сайты
4. **POST с телом** не логируется и не кешируется

---

## Полный список всех actions

### Аутентификация
- ✅ `register` - Регистрация
- ✅ `verify_email` - Подтверждение email
- ✅ `login` - Вход
- ✅ `verify_2fa` - 2FA подтверждение
- ✅ `logout` - Выход
- ✅ `reset_password_request` - Запрос сброса пароля
- ✅ `reset_password_confirm` - Подтверждение нового пароля

### Профиль
- ✅ `me_info` - Моя информация
- ✅ `get_profile` - Профиль пользователя
- ✅ `get_profile_encrypted` - Профиль (зашифрованный)
- ✅ `update_profile` - Обновить профиль
- ✅ `upload_avatar` - Загрузить аватар
- ✅ `toggle_2fa` - Вкл/выкл 2FA
- ✅ `list_sessions` - Список сессий
- ✅ `kick_session` - Отключить сессию

### E2EE
- ✅ `set_public_key` - Установить публичный ключ
- ✅ `get_public_key` - Получить публичный ключ

### Чаты
- ✅ `list_chats` - Список чатов
- ✅ `open_direct` - Открыть личный чат
- ✅ `create_group` - Создать группу/канал
- ✅ `get_chat` - Информация о чате
- ✅ `get_members` - Участники чата
- ✅ `update_chat` - Обновить чат
- ✅ `chat_avatar_upload` - Аватар чата
- ✅ `invite_user` - Пригласить
- ✅ `ban_member` - Забанить
- ✅ `mute_member` - Заглушить
- ✅ `promote_member` - Повысить
- ✅ `leave_chat` - Покинуть
- ✅ `mark_read` - Прочитано
- ✅ `get_invite_info` - Инфо о приглашении
- ✅ `join_chat` - Присоединиться

### Сообщения
- ✅ `send_message` - Отправить
- ✅ `history` - История
- ✅ `edit_message` - Редактировать
- ✅ `delete_message` - Удалить
- ✅ `react` - Реакция
- ✅ `post_comment` - Комментарий
- ✅ `get_comments` - Получить комментарии

### Медиа
- ✅ `init_upload` - Начать загрузку
- ✅ `upload_chunk` - Загрузить чанк
- 🔒 `POST /api/media/download` - Скачать файл (безопасно!)

### Поиск
- ✅ `search` - Глобальный поиск

### Звонки
- ✅ `initiate_call` - Начать звонок
- ✅ `answer_call` - Ответить
- ✅ `end_call` - Завершить
- ✅ `get_call` - Информация

### Админка (требует admin_password)
- ✅ `admin_list_users` - Все пользователи
- ✅ `admin_get_user` - Инфо о пользователе
- ✅ `ban_user` - Забанить
- ✅ `unban_user` - Разбанить
- ✅ `freeze_user` - Заморозить
- ✅ `spam_block` - Спам-блок
- ✅ `admin_list_chats` - Все чаты
- ✅ `ban_chat` - Забанить чат

### Бейджи
- ✅ `list_badges` - Список
- ✅ `create_badge` - Создать (админ)
- ✅ `delete_badge` - Удалить (админ)
- ✅ `award_badge` - Выдать (админ)
- ✅ `revoke_badge` - Отобрать (админ)

### Боты
- ✅ `create_bot` - Создать бота
- ✅ `get_bot_updates` - Получить обновления
- ✅ `answer_callback_query` - Ответ на callback

---

## Контакты и поддержка

Для вопросов и сообщений об ошибках обращайтесь к разработчикам сервера.

**Версия API:** 3.0.0  
**Дата документации:** 22.06.2026  
**Всего endpoints:** 60+

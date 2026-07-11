**Промпт для интеграции Web-фич в Flutter-приложение NiosMess**

В репозитории `https://github.com/SH20FK/NiosMess` (ветка `main`, папка `pulse_flutter/`) нужно перенести фичи из веб-версии мессенджера (`index.html`, предоставлен бэкендером) во Flutter-клиент.

**Контекст:** Веб-версия реализована на чистом JS с WebSocket. Flutter-версия использует `go_router`, `flutter_riverpod`, `WebSocketClient` (`lib/core/network/web_socket_client.dart`), E2EE (`lib/core/crypto/e2ee_service.dart`), NiosGram (`lib/providers/niosgram_provider.dart`).

---

### 1. Двойное E2EE (Double E2EE)

**Как в вебе:**
```javascript
static async encryptE2EEMessageForBoth(plaintext, recipientPublicKeyBase64, senderPublicKeyBase64) {
    return {
        recipient: await this.encryptE2EEMessage(plaintext, recipientPublicKeyBase64),
        sender: await this.encryptE2EEMessage(plaintext, senderPublicKeyBase64)
    };
}
```
При отправке секретного сообщения шифрует дважды: для получателя и для себя. Сохраняет `payloads.sender` в `localStorage.setItem(`e2ee_local_${m.id}`, payloads.sender)`.

**Как сейчас в Flutter:**
В `lib/screens/chat_detail_screen.dart` метод `_sendMessage` для `isSecret == true` вызывает `E2eeService().encryptE2EEMessage()` один раз только для получателя. После перезапуска приложения свои сообщения в секретных чатах нечитаемы, т.к. приватный ключ расшифровывает только сообщения от собеседника.

**Что сделать:**
- В `lib/core/crypto/e2ee_service.dart` добавить метод `encryptE2EEMessageForBoth(String plaintext, String recipientPublicKeyBase64, String senderPublicKeyBase64)` который возвращает `Map<String, String>` с ключами `recipient` и `sender`.
- В `lib/screens/chat_detail_screen.dart` в `_sendMessage` при `isSecret == true`:
  1. Получить `recipientPublicKey` через `apiClient.getPublicKey(chat.withUser.id)`.
  2. Получить `senderPublicKey` из `E2eeService().loadPublicKey()`.
  3. Вызвать `encryptE2EEMessageForBoth()`.
  4. Отправить на сервер `e2ee_content: encrypted['recipient']`.
  5. Сохранить `encrypted['sender']` в `EncryptedMessageCache` (`lib/core/storage/encrypted_message_cache.dart`) по ключу `chatId_messageId`.
  6. При отображении сообщений: если `isE2ee == true` и `senderId == currentUserId`, брать зашифрованный текст из кэша и расшифровывать своим приватным ключом.

---

### 2. Transport Encryption (шифрование всех WS-сообщений)

**Как в вебе:**
```javascript
async encryptTransportPayload(payload, keyBase64) {
    const key = this.base64ToArrayBuffer(keyBase64);
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const jsonBase64 = btoa(unescape(encodeURIComponent(JSON.stringify(payload))));
    const cryptoKey = await crypto.subtle.importKey('raw', key, { name: 'AES-GCM' }, false, ['encrypt']);
    const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv: iv }, cryptoKey, new TextEncoder().encode(jsonBase64));
    // ... возвращает { ciphertext, iv, tag }
}
```
При установке WS-соединения сервер отправляет `key_exchange` с AES-ключом. Все последующие сообщения (кроме `register`, `login`, `verify_email`, `verify_2fa`, `reset_password_request`, `reset_password_confirm`) шифруются этим ключом.

**Как сейчас в Flutter:**
В `lib/core/network/web_socket_client.dart` нет transport encryption. Сообщения отправляются как plain JSON.

**Что сделать:**
- В `WebSocketClient` добавить поле `_transportKey` (String, base64).
- При подключении, когда сервер отправляет первое сообщение с `action: 'key_exchange'`, сохранять `data.key` в `_transportKey`.
- Создать методы `_encryptTransportPayload(Map<String, dynamic> payload)` и `_decryptTransportPayload(Map<String, dynamic> encryptedData)` используя `encrypt` пакет (`package:encrypt/encrypt.dart`) с AES-GCM.
- В методе `send()`:
  - Если `_transportKey` установлен и action НЕ в списке `skipEncryption` — шифровать payload и отправлять `{ encrypted: true, data: encryptedPayload }`.
  - Иначе отправлять как есть.
- В `_onMessage`:
  - Если входящее сообщение имеет `encrypted: true` и `data` — расшифровывать перед парсингом JSON.
- Добавить пакет `encrypt: ^5.0.0` в `pubspec.yaml` если его нет.

---

### 3. Поллинг секретных чатов

**Как в вебе:**
```javascript
if (chat.is_secret) {
    this.secretPollInterval = setInterval(async () => {
        if (this.currentChat && this.currentChat.id === chat.id) {
            try {
                const res = await this.api.getHistory(chat.id);
                this.messages[chat.id] = res.payload?.messages || [];
                await this.renderMessages();
            } catch (err) {
                // Если чат удалён собеседником — показать тост и стереть
                this.showToast("Секретный чат закрыт собеседником", "error");
                this.eraseSecretChatData(chat.id);
            }
        }
    }, 5000);
}
```

**Как сейчас в Flutter:**
В `lib/screens/chat_detail_screen.dart` нет поллинга для секретных чатов. Сообщения приходят только через WebSocket push `new_message`.

**Что сделать:**
- В `ChatDetailScreen` добавить `Timer? _secretPollTimer`.
- В `initState` или при открытии секретного чата запускать таймер с `Duration(seconds: 5)`.
- В колбэке таймера:
  1. Вызывать `ref.read(backendChatProvider(chatId).notifier).refresh()`.
  2. Если приходит ошибка (чат не найден / 404) — показать `SnackBar` «Секретный чат закрыт собеседником» и вызвать `context.pop()`.
- В `dispose` отменять таймер.
- Убедиться, что `ChatMessagesNotifier.refresh()` корректно обрабатывает ошибки от API для удалённых секретных чатов.

---

### 4. Markdown-парсинг в NiosGram

**Как в вебе:**
```javascript
parseMarkdown(text) {
    let safe = CryptoUtils.escapeHTML(text || '');
    safe = safe.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    safe = safe.replace(/__([^_]+)__/g, '<strong>$1</strong>');
    safe = safe.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    safe = safe.replace(/_([^_]+)_/g, '<em>$1</em>');
    safe = safe.replace(/\[(.*?)\]\((https?:\/\/.*?)\)/g, (match, linkText, url) => {
        const safeUrl = CryptoUtils.sanitizeURL(url);
        return safeUrl ? `<a href="${safeUrl}" target="_blank">${linkText}</a>` : match;
    });
    return safe.replace(/
/g, '<br>');
}
```

**Как сейчас в Flutter:**
В `lib/widgets/post_card.dart` текст поста отображается через `Text(post.content)` — raw текст с `**` и `*`.

**Что сделать:**
- Создать `lib/core/utils/markdown_parser.dart` с классом `MarkdownParser`.
- Метод `parse(String text)`:
  1. Экранировать HTML (`<` → `&lt;`, `>` → `&gt;`).
  2. Заменить `**text**` на `<strong>text</strong>`.
  3. Заменить `*text*` на `<em>text</em>`.
  4. Заменить `[text](url)` на `<a href="url">text</a>` (валидировать URL).
  5. Заменить `
` на `<br>`.
- В `PostCard` заменить `Text(post.content)` на `HtmlWidget(MarkdownParser.parse(post.content))`.
- Добавить пакет `flutter_widget_from_html_core: ^0.15.0` (лёгкий HTML-рендерер) в `pubspec.yaml`.
- Альтернатива: если не хочешь зависимость — использовать `RichText` с `TextSpan` и регулярками, но HTML проще.

---

### 5. Скриншот-защита для секретных чатов

**Как в вебе:**
```javascript
setupSecretScreenshotProtection() {
    window.addEventListener('blur', () => {
        if (this.currentChat && this.currentChat.is_secret) {
            document.getElementById('secret-overlay').style.display = 'flex';
        }
    });
    window.addEventListener('focus', () => {
        document.getElementById('secret-overlay').style.display = 'none';
    });
}
```
При сворачивании окна/вкладки — показывает чёрный оверлей «Экран скрыт для безопасности секретного чата».

**Как сейчас в Flutter:**
Нет реализации.

**Что сделать:**
- Добавить пакет `screen_protector: ^1.4.0` (или использовать `WidgetsBindingObserver` + `SystemChrome` для базовой защиты).
- В `ChatDetailScreen` добавить `WidgetsBindingObserver` mixin.
- В `didChangeAppLifecycleState`:
  - `paused` / `inactive` + `currentChat?.isSecret == true` → показать оверлей (`Container(color: Colors.black, child: Center(child: Text('Экран скрыт...')))`) через `Stack` поверх всего контента.
  - `resumed` → скрыть оверлей.
- Дополнительно: использовать `ScreenProtector.preventScreenshotOn()` для блокировки нативных скриншотов на Android/iOS (если пакет доступен).

---

### 6. Deep-linking (`/g/username`, `/u/slug`)

**Как в вебе:**
```javascript
// Разбор пути URL
const pathParts = path.split('/').filter(Boolean);
if (pathParts.length >= 2 && (pathParts[0] === 'g' || pathParts[0] === 'u')) {
    route = pathParts[0]; // 'g' или 'u'
    param = pathParts[1]; // username/slug
}

// /g/username → открыть профиль в NiosGram
// /u/slug → открыть ЛС или вступить в группу/канал
```

**Как сейчас в Flutter:**
В `lib/router/app_router.dart` нет deep-link роутов для `/g/:username` и `/u/:slug`.

**Что сделать:**
- В `AppRouter` (GoRouter) добавить:
  ```dart
  GoRoute(path: '/g/:username', builder: (context, state) => NiosgramScreen(initialProfileUsername: state.pathParameters['username'])),
  GoRoute(path: '/u/:slug', builder: (context, state) => ChatRedirectScreen(slug: state.pathParameters['slug']!)),
  ```
- Создать `ChatRedirectScreen` — StatelessWidget, который:
  1. Показывает `AppLoadingIndicator`.
  2. Вызывает `apiClient.openDirectChat(slug)`.
  3. Если успешно — `context.go('/chat/${chatId}')`.
  4. Если ошибка (не найден) — пробует `apiClient.joinChat(slug)`.
  5. Если и это не сработало — показывает `SnackBar` «Не удалось открыть чат» и `context.pop()`.
- В `NiosgramScreen` добавить параметр `String? initialProfileUsername`. Если передан — сразу вызывать `loadNgFeed('user', userId)` после получения профиля по username.
- Настроить `android/app/src/main/AndroidManifest.xml` и `ios/Runner/Info.plist` для обработки deep links с домена `ni-os.ru`.

---

### 7. Уведомления + mentions система

**Как в вебе:**
```javascript
addNotification(text, postId) {
    const id = CryptoUtils.generateUUID();
    this.notifications.unshift({ id, text, postId, createdAt: Date.now(), read: false });
    localStorage.setItem('user_notifications', JSON.stringify(this.notifications));
}

// При загрузке ленты:
posts.forEach(p => {
    const mention = `@${this.api.username}`;
    if (p.content && p.content.includes(mention) && p.author?.id !== this.api.userId) {
        const alreadyNotified = this.notifications.some(n => n.postId === p.id && n.text.includes("тегнул"));
        if (!alreadyNotified) {
            this.addNotification(`${authorName} тегнул вас в посте!`, p.id);
        }
    }
});
```

**Как сейчас в Flutter:**
В `lib/providers/notifications_provider.dart` есть FCM-уведомления, но нет локальной mentions-системы для NiosGram.

**Что сделать:**
- Создать `lib/providers/local_notifications_provider.dart` — Riverpod StateNotifier для локальных уведомлений (не FCM).
- Состояние: `List<LocalNotification>` с полями `id`, `text`, `postId`, `createdAt`, `read`.
- Хранение в Hive (`lib/core/storage/cache_service.dart` или отдельный box).
- В `NiosgramNotifier` (`lib/providers/niosgram_provider.dart`) при `loadFeed()`:
  1. После получения постов — проверять каждый пост на mention `@${currentUsername}`.
  2. Если mention найден и автор не текущий пользователь — добавлять локальное уведомление через `LocalNotificationsNotifier`.
- Добавить UI для просмотра уведомлений: иконка колокольчика в `NiosgramScreen` с badge (количество unread), выпадающий список при тапе.
- При тапе на уведомление — скролл к посту (аналог `scrollToNgPost` в вебе).

---

### 8. Реакции + подписки для NiosGram + аватарки/имена в комментариях

**Как в вебе:**
```javascript
// Реакции
async reactPost(postId, isLike) {
    await this.api.send('react_post', { post_id: postId, is_like: isLike }, true);
    await this.loadNgFeed(this.ngType, this.ngTargetUserId);
}

// Подписки
async toggleFollow(userId, isFollowed) {
    const action = isFollowed ? 'unfollow_user' : 'follow_user';
    await this.api.send(action, { user_id: userId }, true);
}

// Комментарии с аватарками
comments.map(c => {
    const authorName = c.author?.display_name || c.author?.username || 'User';
    const initials = CryptoUtils.getInitials(authorName);
    const avatarColor = CryptoUtils.generateAvatarColor(c.author?.username);
    const authorAvatar = CryptoUtils.sanitizeURL(c.author?.avatar_url);
    // ... рендер аватарки + имени
});
```

**Как сейчас в Flutter:**
В `lib/providers/niosgram_provider.dart` и `lib/widgets/post_card.dart` нет реакций, подписок, и комментарии не показывают аватарки/имена (если вообще есть комментарии).

**Что сделать:**
- В `NiosgramNotifier` добавить методы:
  - `reactPost(int postId, bool isLike)` — вызывает `apiClient.send('react_post', ...)`.
  - `toggleFollow(int userId, bool isFollowed)` — вызывает `follow_user` / `unfollow_user`.
- В `PostCard` добавить:
  - Кнопки лайк/дизлайк с счётчиками и подсветкой активного состояния (`post.myReaction`).
  - Кнопку «Подписаться/Отписаться» в заголовке поста (если автор не текущий пользователь).
- Создать `CommentsBottomSheet` — модальное окно снизу:
  - Заголовок «Комментарии» + кнопка закрыть.
  - Список комментариев через `ListView.builder`.
  - Каждый комментарий — аватарка (круг 32px, `CachedNetworkImage` или инициалы), имя автора (жирным), текст (с Markdown-парсингом), время.
  - Поле ввода внизу: `TextField` + кнопка отправить.
- В `PostCard` при тапе на иконку комментариев — открывать `CommentsBottomSheet`.
- В `NiosgramNotifier` добавить:
  - `loadComments(int postId)` — `apiClient.send('get_post_comments', ...)`.
  - `sendComment(int postId, String text)` — `apiClient.send('create_comment', ...)`.

---

### Общие требования:

- Не ломать существующую навигацию GoRouter.
- Не ломать WebSocket-подключение.
- Все новые провайдеры — через `flutter_riverpod`.
- Все строки локализовать через `context.l10n` (добавить ключи в ARB).
- Использовать существующие виджеты: `AppLoadingIndicator`, `AppErrorBanner`, `PulseLoadingIndicator` (заменить на MD3 `CircularProgressIndicator` где нужно).
- Для картинок — `CachedNetworkImage` с `cacheKey` и `memCacheWidth`.
- Не использовать `flutter_animate` для новых фич.
- Показать полный diff или все изменённые/созданные файлы.

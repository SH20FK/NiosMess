import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import 'constants.dart';

/// Полный API сервис для NiosMess backend
/// Содержит все эндпоинты из api.py
class ApiService {
  final ApiClient _client = ApiClient.instance;
  WebSocketChannel? _wsChannel;

  // ==================== АУТЕНТИФИКАЦИЯ ====================

  /// Регистрация нового пользователя (шаг 1 - отправка кода)
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    String? name,
  }) async {
    return _client.post('/register', data: {
      'email': email,
      'password': password,
      'username': username,
      'name': name ?? username,
    });
  }

  /// Подтверждение регистрации (шаг 2 - ввод кода)
  Future<Map<String, dynamic>> verifyRegistration({
    required String email,
    required String password,
    required String username,
    String? name,
    required String code,
  }) async {
    return _client.post('/register', data: {
      'email': email,
      'password': password,
      'username': username,
      'name': name ?? username,
      'code': code,
    });
  }

  /// Вход в систему
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final form = FormData.fromMap({
      'username': username,
      'password': password,
    });
    return _client.post('/login', form: form);
  }

  /// Проверка активности сессии
  Future<Map<String, dynamic>> checkSession({
    required String username,
    required String token,
  }) async {
    return _client.post('/check_session', data: {
      'username': username,
      'token': token,
    });
  }

  /// Пинг для обновления last_seen
  Future<Map<String, dynamic>> ping({
    required String username,
    required String token,
  }) async {
    return _client.post('/ping', data: {
      'username': username,
      'token': token,
    });
  }

  // ==================== СЕССИИ ====================

  /// Получить список активных сессий
  Future<List<dynamic>> listSessions({
    required String username,
    required String token,
  }) async {
    final res = await _client.get('/sessions/list', query: {
      'username': username,
      'token': token,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  /// Выход из конкретной сессии
  Future<Map<String, dynamic>> logoutSession({
    required String username,
    required String token,
    String? sessionId,
    bool allExceptCurrent = false,
  }) async {
    final form = FormData.fromMap({
      'username': username,
      'token': token,
      if (sessionId != null) 'session_id': sessionId,
      'all_except_current': allExceptCurrent,
    });
    return _client.post('/sessions/logout', form: form);
  }

  /// Выход из всех других сессий
  Future<Map<String, dynamic>> logoutOtherSessions({
    required String username,
    required String token,
  }) async {
    return _client.post('/sessions/logout_other', data: {
      'username': username,
      'token': token,
    });
  }

  /// Выход из всех сессий
  Future<Map<String, dynamic>> logoutAllSessions({
    required String username,
    required String token,
  }) async {
    return _client.post('/sessions/logout_all', data: {
      'username': username,
      'token': token,
    });
  }

  // ==================== СООБЩЕНИЯ ====================

  /// Отправить сообщение
  Future<Map<String, dynamic>> sendMessage({
    required String token,
    required String sender,
    required String receiver,
    required String text,
    int? replyTo,
    int? ttlSeconds,
    double? lat,
    double? lon,
    String? contactData,
  }) async {
    return _client.post('/send_message', data: {
      'token': token,
      'sender': sender,
      'receiver': receiver,
      'text': text,
      if (replyTo != null) 'reply_to': replyTo,
      if (ttlSeconds != null) 'ttl_seconds': ttlSeconds,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (contactData != null) 'contact_data': contactData,
    });
  }

  /// Получить сообщения чата
  Future<List<dynamic>> getMessages({
    required String me,
    required String other,
    required String token,
  }) async {
    final res = await _client.get('/get_messages', query: {
      'me': me,
      'other': other,
      'token': token,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  /// Получить сообщения чата (альтернативный эндпоинт)
  Future<List<dynamic>> getChatMessages({
    required String chatId,
    required String username,
    required String token,
    int limit = 50,
  }) async {
    final res = await _client.get('/get_chat_messages', query: {
      'chat_id': chatId,
      'username': username,
      'token': token,
      'limit': limit,
    });
    return res['data'] as List<dynamic>? ?? [];
  }

  /// Редактировать сообщение
  Future<Map<String, dynamic>> editMessage({
    required String token,
    required String username,
    required int messageId,
    required String text,
  }) async {
    final form = FormData.fromMap({
      'token': token,
      'username': username,
      'message_id': messageId,
      'text': text,
    });
    return _client.post('/edit_message', form: form);
  }

  /// Удалить сообщение
  Future<Map<String, dynamic>> deleteMessage({
    required String token,
    required String username,
    required int messageId,
  }) async {
    final form = FormData.fromMap({
      'token': token,
      'username': username,
      'message_id': messageId,
    });
    return _client.post('/delete_message', form: form);
  }

  /// Отметить сообщения как прочитанные
  Future<Map<String, dynamic>> markRead({
    required String chatId,
    required String username,
    required String token,
  }) async {
    final form = FormData.fromMap({
      'chat_id': chatId,
      'username': username,
      'token': token,
    });
    return _client.post('/mark_read', form: form);
  }

  /// Отправить в "Избранное" (Saved Messages)
  Future<Map<String, dynamic>> sendToSaved({
    required String token,
    required String username,
    required String text,
  }) async {
    final form = FormData.fromMap({
      'token': token,
      'username': username,
      'text': text,
    });
    return _client.post('/send_chat', form: form);
  }

  /// Поиск сообщений
  Future<List<dynamic>> searchMessages({
    required String chatId,
    required String query,
    required String username,
    required String token,
    required String chatType,
  }) async {
    final res = await _client.get('/search_messages', query: {
      'chat_id': chatId,
      'q': query,
      'username': username,
      'token': token,
      'chat_type': chatType,
    });
    return res['results'] as List<dynamic>? ?? [];
  }

  /// Закрепить/открепить сообщение
  Future<Map<String, dynamic>> pinMessage({
    required String token,
    required String username,
    required String chatId,
    required String chatType,
    required int messageId,
    required bool pinned,
  }) async {
    final form = FormData.fromMap({
      'token': token,
      'username': username,
      'chat_id': chatId,
      'chat_type': chatType,
      'message_id': messageId,
      'pinned': pinned,
    });
    return _client.post('/messages/pin', form: form);
  }

  /// Запланировать сообщение
  Future<Map<String, dynamic>> scheduleMessage({
    required String token,
    required String sender,
    required String chatId,
    required String chatType,
    required String text,
    required double sendAt,
    int? replyTo,
  }) async {
    final form = FormData.fromMap({
      'token': token,
      'sender': sender,
      'chat_id': chatId,
      'chat_type': chatType,
      'text': text,
      'send_at': sendAt,
      if (replyTo != null) 'reply_to': replyTo,
    });
    return _client.post('/messages/schedule', form: form);
  }

  // ==================== КОЛЛЕКТИВНЫЕ ЧАТЫ ====================

  /// Создать группу
  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String owner,
    required String token,
  }) async {
    final form = FormData.fromMap({
      'name': name,
      'owner': owner,
      'token': token,
    });
    return _client.post('/groups/create', form: form);
  }

  /// Создать канал
  Future<Map<String, dynamic>> createChannel({
    required String name,
    required String owner,
    required String token,
  }) async {
    return _client.post('/channels', data: {
      'name': name,
      'owner': owner,
      'token': token,
    });
  }

  /// Отправить сообщение в коллективный чат
  Future<Map<String, dynamic>> sendCollectiveMessage({
    required String chatId,
    required String sender,
    required String token,
    required String text,
    int? replyTo,
    List<String>? attachments,
    int? ttlSeconds,
  }) async {
    final form = FormData.fromMap({
      'chat_id': chatId,
      'sender': sender,
      'token': token,
      'text': text,
      if (replyTo != null) 'reply_to': replyTo,
      if (attachments != null) 'attachments': jsonEncode(attachments),
      if (ttlSeconds != null) 'ttl_seconds': ttlSeconds,
    });
    return _client.post('/collective/send', form: form);
  }

  /// Получить сообщения коллективного чата
  Future<List<dynamic>> getCollectiveMessages({
    required String chatId,
    required String username,
    required String token,
    int limit = 50,
  }) async {
    final res = await _client.get('/collective/messages', query: {
      'chat_id': chatId,
      'username': username,
      'token': token,
      'limit': limit,
    });
    return res['messages'] as List<dynamic>? ?? [];
  }

  /// Отметить сообщения коллективного чата как прочитанные
  Future<Map<String, dynamic>> markCollectiveRead({
    required String chatId,
    required String username,
    required String token,
  }) async {
    final form = FormData.fromMap({
      'chat_id': chatId,
      'username': username,
      'token': token,
    });
    return _client.post('/collective/mark_read', form: form);
  }

  /// Управление участниками группы/канала
  Future<Map<String, dynamic>> manageMembers({
    required String chatId,
    required String token,
    required String operator,
    required String action, // 'add' или 'remove'
    List<String>? members,
    String? target,
  }) async {
    return _client.post('/groups/$chatId/members', data: {
      'token': token,
      'operator': operator,
      'action': action,
      if (members != null) 'members': members,
      if (target != null) 'target': target,
    });
  }

  /// Добавить участника в группу (legacy)
  Future<Map<String, dynamic>> addMember({
    required String chatId,
    required String admin,
    required String member,
    required String token,
  }) async {
    final form = FormData.fromMap({
      'chat_id': chatId,
      'admin': admin,
      'member': member,
      'token': token,
    });
    return _client.post('/groups/add_member', form: form);
  }

  /// Удалить чат
  Future<Map<String, dynamic>> deleteChat({
    required String token,
    required String username,
    required String chatId,
  }) async {
    return _client.post('/chats/delete', data: {
      'token': token,
      'username': username,
      'chat_id': chatId,
    });
  }

  /// Закрепить/открепить чат
  Future<Map<String, dynamic>> pinChat({
    required String token,
    required String username,
    required String chatId,
    required bool pinned,
  }) async {
    final form = FormData.fromMap({
      'token': token,
      'username': username,
      'chat_id': chatId,
      'pinned': pinned,
    });
    return _client.post('/chats/pin', form: form);
  }

  // ==================== РЕАКЦИИ ====================

  /// Добавить/удалить реакцию на сообщение (личный чат)
  Future<Map<String, dynamic>> reactToMessage({
    required String token,
    required String username,
    required int messageId,
    required String emoji,
    required String action, // 'add' или 'remove'
  }) async {
    return _client.post('/messages/react', data: {
      'token': token,
      'username': username,
      'message_id': messageId,
      'emoji': emoji,
      'action': action,
    });
  }

  /// Добавить/удалить реакцию на сообщение (коллективный чат)
  Future<Map<String, dynamic>> reactToCollectiveMessage({
    required String token,
    required String username,
    required int messageId,
    required String emoji,
    required String chatId,
    required String action, // 'add' или 'remove'
  }) async {
    return _client.post('/collective/react', data: {
      'token': token,
      'username': username,
      'message_id': messageId,
      'emoji': emoji,
      'chat_id': chatId,
      'action': action,
    });
  }

  // ==================== ОПРОСЫ ====================

  /// Создать опрос
  Future<Map<String, dynamic>> createPoll({
    required String token,
    required String username,
    required String chatId,
    required String question,
    required List<String> options,
  }) async {
    final form = FormData.fromMap({
      'token': token,
      'username': username,
      'chat_id': chatId,
      'question': question,
      'options': jsonEncode(options),
    });
    return _client.post('/polls/create', form: form);
  }

  // ==================== ПОЛЬЗОВАТЕЛИ ====================

  /// Получить информацию о пользователе
  Future<Map<String, dynamic>> getUserInfo({
    required String username,
    required String token,
    required String myUsername,
  }) async {
    final res = await _client.get('/get_user_info', query: {
      'username': username,
      'token': token,
      'my_username': myUsername,
    });
    return res;
  }

  /// Установить описание профиля (about)
  Future<Map<String, dynamic>> setAbout({
    required String token,
    required String username,
    required String about,
  }) async {
    final form = FormData.fromMap({
      'token': token,
      'username': username,
      'about': about,
    });
    return _client.post('/set_about', form: form);
  }

  /// Получить список чатов
  Future<Map<String, dynamic>> getChats({
    required String username,
    required String token,
  }) async {
    return _client.get('/get_chats', query: {
      'username': username,
      'token': token,
    });
  }

  /// Поиск пользователей
  Future<List<dynamic>> searchUsers({
    required String query,
    required String token,
    required String myUsername,
  }) async {
    final res = await _client.get('/search_users', query: {
      'q': query,
      'token': token,
      'my_username': myUsername,
    });
    return res as List<dynamic>? ?? [];
  }

  /// Установить аватар
  Future<Map<String, dynamic>> setAvatar({
    required String token,
    required String username,
    required File file,
  }) async {
    final form = FormData.fromMap({
      'token': token,
      'username': username,
      'file': await MultipartFile.fromFile(file.path),
    });
    return _client.post('/set_av', form: form);
  }

  /// Получить аватар пользователя
  Future<Map<String, dynamic>> getAvatar({
    required String other,
  }) async {
    final form = FormData.fromMap({
      'other': other,
    });
    return _client.post('/get_av', form: form);
  }

  /// Обновить аватар группы
  Future<Map<String, dynamic>> updateGroupAvatar({
    required String chatId,
    required String owner,
    required String token,
    required File file,
  }) async {
    final form = FormData.fromMap({
      'chat_id': chatId,
      'owner': owner,
      'token': token,
      'file': await MultipartFile.fromFile(file.path),
    });
    return _client.post('/groups/update_avatar', form: form);
  }

  // ==================== ПРЕВЬЮ И AI ====================

  /// Получить превью ссылки
  Future<Map<String, dynamic>> getLinkPreview({
    required String url,
    required String username,
    required String token,
  }) async {
    return _client.get('/link_preview', query: {
      'url': url,
      'username': username,
      'token': token,
    });
  }

  /// Отправить сообщение в поддержку (AI)
  Future<Map<String, dynamic>> sendSupportMessage({
    required String token,
    required String sender,
    required String text,
  }) async {
    return _client.post('/send_message', data: {
      'token': token,
      'sender': sender,
      'receiver': 'supports',
      'text': text,
    });
  }

  // ==================== WEBSOCKET ====================

  /// Подключиться к WebSocket
  void connectWebSocket({
    required String token,
    required String username,
    required Function(dynamic) onMessage,
    Function(dynamic)? onTyping,
    Function(dynamic)? onFileReady,
    Function(dynamic)? onFileSaved,
    Function(dynamic)? onError,
    Function()? onDisconnect,
  }) {
    final wsUrl = '${AppConfig.apiBase.replaceFirst('http', 'ws')}/ws?token=$token&username=$username';
    _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _wsChannel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        final type = data['type'];

        switch (type) {
          case 'typing':
            onTyping?.call(data);
            break;
          case 'file_ready':
            onFileReady?.call(data);
            break;
          case 'file_saved':
            onFileSaved?.call(data);
            break;
          case 'error':
            onError?.call(data);
            break;
          default:
            onMessage(data);
        }
      },
      onDone: onDisconnect,
      onError: (error) => onError?.call({'error': error.toString()}),
    );
  }

  /// Отправить событие "печатает"
  void sendTyping({
    required String receiver,
  }) {
    _wsChannel?.sink.add(jsonEncode({
      'type': 'typing',
      'receiver': receiver,
    }));
  }

  /// Начать загрузку файла
  void startFileUpload({
    required String filename,
  }) {
    _wsChannel?.sink.add(jsonEncode({
      'type': 'file_start',
      'filename': filename,
    }));
  }

  /// Отправить чанк файла
  void sendFileChunk({
    required String chunk,
  }) {
    _wsChannel?.sink.add(jsonEncode({
      'type': 'file_chunk',
      'chunk': chunk,
    }));
  }

  /// Завершить загрузку файла
  void endFileUpload() {
    _wsChannel?.sink.add(jsonEncode({
      'type': 'file_end',
    }));
  }

  /// Начать скачивание файла
  void startFileDownload({
    required String filename,
  }) {
    _wsChannel?.sink.add(jsonEncode({
      'type': 'download_start',
      'filename': filename,
    }));
  }

  /// Закрыть WebSocket соединение
  void disconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  // ==================== УТИЛИТЫ ====================

  /// Отправить событие typing (HTTP fallback)
  Future<Map<String, dynamic>> sendTypingEvent({
    required String token,
    required String username,
  }) async {
    return _client.post('/typing', data: {
      'token': token,
      'username': username,
    });
  }
}

/// Глобальный экземпляр API сервиса
final apiService = ApiService();

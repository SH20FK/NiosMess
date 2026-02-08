import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../api_client.dart';
import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../storage/offline_cache.dart';
import '../obfuscate.dart';

class ApiRepository {
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> login(String username, String password) {
    return _api.post('/login', form: FormData.fromMap({
      'username': username,
      'password': password,
    }));
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) {
    return _api.post('/register', data: payload);
  }

  Future<void> checkSession(String username, String token) async {
    await _api.post('/check_session', data: {'username': username, 'token': token});
  }

  Future<List<ChatItem>> getChats(String username, String token) async {
    final data = await _api.get('/get_chats', query: {'username': username, 'token': token, 'version': '1.0'});
    final list = (data['chats'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    await OfflineCache.saveChats(list);
    return list.map((e) {
      final type = (e['type'] ?? '').toString();
      final rawUsername = e['username']?.toString();
      final rawChatId = (e['chat_id'] ?? e['id'])?.toString();
      final isUserChat = type.isEmpty || type == 'user';
      String chatId;
      if (isUserChat) {
        // Backend for user chats may return `chat_id` as peer and `username` as current user.
        chatId = (rawChatId ?? rawUsername ?? '').toString();
        if (chatId == username && (rawUsername ?? '').isNotEmpty && rawUsername != username) {
          chatId = rawUsername!;
        }
      } else {
        chatId = (rawChatId ?? rawUsername ?? '').toString();
      }
      return ChatItem(
        id: chatId,
        name: (e['name'] ?? chatId).toString(),
        type: type.isEmpty
            ? (chatId.startsWith('group_')
                ? 'group'
                : chatId.startsWith('channel_')
                    ? 'channel'
                    : 'user')
            : type,
        unread: (e['unread_count'] as num?)?.toInt() ?? 0,
        username: rawUsername,
        isOnline: e['isonline'] as bool?,
        lastSeenText: e['last_seen_text'] as String?,
        badgeTitle: e['badge_title'] as String?,
        badgeText: e['badge_text'] as String?,
        badgeIcon: e['badge_icon'] as String?,
      );
    }).toList();
  }

  Future<List<ChatItem>> getCachedChats() async {
    final cached = await OfflineCache.loadChats();
    return cached.map((e) => ChatItem.fromJson(e)).toList();
  }

  Future<List<MessageItem>> getMessagesUser(String me, String other, String token) async {
    final data = await _api.get('/get_messages', query: {'me': me, 'other': other, 'token': token});
    final list = (data['data'] as List<dynamic>? ?? data['messages'] as List<dynamic>? ?? data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    await OfflineCache.saveMessages(other, list);
    return list.map((e) {
      final decoded = Map<String, dynamic>.from(e);
      final rawText = decoded['text']?.toString() ?? '';
      decoded['text'] = Obfuscator.deobfuscate(rawText);
      return MessageItem.fromJson(decoded);
    }).toList();
  }

  Future<List<MessageItem>> getCachedMessages(String chatId) async {
    final cached = await OfflineCache.loadMessages(chatId);
    return cached.map((e) => MessageItem.fromJson(e)).toList();
  }

  Future<List<MessageItem>> getCollectiveMessages(String chatId, String username, String token) async {
    final data = await _api.get('/collective/messages', query: {'chat_id': chatId, 'username': username, 'token': token, 'limit': 50});
    final list = (data['messages'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    await OfflineCache.saveMessages(chatId, list);
    return list.map((e) {
      final decoded = Map<String, dynamic>.from(e);
      final rawText = decoded['text']?.toString() ?? '';
      decoded['text'] = Obfuscator.deobfuscate(rawText);
      return MessageItem.fromJson(decoded);
    }).toList();
  }

  Future<Map<String, dynamic>> getUserInfo(String target, String me, String token) {
    return _api.get('/get_user_info', query: {
      'username': target,
      'token': token,
      'my_username': me,
    });
  }

  Future<void> setAbout(String username, String token, String about) async {
    final form = FormData.fromMap({'username': username, 'token': token, 'about': about});
    await _api.post('/set_about', form: form);
  }

  Future<List<Map<String, dynamic>>> getSessions(String username, String token) async {
    final data = await _api.get('/get_sessions', query: {'username': username, 'token': token});
    final raw = data['data'] ?? data;
    if (raw is List<dynamic>) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> logoutOtherSessions(String username, String token) async {
    await _api.post('/sessions/logout_other', data: {'username': username, 'token': token});
  }

  Future<Uint8List?> getAvatarBytes(String username) async {
    final cached = await OfflineCache.loadAvatar(username);
    if (cached != null) return cached;
    try {
      final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBase, responseType: ResponseType.bytes));
      final res = await dio.post('/get_av', data: FormData.fromMap({'other': username}));
      final data = res.data;
      if (data is List<int>) {
        final bytes = Uint8List.fromList(data);
        await OfflineCache.saveAvatar(username, bytes);
        return bytes;
      }
    } catch (_) {}
    return cached;
  }

  Future<void> sendMessageUser(
    String sender,
    String receiver,
    String text,
    String token, {
    String? replyTo,
  }) async {
    final payload = {
      'sender': sender,
      'receiver': receiver,
      'text': Obfuscator.obfuscate(text),
      'token': token,
    };
    if (replyTo != null && replyTo.isNotEmpty) payload['reply_to'] = replyTo;
    await _api.post('/send_message', data: payload);
  }

  Future<void> sendCollective(
    String chatId,
    String sender,
    String text,
    String token, {
    String? replyTo,
    int? ttlSeconds,
  }) async {
    final form = FormData.fromMap({
      'chat_id': chatId,
      'sender': sender,
      'text': Obfuscator.obfuscate(text),
      'token': token,
      if (replyTo != null && replyTo.isNotEmpty) 'reply_to': replyTo,
      if (ttlSeconds != null) 'ttl_seconds': ttlSeconds,
    });
    await _api.post('/collective/send', form: form);
  }

  Future<Map<String, dynamic>> createCollective({
    required String name,
    required String owner,
    required String token,
    bool isChannel = false,
  }) async {
    if (isChannel) {
      return _api.post('/channels', data: {
        'name': name,
        'owner': owner,
        'token': token,
      });
    }
    final form = FormData.fromMap({'name': name, 'owner': owner, 'token': token});
    return _api.post('/groups/create', form: form);
  }

  Future<void> updateMembers({
    required String chatId,
    required String operator,
    required String token,
    required List<String> members,
    bool isChannel = false,
    String action = 'add',
  }) async {
    final path = isChannel ? '/channels/$chatId/members' : '/groups/$chatId/members';
    await _api.post(path, data: {
      'token': token,
      'operator': operator,
      'members': members,
      'action': action,
    });
  }

  Future<void> deleteMessage({
    required String username,
    required String token,
    required String messageId,
  }) async {
    await _api.post('/delete_message', data: {
      'username': username,
      'token': token,
      'message_id': messageId,
    });
  }

  Future<void> editMessage({
    required String username,
    required String token,
    required String messageId,
    required String text,
  }) async {
    await _api.post('/edit_message', data: {
      'username': username,
      'token': token,
      'message_id': messageId,
      'text': Obfuscator.obfuscate(text),
    });
  }

  Future<void> pinMessage({
    required String username,
    required String token,
    required String chatId,
    required String chatType,
    required String messageId,
    required bool pinned,
  }) async {
    final form = FormData.fromMap({
      'username': username,
      'token': token,
      'chat_id': chatId,
      'chat_type': chatType,
      'message_id': messageId,
      'pinned': pinned,
    });
    await _api.post('/messages/pin', form: form);
  }

  Future<Map<String, dynamic>> reactMessage({
    required String username,
    required String token,
    required String messageId,
    required String emoji,
    required bool active,
    String? chatId,
    bool collective = false,
  }) async {
    final path = collective ? '/collective/react' : '/messages/react';
    return _api.post(path, data: {
      'username': username,
      'token': token,
      'message_id': messageId,
      'emoji': emoji,
      'active': active,
      if (collective) 'chat_id': chatId,
    });
  }

  Future<Map<String, dynamic>> uploadFile({
    required String sender,
    required String receiver,
    required String token,
    required String filePath,
    String? replyTo,
    int? ttlSeconds,
  }) async {
    final form = FormData.fromMap({
      'sender': sender,
      'receiver': receiver,
      'token': token,
      'file': await MultipartFile.fromFile(filePath),
      if (replyTo != null && replyTo.isNotEmpty) 'reply_to': replyTo,
      if (ttlSeconds != null) 'ttl_seconds': ttlSeconds,
    });
    return _api.post('/upload', form: form);
  }
}

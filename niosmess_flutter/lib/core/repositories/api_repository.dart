import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import '../api_client.dart';
import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../storage/offline_cache.dart';
import '../obfuscate.dart';

class ApiRepository {
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> login(String username, String password) {
    return _api.post('/login',
        form: FormData.fromMap({
          'username': username,
          'password': password,
        }));
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) {
    return _api.post('/register', data: payload);
  }

  Future<void> checkSession(String username, String token) async {
    await _api
        .post('/check_session', data: {'username': username, 'token': token});
  }

  Future<List<ChatItem>> getChats(String username, String token) async {
    final data = await _api.get('/get_chats',
        query: {'username': username, 'token': token, 'version': '1.0'});
    final list =
        (data['chats'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
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
        if (chatId == username &&
            (rawUsername ?? '').isNotEmpty &&
            rawUsername != username) {
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

  Future<List<MessageItem>> getMessagesUser(
      String me, String other, String token) async {
    final data = await _api.get('/get_messages',
        query: {'me': me, 'other': other, 'token': token});
    final list = (data['data'] as List<dynamic>? ??
            data['messages'] as List<dynamic>? ??
            data as List<dynamic>? ??
            [])
        .cast<Map<String, dynamic>>();
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

  Future<List<MessageItem>> getCollectiveMessages(
      String chatId, String username, String token) async {
    final data = await _api.get('/collective/messages', query: {
      'chat_id': chatId,
      'username': username,
      'token': token,
      'limit': 50
    });
    final list =
        (data['messages'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    await OfflineCache.saveMessages(chatId, list);
    return list.map((e) {
      final decoded = Map<String, dynamic>.from(e);
      final rawText = decoded['text']?.toString() ?? '';
      decoded['text'] = Obfuscator.deobfuscate(rawText);
      return MessageItem.fromJson(decoded);
    }).toList();
  }

  Future<Map<String, dynamic>> getUserInfo(
      String target, String me, String token) {
    return _api.get('/get_user_info', query: {
      'username': target,
      'token': token,
      'my_username': me,
    });
  }

  Future<void> setAbout(String username, String token, String about) async {
    final form = FormData.fromMap(
        {'username': username, 'token': token, 'about': about});
    await _api.post('/set_about', form: form);
  }

  Future<void> setName(String username, String token, String name) async {
    final form =
        FormData.fromMap({'username': username, 'token': token, 'name': name});
    await _api.post('/profile/set_name', form: form);
  }

  Future<Map<String, dynamic>> setUsername(
      String username, String token, String newUsername) async {
    final form = FormData.fromMap(
        {'username': username, 'token': token, 'new_username': newUsername});
    return _api.post('/profile/set_username', form: form);
  }

  Future<Map<String, dynamic>> setAvatar(
      String username, String token, String filePath) async {
    final form = FormData.fromMap({
      'username': username,
      'token': token,
      'file': await MultipartFile.fromFile(filePath),
    });
    return _api.post('/profile/set_avatar', form: form);
  }

  Future<void> passwordResetRequest({String? email, String? username}) async {
    await _api.post('/password_reset/request', data: {
      if (email != null) 'email': email,
      if (username != null) 'username': username,
    });
  }

  Future<void> passwordResetConfirm({
    String? email,
    String? username,
    required String code,
    required String newPassword,
  }) async {
    await _api.post('/password_reset/confirm', data: {
      if (email != null) 'email': email,
      if (username != null) 'username': username,
      'code': code,
      'new_password': newPassword,
    });
  }

  Future<void> registerPushToken({
    required String username,
    required String sessionToken,
    required String fcmToken,
    required String platform,
  }) async {
    await _api.post('/notifications/register', data: {
      'username': username,
      'session_token': sessionToken,
      'token': fcmToken,
      'platform': platform,
    });
  }

  Future<void> unregisterPushToken({
    required String username,
    required String sessionToken,
    required String fcmToken,
  }) async {
    await _api.post('/notifications/unregister', data: {
      'username': username,
      'session_token': sessionToken,
      'token': fcmToken,
    });
  }

  Future<Map<String, dynamic>> getSettings({
    required String username,
    required String sessionToken,
  }) async {
    final data = await _api.post('/settings/get', data: {
      'username': username,
      'session_token': sessionToken,
    });
    if (data['settings'] is Map) {
      return Map<String, dynamic>.from(data['settings'] as Map);
    }
    return {};
  }

  Future<void> setSettings({
    required String username,
    required String sessionToken,
    required Map<String, dynamic> settings,
  }) async {
    await _api.post('/settings/set', data: {
      'username': username,
      'session_token': sessionToken,
      'settings': settings,
    });
  }

  Future<void> resetSettings({
    required String username,
    required String sessionToken,
  }) async {
    await _api.post('/settings/reset', data: {
      'username': username,
      'session_token': sessionToken,
    });
  }

  Future<Map<String, dynamic>> requestCall({
    required String caller,
    required String callee,
    required String token,
  }) {
    return _api.post('/calls/request', data: {
      'caller': caller,
      'callee': callee,
      'token': token,
    });
  }

  Future<void> respondCall({
    required String username,
    required String token,
    required String callId,
    required String status,
  }) async {
    await _api.post('/calls/respond', data: {
      'username': username,
      'token': token,
      'call_id': callId,
      'status': status,
    });
  }

  Future<List<Map<String, dynamic>>> getCallLogs(
      String username, String token) async {
    final data = await _api
        .get('/calls/list', query: {'username': username, 'token': token});
    final raw = data['data'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getDataUsage(String username, String token) {
    return _api
        .get('/data/usage', query: {'username': username, 'token': token});
  }

  Future<void> syncDataUsage(
      String username, String token, List<Map<String, dynamic>> items) async {
    await _api.post('/data/usage', data: {
      'username': username,
      'token': token,
      'items': items,
    });
  }

  Future<List<Map<String, dynamic>>> getDownloads(String username, String token,
      {int limit = 50}) async {
    final data = await _api.get('/data/downloads',
        query: {'username': username, 'token': token, 'limit': limit});
    final raw = data['data'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchUsers(
      String query, String username, String token) async {
    final data = await _api.get('/search_users',
        query: {'q': query, 'my_username': username, 'token': token});
    if (data['data'] is List) {
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<List<MessageItem>> searchMessages({
    required String chatId,
    required String query,
    required String username,
    required String token,
    required String chatType,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _api.get('/search_messages', query: {
      'chat_id': chatId,
      'q': query,
      'username': username,
      'token': token,
      'chat_type': chatType,
      'limit': limit,
      'offset': offset,
    });
    final list =
        (data['results'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list.map((e) {
      final decoded = Map<String, dynamic>.from(e);
      final rawText = decoded['text']?.toString() ?? '';
      decoded['text'] = Obfuscator.deobfuscate(rawText);
      return MessageItem.fromJson(decoded);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getSessions(
      String username, String token) async {
    final data = await _api
        .get('/get_sessions', query: {'username': username, 'token': token});
    final raw = data['data'] ?? data;
    if (raw is List<dynamic>) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> logoutOtherSessions(String username, String token) async {
    await _api.post('/sessions/logout_other',
        data: {'username': username, 'token': token});
  }

  Future<Uint8List?> getAvatarBytes(String username) async {
    final cached = await OfflineCache.loadAvatar(username);
    if (cached != null) return cached;
    try {
      final dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBase, responseType: ResponseType.bytes));
      final res = await dio.post('/get_av',
          data: FormData.fromMap({'other': username}));
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
    String? msgType,
    double? lat,
    double? lon,
    String? contactData,
  }) async {
    final payload = {
      'sender': sender,
      'receiver': receiver,
      'text': Obfuscator.obfuscate(text),
      'token': token,
      if (msgType != null) 'msg_type': msgType,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (contactData != null) 'contact_data': contactData,
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
    String? msgType,
    double? lat,
    double? lon,
    String? contactData,
  }) async {
    final form = FormData.fromMap({
      'chat_id': chatId,
      'sender': sender,
      'text': Obfuscator.obfuscate(text),
      'token': token,
      if (replyTo != null && replyTo.isNotEmpty) 'reply_to': replyTo,
      if (ttlSeconds != null) 'ttl_seconds': ttlSeconds,
      if (msgType != null) 'msg_type': msgType,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (contactData != null) 'contact_data': contactData,
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
    final form =
        FormData.fromMap({'name': name, 'owner': owner, 'token': token});
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
    final path =
        isChannel ? '/channels/$chatId/members' : '/groups/$chatId/members';
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

  Future<Map<String, dynamic>> getReactionsBatch({
    required String username,
    required String token,
    required List<String> messageIds,
    String? chatId,
    bool collective = false,
  }) async {
    return _api.post('/reactions/list', data: {
      'username': username,
      'token': token,
      'message_ids': messageIds,
      'collective': collective,
      if (collective) 'chat_id': chatId,
    });
  }

  Future<Map<String, dynamic>> getWeeklyMoment({
    required String chatId,
    required String username,
    required String token,
    int limit = 5,
  }) async {
    return _api.get('/channels/weekly_moment', query: {
      'chat_id': chatId,
      'username': username,
      'token': token,
      'limit': limit,
    });
  }

  Future<Map<String, dynamic>> getWeeklyRoles({
    required String chatId,
    required String username,
    required String token,
  }) async {
    return _api.post('/groups/weekly_roles', data: {
      'chat_id': chatId,
      'username': username,
      'token': token,
    });
  }

  Future<void> forwardMessage({
    required String username,
    required String token,
    required String chatId,
    required String chatType,
    required String forwardFrom,
    required String messageId,
    required String forwardChatType,
  }) async {
    final form = FormData.fromMap({
      'username': username,
      'token': token,
      'chat_id': chatId,
      'chat_type': chatType,
      'forward_from': forwardFrom,
      'forward_message_id': messageId,
      'forward_chat_type': forwardChatType,
    });
    await _api.post('/forward_message', form: form);
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

  Future<String> downloadFile({
    required String filename,
    required String username,
    required String token,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${dir.path}/downloads');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final filePath = '${targetDir.path}/$filename';
    final url = '${AppConfig.apiBase}/download/$filename';
    final dio = Dio();
    await dio.download(
      url,
      filePath,
      options: Options(
        headers: {
          'X-Username': username,
          'X-Session-Token': token,
        },
      ),
    );
    return filePath;
  }
}

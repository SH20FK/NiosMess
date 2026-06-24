import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

Map<String, dynamic> asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((dynamic key, dynamic val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

class AdminRepository {
  const AdminRepository(this._ref);
  final Ref _ref;

  Future<List<Map<String, dynamic>>> listUsers(String adminPassword) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('admin_list_users', payload: <String, dynamic>{'admin_password': adminPassword});
    if (response is! List) return const <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getUser(String adminPassword, int userId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('admin_get_user', payload: <String, dynamic>{'admin_password': adminPassword, 'user_id': userId});
    return asStringMap(response);
  }

  Future<void> banUser(String adminPassword, int userId) async {
    await _ref
        .read(webSocketClientProvider)
        .request('ban_user', payload: <String, dynamic>{'admin_password': adminPassword, 'user_id': userId});
  }

  Future<void> unbanUser(String adminPassword, int userId) async {
    await _ref
        .read(webSocketClientProvider)
        .request('unban_user', payload: <String, dynamic>{'admin_password': adminPassword, 'user_id': userId});
  }

  Future<void> freezeUser(String adminPassword, int userId, bool freeze) async {
    await _ref
        .read(webSocketClientProvider)
        .request('freeze_user', payload: <String, dynamic>{'admin_password': adminPassword, 'user_id': userId, 'freeze': freeze});
  }

  Future<void> spamBlock(String adminPassword, int userId, bool spamBlock) async {
    await _ref
        .read(webSocketClientProvider)
        .request('spam_block', payload: <String, dynamic>{'admin_password': adminPassword, 'user_id': userId, 'spam_block': spamBlock});
  }

  Future<List<Map<String, dynamic>>> listChats(String adminPassword) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('admin_list_chats', payload: <String, dynamic>{'admin_password': adminPassword});
    if (response is! List) return const <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  Future<void> banChat(String adminPassword, int chatId, bool ban) async {
    await _ref
        .read(webSocketClientProvider)
        .request('ban_chat', payload: <String, dynamic>{'admin_password': adminPassword, 'chat_id': chatId, 'ban': ban});
  }
}

final Provider<AdminRepository> adminRepositoryProvider = Provider<AdminRepository>((Ref ref) {
  return AdminRepository(ref);
});

import 'package:nios_admin_flutter/core/network/admin_api_client.dart';
import 'package:nios_admin_flutter/models/admin_badge.dart';
import 'package:nios_admin_flutter/models/admin_chat.dart';
import 'package:nios_admin_flutter/models/admin_user.dart';

class AdminRepository {
  const AdminRepository(this._client);

  final AdminApiClient _client;

  Future<void> validatePassword({String? passwordOverride}) async {
    await _client.get(
      '/admin/users',
      query: <String, String>{'page': '1', 'page_size': '1'},
      passwordOverride: passwordOverride,
    );
  }

  Future<List<AdminUser>> getUsers({
    required int page,
    int pageSize = 25,
    String? passwordOverride,
  }) async {
    final dynamic payload = await _client.get(
      '/admin/users',
      query: <String, String>{'page': '$page', 'page_size': '$pageSize'},
      passwordOverride: passwordOverride,
    );
    final List<dynamic> list = payload is List ? payload : const <dynamic>[];
    return list
        .whereType<Map>()
        .map(
          (Map raw) => AdminUser.fromJson(
            raw.map((dynamic key, dynamic value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<AdminUser> getUser(int userId) async {
    final dynamic payload = await _client.get('/admin/users/$userId');
    return AdminUser.fromJson(
      (payload as Map).map((dynamic k, dynamic v) => MapEntry('$k', v)),
    );
  }

  Future<String> banUser({required int userId, required String reason}) async {
    final dynamic payload = await _client.post(
      '/admin/users/ban',
      body: <String, dynamic>{'user_id': userId, 'reason': reason},
    );
    return (payload as Map?)?['message']?.toString() ?? 'Done';
  }

  Future<String> unbanUser({required int userId}) async {
    final dynamic payload = await _client.post(
      '/admin/users/unban',
      body: <String, dynamic>{'user_id': userId},
    );
    return (payload as Map?)?['message']?.toString() ?? 'Done';
  }

  Future<String> setFrozen({required int userId, required bool frozen}) async {
    final dynamic payload = await _client.post(
      '/admin/users/freeze',
      body: <String, dynamic>{'user_id': userId, 'frozen': frozen},
    );
    return (payload as Map?)?['message']?.toString() ?? 'Done';
  }

  Future<String> setSpamBlock({
    required int userId,
    required bool blocked,
  }) async {
    final dynamic payload = await _client.post(
      '/admin/users/spamblock',
      body: <String, dynamic>{'user_id': userId, 'blocked': blocked},
    );
    return (payload as Map?)?['message']?.toString() ?? 'Done';
  }

  Future<List<AdminChat>> getChats({
    required int page,
    int pageSize = 25,
  }) async {
    final dynamic payload = await _client.get(
      '/admin/chats',
      query: <String, String>{'page': '$page', 'page_size': '$pageSize'},
    );
    final List<dynamic> list = payload is List ? payload : const <dynamic>[];
    return list
        .whereType<Map>()
        .map(
          (Map raw) => AdminChat.fromJson(
            raw.map((dynamic key, dynamic value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<String> setChatBanned({
    required int chatId,
    required bool banned,
  }) async {
    final dynamic payload = await _client.post(
      '/admin/chats/ban',
      body: <String, dynamic>{'chat_id': chatId, 'banned': banned},
    );
    return (payload as Map?)?['message']?.toString() ?? 'Done';
  }

  Future<List<AdminBadge>> getBadges() async {
    final dynamic payload = await _client.get('/admin/badges');
    final List<dynamic> list = payload is List ? payload : const <dynamic>[];
    return list
        .whereType<Map>()
        .map(
          (Map raw) => AdminBadge.fromJson(
            raw.map((dynamic key, dynamic value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<String> createBadge({
    required String name,
    required String description,
    required String icon,
    required String color,
  }) async {
    final dynamic payload = await _client.post(
      '/admin/badges/create',
      body: <String, dynamic>{
        'name': name,
        'description': description,
        'icon': icon,
        'color': color,
      },
    );
    return (payload as Map?)?['name']?.toString() ?? 'Done';
  }

  Future<void> deleteBadge(int badgeId) async {
    await _client.delete('/admin/badges/$badgeId');
  }

  Future<void> awardBadge({required int userId, required int badgeId}) async {
    await _client.post(
      '/admin/badges/award',
      body: <String, dynamic>{'user_id': userId, 'badge_id': badgeId},
    );
  }

  Future<void> revokeBadge({required int userId, required int badgeId}) async {
    await _client.post(
      '/admin/badges/revoke',
      body: <String, dynamic>{'user_id': userId, 'badge_id': badgeId},
    );
  }
}

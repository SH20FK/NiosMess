import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_db.dart';
import '../utils/json_utils.dart';

class LocalCache {
  LocalCache._();

  static final LocalCache instance = LocalCache._();

  static const _defaultOwner = 'default';
  static const _migratedKey = 'cache_migrated_v1';

  final LocalDb _db = LocalDb.instance;
  Future<void>? _migrateFuture;

  Future<void> _ensureReady() {
    _migrateFuture ??= _migrateFromSharedPrefs();
    return _migrateFuture!;
  }

  Future<void> _migrateFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool(_migratedKey) ?? false;
    if (migrated) return;

    final keys = prefs.getKeys().toList();
    if (keys.isEmpty) {
      await prefs.setBool(_migratedKey, true);
      return;
    }

    final chatsRaw = prefs.getString('cache_chats');
    if (chatsRaw != null && chatsRaw.isNotEmpty) {
      final list = safeJsonDecode<List<dynamic>>(
        chatsRaw,
        context: 'migrate_cache_chats',
      );
      if (list != null) {
        await _saveChats(list.cast<Map<String, dynamic>>());
        await prefs.remove('cache_chats');
      }
    }

    final settingsRaw = prefs.getString('cache_settings_v1');
    if (settingsRaw != null && settingsRaw.isNotEmpty) {
      final settings = safeJsonDecode<Map<String, dynamic>>(
        settingsRaw,
        context: 'migrate_cache_settings',
      );
      if (settings != null) {
        await _saveSettings(settings);
        await prefs.remove('cache_settings_v1');
      }
    }

    for (final key in keys) {
      if (key.startsWith('cache_messages_')) {
        final chatId = key.replaceFirst('cache_messages_', '');
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          final list = safeJsonDecode<List<dynamic>>(
            raw,
            context: 'migrate_cache_messages:$chatId',
          );
          if (list != null) {
            final casted = list.cast<Map<String, dynamic>>();
            await _saveMessages(chatId, casted, limit: casted.length);
            await prefs.remove(key);
          }
        }
      } else if (key.startsWith('cache_profile_')) {
        final username = key.replaceFirst('cache_profile_', '');
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          final profile = safeJsonDecode<Map<String, dynamic>>(
            raw,
            context: 'migrate_cache_profile:$username',
          );
          if (profile != null) {
            await _saveProfile(username, profile);
            await prefs.remove(key);
          }
        }
      } else if (key.startsWith('cache_sessions_')) {
        final username = key.replaceFirst('cache_sessions_', '');
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          final sessions = safeJsonDecode<List<dynamic>>(
            raw,
            context: 'migrate_cache_sessions:$username',
          );
          if (sessions != null) {
            await _saveSessions(username, sessions.cast<Map<String, dynamic>>());
            await prefs.remove(key);
          }
        }
      } else if (key.startsWith('cache_avatar_')) {
        final username = key.replaceFirst('cache_avatar_', '');
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          try {
            final bytes = base64Decode(raw);
            await _saveAvatar(username, bytes);
            await prefs.remove(key);
          } catch (_) {}
        }
      }
    }

    final outboxRaw = prefs.getString('outbox_queue_v1');
    if (outboxRaw != null && outboxRaw.isNotEmpty) {
      final list = safeJsonDecode<List<dynamic>>(
        outboxRaw,
        context: 'migrate_outbox',
      );
      if (list != null) {
        await _saveOutbox(list.cast<Map<String, dynamic>>());
        await prefs.remove('outbox_queue_v1');
      }
    }

    await prefs.setBool(_migratedKey, true);
  }

  Future<void> saveChats(List<Map<String, dynamic>> chats) async {
    await _ensureReady();
    await _saveChats(chats);
  }

  Future<void> _saveChats(List<Map<String, dynamic>> chats) async {
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM chats WHERE owner = ?',
        [_defaultOwner],
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < chats.length; i++) {
        final item = chats[i];
        final chatId =
            (item['chat_id'] ?? item['id'] ?? item['username'] ?? '').toString();
        final payload = jsonEncode(item);
        await _db.customStatement(
          'INSERT OR REPLACE INTO chats(owner, id, payload, updated_at) VALUES (?, ?, ?, ?)',
          [_defaultOwner, chatId.isEmpty ? '$i' : chatId, payload, now + i],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadChats() async {
    await _ensureReady();
    try {
      final rows = await _db.customSelect(
        'SELECT payload FROM chats WHERE owner = ? ORDER BY updated_at ASC',
        variables: [Variable.withString(_defaultOwner)],
      ).get();
      final result = <Map<String, dynamic>>[];
      for (final row in rows) {
        final payload = row.read<String>('payload');
        final decoded = safeJsonDecode<Map<String, dynamic>>(
          payload,
          context: 'db_chats_payload',
        );
        if (decoded == null) {
          continue;
        }
        result.add(Map<String, dynamic>.from(decoded));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessages(
    String chatId,
    List<Map<String, dynamic>> messages, {
    int limit = 200,
  }) async {
    await _ensureReady();
    await _saveMessages(chatId, messages, limit: limit);
  }

  Future<void> _saveMessages(
    String chatId,
    List<Map<String, dynamic>> messages, {
    int limit = 200,
  }) async {
    final trimmed = messages.length > limit
        ? messages.sublist(messages.length - limit)
        : messages;
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM messages WHERE owner = ? AND chat_id = ?',
        [_defaultOwner, chatId],
      );
      for (var i = 0; i < trimmed.length; i++) {
        final item = trimmed[i];
        final msgId = (item['id'] ?? item['message_id'] ?? '').toString();
        final rawTime = item['time']?.toString() ?? '';
        final parsed = double.tryParse(rawTime);
        final time = parsed != null
            ? (parsed * 1000).round()
            : DateTime.now().millisecondsSinceEpoch + i;
        final payload = jsonEncode(item);
        await _db.customStatement(
          'INSERT OR REPLACE INTO messages(owner, chat_id, id, payload, time) VALUES (?, ?, ?, ?, ?)',
          [
            _defaultOwner,
            chatId,
            msgId.isEmpty ? '$i' : msgId,
            payload,
            time,
          ],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadMessages(String chatId) async {
    await _ensureReady();
    try {
      final rows = await _db.customSelect(
        'SELECT payload FROM messages WHERE owner = ? AND chat_id = ? ORDER BY time ASC',
        variables: [
          Variable.withString(_defaultOwner),
          Variable.withString(chatId),
        ],
      ).get();
      return rows.map((row) {
        final payload = row.read<String>('payload');
        final decoded = safeJsonDecode<Map<String, dynamic>>(
          payload,
          context: 'db_messages_payload:$chatId',
        );
        if (decoded == null) {
          throw const FormatException('Invalid messages payload');
        }
        return Map<String, dynamic>.from(decoded);
      }).toList();
    } catch (_) {
      await _db.customStatement(
        'DELETE FROM messages WHERE owner = ? AND chat_id = ?',
        [_defaultOwner, chatId],
      );
      return [];
    }
  }

  Future<void> saveProfile(String username, Map<String, dynamic> profile) async {
    await _ensureReady();
    await _saveProfile(username, profile);
  }

  Future<void> _saveProfile(String username, Map<String, dynamic> profile) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO profiles(username, payload) VALUES (?, ?)',
      [username, jsonEncode(profile)],
    );
  }

  Future<Map<String, dynamic>?> loadProfile(String username) async {
    await _ensureReady();
    try {
      final rows = await _db.customSelect(
        'SELECT payload FROM profiles WHERE username = ?',
        variables: [Variable.withString(username)],
      ).get();
      if (rows.isEmpty) return null;
      final payload = rows.first.read<String>('payload');
      final decoded = safeJsonDecode<Map<String, dynamic>>(
        payload,
        context: 'db_profile_payload:$username',
      );
      if (decoded == null) {
        throw const FormatException('Invalid profile payload');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      await _db.customStatement(
        'DELETE FROM profiles WHERE username = ?',
        [username],
      );
      return null;
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _ensureReady();
    await _saveSettings(settings);
  }

  Future<void> _saveSettings(Map<String, dynamic> settings) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO settings(owner, payload) VALUES (?, ?)',
      [_defaultOwner, jsonEncode(settings)],
    );
  }

  Future<Map<String, dynamic>> loadSettings() async {
    await _ensureReady();
    try {
      final rows = await _db.customSelect(
        'SELECT payload FROM settings WHERE owner = ?',
        variables: [Variable.withString(_defaultOwner)],
      ).get();
      if (rows.isEmpty) return {};
      final payload = rows.first.read<String>('payload');
      final decoded = safeJsonDecode<Map<String, dynamic>>(
        payload,
        context: 'db_settings_payload',
      );
      if (decoded == null) {
        throw const FormatException('Invalid settings payload');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      await _db.customStatement(
        'DELETE FROM settings WHERE owner = ?',
        [_defaultOwner],
      );
      return {};
    }
  }

  Future<void> saveSessions(
    String username,
    List<Map<String, dynamic>> sessions,
  ) async {
    await _ensureReady();
    await _saveSessions(username, sessions);
  }

  Future<void> _saveSessions(
    String username,
    List<Map<String, dynamic>> sessions,
  ) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO sessions(owner, payload) VALUES (?, ?)',
      [username, jsonEncode(sessions)],
    );
  }

  Future<List<Map<String, dynamic>>> loadSessions(String username) async {
    await _ensureReady();
    try {
      final rows = await _db.customSelect(
        'SELECT payload FROM sessions WHERE owner = ?',
        variables: [Variable.withString(username)],
      ).get();
      if (rows.isEmpty) return [];
      final payload = rows.first.read<String>('payload');
      final list = safeJsonDecode<List<dynamic>>(
        payload,
        context: 'db_sessions_payload:$username',
      );
      if (list == null) {
        throw const FormatException('Invalid sessions payload');
      }
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      await _db.customStatement(
        'DELETE FROM sessions WHERE owner = ?',
        [username],
      );
      return [];
    }
  }

  Future<void> saveOutbox(List<Map<String, dynamic>> items) async {
    await _ensureReady();
    await _saveOutbox(items);
  }

  Future<void> _saveOutbox(List<Map<String, dynamic>> items) async {
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM outbox WHERE owner = ?',
        [_defaultOwner],
      );
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final id = item['id']?.toString() ?? '$i';
        final createdAt =
            (item['created_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        await _db.customStatement(
          'INSERT OR REPLACE INTO outbox(owner, id, payload, created_at) VALUES (?, ?, ?, ?)',
          [_defaultOwner, id, jsonEncode(item), createdAt],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadOutbox() async {
    await _ensureReady();
    try {
      final rows = await _db.customSelect(
        'SELECT payload FROM outbox WHERE owner = ? ORDER BY created_at ASC',
        variables: [Variable.withString(_defaultOwner)],
      ).get();
      return rows.map((row) {
        final payload = row.read<String>('payload');
        final decoded = safeJsonDecode<Map<String, dynamic>>(
          payload,
          context: 'db_outbox_payload',
        );
        if (decoded == null) {
          throw const FormatException('Invalid outbox payload');
        }
        return Map<String, dynamic>.from(decoded);
      }).toList();
    } catch (_) {
      await _db.customStatement(
        'DELETE FROM outbox WHERE owner = ?',
        [_defaultOwner],
      );
      return [];
    }
  }

  Future<void> saveAvatar(String username, Uint8List bytes) async {
    await _ensureReady();
    await _saveAvatar(username, bytes);
  }

  Future<void> _saveAvatar(String username, Uint8List bytes) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO avatars(username, bytes, updated_at) VALUES (?, ?, ?)',
      [username, bytes, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<Uint8List?> loadAvatar(String username) async {
    await _ensureReady();
    try {
      final rows = await _db.customSelect(
        'SELECT bytes FROM avatars WHERE username = ?',
        variables: [Variable.withString(username)],
      ).get();
      if (rows.isEmpty) return null;
      return rows.first.read<Uint8List>('bytes');
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    await _ensureReady();
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM chats WHERE owner = ?', [_defaultOwner]);
      await _db.customStatement(
        'DELETE FROM messages WHERE owner = ?',
        [_defaultOwner],
      );
      await _db.customStatement('DELETE FROM profiles');
      await _db.customStatement('DELETE FROM settings');
      await _db.customStatement('DELETE FROM sessions');
      await _db.customStatement('DELETE FROM avatars');
    });
  }
}

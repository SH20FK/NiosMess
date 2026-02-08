import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCache {
  static const _chatsKey = 'cache_chats';
  static const _settingsKey = 'cache_settings_v1';

  static Future<void> saveChats(List<Map<String, dynamic>> chats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatsKey, jsonEncode(chats));
  }

  static Future<List<Map<String, dynamic>>> loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> saveMessages(String chatId, List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_messages_$chatId', jsonEncode(messages));
  }

  static Future<List<Map<String, dynamic>>> loadMessages(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_messages_$chatId');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> saveProfile(String username, Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_profile_$username', jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> loadProfile(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_profile_$username');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveSessions(String username, List<Map<String, dynamic>> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_sessions_$username', jsonEncode(sessions));
  }

  static Future<List<Map<String, dynamic>>> loadSessions(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_sessions_$username');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAvatar(String username, Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_avatar_$username', base64Encode(bytes));
  }

  static Future<Uint8List?> loadAvatar(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_avatar_$username');
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

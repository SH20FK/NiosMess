import 'dart:typed_data';
import 'local_cache.dart';

class OfflineCache {
  static Future<void> saveChats(List<Map<String, dynamic>> chats) async {
    await LocalCache.instance.saveChats(chats);
  }

  static Future<List<Map<String, dynamic>>> loadChats() async {
    return LocalCache.instance.loadChats();
  }

  static Future<void> saveMessages(
      String chatId, List<Map<String, dynamic>> messages,
      {int limit = 200}) async {
    await LocalCache.instance.saveMessages(chatId, messages, limit: limit);
  }

  static Future<List<Map<String, dynamic>>> loadMessages(String chatId) async {
    return LocalCache.instance.loadMessages(chatId);
  }

  static Future<void> saveProfile(
      String username, Map<String, dynamic> profile) async {
    await LocalCache.instance.saveProfile(username, profile);
  }

  static Future<Map<String, dynamic>?> loadProfile(String username) async {
    return LocalCache.instance.loadProfile(username);
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    await LocalCache.instance.saveSettings(settings);
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    return LocalCache.instance.loadSettings();
  }

  static Future<void> saveSessions(
      String username, List<Map<String, dynamic>> sessions) async {
    await LocalCache.instance.saveSessions(username, sessions);
  }

  static Future<List<Map<String, dynamic>>> loadSessions(
      String username) async {
    return LocalCache.instance.loadSessions(username);
  }

  static Future<void> saveOutbox(List<Map<String, dynamic>> items) async {
    await LocalCache.instance.saveOutbox(items);
  }

  static Future<List<Map<String, dynamic>>> loadOutbox() async {
    return LocalCache.instance.loadOutbox();
  }

  static Future<void> saveAvatar(String username, Uint8List bytes) async {
    await LocalCache.instance.saveAvatar(username, bytes);
  }

  static Future<Uint8List?> loadAvatar(String username) async {
    return LocalCache.instance.loadAvatar(username);
  }

  static Future<void> clearAll() async {
    await LocalCache.instance.clearAll();
  }
}

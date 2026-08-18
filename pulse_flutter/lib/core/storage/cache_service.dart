import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';

class CacheService {
  const CacheService();

  static const String _chatsBoxName = 'chats_cache_box';
  static const String _messagesBoxName = 'messages_cache_box';
  static const String _contactsBoxName = 'contacts_cache_box';
  static const String _profilesBoxName = 'profiles_cache_box';
  static bool _hiveInitialized = false;

  Future<Box<List<dynamic>>> _ensureBox(String name) async {
    if (!Hive.isBoxOpen(name)) {
      await ensureInitialized();
    }
    return Hive.box<List<dynamic>>(name);
  }

  Future<Box<Map<dynamic, dynamic>>> _ensureMapBox(String name) async {
    if (!Hive.isBoxOpen(name)) {
      await ensureInitialized();
    }
    return Hive.box<Map<dynamic, dynamic>>(name);
  }

  Future<void> ensureInitialized() async {
    try {
      if (!_hiveInitialized) {
        await Hive.initFlutter();
        _hiveInitialized = true;
      }
      await Hive.openBox<List<dynamic>>(_chatsBoxName);
      await Hive.openBox<List<dynamic>>(_messagesBoxName);
      await Hive.openBox<List<dynamic>>(_contactsBoxName);
      await Hive.openBox<Map<dynamic, dynamic>>(_profilesBoxName);
    } catch (e) {
      debugPrint('[CacheService] Initialization error: $e');
    }
  }

  Future<void> saveProfile(ApiProfile profile) async {
    try {
      final Box<Map<dynamic, dynamic>> box = await _ensureMapBox(_profilesBoxName);
      final Map<String, dynamic> json = profile.toJson();
      if (profile.username.isNotEmpty) {
        await box.put(profile.username.toLowerCase(), json);
      }
      if (profile.id > 0) {
        await box.put('id_${profile.id}', json);
      }
    } catch (e) {
      debugPrint('[CacheService] Error saving profile: $e');
    }
  }

  ApiProfile? getCachedProfile(String username) {
    try {
      if (!Hive.isBoxOpen(_profilesBoxName)) return null;
      final Box<Map<dynamic, dynamic>> box = Hive.box<Map<dynamic, dynamic>>(_profilesBoxName);
      final dynamic data = box.get(username.toLowerCase());
      if (data is Map) {
        return ApiProfile.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      debugPrint('[CacheService] Error loading cached profile: $e');
      return null;
    }
  }

  ApiProfile? getCachedProfileById(int id) {
    try {
      if (!Hive.isBoxOpen(_profilesBoxName)) return null;
      final Box<Map<dynamic, dynamic>> box = Hive.box<Map<dynamic, dynamic>>(_profilesBoxName);
      final dynamic data = box.get('id_$id');
      if (data is Map) {
        return ApiProfile.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      debugPrint('[CacheService] Error loading cached profile by id: $e');
      return null;
    }
  }

  Future<void> saveMessages(int chatId, List<ApiMessage> messages) async {
    try {
      final Box<List<dynamic>> box = await _ensureBox(_messagesBoxName);
      final List<Map<String, dynamic>> jsonList =
          messages.take(100).map((e) => e.toJson()).toList(growable: false);
      await box.put('chat_$chatId', jsonList);
    } catch (e) {
      debugPrint('[CacheService] Error saving messages: $e');
    }
  }

  List<ApiMessage> getCachedMessages(int chatId) {
    try {
      if (!Hive.isBoxOpen(_messagesBoxName)) return <ApiMessage>[];
      final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_messagesBoxName);
      final List<dynamic>? list = box.get('chat_$chatId');
      if (list == null) return <ApiMessage>[];
      return list
          .whereType<Map>()
          .map((e) => ApiMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[CacheService] Error loading cached messages: $e');
      return <ApiMessage>[];
    }
  }

  Future<void> saveChats(List<ApiChatSummary> chats) async {
    try {
      final Box<List<dynamic>> box = await _ensureBox(_chatsBoxName);
      final List<Map<String, dynamic>> jsonList = chats.map((e) => e.toJson()).toList();
      await box.put('list', jsonList);
    } catch (e) {
      debugPrint('[CacheService] Error saving chats: $e');
    }
  }

  List<ApiChatSummary> getCachedChats() {
    try {
      if (!Hive.isBoxOpen(_chatsBoxName)) return <ApiChatSummary>[];
      final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_chatsBoxName);
      final List<dynamic>? list = box.get('list');
      if (list == null) return <ApiChatSummary>[];
      return list
          .whereType<Map>()
          .map((e) => ApiChatSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[CacheService] Error loading cached chats: $e');
      return <ApiChatSummary>[];
    }
  }

  Future<void> saveContacts(List<ApiChatSummary> contacts) async {
    try {
      final Box<List<dynamic>> box = await _ensureBox(_contactsBoxName);
      final List<Map<String, dynamic>> jsonList = contacts.map((e) => e.toJson()).toList();
      await box.put('list', jsonList);
    } catch (e) {
      debugPrint('[CacheService] Error saving contacts: $e');
    }
  }

  List<ApiChatSummary> getCachedContacts() {
    try {
      if (!Hive.isBoxOpen(_contactsBoxName)) return <ApiChatSummary>[];
      final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_contactsBoxName);
      final List<dynamic>? list = box.get('list');
      if (list == null) return <ApiChatSummary>[];
      return list
          .whereType<Map>()
          .map((e) => ApiChatSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[CacheService] Error loading cached contacts: $e');
      return <ApiChatSummary>[];
    }
  }

  Future<void> clearAll() async {
    try {
      if (Hive.isBoxOpen(_chatsBoxName)) await Hive.box<List<dynamic>>(_chatsBoxName).clear();
      if (Hive.isBoxOpen(_messagesBoxName)) await Hive.box<List<dynamic>>(_messagesBoxName).clear();
      if (Hive.isBoxOpen(_contactsBoxName)) await Hive.box<List<dynamic>>(_contactsBoxName).clear();
      if (Hive.isBoxOpen(_profilesBoxName)) await Hive.box<Map<dynamic, dynamic>>(_profilesBoxName).clear();
    } catch (e) {
      debugPrint('[CacheService] Error clearing cache: $e');
    }
  }
}

final Provider<CacheService> cacheServiceProvider =
    Provider<CacheService>((Ref ref) => const CacheService());

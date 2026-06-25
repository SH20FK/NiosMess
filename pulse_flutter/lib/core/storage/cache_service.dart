import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

class CacheService {
  const CacheService();

  static const String _chatsBoxName = 'chats_cache_box';
  static const String _messagesBoxName = 'messages_cache_box';
  static const String _contactsBoxName = 'contacts_cache_box';
  static bool _hiveInitialized = false;

  Future<void> ensureInitialized() async {
    try {
      if (!_hiveInitialized) {
        await Hive.initFlutter();
        _hiveInitialized = true;
      }
      await Hive.openBox<List<dynamic>>(_chatsBoxName);
      await Hive.openBox<List<dynamic>>(_messagesBoxName);
      await Hive.openBox<List<dynamic>>(_contactsBoxName);
    } catch (e) {
      debugPrint('[CacheService] Initialization error: $e');
    }
  }

  Future<void> saveChats(List<ApiChatSummary> chats) async {
    try {
      final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_chatsBoxName);
      final List<Map<String, dynamic>> jsonList = chats.map((e) => e.toJson()).toList();
      await box.put('list', jsonList);
    } catch (e) {
      debugPrint('[CacheService] Error saving chats: $e');
    }
  }

  List<ApiChatSummary> getCachedChats() {
    try {
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

  Future<void> saveMessages(int chatId, List<ApiMessage> messages) async {
    try {
      final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_messagesBoxName);
      // Only keep the last 100 messages in cache to optimize local storage size
      final List<ApiMessage> trimmed = messages.length > 100 
          ? messages.sublist(messages.length - 100) 
          : messages;
      final List<Map<String, dynamic>> jsonList = trimmed.map((e) => e.toJson()).toList();
      await box.put(chatId.toString(), jsonList);
    } catch (e) {
      debugPrint('[CacheService] Error saving messages: $e');
    }
  }

  List<ApiMessage> getCachedMessages(int chatId) {
    try {
      final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_messagesBoxName);
      final List<dynamic>? list = box.get(chatId.toString());
      if (list == null) return <ApiMessage>[];
      return list
          .whereType<Map>()
          .map((e) => ApiMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[CacheService] Error loading cached messages for $chatId: $e');
      return <ApiMessage>[];
    }
  }

  Future<void> saveContacts(List<ApiChatSummary> contacts) async {
    try {
      final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_contactsBoxName);
      final List<Map<String, dynamic>> jsonList = contacts.map((e) => e.toJson()).toList();
      await box.put('list', jsonList);
    } catch (e) {
      debugPrint('[CacheService] Error saving contacts: $e');
    }
  }

  List<ApiChatSummary> getCachedContacts() {
    try {
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
      await Hive.box<List<dynamic>>(_chatsBoxName).clear();
      await Hive.box<List<dynamic>>(_messagesBoxName).clear();
      await Hive.box<List<dynamic>>(_contactsBoxName).clear();
    } catch (e) {
      debugPrint('[CacheService] Error clearing cache: $e');
    }
  }
}

final Provider<CacheService> cacheServiceProvider =
    Provider<CacheService>((Ref ref) => const CacheService());

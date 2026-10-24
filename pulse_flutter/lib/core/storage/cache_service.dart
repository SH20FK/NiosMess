import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';

class CacheService {
  const CacheService();

  static const String _chatsBoxName = 'chats_cache_box';
  static const String _messagesBoxName = 'messages_cache_box';
  static const String _contactsBoxName = 'contacts_cache_box';
  static const String _profilesBoxName = 'profiles_cache_box';
  static const String _feedBoxName = 'feed_cache_box';
  static const String _stickersBoxName = 'stickers_cache_box';
  static Future<void>? _initialization;

  Future<Box<List<dynamic>>?> _ensureBox(String name) async {
    try {
      if (!Hive.isBoxOpen(name)) {
        await ensureInitialized();
      }
      if (Hive.isBoxOpen(name)) {
        return Hive.box<List<dynamic>>(name);
      }
      return null;
    } catch (e) {
      debugPrint('[CacheService] _ensureBox error: $e');
      return null;
    }
  }

  Future<Box<Map<dynamic, dynamic>>?> _ensureMapBox(String name) async {
    try {
      if (!Hive.isBoxOpen(name)) {
        await ensureInitialized();
      }
      if (Hive.isBoxOpen(name)) {
        return Hive.box<Map<dynamic, dynamic>>(name);
      }
      return null;
    } catch (e) {
      debugPrint('[CacheService] _ensureMapBox error: $e');
      return null;
    }
  }

  Future<void> ensureInitialized() =>
      _initialization ??= _openBoxes().whenComplete(() {
        _initialization = null;
      });

  Future<void> _openBoxes() async {
    await HiveBootstrap.ensureInitialized();
    await Future.wait([
      Hive.openBox<List<dynamic>>(_chatsBoxName),
      Hive.openBox<List<dynamic>>(_messagesBoxName),
      Hive.openBox<List<dynamic>>(_contactsBoxName),
      Hive.openBox<Map<dynamic, dynamic>>(_profilesBoxName),
      Hive.openBox<List<dynamic>>(_feedBoxName),
      Hive.openBox<List<dynamic>>(_stickersBoxName),
    ]);
  }

  Future<void> saveProfile(ApiProfile profile) async {
    try {
      final Box<Map<dynamic, dynamic>>? box = await _ensureMapBox(
        _profilesBoxName,
      );
      if (box == null) return;
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
      final Box<Map<dynamic, dynamic>> box = Hive.box<Map<dynamic, dynamic>>(
        _profilesBoxName,
      );
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
      final Box<Map<dynamic, dynamic>> box = Hive.box<Map<dynamic, dynamic>>(
        _profilesBoxName,
      );
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
      final Box<List<dynamic>>? box = await _ensureBox(_messagesBoxName);
      if (box == null) return;
      final List<Map<String, dynamic>> jsonList = messages
          .take(100)
          .map((e) => e.toJson())
          .toList(growable: false);
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
      final Box<List<dynamic>>? box = await _ensureBox(_chatsBoxName);
      if (box == null) return;
      final List<Map<String, dynamic>> jsonList = chats.map((e) {
        final data = e.toJson();
        if (e.isSecret) {
          data['last_message'] = null;
        } else if (e.lastMessage?.isE2ee == true) {
          // Persist the existing ciphertext envelope, not decrypted ordinary previews.
          data['last_message'] = {
            ...e.lastMessage!.toJson(),
            'content': '',
            'is_decrypted': false,
            'e2ee_file_key': null,
            'sticker': null,
            'reply_markup': null,
            'system_event': null,
            'system_event_type': null,
            'media_name': null,
            'media_size': null,
          };
        }
        return data;
      }).toList();
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
      final Box<List<dynamic>>? box = await _ensureBox(_contactsBoxName);
      if (box == null) return;
      final List<Map<String, dynamic>> jsonList = contacts
          .map((e) => e.toJson())
          .toList();
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

  Future<void> saveFeed(List<NgPost> posts) async {
    try {
      final Box<List<dynamic>>? box = await _ensureBox(_feedBoxName);
      if (box == null) return;
      final List<Map<String, dynamic>> jsonList = posts
          .take(60)
          .map((NgPost p) => p.toPublicCacheJson())
          .toList(growable: false);
      await box.put('feed', jsonList);
    } catch (e) {
      debugPrint('[CacheService] Error saving feed: $e');
    }
  }

  List<NgPost> getCachedFeed() {
    try {
      if (!Hive.isBoxOpen(_feedBoxName)) return <NgPost>[];
      final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_feedBoxName);
      final List<dynamic>? list = box.get('feed');
      if (list == null) return <NgPost>[];
      return list
          .whereType<Map>()
          .map(
            (dynamic e) => NgPost.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(growable: false);
    } catch (e) {
      debugPrint('[CacheService] Error loading cached feed: $e');
      return <NgPost>[];
    }
  }

  Future<void> saveStickerSets(List<ApiStickerSet> sets) async {
    try {
      final Box<List<dynamic>>? box = await _ensureBox(_stickersBoxName);
      if (box == null) return;
      final List<Map<String, dynamic>> jsonList = sets
          .map((ApiStickerSet s) => s.toJson())
          .toList(growable: false);
      await box.put('sets', jsonList);
    } catch (e) {
      debugPrint('[CacheService] Error saving sticker sets: $e');
    }
  }

  List<ApiStickerSet> getCachedStickerSets() {
    try {
      if (!Hive.isBoxOpen(_stickersBoxName)) return <ApiStickerSet>[];
      final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_stickersBoxName);
      final List<dynamic>? list = box.get('sets');
      if (list == null) return <ApiStickerSet>[];
      return list
          .whereType<Map>()
          .map(
            (dynamic e) =>
                ApiStickerSet.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(growable: false);
    } catch (e) {
      debugPrint('[CacheService] Error loading cached sticker sets: $e');
      return <ApiStickerSet>[];
    }
  }

  Future<void> clearAll() async {
    try {
      if (Hive.isBoxOpen('bluetooth_mesh_ciphertext_v1')) {
        await Hive.box<String>('bluetooth_mesh_ciphertext_v1').clear();
      }
      if (Hive.isBoxOpen(_chatsBoxName)) {
        await Hive.box<List<dynamic>>(_chatsBoxName).clear();
      }
      if (Hive.isBoxOpen(_messagesBoxName)) {
        await Hive.box<List<dynamic>>(_messagesBoxName).clear();
      }
      if (Hive.isBoxOpen(_contactsBoxName)) {
        await Hive.box<List<dynamic>>(_contactsBoxName).clear();
      }
      if (Hive.isBoxOpen(_profilesBoxName)) {
        await Hive.box<Map<dynamic, dynamic>>(_profilesBoxName).clear();
      }
      if (Hive.isBoxOpen(_feedBoxName)) {
        await Hive.box<List<dynamic>>(_feedBoxName).clear();
      }
      if (Hive.isBoxOpen(_stickersBoxName)) {
        await Hive.box<List<dynamic>>(_stickersBoxName).clear();
      }
    } catch (e) {
      debugPrint('[CacheService] Error clearing cache: $e');
    }
  }
}

final Provider<CacheService> cacheServiceProvider = Provider<CacheService>(
  (Ref ref) => const CacheService(),
);

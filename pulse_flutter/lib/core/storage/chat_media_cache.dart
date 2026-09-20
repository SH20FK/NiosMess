import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

/// Persistent local cache for all shared media in a chat (photos, videos,
/// voice messages, video notes, documents, and web links).
///
/// Ensures that once media is loaded for a chat, it is permanently preserved
/// locally and displays instantly (0ms) without refetching from scratch.
class ChatMediaCache {
  const ChatMediaCache._();

  static const String _boxName = 'chat_shared_media_v1';
  static const int _maxCachedMedia = 300;
  static bool _initialized = false;

  static final RegExp _urlRegExp = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  /// Checks if a message qualifies as shared media (photo, video, audio, file, voice, link).
  static bool isMediaMessage(ApiMessage m) {
    if (m.isDeleted) return false;
    if (m.isSticker) return false;
    final String msgType = m.msgType.toLowerCase();
    if (msgType == 'sticker') return false;

    final String mediaUrl = (m.mediaUrl ?? '').trim();
    if (mediaUrl.isNotEmpty) {
      if (m.isSticker || msgType == 'sticker') return false;
      return true;
    }

    if (msgType == 'voice' ||
        msgType == 'circle_video' ||
        msgType == 'video_note' ||
        msgType == 'round_video' ||
        msgType == 'file' ||
        msgType == 'image' ||
        msgType == 'video') {
      return true;
    }
    final String mediaType = (m.mediaType ?? '').toLowerCase();
    if (mediaType.startsWith('audio/') ||
        mediaType.startsWith('image/') ||
        mediaType.startsWith('video/') ||
        mediaType.contains('pdf') ||
        mediaType.contains('document')) {
      return true;
    }
    if (m.content.isNotEmpty && _urlRegExp.hasMatch(m.content)) {
      return true;
    }
    return false;
  }

  static Future<void> ensureInitialized() async {
    if (_initialized && Hive.isBoxOpen(_boxName)) return;
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<List<dynamic>>(_boxName);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[ChatMediaCache] Initialization error: $e');
    }
  }

  static Box<List<dynamic>>? _getBox() {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<List<dynamic>>(_boxName);
    }
    return null;
  }

  /// Synchronously loads cached media messages if the Hive box is open.
  static List<ApiMessage> getCachedMediaSync(int chatId) {
    try {
      final Box<List<dynamic>>? box = _getBox();
      if (box == null) return const <ApiMessage>[];
      final List<dynamic>? raw = box.get('chat_$chatId');
      if (raw == null || raw.isEmpty) return const <ApiMessage>[];

      return raw
          .whereType<Map>()
          .map((dynamic item) => ApiMessage.fromJson(
                (item as Map).map(
                  (dynamic k, dynamic v) => MapEntry(k.toString(), v),
                ),
              ))
          .where(isMediaMessage)
          .toList(growable: false);
    } catch (e) {
      debugPrint('[ChatMediaCache] getCachedMediaSync error: $e');
      return const <ApiMessage>[];
    }
  }

  /// Asynchronously loads all cached media messages for [chatId].
  static Future<List<ApiMessage>> getCachedMedia(int chatId) async {
    await ensureInitialized();
    return getCachedMediaSync(chatId);
  }

  /// Merges new media messages into the permanent cache for [chatId].
  /// Existing messages are updated, new ones are inserted, order is preserved.
  static Future<void> saveMediaMessages(
    int chatId,
    List<ApiMessage> messages,
  ) async {
    if (chatId <= 0 || messages.isEmpty) return;

    try {
      await ensureInitialized();
      final Box<List<dynamic>>? box = _getBox();
      if (box == null) return;

      // Filter only messages containing media
      final List<ApiMessage> newMedia =
          messages.where(isMediaMessage).toList(growable: false);
      if (newMedia.isEmpty) return;

      // Load existing cached media
      final List<ApiMessage> existing = getCachedMediaSync(chatId);
      final Map<int, ApiMessage> byId = <int, ApiMessage>{};

      for (final ApiMessage m in existing) {
        if (isMediaMessage(m)) {
          byId[m.id] = m;
        }
      }

      bool changed = false;
      for (final ApiMessage m in newMedia) {
        final ApiMessage? previous = byId[m.id];
        if (previous == null ||
            jsonEncode(previous.toJson()) != jsonEncode(m.toJson())) {
          byId[m.id] = m;
          changed = true;
        }
      }
      if (!changed && byId.length <= _maxCachedMedia) return;

      final List<ApiMessage> merged = byId.values.toList()
        ..sort((ApiMessage a, ApiMessage b) => b.sentAt.compareTo(a.sentAt));
      final List<ApiMessage> capped = merged.length > _maxCachedMedia
          ? merged.sublist(0, _maxCachedMedia)
          : merged;

      final List<Map<String, dynamic>> jsonList =
          capped.map((ApiMessage m) => m.toJson()).toList(growable: false);

      await box.put('chat_$chatId', jsonList);
    } catch (e) {
      debugPrint('[ChatMediaCache] saveMediaMessages error: $e');
    }
  }

  /// Appends or updates a single media message in the cache for [chatId].
  static Future<void> addSingleMediaMessage(
    int chatId,
    ApiMessage message,
  ) async {
    if (chatId <= 0 || !isMediaMessage(message)) return;
    await saveMediaMessages(chatId, <ApiMessage>[message]);
  }

  /// Removes a media message from cache if deleted.
  static Future<void> removeMediaMessage(int chatId, int messageId) async {
    if (chatId <= 0) return;
    try {
      await ensureInitialized();
      final Box<List<dynamic>>? box = _getBox();
      if (box == null) return;

      final List<ApiMessage> existing = getCachedMediaSync(chatId);
      final List<ApiMessage> updated =
          existing.where((ApiMessage m) => m.id != messageId).toList(growable: false);

      if (updated.length != existing.length) {
        final List<Map<String, dynamic>> jsonList =
            updated.map((ApiMessage m) => m.toJson()).toList(growable: false);
        await box.put('chat_$chatId', jsonList);
      }
    } catch (e) {
      debugPrint('[ChatMediaCache] removeMediaMessage error: $e');
    }
  }

  /// Clears cached media for a specific chat.
  static Future<void> clearChatMedia(int chatId) async {
    try {
      await ensureInitialized();
      final Box<List<dynamic>>? box = _getBox();
      if (box == null) return;
      await box.delete('chat_$chatId');
    } catch (e) {
      debugPrint('[ChatMediaCache] clearChatMedia error: $e');
    }
  }
}

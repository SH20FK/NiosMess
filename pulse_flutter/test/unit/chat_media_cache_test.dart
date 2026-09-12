import 'package:universal_io/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/storage/chat_media_cache.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

ApiMessage _createTestMsg({
  required int id,
  required int chatId,
  String content = '',
  String msgType = 'text',
  String? mediaUrl,
  String? mediaType,
  bool isDeleted = false,
  DateTime? sentAt,
}) {
  return ApiMessage(
    id: id,
    chatId: chatId,
    senderId: 1,
    senderUsername: 'test',
    senderDisplayName: 'Test',
    senderBadges: const [],
    content: content,
    msgType: msgType,
    replyToId: null,
    mediaUrl: mediaUrl,
    mediaType: mediaType,
    mediaName: null,
    mediaSize: null,
    mediaDuration: null,
    commentsCount: 0,
    reactions: const {},
    sentAt: sentAt ?? DateTime.now(),
    editedAt: null,
    isDeleted: isDeleted,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chat_media_cache_test');
    Hive.init(tempDir.path);
    await ChatMediaCache.ensureInitialized();
  });

  tearDown(() async {
    try {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('ChatMediaCache isMediaMessage classification', () {
    test('Identifies messages with mediaUrl as media', () {
      final m = _createTestMsg(
        id: 1,
        chatId: 10,
        msgType: 'image',
        mediaUrl: '/uploads/photos/test.jpg',
      );
      expect(ChatMediaCache.isMediaMessage(m), isTrue);
    });

    test('Identifies voice and circle video notes as media', () {
      final voice = _createTestMsg(
        id: 2,
        chatId: 10,
        msgType: 'voice',
        mediaUrl: '/uploads/voice/note.ogg',
      );
      expect(ChatMediaCache.isMediaMessage(voice), isTrue);

      final circle = _createTestMsg(
        id: 3,
        chatId: 10,
        msgType: 'circle_video',
        mediaUrl: '/uploads/video/circle.mp4',
      );
      expect(ChatMediaCache.isMediaMessage(circle), isTrue);
    });

    test('Identifies messages with web links as media', () {
      final linkMsg = _createTestMsg(
        id: 4,
        chatId: 10,
        content: 'Check out https://github.com/flutter/flutter for more info',
      );
      expect(ChatMediaCache.isMediaMessage(linkMsg), isTrue);
    });

    test('Rejects plain text without media or links', () {
      final textMsg = _createTestMsg(
        id: 5,
        chatId: 10,
        content: 'Привет! Как дела?',
      );
      expect(ChatMediaCache.isMediaMessage(textMsg), isFalse);
    });

    test('Rejects deleted messages', () {
      final deleted = _createTestMsg(
        id: 6,
        chatId: 10,
        content: 'https://example.com',
        isDeleted: true,
      );
      expect(ChatMediaCache.isMediaMessage(deleted), isFalse);
    });
  });

  group('ChatMediaCache persistence and deduplication', () {
    test('Saves, merges and retrieves media messages permanently', () async {
      final m1 = _createTestMsg(
        id: 101,
        chatId: 99,
        content: 'Photo 1',
        msgType: 'image',
        mediaUrl: '/uploads/p1.jpg',
        sentAt: DateTime(2026, 1, 1, 12, 0),
      );

      final m2 = _createTestMsg(
        id: 102,
        chatId: 99,
        content: 'Just plain text',
        msgType: 'text',
        sentAt: DateTime(2026, 1, 1, 12, 5),
      );

      final m3 = _createTestMsg(
        id: 103,
        chatId: 99,
        content: 'Link: https://ni-os.ru',
        msgType: 'text',
        sentAt: DateTime(2026, 1, 1, 12, 10),
      );

      // Save initial batch: m1 (media), m2 (plain text - ignored), m3 (link)
      await ChatMediaCache.saveMediaMessages(99, [m1, m2, m3]);

      final cached1 = ChatMediaCache.getCachedMediaSync(99);
      expect(cached1.length, 2);
      expect(cached1.map((m) => m.id).toSet(), {101, 103});

      // Save second batch with overlapping m3 and new m4 (voice)
      final m4 = _createTestMsg(
        id: 104,
        chatId: 99,
        msgType: 'voice',
        mediaUrl: '/uploads/voice.ogg',
        sentAt: DateTime(2026, 1, 1, 12, 15),
      );

      await ChatMediaCache.saveMediaMessages(99, [m3, m4]);

      final cached2 = await ChatMediaCache.getCachedMedia(99);
      expect(cached2.length, 3);
      expect(cached2.map((m) => m.id).toSet(), {101, 103, 104});

      // Remove m1 (deleted)
      await ChatMediaCache.removeMediaMessage(99, 101);
      final cached3 = ChatMediaCache.getCachedMediaSync(99);
      expect(cached3.length, 2);
      expect(cached3.map((m) => m.id).toSet(), {103, 104});
    });
  });
}

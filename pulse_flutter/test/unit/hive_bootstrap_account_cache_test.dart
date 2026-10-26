import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/chat_media_cache.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:universal_io/io.dart';

ApiMessage _message(int id, String text) => ApiMessage.fromJson({
  'id': id,
  'chat_id': 42,
  'sender_id': 1,
  'content': text,
  'msg_type': 'text',
  'sent_at': '2026-10-15T10:00:00Z',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    // The aggregate suite inherits other modules' root-level storage setup.
    // Reinitializing Hive's path alone keeps their already-open boxes alive.
    // This fixture requires an actually cold, independently owned store.
    await Hive.close();
    directory = await Directory.systemTemp.createTemp('niosmess_bootstrap_');
    Hive.init(directory.path);
    HiveBootstrap.resetForTesting();
    await EncryptedMessageCache.clearAll();
    FlutterSecureStorage.setMockInitialValues({});
    EncryptedMessageCache.resetMemoryForTesting();
  });
  tearDown(() async {
    await Hive.close();
    HiveBootstrap.resetForTesting();
    await directory.delete(recursive: true);
  });

  test('all concurrent cache opens wait for one Hive bootstrap', () async {
    // Simulate a genuinely cold Hive process with a delayed path_provider.
    Hive.init(null);
    final directoryResult = Completer<String>();
    var pathRequests = 0;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            pathRequests++;
            return directoryResult.future;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final pending = Future.wait([
      const CacheService().ensureInitialized(),
      EncryptedMessageCache.ensureInitialized(),
      ChatMediaCache.ensureInitialized(),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(Hive.isBoxOpen('enc_messages_v1'), isFalse);
    directoryResult.complete(directory.path);
    await pending;
    expect(pathRequests, 1);
    for (final name in [
      'chats_cache_box',
      'messages_cache_box',
      'enc_messages_v1',
      'enc_sender_plaintext_v2',
      'chat_shared_media_v1',
    ]) {
      expect(Hive.isBoxOpen(name), isTrue, reason: name);
    }
  });

  test(
    'failed Hive bootstrap is reported and the next attempt can recover',
    () async {
      Hive.init(null);
      var requests = 0;
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (++requests == 1) {
              throw PlatformException(code: 'storage_unavailable');
            }
            return directory.path;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await expectLater(
        HiveBootstrap.ensureInitialized(),
        throwsA(isA<PlatformException>()),
      );
      await EncryptedMessageCache.ensureInitialized();
      expect(Hive.isBoxOpen('enc_messages_v1'), isTrue);
      expect(requests, 2);
    },
  );

  test(
    'cache survives restart and never falls back to another account or unowned legacy',
    () async {
      await EncryptedMessageCache.ensureInitialized();
      await EncryptedMessageCache.saveMessages(42, [
        _message(1, 'A'),
      ], userId: 1);
      await EncryptedMessageCache.saveMessages(42, [
        _message(2, 'B'),
      ], userId: 2);
      await EncryptedMessageCache.saveMessages(42, [_message(3, 'legacy')]);
      await Hive.close();
      EncryptedMessageCache.resetMemoryForTesting();
      Hive.init(directory.path);
      await EncryptedMessageCache.ensureInitialized();
      expect(
        (await EncryptedMessageCache.loadMessages(
          42,
          userId: 1,
        )).single.content,
        'A',
      );
      expect(
        (await EncryptedMessageCache.loadMessages(
          42,
          userId: 2,
        )).single.content,
        'B',
      );
      expect(await EncryptedMessageCache.loadMessages(42, userId: 3), isEmpty);
      expect(
        await EncryptedMessageCache.loadMessages(
          42,
          userId: 3,
          legacyOwnerUserId: 1,
        ),
        isEmpty,
      );
      await EncryptedMessageCache.clearChat(42, userId: 1);
      expect(
        (await EncryptedMessageCache.loadMessages(
          42,
          userId: 2,
        )).single.content,
        'B',
      );
      expect(
        (await EncryptedMessageCache.loadMessages(42)).single.content,
        'legacy',
      );
    },
  );
  test(
    'legacy sender text requires ownership and never replaces scoped text',
    () async {
      await EncryptedMessageCache.ensureInitialized();
      await EncryptedMessageCache.saveSenderPlaintext(
        chatId: 42,
        messageId: 1,
        plaintext: 'owned',
        userId: 1,
      );
      await EncryptedMessageCache.saveSenderPlaintext(
        chatId: 42,
        messageId: 1,
        plaintext: 'legacy duplicate',
      );
      await EncryptedMessageCache.saveSenderPlaintext(
        chatId: 42,
        messageId: 2,
        plaintext: 'legacy only',
      );
      expect(
        await EncryptedMessageCache.senderPlaintextsForMigration(42, 2),
        isEmpty,
      );
      expect(await EncryptedMessageCache.senderPlaintextsForMigration(42, 1), {
        1: 'owned',
      });
      expect(
        await EncryptedMessageCache.senderPlaintextsForMigration(
          42,
          1,
          legacyOwnerUserId: 1,
          legacyMessageIds: {2},
        ),
        {1: 'owned', 2: 'legacy only'},
      );
      await EncryptedMessageCache.clearMigratedSecretChat(42, userId: 1);
      expect(
        await EncryptedMessageCache.getSenderPlaintext(
          chatId: 42,
          messageId: 2,
        ),
        'legacy only',
      );
      await EncryptedMessageCache.clearMigratedSecretChat(
        42,
        userId: 1,
        legacyOwnerUserId: 1,
        legacyMessageIds: {2},
      );
      expect(
        await EncryptedMessageCache.getSenderPlaintext(
          chatId: 42,
          messageId: 2,
        ),
        isNull,
      );
    },
  );
  test(
    'new chat-list caches are scoped and cannot adopt an unowned legacy list',
    () async {
      const cache = CacheService();
      await cache.ensureInitialized();
      final one = ApiChatSummary(
        id: 1,
        chatType: 'direct',
        name: 'One',
        unreadCount: 0,
        membersCount: 2,
      );
      final two = ApiChatSummary(
        id: 2,
        chatType: 'direct',
        name: 'Two',
        unreadCount: 0,
        membersCount: 2,
      );
      await cache.saveChats([one]);
      await cache.saveChats([two], accountId: 2);
      expect(cache.getCachedChats(accountId: 1), isEmpty);
      expect(cache.getCachedChats(accountId: 2).single.id, 2);
      expect(cache.getCachedChats().single.id, 1);
    },
  );
  test(
    'unavailable cache key retains legacy source without an unhandled completer error',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'niosmess_msg_cache_key_v1': 'invalid !',
      });
      final legacy = await Hive.openBox<String>('enc_sender_plaintext_v1');
      await legacy.put('1_42_1', 'retained original');
      await EncryptedMessageCache.ensureInitialized();
      expect(legacy.get('1_42_1'), 'retained original');
    },
  );
  test(
    'sender originals are encrypted, context-bound and survive a cold memory restart',
    () async {
      await EncryptedMessageCache.ensureInitialized();
      await EncryptedMessageCache.saveSenderPlaintext(
        chatId: 42,
        messageId: 1,
        plaintext: 'private original fixture',
        userId: 1,
      );
      final box = Hive.box<String>('enc_sender_plaintext_v2');
      expect(box.get('1_42_1'), isNot(contains('private original fixture')));
      await box.put('2_42_1', box.get('1_42_1')!);
      EncryptedMessageCache.resetMemoryForTesting();
      expect(
        await EncryptedMessageCache.getSenderPlaintext(
          chatId: 42,
          messageId: 1,
          userId: 1,
        ),
        'private original fixture',
      );
      expect(
        await EncryptedMessageCache.getSenderPlaintext(
          chatId: 42,
          messageId: 1,
          userId: 2,
        ),
        isNull,
      );
    },
  );
  test(
    'sender cache migration verifies ciphertext before removing legacy original',
    () async {
      final legacy = await Hive.openBox<String>('enc_sender_plaintext_v1');
      await legacy.put('1_42_1', 'legacy sender fixture');
      await legacy.flush();
      await EncryptedMessageCache.ensureInitialized();
      expect(legacy.get('1_42_1'), isNull);
      expect(
        Hive.box<String>('enc_sender_plaintext_v2').get('1_42_1'),
        isNot(contains('legacy sender fixture')),
      );
      EncryptedMessageCache.resetMemoryForTesting();
      expect(
        await EncryptedMessageCache.getSenderPlaintext(
          chatId: 42,
          messageId: 1,
          userId: 1,
        ),
        'legacy sender fixture',
      );
    },
  );
  test(
    'sender cache failed migration preserves the only legacy original',
    () async {
      final legacy = await Hive.openBox<String>('enc_sender_plaintext_v1');
      final protected = await Hive.openBox<String>('enc_sender_plaintext_v2');
      await legacy.put('1_42_1', 'retained source');
      await protected.put('1_42_1', 'corrupt target');
      await EncryptedMessageCache.ensureInitialized();
      expect(legacy.get('1_42_1'), 'retained source');
    },
  );
  test(
    'account erase cancels both in-flight encryption and delayed UI cache flushes',
    () async {
      await EncryptedMessageCache.ensureInitialized();
      final revision = EncryptedMessageCache.accountGeneration(1);
      final inFlight = EncryptedMessageCache.saveMessages(42, [
        _message(1, 'pending'),
      ], userId: 1);
      await EncryptedMessageCache.clearAccount(1, []);
      await inFlight;
      await EncryptedMessageCache.saveMessages(
        42,
        [_message(2, 'delayed old snapshot')],
        userId: 1,
        expectedAccountGeneration: revision,
      );
      expect(await EncryptedMessageCache.loadMessages(42, userId: 1), isEmpty);
      await EncryptedMessageCache.saveMessages(42, [
        _message(3, 'another account'),
      ], userId: 2);
      expect(
        (await EncryptedMessageCache.loadMessages(
          42,
          userId: 2,
        )).single.content,
        'another account',
      );
    },
  );
  test(
    'manual cache clear fences pending encryption while keeping the live account lease usable',
    () async {
      await EncryptedMessageCache.ensureInitialized();
      // This is the lease captured by an already mounted ChatMessagesNotifier.
      final mountedAccountLease = EncryptedMessageCache.accountGeneration(1);
      final inFlight = EncryptedMessageCache.saveMessages(
        42,
        [_message(1, 'before clear')],
        userId: 1,
        expectedAccountGeneration: mountedAccountLease,
      );
      await EncryptedMessageCache.clearAll();
      await inFlight;
      expect(await EncryptedMessageCache.loadMessages(42, userId: 1), isEmpty);
      // No provider recreation or lease refresh after the settings action.
      await EncryptedMessageCache.saveMessages(
        42,
        [_message(2, 'after clear')],
        userId: 1,
        expectedAccountGeneration: mountedAccountLease,
      );
      expect(
        (await EncryptedMessageCache.loadMessages(
          42,
          userId: 1,
        )).single.content,
        'after clear',
      );
    },
  );
  test(
    'sender plaintext RAM is bounded without truncating or deleting disk originals',
    () async {
      await EncryptedMessageCache.ensureInitialized();
      final original = List.filled(10000, 'x').join();
      await EncryptedMessageCache.saveSenderPlaintext(
        chatId: 42,
        messageId: 1,
        plaintext: original,
        userId: 1,
      );
      for (
        var id = 2;
        id <= EncryptedMessageCache.senderPlaintextMemoryLimit + 1;
        id++
      ) {
        await EncryptedMessageCache.saveSenderPlaintext(
          chatId: 42,
          messageId: id,
          plaintext: 'fixture $id',
          userId: 1,
        );
      }
      expect(
        EncryptedMessageCache.debugSenderPlaintextCount,
        EncryptedMessageCache.senderPlaintextMemoryLimit,
      );
      // Entry 1 has been evicted from RAM, but its full original stays on disk.
      expect(
        Hive.box<String>('enc_sender_plaintext_v2').length,
        EncryptedMessageCache.senderPlaintextMemoryLimit + 1,
      );
      expect(
        await EncryptedMessageCache.getSenderPlaintext(
          chatId: 42,
          messageId: 1,
          userId: 1,
        ),
        original,
      );
      expect(
        EncryptedMessageCache.debugSenderPlaintextCount,
        EncryptedMessageCache.senderPlaintextMemoryLimit,
      );
    },
  );
  test('plain text cache snapshots do not open the shared media box', () async {
    expect(Hive.isBoxOpen('chat_shared_media_v1'), isFalse);
    await ChatMediaCache.saveMediaMessages(42, [_message(1, 'plain fixture')]);
    expect(Hive.isBoxOpen('chat_shared_media_v1'), isFalse);
  });

  test(
    'account erase fences a media write waiting for storage initialization',
    () async {
      Hive.init(null);
      HiveBootstrap.resetForTesting();
      final pendingDirectory = Completer<String>();
      var pathRequests = 0;
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              pathRequests++;
              return pendingDirectory.future;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final generation = EncryptedMessageCache.accountGeneration(1);
      final writing = ChatMediaCache.saveMediaMessages(
        42,
        [
          _message(
            1,
            'caption',
          ).copyWith(mediaUrl: 'https://fixture.invalid/image'),
        ],
        canWrite: () =>
            generation == EncryptedMessageCache.accountGeneration(1),
      );
      Future<void>? erased;
      try {
        for (var i = 0; i < 30 && pathRequests == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        expect(pathRequests, 1);
        erased = EncryptedMessageCache.clearAccount(1, []);
        expect(EncryptedMessageCache.accountGeneration(1), isNot(generation));
        pendingDirectory.complete(directory.path);
        await Future.wait([writing, erased]);
        expect(ChatMediaCache.getCachedMediaSync(42), isEmpty);
        expect(
          Hive.box<List<dynamic>>('chat_shared_media_v1').get('chat_42'),
          isNull,
        );
      } finally {
        // Assertions must not strand an opening Hive box beyond this fixture.
        if (!pendingDirectory.isCompleted) {
          pendingDirectory.complete(directory.path);
        }
        await writing;
        await erased;
      }
    },
  );
}

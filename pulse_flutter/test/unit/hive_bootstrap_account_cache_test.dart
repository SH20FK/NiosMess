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
      'enc_sender_plaintext_v1',
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
        EncryptedMessageCache.senderPlaintextsForMigration(42, 2),
        isEmpty,
      );
      expect(EncryptedMessageCache.senderPlaintextsForMigration(42, 1), {
        1: 'owned',
      });
      expect(
        EncryptedMessageCache.senderPlaintextsForMigration(
          42,
          1,
          legacyOwnerUserId: 1,
        ),
        {1: 'owned', 2: 'legacy only'},
      );
      await EncryptedMessageCache.clearMigratedSecretChat(42, userId: 1);
      expect(
        EncryptedMessageCache.getSenderPlaintext(chatId: 42, messageId: 2),
        'legacy only',
      );
      await EncryptedMessageCache.clearMigratedSecretChat(
        42,
        userId: 1,
        legacyOwnerUserId: 1,
      );
      expect(
        EncryptedMessageCache.getSenderPlaintext(chatId: 42, messageId: 2),
        isNull,
      );
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
}

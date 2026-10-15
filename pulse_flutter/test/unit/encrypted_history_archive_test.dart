import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/storage/chat_history_anchor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:universal_io/io.dart';

ApiMessage _message(int id, {String? text}) => ApiMessage.fromJson({
  'id': id,
  'chat_id': 71219,
  'sender_id': 1,
  'content': text ?? 'archive $id',
  'msg_type': 'text',
  'sent_at': DateTime.utc(
    2026,
    10,
    15,
  ).add(Duration(seconds: id.abs())).toIso8601String(),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Encrypted active history backing', () {
    late Directory directory;
    late EncryptedHistoryArchive archive;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('niosmess_archive_');
      Hive.init(directory.path);
      HiveBootstrap.resetForTesting();
      FlutterSecureStorage.setMockInitialValues({});
      EncryptedMessageCache.resetMemoryForTesting();
      archive = await EncryptedHistoryArchive.open(71218, 71219);
    });
    tearDown(() async {
      await Hive.close();
      HiveBootstrap.resetForTesting();
      await directory.delete(recursive: true);
    });

    test(
      'lazy disk backing pages both ways without dropping archived bodies',
      () async {
        await archive.write([for (var id = 1; id <= 1200; id++) _message(id)]);
        expect(Hive.lazyBox<String>('enc_history_archive_v1').lazy, isTrue);
        final latest = await archive.read();
        expect(latest.length, 300);
        expect(latest.first.id, 901);
        final older = await archive.read(before: latest.first, limit: 50);
        expect(older.map((m) => m.id), [
          for (var id = 851; id <= 900; id++) id,
        ]);
        final newer = await archive.read(after: older.last, limit: 50);
        expect(newer.first.id, 901);
        expect((await archive.message(12))?.content, 'archive 12');
        await archive.patch(12, (m) => m.copyWith(content: 'off-window edit'));
        await archive.markReadBy(2);
        expect((await archive.message(12))?.content, 'off-window edit');
        expect((await archive.message(12))?.isRead, isTrue);
        await archive.write([], remove: {12});
        expect(await archive.message(12), isNull);
      },
    );

    test(
      'crash orphan rows never appear and scanning still fills the requested page',
      () async {
        final rows = [for (var id = 1; id <= 620; id++) _message(id)];
        await archive.write(rows);
        final box = Hive.lazyBox<String>('enc_history_archive_v1');
        // Simulate a kill after ciphertext put but before identity-pointer commit.
        // There are more orphan records than the requested window size.
        await box.deleteAll([
          for (var id = 301; id <= 620; id++) 'i:71218:71219:$id',
        ]);
        final result = await archive.read(limit: 300);
        expect(result.length, 300);
        expect(result.first.id, 1);
        expect(result.last.id, 300);
        final original = rows[98];
        final oldKey = archive.orderKey(original);
        final oldCiphertext = await box.get(oldKey);
        final moved = original.copyWith(sentAt: DateTime.utc(2026, 10, 16));
        await archive.write([moved]);
        // Simulate kill after the new pointer commit but before deleting old row.
        await box.put(oldKey, oldCiphertext!);
        final afterMove = await archive.read(limit: 400);
        expect(afterMove.where((m) => m.id == 99), hasLength(1));
        expect(afterMove.last.id, 99);
      },
    );

    test(
      'pending-to-confirmed pointer has one visible body at every commit boundary',
      () async {
        const stableId = 'normal:71218:71219:-9';
        final pending = _message(-9, text: 'saved locally').copyWith(
          isSending: true,
          sentAt: DateTime(2026, 10, 15, 17, 55),
          clientMessageId: stableId,
        );
        await archive.write([pending]);
        final box = Hive.lazyBox<String>('enc_history_archive_v1');
        final pendingKey = archive.orderKey(pending);
        final pendingCipher = await box.get(pendingKey);
        final confirmed = _message(
          900,
          text: 'saved locally',
        ).copyWith(clientMessageId: stableId);
        await archive.write([confirmed]);
        expect((await archive.read()).map((m) => m.id), [900]);
        // The pending row/identity may survive interrupted cleanup. The logical
        // pointer chooses one version; replay never exposes a duplicate bubble.
        await box.putAll({
          pendingKey: pendingCipher!,
          'i:71218:71219:-9': pendingKey,
        });
        expect((await archive.read()).map((m) => m.id), [900]);
        expect(await archive.message(-9), isNull);
        await box.put('c:71218:71219:$stableId', pendingKey);
        expect((await archive.read()).map((m) => m.id), [-9]);
        expect(await archive.message(900), isNull);
      },
    );

    test(
      'account erasure fences delayed writes and preserves another account',
      () async {
        final other = await EncryptedHistoryArchive.open(71220, 71219);
        await other.write([_message(1, text: 'other account')]);
        final pending = archive.write([
          for (var id = 1; id <= 400; id++) _message(id),
        ]);
        final rejected = expectLater(pending, throwsStateError);
        await EncryptedMessageCache.clearAccount(71218, []);
        await rejected;
        expect(archive.valid, isFalse);
        final fresh = await EncryptedHistoryArchive.open(71218, 71219);
        expect(await fresh.read(), isEmpty);
        await fresh.write([_message(2, text: 'fresh session')]);
        expect((await fresh.read()).single.content, 'fresh session');
        expect((await other.read()).single.content, 'other account');
      },
    );
    test(
      'scroll bookmarks survive reload encrypted and stay isolated by account',
      () async {
        const anchor = ChatHistoryAnchor(messageId: 754, fraction: 0.623);
        await archive.writeScrollAnchor(anchor);
        final raw = await Hive.lazyBox<String>(
          'enc_history_archive_v1',
        ).get('a:71218:71219');
        expect(raw, isNotNull);
        expect(raw, isNot(contains('message_id')));
        expect(raw, isNot(contains('0.623')));
        await Hive.close();
        Hive.init(directory.path);
        archive = await EncryptedHistoryArchive.open(71218, 71219);
        expect(await archive.readScrollAnchor(), anchor);
        final other = await EncryptedHistoryArchive.open(71220, 71219);
        expect(await other.readScrollAnchor(), isNull);
        await other.writeScrollAnchor(
          const ChatHistoryAnchor(messageId: 123, fraction: 0.1),
        );
        await EncryptedMessageCache.clearAccount(71218, []);
        final fresh = await EncryptedHistoryArchive.open(71218, 71219);
        expect(await fresh.readScrollAnchor(), isNull);
        expect((await other.readScrollAnchor())?.messageId, 123);
        final rejected = fresh.writeScrollAnchor(anchor);
        final check = expectLater(rejected, throwsStateError);
        await EncryptedMessageCache.clearAccount(71218, []);
        await check;
        expect(
          await (await EncryptedHistoryArchive.open(
            71218,
            71219,
          )).readScrollAnchor(),
          isNull,
        );
      },
    );

    test('invalid scroll bookmark cannot hide valid message history', () async {
      await archive.write([_message(5)]);
      await Hive.lazyBox<String>(
        'enc_history_archive_v1',
      ).put('a:71218:71219', 'broken');
      expect(await archive.readScrollAnchor(), isNull);
      expect((await archive.read()).single.id, 5);
      expect(
        ChatHistoryAnchor.fromJson({
          'version': 1,
          'message_id': 5,
          'fraction': double.nan,
        }),
        isNull,
      );
    });
  });
}

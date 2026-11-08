import 'dart:convert';
import 'dart:typed_data';

import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('SqliteWalDurableStore with Bounded Compaction', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nios_sqlite_wal_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('stores operations, confirms ACKs, and survives reopen in WAL mode', () async {
      final store = await SqliteWalDurableStore.open(
        directory: tempDir.path,
        name: 'test_wal_journal',
      );

      final envelope = EncryptedEnvelope(
        context: EnvelopeContext(
          kind: 'operation',
          senderId: 'alice-device',
          recipientId: 'bob-device',
          sessionId: 'session-123',
          operationId: 'op-101',
          sequence: 1,
        ),
        nonce: Uint8List(12),
        ciphertext: Uint8List.fromList(utf8.encode('ciphertext-data')),
        mac: Uint8List(16),
      );

      store.saveOperation(
        operationId: 'op-101',
        sequence: 1,
        peerId: 'bob-device',
        sessionId: 'session-123',
        state: 'enqueued',
        payload: {'action': 'message', 'text': 'Hello WAL!'},
        envelope: envelope,
      );

      expect(store.operationCount, 1);
      expect(store.isOperationRecorded('op-101'), isTrue);

      final fetched = store.getOperation('op-101');
      expect(fetched, isNotNull);
      expect(fetched!['payload']['text'], 'Hello WAL!');
      expect(fetched['state'], 'enqueued');

      // Acknowledge operation
      final ackEnvelope = EncryptedEnvelope(
        context: EnvelopeContext(
          kind: 'ack',
          senderId: 'bob-device',
          recipientId: 'alice-device',
          sessionId: 'session-123',
          operationId: 'op-101',
          sequence: 1,
        ),
        nonce: Uint8List(12),
        ciphertext: Uint8List(16),
        mac: Uint8List(16),
      );
      store.markAcknowledged('op-101', ackEnvelope);

      await store.close();

      // Reopen from disk
      final reopened = await SqliteWalDurableStore.open(
        directory: tempDir.path,
        name: 'test_wal_journal',
      );
      final afterReopen = reopened.getOperation('op-101');
      expect(afterReopen!['state'], 'acknowledged');
      expect(afterReopen['ack'], isNotNull);
      await reopened.close();
    });

    test('compacts acknowledged operations below watermark and prunes disk space', () async {
      final store = await SqliteWalDurableStore.open(
        directory: tempDir.path,
        name: 'test_compaction_journal',
      );

      // Save 50 operations
      for (var seq = 1; seq <= 50; seq++) {
        final opId = 'op-$seq';
        store.saveOperation(
          operationId: opId,
          sequence: seq,
          peerId: 'peer-dev',
          sessionId: 'sess-1',
          state: 'enqueued',
          payload: {'msg': 'Item $seq'},
        );
        // Acknowledge the first 40 operations
        if (seq <= 40) {
          final ack = EncryptedEnvelope(
            context: EnvelopeContext(
              kind: 'ack',
              senderId: 'peer-dev',
              recipientId: 'my-dev',
              sessionId: 'sess-1',
              operationId: opId,
              sequence: seq,
            ),
            nonce: Uint8List(12),
            ciphertext: Uint8List(16),
            mac: Uint8List(16),
          );
          store.markAcknowledged(opId, ack);
        }
      }

      expect(store.operationCount, 50);

      // Perform bounded compaction up to watermark sequence 35
      final checkpoint = store.compact(watermarkSequence: 35);
      expect(checkpoint.compactedCount, 34); // sequences 1..34 pruned
      expect(checkpoint.watermarkSequence, 35);
      expect(checkpoint.stateHash.isNotEmpty, isTrue);

      // Operation count should now be 50 - 34 = 16 operations remaining
      expect(store.operationCount, 16);

      // Pruned operations must no longer exist in operations table
      expect(store.getOperation('op-1'), isNull);
      expect(store.getOperation('op-34'), isNull);

      // But their deduplication entry MUST still exist to prevent replays!
      expect(store.isOperationRecorded('op-1'), isTrue);
      expect(store.isOperationRecorded('op-34'), isTrue);

      // Uncompacted operations remain fully intact
      expect(store.getOperation('op-35'), isNotNull);
      expect(store.getOperation('op-50'), isNotNull);

      // Checkpoint record is retrievable
      final lastCheckpoint = store.getLastCheckpoint();
      expect(lastCheckpoint, isNotNull);
      expect(lastCheckpoint!.watermarkSequence, 35);

      await store.close();
    });
  });
}

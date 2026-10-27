import 'dart:async' show Completer;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/services/encrypted_draft_sync.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class _Local extends DraftStorage {
  _Local() : super.forAccount(7);
  final values = <int, String>{};
  @override
  Future<Map<int, String>> asMap() async => Map.of(values);
  @override
  Future<bool> compareAndSet(int id, String expected, String value) async {
    if ((values[id] ?? '') != expected) return false;
    if (value.isEmpty) {
      values.remove(id);
    } else {
      values[id] = value;
    }
    return true;
  }
}

class _Server {
  final rows = <int, E2eJson>{};
}

class _Crypto extends OrdinaryE2eeService {
  _Crypto(this.server, this.keys, {this.beforeRead}) : super(7, (action, {payload}) async => {});
  final _Server server;
  final OrdinaryKeys keys;
  final Future<void>? beforeRead;
  @override
  Future<List<E2eJson>> encryptedDrafts() async {
    await beforeRead;
    return server.rows.values.map((x) => Map<String, dynamic>.of(x)).toList();
  }
  @override
  Future<String> decryptDraft(E2eJson row) => OrdinaryCodec.openDraft(
    keys,
    row['chat_id'] as int,
    row['packet'] as String,
  );
  @override
  Future<int> putEncryptedDraft(int id, int revision, String text) async {
    if ((server.rows[id]?['revision'] ?? 0) != revision) {
      throw StateError('CAS conflict');
    }
    server.rows[id] = {
      'chat_id': id,
      'epoch': keys.epoch,
      'revision': revision + 1,
      'packet': await OrdinaryCodec.sealDraft(keys, id, text),
    };
    return revision + 1;
  }
}

void main() {
  test(
    'two devices sync encrypted drafts, deletions and preserve concurrent edits',
    () async {
      final server = _Server(), keys = OrdinaryKeys.create(7);
      final a = _Local(), b = _Local();
      final metadataA = <String, String>{}, metadataB = <String, String>{};
      EncryptedDraftSync device(_Local local, Map<String, String> metadata) =>
          EncryptedDraftSync(
            userId: 7,
            storage: local,
            crypto: _Crypto(server, keys),
            readMetadata: (key) async => metadata[key],
            writeMetadata: (key, value) async {
              metadata[key] = value;
            },
          );
      final one = device(a, metadataA), two = device(b, metadataB);
      addTearDown(one.close);
      addTearDown(two.close);
      a.values[10] = 'Первый черновик';
      await one.sync();
      await two.sync();
      expect(b.values[10], 'Первый черновик');
      expect(server.rows[10]!['packet'], isNot(contains('Первый')));
      a.values[10] = 'Изменён на первом';
      b.values[10] = 'Изменён на втором';
      await one.sync();
      await two.sync();
      expect(b.values[10], 'Изменён на втором');
      expect(two.conflicts, contains(10));
      expect(
        await OrdinaryCodec.openDraft(
          keys,
          10,
          server.rows[10]!['packet'] as String,
        ),
        'Изменён на первом',
      );
      final versions = await two.conflictVersions(10);
      final selected = await two.resolveConflict(
        10,
        local: versions.local,
        remote: versions.remote,
        revision: versions.revision,
        keepLocal: false,
      );
      expect(selected, 'Изменён на первом');
      expect(b.values[10], selected);
      expect(two.conflicts, isEmpty);
      a.values.remove(10);
      await one.sync();
      await two.sync();
      expect(b.values.containsKey(10), false);
      expect(metadataA.values.join(), isNot(contains('черновик')));
      // Restart keeps revisions, so deletion cannot resurrect from an old baseline.
      final restarted = device(b, metadataB);
      addTearDown(restarted.close);
      await restarted.sync();
      expect(b.values, isEmpty);
    },
  );

  test(
    'account shutdown prevents pending remote data from writing locally',
    () async {
      final server = _Server(), keys = OrdinaryKeys.create(7);
      final local = _Local(), meta = <String, String>{};
      final pending = Completer<void>();
      await _Crypto(server, keys).putEncryptedDraft(10, 0, 'С другого устройства');
      final service = EncryptedDraftSync(
        userId: 7,
        storage: local,
        crypto: _Crypto(server, keys, beforeRead: pending.future),
        readMetadata: (key) async => meta[key],
        writeMetadata: (key, value) async {
          meta[key] = value;
        },
      );
      final running = service.sync();
      await Future<void>.delayed(Duration.zero);
      var stopped = false;
      final stopping = EncryptedDraftSync.shutdownAccount(7).then((_) { stopped = true; });
      await Future<void>.delayed(Duration.zero);
      expect(stopped, false);
      pending.complete();
      await running;
      await stopping;
      expect(local.values, isEmpty);
      local.values[10] = 'После выхода';
      await service.sync();
      expect(server.rows[10]!['revision'], 1);
      expect(meta, isEmpty);
    },
  );
}

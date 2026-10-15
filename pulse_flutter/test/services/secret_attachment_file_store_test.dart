import 'dart:async';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:pulse_flutter/services/secret_chat/secret_attachment_store.dart';

void main() {
  late Directory root;
  late String accountPath;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('secret-file-store-');
    Hive.init('${root.path}/hive');
    accountPath = '${root.path}/account-1';
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  test(
    'encrypted source survives source deletion and a store restart',
    () async {
      final original = Uint8List.fromList(
        List.generate(180003, (i) => i % 251),
      );
      final source = await File(
        '${root.path}/picker.tmp',
      ).writeAsBytes(original);
      final key = E2eeFileCrypto.generateFileKey();
      var store = await SecretAttachmentStore.open(
        'files',
        directoryPath: accountPath,
      );
      await store.saveFile(
        'message-1',
        (path) => E2eeFileCrypto.encryptFile(
          plainPath: source.path,
          outputPath: path,
          key: key,
        ),
      );
      expect(
        Hive.lazyBox<Uint8List>('files').keys,
        isEmpty,
        reason: 'A downgraded client must never see an empty legacy marker',
      );
      final ciphertextPath = await store.readFile('message-1');
      expect(await File(ciphertextPath).length(), original.length + 28);
      await source.delete();
      await store.close();

      store = await SecretAttachmentStore.open(
        'files',
        directoryPath: accountPath,
      );
      expect(store.ids, ['message-1']);
      final recovered = await store.readFile('message-1');
      expect(recovered, ciphertextPath);
      final output = '${root.path}/recovered.tmp';
      await E2eeFileCrypto.decryptFile(
        encryptedPath: recovered,
        outputPath: output,
        key: key,
      );
      expect(await File(output).readAsBytes(), original);
      await store.close();
    },
  );

  test(
    'legacy payload is materialized on demand and collection removes both copies',
    () async {
      final legacy = await Hive.openBox<Uint8List>('files');
      await legacy.put('legacy-file', Uint8List.fromList([7, 6, 5]));
      await legacy.close();
      final store = await SecretAttachmentStore.open(
        'files',
        directoryPath: accountPath,
      );
      expect(await Directory(accountPath).list().isEmpty, isTrue);
      final path = await store.readFile('legacy-file');
      expect(await File(path).readAsBytes(), [7, 6, 5]);
      expect(
        Hive.lazyBox<Uint8List>('files').containsKey('legacy-file'),
        isTrue,
      );
      expect(await store.retain({'legacy-file'}), isFalse);
      expect(await store.retain({}), isTrue);
      expect(await File(path).exists(), isFalse);
      expect(
        Hive.lazyBox<Uint8List>('files').containsKey('legacy-file'),
        isFalse,
      );
      await store.close();
    },
  );

  test('restart clears only recognized unpublished cipher staging', () async {
    final directory = await Directory(accountPath).create();
    await File('$accountPath/message-1.partial').writeAsBytes([1]);
    await File('$accountPath/message-2.partial.partial').writeAsBytes([2]);
    await File('$accountPath/orphan.enc').writeAsBytes([3]);
    await File('$accountPath/unrelated.txt').writeAsBytes([4]);
    final quarantine = await directory.createTemp('.nios_gcm_');
    await File('${quarantine.path}/payload.partial').writeAsBytes([5]);
    final store = await SecretAttachmentStore.open(
      'files',
      directoryPath: accountPath,
    );
    expect(await File('$accountPath/message-1.partial').exists(), isFalse);
    expect(
      await File('$accountPath/message-2.partial.partial').exists(),
      isFalse,
    );
    expect(await quarantine.exists(), isFalse);
    expect(store.ids, ['orphan']);
    expect(await store.retain({}), isTrue);
    await store.close(erase: true);
    expect(await File('$accountPath/unrelated.txt').readAsBytes(), [4]);
  });

  test(
    'logout waits for an active write and prevents late publication',
    () async {
      final store = await SecretAttachmentStore.open(
        'files',
        directoryPath: accountPath,
      );
      final started = Completer<void>();
      final release = Completer<void>();
      final pending = store.saveFile('in-flight', (path) async {
        await File(path).writeAsBytes([1, 2, 3]);
        started.complete();
        await release.future;
      });
      final failed = expectLater(pending, throwsStateError);
      await started.future;
      var closed = false;
      final closing = store.close(erase: true).then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      release.complete();
      await failed;
      await closing;
      expect(await Directory(accountPath).exists(), isFalse);
      final reopened = await SecretAttachmentStore.open(
        'files',
        directoryPath: accountPath,
      );
      expect(reopened.ids, isEmpty);
      await reopened.close(erase: true);
    },
  );

  test(
    'late account erase leaves the other account and rejects traversal IDs',
    () async {
      final first = await SecretAttachmentStore.open(
        'files',
        directoryPath: accountPath,
      );
      final second = await SecretAttachmentStore.open(
        'other-files',
        directoryPath: '${root.path}/account-2',
      );
      await first.save('queued', Uint8List.fromList([8]));
      await second.save('queued', Uint8List.fromList([9]));
      expect(
        () => first.save('../account-2/queued', Uint8List.fromList([0])),
        throwsArgumentError,
      );
      await first.close();
      expect(await File('$accountPath/queued.enc').exists(), isTrue);
      await first.close(erase: true);
      expect(await Directory(accountPath).exists(), isFalse);
      expect(await second.read('queued'), [9]);
      await second.close(erase: true);
    },
  );
}

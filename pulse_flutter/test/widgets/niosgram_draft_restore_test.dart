import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/core/storage/niosgram_draft_store.dart';
import 'package:universal_io/io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'draft text and encrypted attachment survive closing and reopening Hive',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'niosgram-draft-restart-',
      );
      Hive.init(directory.path);
      HiveBootstrap.resetForTesting();
      FlutterSecureStorage.setMockInitialValues({});
      try {
        final bytes = Uint8List.fromList(
          utf8.encode('synthetic attachment bytes'),
        );
        final store = NiosgramDraftStore(401);
        final file = await store.saveFile('clip.mp4', bytes, durationMs: 3200);
        await store.write(
          NiosgramPostDraft(text: 'Actual stored draft', files: [file]),
        );
        await Hive.close();
        Hive.init(directory.path);
        HiveBootstrap.resetForTesting();
        final restoredStore = NiosgramDraftStore(401);
        final restored = (await restoredStore.read())!;
        expect(restored.text, 'Actual stored draft');
        expect(restored.files.single.durationMs, 3200);
        expect(
          await restoredStore.readFile(restored.files.single),
          orderedEquals(bytes),
        );
      } finally {
        await Hive.close();
        HiveBootstrap.resetForTesting();
        await directory.delete(recursive: true);
      }
    },
  );
}

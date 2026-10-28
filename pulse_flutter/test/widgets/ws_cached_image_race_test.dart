import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/widgets/chat/ws_cached_image.dart';

void main() {
  testWidgets('late local image cannot replace the current image', (
    tester,
  ) async {
    final key = E2eeFileCrypto.generateFileKey();
    final first = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lX8AAAAASUVORK5CYII=',
      ),
    );
    final second = Uint8List.fromList([...first, 1]);
    late Uint8List firstEncrypted;
    late Uint8List secondEncrypted;
    await tester.runAsync(() async {
      firstEncrypted = await E2eeFileCrypto.encrypt(first, key);
      secondEncrypted = await E2eeFileCrypto.encrypt(second, key);
    });
    final oldLoad = Completer<Uint8List>();
    final newLoad = Completer<Uint8List>();
    WsMediaFetcher.secretLocalLoader = (id) =>
        id == 'first' ? oldLoad.future : newLoad.future;
    addTearDown(() {
      WsMediaFetcher.secretLocalLoader = null;
      WsMediaFetcher.clearMemoryCache();
    });

    Widget subject(String id) => ProviderScope(
      overrides: [autoDownloadAllowedProvider.overrideWithValue(false)],
      child: MaterialApp(
        home: WsCachedImage(
          mediaUrl: 'secret-local://$id',
          chatId: 1,
          isE2ee: true,
          e2eeFileKey: base64Encode(key),
          placeholder: (_) => const SizedBox(),
        ),
      ),
    );
    Future<void> waitForCache(String id) async {
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 200; attempt++) {
          if (WsMediaFetcher.getMemoryCachedBytes(
                filePath: 'secret-local://$id',
                e2eeFileKey: key,
              ) !=
              null) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('The $id fixture did not finish decrypting');
      });
    }

    await tester.pumpWidget(subject('first'));
    await tester.pumpWidget(subject('second'));
    newLoad.complete(secondEncrypted);
    await waitForCache('second');
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      ((image.image as ResizeImage).imageProvider as MemoryImage).bytes,
      second,
    );
    oldLoad.complete(firstEncrypted);
    await waitForCache('first');
    await tester.pump();
    final current = tester.widget<Image>(find.byType(Image));
    expect(
      ((current.image as ResizeImage).imageProvider as MemoryImage).bytes,
      second,
    );
  });
}

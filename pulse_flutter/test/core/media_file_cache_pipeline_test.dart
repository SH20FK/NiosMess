import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:universal_io/io.dart';

class _Socket extends Fake implements WebSocketClient {
  var tokenReads = 0;
  var wsRequests = 0;
  @override
  String? Function() get readToken => () {
    tokenReads++;
    return 'test-session';
  };

  @override
  Future<dynamic> request(
    String type, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    wsRequests++;
    throw StateError('WS fallback must not run');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late CacheManager raw;
  late CacheManager playback;
  late _Socket socket;
  late http.Client client;
  late VoidCallback restore;
  var requests = 0;
  late Uint8List payload;
  Future<Directory> Function()? temporaryGate;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nios_media_pipeline_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    raw = CacheManager(
      Config(
        'raw_${directory.path.hashCode}',
        repo: JsonCacheInfoRepository.withFile(
          File('${directory.path}/raw.json'),
        ),
      ),
    );
    playback = CacheManager(
      Config(
        'play_${directory.path.hashCode}',
        repo: JsonCacheInfoRepository.withFile(
          File('${directory.path}/playback.json'),
        ),
      ),
    );
    socket = _Socket();
    payload = Uint8List.fromList(List.generate(256 * 1024, (i) => i % 251));
    requests = 0;
    temporaryGate = null;
    client = MockClient.streaming((request, body) async {
      await body.drain<void>();
      requests++;
      return http.StreamedResponse(
        Stream.fromIterable([
          Uint8List.sublistView(payload, 0, 128 * 1024),
          Uint8List.sublistView(payload, 128 * 1024),
        ]),
        200,
      );
    });
    restore = WsMediaFetcher.debugOverride(
      cacheManager: raw,
      playbackCache: playback,
      httpClient: client,
      temporaryDirectory: () =>
          temporaryGate?.call() ?? Future.value(directory),
    );
  });

  tearDown(() async {
    await WsMediaFetcher.clearPrivateCache();
    restore();
    client.close();
    await raw.dispose();
    await playback.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  test(
    'ordinary media streams to disk and warm playback does no token or network work',
    () async {
      final path = await WsMediaFetcher.fetchToLocalFile(
        filePath: 'video/sample.mp4',
        wsClient: socket,
      );
      expect(await File(path).readAsBytes(), payload);
      expect(requests, 1);
      expect(socket.tokenReads, 1);
      final warm = await WsMediaFetcher.fetchToLocalFile(
        filePath: 'video/sample.mp4',
        wsClient: socket,
      );
      expect(warm, path);
      expect(socket.tokenReads, 1);
      expect(requests, 1);
      expect(socket.wsRequests, 0);
      expect(WsMediaFetcher.currentMemoryBytes, 0);
    },
  );

  test(
    'secret warm playback checks authenticated file before loading ciphertext',
    () async {
      final key = E2eeFileCrypto.generateFileKey();
      final clear = payload;
      payload = await E2eeFileCrypto.encrypt(payload, key);
      final path = await WsMediaFetcher.fetchToLocalFile(
        filePath: 'secret/sample.mp4',
        wsClient: socket,
        e2eeFileKey: key,
      );
      expect(await File(path).readAsBytes(), clear);
      await raw.emptyCache();
      final warm = await WsMediaFetcher.fetchToLocalFile(
        filePath: 'secret/sample.mp4',
        wsClient: socket,
        e2eeFileKey: key,
      );
      expect(warm, path);
      expect(socket.tokenReads, 1);
      expect(requests, 1);
      expect(WsMediaFetcher.currentMemoryBytes, 0);
      expect(
        directory
            .listSync(recursive: true)
            .whereType<Directory>()
            .where(
              (dir) => dir.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('work_'),
            ),
        isEmpty,
      );
    },
  );
  test(
    'logout purges playback and a different key cannot reuse plaintext',
    () async {
      final key = E2eeFileCrypto.generateFileKey();
      payload = await E2eeFileCrypto.encrypt(payload, key);
      final first = await WsMediaFetcher.fetchToLocalFile(
        filePath: 'secret/same.mp4',
        wsClient: socket,
        e2eeFileKey: key,
      );
      await expectLater(
        WsMediaFetcher.fetchToLocalFile(
          filePath: 'secret/same.mp4',
          wsClient: socket,
          e2eeFileKey: E2eeFileCrypto.generateFileKey(),
        ),
        throwsA(anything),
      );
      expect(await File(first).exists(), isTrue);
      await WsMediaFetcher.clearPrivateCache();
      expect(await File(first).exists(), isFalse);
      await WsMediaFetcher.fetchToLocalFile(
        filePath: 'secret/same.mp4',
        wsClient: socket,
        e2eeFileKey: key,
      );
      expect(requests, 2);
    },
  );

  test(
    'account open purges crash quarantine without touching unrelated files',
    () async {
      final orphan = await Directory(
        '${directory.path}/nios_media_staging_v2/crashed-0/work_orphan',
      ).create(recursive: true);
      await File('${orphan.path}/payload.partial').writeAsBytes([1, 2, 3]);
      final legacy = await Directory(
        '${directory.path}/nios_media_legacy_fixture',
      ).create();
      await File('${legacy.path}/authenticated').writeAsBytes([4, 5, 6]);
      final unrelated = await Directory('${directory.path}/keep_me').create();
      await WsMediaFetcher.clearPrivateCache();
      expect(await orphan.exists(), isFalse);
      expect(await legacy.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
    },
  );

  test('a late old cleanup cannot delete a new account publication', () async {
    final entered = Completer<void>();
    final gate = Completer<Directory>();
    var first = true;
    temporaryGate = () {
      if (first) {
        first = false;
        entered.complete();
        return gate.future;
      }
      return Future.value(directory);
    };
    final cleanup = WsMediaFetcher.clearPrivateCache();
    await entered.future;
    final newFile = WsMediaFetcher.fetchToLocalFile(
      filePath: 'new/account.mp4',
      wsClient: socket,
    );
    await Future<void>.delayed(Duration.zero);
    expect(requests, 0, reason: 'New publication waits for old cache cleanup');
    gate.complete(directory);
    await cleanup;
    final path = await newFile;
    expect(await File(path).readAsBytes(), payload);
    expect(requests, 1);
  });
}

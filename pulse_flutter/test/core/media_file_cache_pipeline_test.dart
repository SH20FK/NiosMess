import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late CacheManager publicImages;
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
    publicImages = CacheManager(
      Config(
        'public_${directory.path.hashCode}',
        repo: JsonCacheInfoRepository.withFile(
          File('${directory.path}/public.json'),
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
    await publicImages.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  test(
    'routine cleanup preserves shared images; logout removes them',
    () async {
      expect(
        identical(
          WsMediaFetcher.debugDefaultPrivateCache,
          CachedNetworkImageProvider.defaultCacheManager,
        ),
        isFalse,
      );
      restore();
      restore = WsMediaFetcher.debugOverride(
        cacheManager: raw,
        playbackCache: playback,
        httpClient: client,
        temporaryDirectory: () async => directory,
        sharedImageCache: publicImages,
      );
      const avatar = 'https://fixture.invalid/avatar.png';
      await publicImages.putFile(avatar, Uint8List.fromList([1, 2, 3]));
      await raw.putFile('private', Uint8List.fromList([4, 5, 6]));
      await WsMediaFetcher.clearPrivateCache(clearSharedImages: false);
      expect(await publicImages.getFileFromCache(avatar), isNotNull);
      expect(await raw.getFileFromCache('private'), isNull);
      await WsMediaFetcher.clearPrivateCache();
      expect(await publicImages.getFileFromCache(avatar), isNull);
    },
  );

  test(
    'legacy mixed cache is purged once; new public entries survive',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const oldPrivate = 'ws_media_0:private';
      const avatar = 'https://fixture.invalid/avatar.png';
      await raw.putFile(oldPrivate, Uint8List.fromList([1, 2, 3]));
      await WsMediaFetcher.debugClearLegacySharedCache(prefs, raw);
      expect(await raw.getFileFromCache(oldPrivate), isNull);
      await raw.putFile(avatar, Uint8List.fromList([4, 5, 6]));
      await WsMediaFetcher.debugClearLegacySharedCache(prefs, raw);
      expect(await raw.getFileFromCache(avatar), isNotNull);
    },
  );

  test('disk cache is readable without a token or network request', () async {
    await WsMediaFetcher.fetchAndDecryptMedia(
      filePath: 'image/offline.png',
      wsClient: socket,
    );
    WsMediaFetcher.clearMemoryCache();
    final tokenReads = socket.tokenReads;
    final cached = await WsMediaFetcher.getDiskCachedBytes(
      filePath: 'image/offline.png',
    );
    expect(cached, payload);
    expect(socket.tokenReads, tokenReads);
    expect(requests, 1);
    expect(
      await WsMediaFetcher.getDiskCachedBytes(filePath: 'missing.png'),
      isNull,
    );
    expect(socket.tokenReads, tokenReads);
    expect(requests, 1);
  });

  test('cached secret image is authenticated before display', () async {
    final key = E2eeFileCrypto.generateFileKey();
    final clear = payload;
    payload = await E2eeFileCrypto.encrypt(payload, key);
    await WsMediaFetcher.fetchAndDecryptMedia(
      filePath: 'secret/photo.png',
      wsClient: socket,
      e2eeFileKey: key,
    );
    WsMediaFetcher.clearMemoryCache();
    await expectLater(
      WsMediaFetcher.getDiskCachedBytes(
        filePath: 'secret/photo.png',
        e2eeFileKey: E2eeFileCrypto.generateFileKey(),
      ),
      throwsA(anything),
    );
    expect(
      await WsMediaFetcher.getDiskCachedBytes(
        filePath: 'secret/photo.png',
        e2eeFileKey: key,
      ),
      clear,
    );
    expect(requests, 1);
  });

  test(
    'local secret attachment is readable offline and authenticated',
    () async {
      final key = E2eeFileCrypto.generateFileKey();
      final encrypted = await E2eeFileCrypto.encrypt(payload, key);
      WsMediaFetcher.secretLocalLoader = (id) async {
        expect(id, 'photo');
        return encrypted;
      };
      addTearDown(() => WsMediaFetcher.secretLocalLoader = null);
      await expectLater(
        WsMediaFetcher.getDiskCachedBytes(
          filePath: 'secret-local://photo',
          e2eeFileKey: E2eeFileCrypto.generateFileKey(),
        ),
        throwsA(anything),
      );
      expect(
        await WsMediaFetcher.getDiskCachedBytes(
          filePath: 'secret-local://photo',
          e2eeFileKey: key,
        ),
        payload,
      );
      expect(requests, 0);
      expect(socket.tokenReads, 0);
    },
  );

  test(
    'media downloads are globally bounded and duplicate paths share a request',
    () async {
      final gate = Completer<void>();
      final reachedLimit = Completer<void>();
      var active = 0;
      var peak = 0;
      client.close();
      client = MockClient.streaming((request, body) async {
        await body.drain<void>();
        requests++;
        active++;
        if (active > peak) peak = active;
        if (active == 4 && !reachedLimit.isCompleted) reachedLimit.complete();
        await gate.future;
        active--;
        return http.StreamedResponse(Stream.value(payload), 200);
      });
      restore();
      restore = WsMediaFetcher.debugOverride(
        cacheManager: raw,
        playbackCache: playback,
        httpClient: client,
        temporaryDirectory: () async => directory,
      );
      final jobs = <Future<dynamic>>[
        for (var i = 0; i < 8; i++)
          WsMediaFetcher.fetchAndDecryptMedia(
            filePath: 'photo/$i.png',
            wsClient: socket,
          ),
        WsMediaFetcher.fetchToLocalFile(
          filePath: 'photo/0.png',
          wsClient: socket,
        ),
      ];
      await reachedLimit.future.timeout(const Duration(seconds: 5));
      expect(requests, 4);
      gate.complete();
      await Future.wait(jobs);
      expect(peak, lessThanOrEqualTo(4));
      expect(requests, 8);
    },
  );

  test('queued downloads do not start after account cleanup', () async {
    final gate = Completer<void>();
    final reachedLimit = Completer<void>();
    client.close();
    client = MockClient.streaming((request, body) async {
      await body.drain<void>();
      requests++;
      if (requests == 4) reachedLimit.complete();
      await gate.future;
      return http.StreamedResponse(Stream.value(payload), 200);
    });
    restore();
    restore = WsMediaFetcher.debugOverride(
      cacheManager: raw,
      playbackCache: playback,
      httpClient: client,
      temporaryDirectory: () async => directory,
    );
    final jobs = [
      for (var i = 0; i < 6; i++)
        WsMediaFetcher.fetchAndDecryptMedia(
          filePath: 'queued/$i.png',
          wsClient: socket,
        ).then((_) => false, onError: (Object _) => true),
    ];
    await reachedLimit.future.timeout(const Duration(seconds: 5));
    await WsMediaFetcher.clearPrivateCache();
    gate.complete();
    expect(await Future.wait(jobs), everyElement(isTrue));
    expect(requests, 4);
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

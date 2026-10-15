import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

import '../services/secret_chat_delivery_test.dart' show Hub;

class _Cache extends Fake implements BaseCacheManager {
  @override
  Future<void> emptyCache() async {}
}

class _Repository extends Fake implements ChatRepository {
  final paths = <String>[];
  final byteUploads = <Uint8List?>[];
  final cancellations = <CancellationToken?>[];
  final entered = Completer<void>();
  bool delayUpload = false;
  @override
  Future<String> uploadSecretCiphertext({
    Uint8List? bytes,
    String? filePath,
    required String mediaSubtype,
    required String localId,
    CancellationToken? cancellationToken,
  }) async {
    paths.add(filePath!);
    byteUploads.add(bytes);
    cancellations.add(cancellationToken);
    if (!entered.isCompleted) entered.complete();
    expect(await File(filePath).exists(), isTrue);
    if (delayUpload) {
      final pending = Completer<String>();
      void cancel() {
        if (!pending.isCompleted) {
          pending.completeError(const UploadCancelledException());
        }
      }

      cancellationToken!.addListener(cancel);
      try {
        return await pending.future;
      } finally {
        cancellationToken.removeListener(cancel);
      }
    }
    cancellationToken?.throwIfCancelled();
    return 'upload-$localId';
  }
}

class _Socket extends WebSocketClient {
  _Socket(this.hub, this.user)
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final Hub hub;
  final int user;
  String peerKey = '';
  bool paused = true;
  final connectedEvents = StreamController<void>.broadcast();
  final pushes = StreamController<Map<String, dynamic>>.broadcast();
  final actions = <String>[];
  @override
  bool get isConnected => true;
  @override
  bool get isBackgroundPaused => paused;
  @override
  Stream<void> get onConnected => connectedEvents.stream;
  @override
  Stream<Map<String, dynamic>> get pushStream => pushes.stream;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    actions.add(action);
    if (paused) throw StateError('Background transport must remain idle');
    if (action == 'set_public_key') return <String, dynamic>{};
    return hub.request(user, peerKey, action, payload!);
  }

  Future<void> disposeFixture() async {
    await connectedEvents.close();
    await pushes.close();
    super.close();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  late Hub hub;
  late _Socket socketA;
  late _Socket socketB;
  late _Repository repository;
  late SecretChatCoordinator a;
  late SecretChatCoordinator b;
  late http.Client httpClient;
  late void Function() restoreMedia;
  late int initialWork;
  setUp(() async {
    initialWork = BackgroundService.workCount.value;
    directory = await Directory.systemTemp.createTemp('secret-file-delivery-');
    Hive.init('${directory.path}/hive');
    FlutterSecureStorage.setMockInitialValues({});
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      paths,
      (_) async => directory.path,
    );
    httpClient = MockClient((_) async => http.Response('', 200));
    restoreMedia = WsMediaFetcher.debugOverride(
      cacheManager: _Cache(),
      playbackCache: _Cache(),
      httpClient: httpClient,
      temporaryDirectory: () async => directory,
    );
    hub = Hub();
    socketA = _Socket(hub, 1);
    socketB = _Socket(hub, 2);
    repository = _Repository();
    a = await SecretChatCoordinator.open(1, 'A', socketA, repository);
    b = await SecretChatCoordinator.open(2, 'B', socketB, _Repository());
    socketA.peerKey = b.engine.publicKey;
    socketB.peerKey = a.engine.publicKey;
    await a.engine.open(
      peerId: 2,
      peerName: 'B',
      remoteId: 42,
      peerKey: socketA.peerKey,
    );
    await b.engine.open(
      peerId: 1,
      peerName: 'A',
      remoteId: 42,
      peerKey: socketB.peerKey,
    );
    a.setBackground(true);
    b.setBackground(true);
  });
  tearDown(() async {
    await a.close(erase: true);
    await b.close(erase: true);
    await socketA.disposeFixture();
    await socketB.disposeFixture();
    httpClient.close();
    restoreMedia();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
    await Hive.close();
    await directory.delete(recursive: true);
    expect(BackgroundService.workCount.value, initialWork);
  });

  Future<void> settle([int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await Future.wait([a.tick(), b.tick()]);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  void allowTransport() {
    socketA.paused = false;
    socketB.paused = false;
    a.setTransportAllowed(true);
    b.setTransportAllowed(true);
  }

  test(
    'paused pending file survives source removal and restart, then delivers automatically',
    () async {
      final plain = Uint8List.fromList(List.generate(98307, (i) => i % 251));
      final source = await File(
        '${directory.path}/picker.tmp',
      ).writeAsBytes(plain);
      await a.enqueueAttachmentFile(
        42,
        source.path,
        filename: 'holiday.jpg',
        type: 'image',
        text: 'saved caption',
      );
      final row = a.engine.journal.messageViews(a.engine.findChat(42)!).single;
      final file = secretMap(secretMap(row['body'])['file']);
      final attachmentId = file['attachment_id'] as String;
      final key = Uint8List.fromList(base64Decode(file['key'] as String));
      final cipherPath = await a.readAttachmentFile(attachmentId);
      await source.delete();
      await a.tick();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(socketA.actions, isEmpty);
      expect(a.debugPollingScheduled, isFalse);
      expect(a.engine.journal.hasPendingWork, isTrue);
      expect(a.engine.messages(42).single['content'], 'saved caption');
      socketA.paused = false;
      a.setTransportAllowed(false);
      await a.tick();
      expect(socketA.actions, isEmpty);
      expect(a.debugPollingScheduled, isFalse);
      socketA.paused = true;
      await a.close();

      a = await SecretChatCoordinator.open(1, 'A', socketA, repository);
      a.setBackground(true);
      expect(a.engine.messages(42).single['content'], 'saved caption');
      expect(await a.readAttachmentFile(attachmentId), cipherPath);
      expect(a.engine.journal.hasPendingWork, isTrue);
      allowTransport();
      await settle();
      expect(a.engine.chat(42)['status'], 'secured');
      expect(b.engine.messages(42).single['content'], 'saved caption');
      expect(hub.messages, 1);
      expect(repository.paths, [cipherPath]);
      expect(repository.byteUploads, [null]);
      expect(a.engine.journal.hasPendingWork, isFalse);
      final decoded = '${directory.path}/decoded.tmp';
      await E2eeFileCrypto.decryptFile(
        encryptedPath: cipherPath,
        outputPath: decoded,
        key: key,
      );
      expect(await File(decoded).readAsBytes(), plain);
    },
  );

  test(
    'transport allow wakes a paused secured queue without a manual tick',
    () async {
      allowTransport();
      await settle();
      socketA.paused = true;
      a.setTransportAllowed(false);
      socketA.actions.clear();
      final source = await File(
        '${directory.path}/picker.tmp',
      ).writeAsBytes([7, 8, 9]);
      await a.enqueueAttachmentFile(
        42,
        source.path,
        filename: 'file.bin',
        type: 'file',
      );
      await a.tick();
      expect(socketA.actions, isEmpty);
      expect(repository.paths, isEmpty);
      expect(a.debugPollingScheduled, isFalse);
      socketA.paused = false;
      a.setTransportAllowed(true);
      await repository.entered.future;
      for (var i = 0; i < 100 && hub.messages == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(hub.messages, 1);
    },
  );

  test(
    'logout fences a delayed open and a later login waits for the purge',
    () async {
      await a.engine.enqueue(42, {
        'text': 'retire this history',
        'type': 'text',
      });
      await a.close();
      const secure = FlutterSecureStorage();
      final oldKey = await secure.read(key: 'niosmess.secret.1.v2.key');
      final pathEntered = Completer<void>();
      final pathRelease = Completer<void>();
      var delayOnce = true;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (_) async {
        if (delayOnce) {
          delayOnce = false;
          pathEntered.complete();
          await pathRelease.future;
        }
        return directory.path;
      });
      final opening = SecretChatCoordinator.open(1, 'A', socketA, repository);
      final revoked = expectLater(opening, throwsStateError);
      await pathEntered.future;
      final erasing = SecretChatCoordinator.shutdownAccount(1, erase: true);
      var newLoginReady = false;
      final nextLogin = SecretChatCoordinator.open(1, 'A', socketA, repository)
          .then((value) {
            newLoginReady = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(newLoginReady, isFalse);
      pathRelease.complete();
      await revoked;
      expect(await erasing, [42]);
      a = await nextLogin;
      expect(a.engine.journal.conversations, isEmpty);
      expect(await secure.read(key: 'niosmess.secret.1.v2.key'), isNot(oldKey));
      expect(socketA.actions, isEmpty);
    },
  );

  test(
    'logout cancels pending upload before deleting ciphertext and journal',
    () async {
      allowTransport();
      await settle();
      expect(a.engine.chat(42)['status'], 'secured');
      repository.delayUpload = true;
      final source = await File(
        '${directory.path}/picker.tmp',
      ).writeAsBytes(List.filled(65537, 22));
      await a.enqueueAttachmentFile(
        42,
        source.path,
        filename: 'voice.ogg',
        type: 'voice',
      );
      await repository.entered.future;
      final path = repository.paths.single;
      expect(BackgroundService.workCount.value, greaterThan(initialWork));
      expect(await File(path).exists(), isTrue);
      await a.close(erase: true);
      expect(repository.cancellations.single!.isCancelled, isTrue);
      expect(await File(path).exists(), isFalse);
      expect(hub.messages, 0);
      expect(BackgroundService.workCount.value, initialWork);
      expect(b.engine.chat(42)['status'], 'secured');
      a = await SecretChatCoordinator.open(1, 'A', socketA, repository);
      expect(a.engine.journal.conversations, isEmpty);
    },
  );
}

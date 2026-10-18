import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nios_sdk/link.dart';
import 'package:nios_sdk/stream.dart';
import 'package:path/path.dart' as p;
import 'package:pulse_flutter/services/protocol/nios_protocol_accounts.dart';
import 'package:pulse_flutter/services/secret_chat/secret_stream_service.dart';
import 'package:universal_io/io.dart';

class _Secrets implements ProtocolSecretStore {
  final Map<String, String> values = {};
  Completer<void>? reading;
  Completer<void>? resume;
  @override
  Future<String?> read(String name) async {
    reading?.complete();
    await resume?.future;
    return values[name];
  }

  @override
  Future<void> write(String name, String value) async {
    values[name] = value;
  }

  @override
  Future<void> delete(String name) async {
    values.remove(name);
  }
}

// These account lifecycle tests intentionally use real loopback services.
// HttpOverrides' default implementation bypasses the widget binding's fake 400.
class _RealHttp extends HttpOverrides {}

class _Route implements LinkTransport {
  bool closed = false;
  int deliveries = 0;
  Future<void> Function()? beforeDelivery;
  @override
  Future<TransportReceipt> deliver(EncryptedEnvelope envelope) async {
    if (closed) throw StateError('closed');
    await beforeDelivery?.call();
    deliveries++;
    return const TransportReceipt(mailboxStored: true);
  }

  @override
  Future<void> publishAcknowledgement(
    EncryptedEnvelope acknowledgement,
  ) async {}
  @override
  Future<List<EncryptedEnvelope>> poll(String deviceId) async => [];
  @override
  Future<void> confirmReceived(EncryptedEnvelope envelope) async {}
  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpOverrides? previousHttp;
  setUp(() {
    previousHttp = HttpOverrides.current;
    HttpOverrides.global = _RealHttp();
  });
  tearDown(() {
    HttpOverrides.global = previousHttp;
  });

  test(
    'bound streaming owner drains gateway and pending export before account erasure',
    () async {
      final root = await Directory.systemTemp.createTemp('nios-bound-stream-');
      final secrets = _Secrets();
      final accounts = NiosProtocolAccounts(
        secrets: secrets,
        directory: () async => root,
      );
      final account = await accounts.openAccount('alice');
      await accounts.openAccount('bob');
      final service = SecretStreamService(
        accountId: 1,
        origin: Uri.parse('https://fixture.invalid'),
        token: () => 'fixture',
        directory: () async => account.directory,
        ensureRegistered: () async {},
      );
      account.bindResource(service.close);
      final entered = Completer<void>();
      final release = Completer<void>();
      String? exportPath;
      try {
        final input = await File(
          p.join(root.path, 'video'),
        ).writeAsBytes(List.filled(1024 * 1024 + 9, 19));
        final file = await service.prepareFile(
          inputPath: input.path,
          filename: 'video.mp4',
          mimeType: 'video/mp4',
          subtype: 'media',
        );
        final player = await service.openPlayback(file);
        final exporting = service.withExport(file, (path) async {
          exportPath = path;
          entered.complete();
          await release.future;
        });
        final rejected = expectLater(
          exporting,
          throwsA(isA<StreamCancelledException>()),
        );
        await entered.future;
        await accounts
            .shutdownAccount('alice', erase: true)
            .timeout(const Duration(seconds: 5));
        await rejected;
        expect(await File(exportPath!).exists(), isFalse);
        expect(await account.directory.exists(), isFalse);
        expect(secrets.values.length, 1);
        await player.close();
      } finally {
        release.complete();
        await service.close();
        await accounts.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'account manager is lazy and logout fences an unfinished key-store read',
    () async {
      final temp = await Directory.systemTemp.createTemp('nios-account-race-');
      final secrets = _Secrets()
        ..reading = Completer<void>()
        ..resume = Completer<void>();
      var directoryReads = 0;
      final accounts = NiosProtocolAccounts(
        secrets: secrets,
        directory: () async {
          directoryReads++;
          return temp;
        },
      );
      expect(directoryReads, 0);
      final opening = accounts.openAccount('alice');
      final rejected = expectLater(opening, throwsStateError);
      await secrets.reading!.future;
      final stopped = accounts.shutdownAccount('alice', erase: true);
      secrets.resume!.complete();
      await rejected;
      await stopped;
      expect(secrets.values, isEmpty);
      expect(
        await Directory(
          p.join(temp.path, 'nios_protocol'),
        ).list().where((entry) => entry is Directory).isEmpty,
        isTrue,
      );
      await accounts.close();
      await temp.delete(recursive: true);
    },
  );

  test(
    'unsealed text and encrypted attachment survive reopen before keys arrive',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'nios-account-restart-',
      );
      final secrets = _Secrets();
      NiosProtocolAccounts manager() =>
          NiosProtocolAccounts(secrets: secrets, directory: () async => temp);
      var accounts = manager();
      try {
        var alice = await accounts.openAccount('alice');
        final deviceId = alice.deviceId;
        Future<DurableSession> configure(NiosProtocolAccount account) =>
            account.startDelivery(
              negotiatedVersion: 1,
              cipher: AesGcmEnvelopeCipher(
                deviceId: account.deviceId,
                keyForPeer: (_) async => throw StateError('peer_key_pending'),
              ),
              transports: (_, _) async => [],
              reducer: (previous, _) => previous,
            );
        var session = await configure(alice);
        final message = await alice.enqueue(
          peerDeviceId: 'bob',
          sessionId: 'chat',
          payload: {'text': 'important'},
        );
        expect(message.isPrepared, isFalse);
        final input = await File(
          p.join(temp.path, 'source'),
        ).writeAsBytes(List.generate(20000, (i) => i % 251));
        final attachment = await alice.enqueueAttachment(
          inputPath: input.path,
          peerDeviceId: 'bob',
          sessionId: 'chat',
          caption: 'caption',
        );
        final payload = session.savedPayload(attachment.operationId)!;
        final orphan = await Directory(
          p.join(alice.directory.path, 'attachments', 'f' * 32),
        ).create();
        await File(p.join(orphan.path, 'content.nsc')).writeAsBytes([7]);
        final cipherFile = File(
          p.join(
            alice.directory.path,
            'attachments',
            attachment.operationId,
            'content.nsc',
          ),
        );
        expect(await cipherFile.exists(), isTrue);
        expect(
          await cipherFile.readAsBytes(),
          isNot(await input.readAsBytes()),
        );
        await accounts.shutdownAccount('alice', erase: false);
        await accounts.close();
        accounts = manager();
        alice = await accounts.openAccount('alice');
        expect(alice.deviceId, deviceId);
        session = await configure(alice);
        expect(session.savedPayload(message.operationId), {
          'text': 'important',
        });
        expect(session.savedPayload(attachment.operationId), payload);
        expect(await orphan.exists(), isFalse);
        expect(await cipherFile.exists(), isTrue);
        expect(session.operation(message.operationId)!.isPrepared, isFalse);
      } finally {
        await accounts.close();
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'a missing wrapping key preserves existing history and never creates a replacement',
    () async {
      final temp = await Directory.systemTemp.createTemp('nios-key-loss-');
      final secrets = _Secrets();
      final accounts = NiosProtocolAccounts(
        secrets: secrets,
        directory: () async => temp,
      );
      try {
        final account = await accounts.openAccount('alice');
        await account.startDelivery(
          negotiatedVersion: 1,
          cipher: AesGcmEnvelopeCipher(
            deviceId: account.deviceId,
            keyForPeer: (_) async => throw StateError('pending'),
          ),
          transports: (_, _) async => [],
          reducer: (previous, _) => previous,
        );
        await account.enqueue(
          peerDeviceId: 'bob',
          sessionId: 'chat',
          payload: {'text': 'preserve'},
        );
        await accounts.shutdownAccount('alice', erase: false);
        final journals = await account.directory
            .list(recursive: true)
            .where((entry) => entry is File && entry.path.endsWith('.hive'))
            .cast<File>()
            .toList();
        expect(journals, isNotEmpty);
        final before = await journals.single.readAsBytes();
        secrets.values.clear();
        await expectLater(accounts.openAccount('alice'), throwsStateError);
        expect(secrets.values, isEmpty);
        expect(await journals.single.readAsBytes(), before);
      } finally {
        await accounts.close();
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'blob is durably published before the message, logout closes player and only its own account',
    () async {
      final temp = await Directory.systemTemp.createTemp('nios-account-media-');
      final secrets = _Secrets();
      final accounts = NiosProtocolAccounts(
        secrets: secrets,
        directory: () async => temp,
      );
      final server = await CiphertextBlobServer.bind(
        directory: p.join(temp.path, 'server'),
        bearerToken: 'test-token',
      );
      final httpClient = http.Client();
      try {
        final alice = await accounts.openAccount('alice');
        final bob = await accounts.openAccount('bob');
        final route = _Route();
        final blobs = HttpCiphertextBlobStore(
          baseUri: server.baseUri,
          bearerToken: 'test-token',
          allowInsecureLoopback: true,
        );
        final delivery = await alice.startDelivery(
          negotiatedVersion: 1,
          cipher: AesGcmEnvelopeCipher(
            deviceId: alice.deviceId,
            keyForPeer: (_) async => SecretKey(List.filled(32, 7)),
          ),
          transports: (_, _) async => [route],
          reducer: (previous, _) => previous,
          blobs: blobs,
        );
        final bytes = List.generate(20000, (i) => i % 251);
        final input = await File(
          p.join(temp.path, 'source'),
        ).writeAsBytes(bytes);
        final saved = await alice.enqueueAttachment(
          inputPath: input.path,
          peerDeviceId: 'bob',
          sessionId: 'chat',
        );
        final payload = delivery.savedPayload(saved.operationId)!;
        final manifest = NiosStreamManifest.fromJson(
          Map<String, Object?>.from(payload['manifest'] as Map),
          expectedHash: payload['manifestHash'] as String,
        );
        route.beforeDelivery = () async {
          final response = await httpClient.head(
            server.baseUri.resolve('/v1/blobs/${manifest.hash}'),
            headers: {'authorization': 'Bearer test-token'},
          );
          expect(response.statusCode, 200);
        };
        await delivery.pump();
        expect(route.deliveries, greaterThanOrEqualTo(1));
        final download = await alice.openAttachment(
          payload: payload,
          sources: [blobs.sourceFor(manifest)],
        );
        final gateway = await alice.openMedia(
          download: download,
          mimeType: 'video/mp4',
        );
        final response = await httpClient.get(
          gateway.uri,
          headers: {'range': 'bytes=100-299'},
        );
        expect(response.statusCode, 206);
        expect(response.bodyBytes, bytes.sublist(100, 300));
        await accounts.shutdownAccount('alice', erase: true);
        expect(route.closed, isTrue);
        expect(await alice.directory.exists(), isFalse);
        expect(await bob.directory.exists(), isTrue);
        expect(secrets.values.length, 1);
        await expectLater(
          httpClient.get(gateway.uri),
          throwsA(isA<http.ClientException>()),
        );
        expect(
          () => alice.enqueue(
            peerDeviceId: 'bob',
            sessionId: 'chat',
            payload: {},
          ),
          throwsStateError,
        );
      } finally {
        httpClient.close();
        await accounts.close();
        await server.close();
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'logout closes a transport created during an unfinished start',
    () async {
      final temp = await Directory.systemTemp.createTemp('nios-start-race-');
      final accounts = NiosProtocolAccounts(
        secrets: _Secrets(),
        directory: () async => temp,
      );
      final account = await accounts.openAccount('alice');
      final started = Completer<void>();
      final release = Completer<void>();
      final route = _Route();
      final opening = account.startDelivery(
        negotiatedVersion: 1,
        cipher: AesGcmEnvelopeCipher(
          deviceId: account.deviceId,
          keyForPeer: (_) async => SecretKey(List.filled(32, 1)),
        ),
        transports: (_, _) async {
          started.complete();
          await release.future;
          return [route];
        },
        reducer: (previous, _) => previous,
      );
      final rejected = expectLater(opening, throwsStateError);
      await started.future;
      final stopped = accounts.shutdownAccount('alice', erase: true);
      release.complete();
      await rejected;
      await stopped;
      expect(route.closed, isTrue);
      expect(route.deliveries, 0);
      await accounts.close();
      await temp.delete(recursive: true);
    },
  );
}

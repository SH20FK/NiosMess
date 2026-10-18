import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nios_sdk/stream.dart';
import 'package:path/path.dart' as p;
import 'package:pulse_flutter/services/secret_chat/secret_stream_service.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  late HttpOverrides? previousHttp;
  setUp(() {
    previousHttp = HttpOverrides.current;
    HttpOverrides.global = _RealHttp();
  });
  tearDown(() {
    HttpOverrides.global = previousHttp;
  });
  test(
    'secret video uses authenticated ranges, shares leases and resumes ciphertext',
    () async {
      final root = await Directory.systemTemp.createTemp('nios-secret-stream-');
      final server = await CiphertextBlobServer.bind(
        directory: p.join(root.path, 'server'),
        bearerToken: 'fixture-token',
      );
      var registrations = 0;
      final grants = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer fixture-token');
        if (request.url.path == '/v1/protocols') {
          return http.Response(
            jsonEncode({
              'stream': [1],
            }),
            200,
          );
        }
        expect(request.method, 'POST');
        expect(
          request.url.path,
          matches(RegExp(r'^/v1/blobs/[a-f0-9]{64}/grants$')),
        );
        grants.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{}', 200);
      });
      SecretStreamService service(String account) => SecretStreamService(
        accountId: account == 'alice' ? 1 : 2,
        origin: server.baseUri,
        token: () => 'fixture-token',
        directory: () async => Directory(p.join(root.path, account)),
        ensureRegistered: () async {
          registrations++;
        },
        allowInsecureLoopback: true,
        client: client,
      );
      final sender = service('alice');
      final receiver = service('bob');
      final bytes = Uint8List.fromList(
        List.generate(4 * 1024 * 1024 + 31, (i) => (i * 37 + 11) & 255),
      );
      final input = await File(
        p.join(root.path, 'fixture.mp4'),
      ).writeAsBytes(bytes);
      final player = http.Client();
      try {
        expect(await sender.isSupported(), isTrue);
        final file = await sender.prepareFile(
          inputPath: input.path,
          filename: 'private-title.mp4',
          mimeType: 'video/mp4',
          subtype: 'media',
        );
        final descriptor = SecretStreamDescriptor.fromFile(file);
        expect(descriptor.manifest.segmentCount, 5);
        final upload = await sender.upload(file, chatId: 42);
        expect(upload, 'nios-stream:${descriptor.manifest.hash}');
        expect(grants.single, {'chat_id': 42});
        expect(grants.single.containsKey('key'), isFalse);
        expect(grants.single.containsKey('name'), isFalse);
        final first = await receiver.openPlayback(file);
        final second = await receiver.openPlayback(file);
        final response = await player.get(
          first.uri!,
          headers: {'range': 'bytes=10-99'},
        );
        expect(response.statusCode, 206);
        expect(
          response.headers['content-range'],
          'bytes 10-99/${bytes.length}',
        );
        expect(response.headers['content-type'], startsWith('video/mp4'));
        expect(response.bodyBytes, bytes.sublist(10, 100));
        final bitmapFile = File(
          p.join(
            root.path,
            'bob',
            'secret_stream',
            'downloads',
            descriptor.manifest.hash,
            'download.json',
          ),
        );
        final bitmap = base64Decode(
          (jsonDecode(await bitmapFile.readAsString()) as Map)['verified']
              as String,
        );
        expect(
          bitmap.single,
          1,
          reason: 'Playback fetched one segment, not the entire movie',
        );
        await first.close();
        final remaining = await player.get(
          second.uri!,
          headers: {'range': 'bytes=-10'},
        );
        expect(remaining.statusCode, 206);
        expect(remaining.bodyBytes, bytes.sublist(bytes.length - 10));
        await second.close();
        await server.close();
        final resumed = await receiver.openPlayback(file);
        final offline = await player.get(
          resumed.uri!,
          headers: {'range': 'bytes=10-99'},
        );
        expect(offline.bodyBytes, bytes.sublist(10, 100));
        await resumed.close();
        expect(registrations, greaterThanOrEqualTo(3));
        descriptor.dispose();
        await receiver.close();
        final localFiles = await Directory(
          p.join(root.path, 'bob'),
        ).list(recursive: true).where((f) => f is File).toList();
        expect(
          localFiles.map((f) => p.basename(f.path)),
          containsAll(['content.nsc', 'manifest.json', 'download.json']),
        );
        expect(localFiles.any((f) => f.path.endsWith('.mp4')), isFalse);
        for (final entity in localFiles.whereType<File>()) {
          expect(
            (await entity.readAsBytes()).length < bytes.length ||
                p.basename(entity.path) == 'content.nsc',
            isTrue,
          );
        }
      } finally {
        player.close();
        await sender.close();
        await receiver.close();
        await server.close();
        client.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'unknown peer/service capability keeps legacy compatibility and wrong key fails closed',
    () async {
      final root = await Directory.systemTemp.createTemp('nios-stream-guard-');
      final service = SecretStreamService(
        accountId: 1,
        origin: Uri.parse('https://fixture.invalid'),
        token: () => 'fixture',
        directory: () async => root,
        ensureRegistered: () async {},
        client: MockClient((_) async => http.Response('{}', 404)),
      );
      try {
        expect(await service.isSupported(), isFalse);
        final input = await File(
          p.join(root.path, 'input'),
        ).writeAsBytes([1, 2, 3, 4]);
        final file = await service.prepareFile(
          inputPath: input.path,
          filename: 'input.bin',
          mimeType: 'application/octet-stream',
          subtype: 'media',
        );
        expect(await service.readBytes(file), [1, 2, 3, 4]);
        final wrong = {...file, 'key': base64Encode(List.filled(32, 0))};
        await expectLater(
          service.readBytes(wrong),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        expect(
          () => SecretStreamDescriptor.fromFile({...file, 'size': 99}),
          throwsFormatException,
        );
        await service.close();
        expect(() => service.openPlayback(file), throwsStateError);
      } finally {
        await service.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'cold offline receiver plays verified cache without enrollment and retries missing ranges after reconnect',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'nios-stream-offline-receiver-',
      );
      final server = await CiphertextBlobServer.bind(
        directory: p.join(root.path, 'server'),
        bearerToken: 'fixture-token',
      );
      final grantClient = MockClient((_) async => http.Response('{}', 200));
      final sender = SecretStreamService(
        accountId: 1,
        origin: server.baseUri,
        token: () => 'fixture-token',
        directory: () async => Directory(p.join(root.path, 'alice')),
        ensureRegistered: () async {},
        allowInsecureLoopback: true,
        client: grantClient,
      );
      var enrollmentAttempts = 0;
      var offline = false;
      SecretStreamService newReceiver() => SecretStreamService(
        accountId: 2,
        origin: server.baseUri,
        token: () => 'fixture-token',
        directory: () async => Directory(p.join(root.path, 'bob')),
        ensureRegistered: () async {
          enrollmentAttempts++;
          if (offline) throw const SocketException('offline');
        },
        allowInsecureLoopback: true,
      );
      var receiver = newReceiver();
      final player = http.Client();
      try {
        final bytes = Uint8List.fromList(
          List.generate(2 * 1024 * 1024 + 31, (i) => (i * 19 + 3) & 255),
        );
        final input = await File(
          p.join(root.path, 'source.mp4'),
        ).writeAsBytes(bytes);
        final file = await sender.prepareFile(
          inputPath: input.path,
          filename: 'video.mp4',
          mimeType: 'video/mp4',
          subtype: 'media',
        );
        await sender.upload(file, chatId: 42);
        final first = await receiver.openPlayback(file);
        expect(enrollmentAttempts, 0);
        expect(
          (await player.get(
            first.uri!,
            headers: {'range': 'bytes=10-99'},
          )).bodyBytes,
          bytes.sublist(10, 100),
        );
        expect(enrollmentAttempts, 1);
        await first.close();
        await receiver.close();

        // Recreate the service: a real enrollment helper has no in-memory
        // registration cache after process restart and would now fail offline.
        offline = true;
        enrollmentAttempts = 0;
        receiver = newReceiver();
        final resumed = await receiver.openPlayback(file);
        expect(enrollmentAttempts, 0);
        expect(
          (await player.get(
            resumed.uri!,
            headers: {'range': 'bytes=10-99'},
          )).bodyBytes,
          bytes.sublist(10, 100),
        );
        expect(enrollmentAttempts, 0);
        await expectLater(
          receiver.readBytes(file),
          throwsA(isA<StreamSourceException>()),
        );
        expect(enrollmentAttempts, 1);
        expect(
          (await player.get(
            resumed.uri!,
            headers: {'range': 'bytes=10-99'},
          )).bodyBytes,
          bytes.sublist(10, 100),
        );
        expect(
          enrollmentAttempts,
          1,
          reason:
              'An unavailable missing segment cannot invalidate verified data',
        );

        offline = false;
        expect(
          (await player.get(
            resumed.uri!,
            headers: {'range': 'bytes=-20'},
          )).bodyBytes,
          bytes.sublist(bytes.length - 20),
        );
        expect(
          enrollmentAttempts,
          2,
          reason: 'Failed enrollment must be retried after reconnect',
        );
        await resumed.close();
      } finally {
        player.close();
        await sender.close();
        await receiver.close();
        await server.close();
        grantClient.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'explicit export stays bounded and logout cancels a pending consumer and removes plaintext',
    () async {
      final root = await Directory.systemTemp.createTemp('nios-stream-export-');
      final service = SecretStreamService(
        accountId: 1,
        origin: Uri.parse('https://fixture.invalid'),
        token: () => 'fixture',
        directory: () async => root,
        ensureRegistered: () async {},
      );
      final input = await File(
        p.join(root.path, 'input'),
      ).writeAsBytes(List.generate(1024 * 1024 + 29, (i) => i & 255));
      final entered = Completer<void>();
      final release = Completer<void>();
      String? temporary;
      try {
        final file = await service.prepareFile(
          inputPath: input.path,
          filename: 'report.bin',
          mimeType: 'application/octet-stream',
          subtype: 'media',
        );
        await expectLater(
          service.readBytes(file, maximumBytes: 32),
          throwsStateError,
        );
        final exporting = service.withExport(file, (path) async {
          temporary = path;
          expect(await File(path).length(), await input.length());
          expect(await File(path).readAsBytes(), await input.readAsBytes());
          entered.complete();
          await release.future;
        });
        final rejected = expectLater(
          exporting,
          throwsA(isA<StreamCancelledException>()),
        );
        await entered.future;
        await service.close().timeout(const Duration(seconds: 5));
        await rejected;
        expect(await File(temporary!).exists(), isFalse);
      } finally {
        if (!release.isCompleted) release.complete();
        await service.close();
        await root.delete(recursive: true);
      }
    },
  );
}

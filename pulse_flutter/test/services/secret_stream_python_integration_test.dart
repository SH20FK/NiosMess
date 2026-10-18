import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pulse_flutter/services/protocol/nios_protocol_accounts.dart';
import 'package:pulse_flutter/services/protocol/nios_protocol_enrollment.dart';
import 'package:pulse_flutter/services/secret_chat/secret_stream_service.dart';
import 'package:universal_io/io.dart';

class _Secrets implements ProtocolSecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async {
    values[name] = value;
  }

  @override
  Future<void> delete(String name) async {
    values.remove(name);
  }
}

class _RealHttp extends HttpOverrides {}

final class _Fixture {
  _Fixture(this.process, this.origin, this.stdout, this.stderr);
  final Process process;
  final Uri origin;
  final StreamSubscription<String> stdout;
  final StreamSubscription<String> stderr;
  Future<void> close() async {
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 10));
    await stdout.cancel();
    await stderr.cancel();
  }

  static Future<_Fixture> start(String python, Directory data) async {
    final script = p.normalize(
      p.join(
        Directory.current.path,
        '..',
        'backend_changes',
        'protocol_v1',
        'tests',
        'serve_stream_fixture.py',
      ),
    );
    final process = await Process.start(python, [script, '--root', data.path]);
    final ready = Completer<Uri>();
    final errors = StringBuffer();
    final stderr = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (errors.length < 4096) errors.writeln(line);
        });
    final stdout = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          try {
            final value = jsonDecode(line) as Map;
            if (!ready.isCompleted && value['origin'] is String) {
              ready.complete(Uri.parse(value['origin'] as String));
            }
          } on FormatException {
            /* uvicorn may print a startup message. */
          }
        });
    unawaited(
      process.exitCode.then((code) {
        if (!ready.isCompleted) {
          ready.completeError(
            StateError('Python fixture exited $code: $errors'),
          );
        }
      }),
    );
    try {
      return _Fixture(
        process,
        await ready.future.timeout(const Duration(seconds: 30)),
        stdout,
        stderr,
      );
    } catch (_) {
      process.kill();
      await stdout.cancel();
      await stderr.cancel();
      rethrow;
    }
  }
}

void main() {
  final python = Platform.environment['NIOS_PROTOCOL_TEST_PYTHON'];
  test(
    'Flutter enrollment and stream interoperate with the actual Python server across restart',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = _RealHttp();
      final root = await Directory.systemTemp.createTemp('nios-python-stream-');
      final secrets = _Secrets();
      final accounts = NiosProtocolAccounts(
        secrets: secrets,
        directory: () async => Directory(p.join(root.path, 'client')),
      );
      _Fixture? fixture;
      SecretStreamService? sender;
      SecretStreamService? receiver;
      final player = http.Client();
      try {
        fixture = await _Fixture.start(
          python!,
          Directory(p.join(root.path, 'server')),
        );
        NiosProtocolEnrollment enrollment() =>
            NiosProtocolEnrollment(accounts: accounts, origin: fixture!.origin);
        var registrar = enrollment();
        String legacy(int id) =>
            base64Encode(List.filled(32, id == 101 ? 11 : 22));
        String token(int id) => id == 101 ? 'alice-fixture' : 'bob-fixture';
        Future<void> enroll(int id) => registrar.ensureRegistered(
          accountId: id,
          legacyPublicKey: legacy(id),
          bearerToken: token(id),
        );
        SecretStreamService stream(int id) => SecretStreamService(
          accountId: id,
          origin: fixture!.origin,
          token: () => token(id),
          directory: () async => (await accounts.openAccount('$id')).directory,
          ensureRegistered: () => enroll(id),
          allowInsecureLoopback: true,
        );
        sender = stream(101);
        expect(await sender.isSupported(), isTrue);
        final bytes = Uint8List.fromList(
          List.generate(4 * 1024 * 1024 + 55, (i) => (i * 19 + 7) & 255),
        );
        final input = await File(
          p.join(root.path, 'source.mp4'),
        ).writeAsBytes(bytes);
        final file = await sender.prepareFile(
          inputPath: input.path,
          filename: 'private-video-title.mp4',
          mimeType: 'video/mp4',
          subtype: 'media',
        );
        final descriptor = SecretStreamDescriptor.fromFile(file);
        // Upload succeeded, but no eligible recipient exists yet. A retry must
        // preserve the prepared bytes and consume no second blob reservation.
        await expectLater(sender.upload(file, chatId: 77), throwsStateError);
        await enroll(202);
        expect(
          await sender.upload(file, chatId: 77),
          'nios-stream:${descriptor.manifest.hash}',
        );
        receiver = stream(202);
        final source = await receiver.openPlayback(file);
        final head = await player.get(
          source.uri!,
          headers: {'range': 'bytes=20-199'},
        );
        expect(head.statusCode, 206);
        expect(head.bodyBytes, bytes.sublist(20, 200));
        final tail = await player.get(
          source.uri!,
          headers: {'range': 'bytes=-25'},
        );
        expect(tail.bodyBytes, bytes.sublist(bytes.length - 25));
        final statsUri = fixture.origin.resolve('/fixture/stats');
        final stats =
            jsonDecode(
                  (await player.get(
                    statsUri,
                    headers: {'authorization': 'Bearer alice-fixture'},
                  )).body,
                )
                as Map;
        expect(stats, {'devices': 2, 'blobs': 1, 'grants': 1, 'ranges': 2});
        await source.close();
        await receiver.close();
        await sender.close();
        await fixture.close();
        fixture = await _Fixture.start(
          python,
          Directory(p.join(root.path, 'server')),
        );
        registrar = enrollment();
        sender = stream(101);
        receiver = stream(202);
        expect(
          await sender.upload(file, chatId: 77),
          'nios-stream:${descriptor.manifest.hash}',
        );
        final resumed = await receiver.openPlayback(file);
        final cached = await player.get(
          resumed.uri!,
          headers: {'range': 'bytes=20-199'},
        );
        expect(cached.bodyBytes, bytes.sublist(20, 200));
        final restartedStats =
            jsonDecode(
                  (await player.get(
                    fixture.origin.resolve('/fixture/stats'),
                    headers: {'authorization': 'Bearer bob-fixture'},
                  )).body,
                )
                as Map;
        expect(restartedStats, {
          'devices': 2,
          'blobs': 1,
          'grants': 1,
          'ranges': 0,
        });
        await resumed.close();
        await receiver.close();
        final receiverPath = (await accounts.openAccount('202')).directory.path;
        await accounts.shutdownAccount('202', erase: true);
        expect(await Directory(receiverPath).exists(), isFalse);
        expect(secrets.values.length, 1);
        descriptor.dispose();
      } finally {
        player.close();
        await sender?.close();
        await receiver?.close();
        await accounts.close();
        await fixture?.close();
        HttpOverrides.global = previous;
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: python == null
        ? 'Set NIOS_PROTOCOL_TEST_PYTHON to an interpreter with protocol_v1 requirements-test.txt.'
        : false,
  );
}

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:nios_sdk/distributed.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  test(
    'absolute deadline aborts a trickling body and close preserves an injected client',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        try {
          if (request.uri.path == '/health') {
            request.response.write('ok');
          } else {
            for (var i = 0; i < 100; i++) {
              request.response.write(' ');
              await request.response.flush();
              await Future<void>.delayed(const Duration(milliseconds: 15));
            }
          }
        } catch (_) {
          /* The timed-out client aborts the socket. */
        } finally {
          try {
            await request.response.close();
          } catch (_) {}
        }
      });
      final client = http.Client();
      final origin = Uri.parse('http://127.0.0.1:${server.port}');
      final node = HttpShardNode(
        id: 'node',
        failureDomain: 'site',
        origin: origin,
        token: 'test',
        client: client,
        timeout: const Duration(milliseconds: 100),
      );
      try {
        final manifest = DistributedManifest(
          objectId: 'a' * 32,
          ciphertextHash: 'b' * 64,
          ciphertextLength: 1,
          blockSize: 32,
          roots: List.filled(5, 'c' * 64),
        );
        final watch = Stopwatch()..start();
        await expectLater(
          node.get(manifest, 0, 0),
          throwsA(anyOf(isA<TimeoutException>(), isA<http.ClientException>())),
        );
        expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
        node.close();
        expect((await client.get(origin.resolve('/health'))).body, 'ok');
      } finally {
        node.close();
        client.close();
        await server.close(force: true);
      }
    },
  );
  test(
    'five authenticated HTTP nodes store, restart, recover, repair and delete',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-http-shards-',
      );
      final servers = <ShardNodeServer>[];
      final clients = <HttpShardNode>[];
      try {
        for (var i = 0; i < 5; i++) {
          final node = DirectoryShardNode(
            id: 'node-$i',
            failureDomain: 'site-$i',
            directory: p.join(directory.path, 'node-$i'),
          );
          final server = await ShardNodeServer.bind(
            node: node,
            token: 'test-$i',
          );
          servers.add(server);
          clients.add(
            HttpShardNode(
              id: node.id,
              failureDomain: node.failureDomain,
              origin: server.origin,
              token: 'test-$i',
              timeout: const Duration(seconds: 2),
            ),
          );
        }
        final input = File(p.join(directory.path, 'ciphertext'));
        final bytes = List.generate(29001, (i) => i % 251);
        await input.writeAsBytes(bytes);
        final store = DistributedStore(
          nodes: clients,
          spoolDirectory: p.join(directory.path, 'spool'),
        );
        final result = await store.putCiphertext(input.path, blockSize: 4096);
        final wrong = HttpShardNode(
          id: 'node-0',
          failureDomain: 'site-0',
          origin: servers[0].origin,
          token: 'wrong',
        );
        await expectLater(wrong.get(result.manifest, 0, 0), throwsStateError);
        wrong.close();
        // A process restart loses the server's in-memory manifest cache.
        final old = servers[2];
        final port = old.port;
        await old.close();
        servers[2] = await ShardNodeServer.bind(
          node: old.node,
          token: 'test-2',
          port: port,
        );
        final recovered = await store.recoverCiphertext(
          result.manifest,
          p.join(directory.path, 'recovered'),
        );
        expect(await recovered.readAsBytes(), bytes);
        await servers[0].close();
        await servers[1].close();
        final degraded = await store.recoverCiphertext(
          result.manifest,
          p.join(directory.path, 'degraded'),
        );
        expect(await degraded.readAsBytes(), bytes);
        // Bring nodes back to exercise distributed deletion too.
        for (var i = 0; i < 2; i++) {
          servers[i] = await ShardNodeServer.bind(
            node: servers[i].node,
            token: 'test-$i',
            port: servers[i].port,
          );
        }
        await store.delete(result.manifest);
        await expectLater(
          clients[2].get(result.manifest, 2, 0),
          throwsStateError,
        );
      } finally {
        for (final client in clients) {
          client.close();
        }
        for (final server in servers) {
          await server.close();
        }
        if (!p.basename(directory.path).startsWith('nios-http-shards-')) {
          throw StateError('Wrong test directory');
        }
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'non-loopback HTTP and header injection cannot receive storage credentials',
    () {
      expect(
        () => HttpShardNode(
          id: 'n',
          failureDomain: 'f',
          origin: Uri.parse('http://example.com'),
          token: 'secret',
        ),
        throwsArgumentError,
      );
      expect(
        () => HttpShardNode(
          id: 'n',
          failureDomain: 'f',
          origin: Uri.parse('https://example.com'),
          token: 'secret\r\nInjected: value',
        ),
        throwsArgumentError,
      );
    },
  );
}

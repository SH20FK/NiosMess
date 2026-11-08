import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/worker/headless_worker_client.dart';
import 'package:universal_io/io.dart';

void main() {
  group('Headless Background Core Isolate Architecture', () {
    late HeadlessWorkerClient client;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nios_worker_test_');
      client = HeadlessWorkerClient();
      await client.init();
    });

    tearDown(() async {
      await client.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('handshakes and responds to ping from background isolate core', () async {
      expect(client.isRunning, isTrue);
      final pong = await client.ping();
      expect(pong, isTrue);
    });

    test('encrypts payload in background core using AES-256-GCM', () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
      final nonce = Uint8List.fromList(List.generate(12, (i) => i + 1));
      final plaintext = Uint8List.fromList(utf8.encode('Top-secret payload for Core 2'));

      final ciphertext = await client.encryptPayload(
        key: key,
        nonce: nonce,
        bytes: plaintext,
        aad: 'nios-aad-ctx',
      );

      expect(ciphertext.length, plaintext.length + 16);
      expect(ciphertext, isNot(equals(plaintext)));
    });

    test('decrypts batch of incoming messages concurrently in background core', () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i + 5));
      final nonce1 = Uint8List.fromList(List.generate(12, (i) => i + 10));
      final nonce2 = Uint8List.fromList(List.generate(12, (i) => i + 20));

      final c1 = await client.encryptPayload(
        key: key,
        nonce: nonce1,
        bytes: Uint8List.fromList(utf8.encode('Message one')),
      );
      final c2 = await client.encryptPayload(
        key: key,
        nonce: nonce2,
        bytes: Uint8List.fromList(utf8.encode('Message two')),
      );

      final batch = [
        {
          'id': 'msg-1',
          'key': base64Encode(key),
          'nonce': base64Encode(nonce1),
          'ciphertext': base64Encode(c1),
        },
        {
          'id': 'msg-2',
          'key': base64Encode(key),
          'nonce': base64Encode(nonce2),
          'ciphertext': base64Encode(c2),
        },
      ];

      final decrypted = await client.decryptBatch(batch);
      expect(decrypted.length, 2);
      expect(decrypted[0]['id'], 'msg-1');
      expect(decrypted[0]['text'], 'Message one');
      expect(decrypted[1]['id'], 'msg-2');
      expect(decrypted[1]['text'], 'Message two');
    });

    test('hashes media stream chunks without blocking UI thread', () async {
      final largeBytes = Uint8List.fromList(List.generate(65536, (i) => i % 256));
      final hash = await client.hashMedia(largeBytes);
      expect(hash.length, 64);
    });

    test('initializes isolated SQLite WAL database and executes checkpoints', () async {
      final dbPath = '${tempDir.path}/worker_wal.db';
      await client.initStorage(dbPath);
      expect(File(dbPath).existsSync(), isTrue);

      await client.walCheckpoint();
    });

    test('performs background search across message history', () async {
      final messages = [
        {'id': 1, 'content': 'Where are the keys?'},
        {'id': 2, 'content': 'Launch the rocket now'},
        {'id': 3, 'content': 'No keys found'},
      ];

      final results = await client.searchMessages('keys', messages);
      expect(results.length, 2);
      expect(results[0]['id'], 1);
      expect(results[1]['id'], 3);
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';
import 'package:nios_sdk/link.dart';
import 'package:universal_io/io.dart';

import 'worker_protocol.dart';

/// Top-level entry point executed when spawning the dedicated Headless Core Isolate.
///
/// Runs on a separate CPU core, completely decoupled from Flutter's UI and Raster threads.
void niosHeadlessCoreEntryPoint(SendPort uiPort) {
  final commandPort = ReceivePort();
  uiPort.send(commandPort.sendPort);

  final worker = _HeadlessCoreWorker(uiPort);

  commandPort.listen((message) async {
    if (message is WorkerRequest) {
      await worker.handleRequest(message);
    } else if (message is Map<String, dynamic>) {
      // Allow map-based envelope dispatch
      final actionStr = message['action'] as String?;
      final action = WorkerAction.values.firstWhere(
        (a) => a.name == actionStr,
        orElse: () => WorkerAction.ping,
      );
      final req = WorkerRequest(
        id: message['id'] as int? ?? 0,
        action: action,
        payload: Map<String, dynamic>.from(message['payload'] as Map? ?? {}),
        transferableBytes: message['bytes'] as TransferableTypedData?,
      );
      await worker.handleRequest(req);
    }
  });
}

final class _HeadlessCoreWorker {
  final SendPort _uiPort;
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Chacha20 _chacha20 = Chacha20.poly1305Aead();
  SqliteWalDurableStore? _store;

  _HeadlessCoreWorker(this._uiPort);

  Future<void> handleRequest(WorkerRequest req) async {
    try {
      switch (req.action) {
        case WorkerAction.ping:
          _uiPort.send(
            WorkerResponse.ok(
              req.id,
              data: {
                'pong': true,
                'workerTime': DateTime.now().millisecondsSinceEpoch,
              },
            ),
          );

        case WorkerAction.initStorage:
          final dbPath = req.payload['path'] as String?;
          if (dbPath != null) {
            await _store?.close();
            final file = File(dbPath);
            _store = await SqliteWalDurableStore.open(
              directory: file.parent.path,
              name: file.uri.pathSegments.last.replaceAll('.db', ''),
            );
          }
          _uiPort.send(WorkerResponse.ok(req.id, data: {'initialized': true}));

        case WorkerAction.encryptPayload:
          final keyBytes = base64Decode(req.payload['key'] as String);
          final nonceBytes = base64Decode(req.payload['nonce'] as String);
          final aadStr = req.payload['aad'] as String?;
          final aadBytes = aadStr != null ? utf8.encode(aadStr) : <int>[];
          final rawBytes = req.transferableBytes?.materialize().asUint8List() ??
              utf8.encode(req.payload['text'] as String? ?? '');

          final algorithmName = req.payload['algorithm'] as String? ?? 'A256GCM';
          final Cipher cipher = algorithmName == 'CHACHA20_POLY1305'
              ? _chacha20
              : _aesGcm;

          final secretBox = await cipher.encrypt(
            rawBytes,
            secretKey: SecretKey(keyBytes),
            nonce: nonceBytes,
            aad: aadBytes,
          );

          final combined = Uint8List(secretBox.cipherText.length + 16)
            ..setRange(0, secretBox.cipherText.length, secretBox.cipherText)
            ..setRange(
              secretBox.cipherText.length,
              secretBox.cipherText.length + 16,
              secretBox.mac.bytes,
            );

          _uiPort.send(
            WorkerResponse.ok(
              req.id,
              data: {'length': combined.length},
              bytes: TransferableTypedData.fromList([combined]),
            ),
          );

        case WorkerAction.decryptPayloadBatch:
          final items = req.payload['items'] as List<dynamic>? ?? [];
          final results = <Map<String, dynamic>>[];

          for (final item in items) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final keyBytes = base64Decode(map['key'] as String);
            final nonceBytes = base64Decode(map['nonce'] as String);
            final cipherBytes = base64Decode(map['ciphertext'] as String);
            final aadStr = map['aad'] as String?;
            final aadBytes = aadStr != null ? utf8.encode(aadStr) : <int>[];

            if (cipherBytes.length < 16) {
              results.add({'id': map['id'], 'error': 'invalid_ciphertext_len'});
              continue;
            }

            final split = cipherBytes.length - 16;
            final cipherText = cipherBytes.sublist(0, split);
            final macBytes = cipherBytes.sublist(split);

            try {
              final plain = await _aesGcm.decrypt(
                SecretBox(
                  cipherText,
                  nonce: nonceBytes,
                  mac: Mac(macBytes),
                ),
                secretKey: SecretKey(keyBytes),
                aad: aadBytes,
              );
              results.add({
                'id': map['id'],
                'text': utf8.decode(plain),
              });
            } catch (_) {
              results.add({'id': map['id'], 'error': 'decrypt_failed'});
            }
          }

          _uiPort.send(WorkerResponse.ok(req.id, data: {'items': results}));

        case WorkerAction.hashMediaStream:
          final rawBytes = req.transferableBytes?.materialize().asUint8List() ??
              Uint8List(0);
          final sha256Hash = digest.sha256.convert(rawBytes).toString();
          _uiPort.send(
            WorkerResponse.ok(
              req.id,
              data: {
                'sha256': sha256Hash,
                'bytesCount': rawBytes.length,
              },
            ),
          );

        case WorkerAction.searchHistory:
          final query = (req.payload['query'] as String? ?? '').toLowerCase();
          final messages = req.payload['messages'] as List<dynamic>? ?? [];
          final matches = <dynamic>[];

          for (final msg in messages) {
            if (msg is Map) {
              final content = (msg['content'] as String? ?? '').toLowerCase();
              if (content.contains(query)) {
                matches.add(msg);
              }
            }
          }
          _uiPort.send(
            WorkerResponse.ok(
              req.id,
              data: {'matches': matches, 'query': query},
            ),
          );

        case WorkerAction.walCheckpoint:
          if (_store != null) {
            _store!.compact(watermarkSequence: 1 << 30);
          }
          _uiPort.send(
            WorkerResponse.ok(req.id, data: {'checkpointComplete': true}),
          );

        case WorkerAction.shutdown:
          await _store?.close();
          _store = null;
          _uiPort.send(WorkerResponse.ok(req.id, data: {'terminated': true}));
      }
    } catch (e, stack) {
      _uiPort.send(WorkerResponse.fail(req.id, '$e\n$stack'));
    }
  }
}

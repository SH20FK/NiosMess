import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/api.dart' show InvalidCipherTextException;
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/utils/e2ee_streaming_file_cipher.dart';

/// Client-side encryption for media files in E2EE (secret) chats.
///
/// Files are encrypted before upload and decrypted after download with a
/// random per-file AES-256-GCM key. The key travels only inside the
/// Double-Ratchet-encrypted message envelope, never in the clear.
///
/// Blob layout on the server: `[nonce 12B][ciphertext|tag]`.
class E2eeFileCrypto {
  const E2eeFileCrypto._();

  static const int nonceBytes = 12;
  static const int macBytes = 16;
  static const int _maxConcurrentWorkers = 2;
  static int _activeWorkers = 0;
  static final List<Completer<void>> _workerWaiters = <Completer<void>>[];
  static const _workerThreshold = 256 * 1024;
  static const _nativeWorkers =
      !bool.fromEnvironment('dart.library.js_interop') &&
      !bool.fromEnvironment('dart.library.html');

  static Future<void> _acquireWorkerSlot() async {
    while (_activeWorkers >= _maxConcurrentWorkers) {
      final c = Completer<void>();
      _workerWaiters.add(c);
      await c.future;
    }
    _activeWorkers++;
  }

  static void _releaseWorkerSlot() {
    if (_activeWorkers > 0) _activeWorkers--;
    if (_workerWaiters.isNotEmpty) {
      _workerWaiters.removeAt(0).complete();
    }
  }

  static Future<T> _inWorker<T>(Future<T> Function() work) async {
    await _acquireWorkerSlot();
    try {
      return await Isolate.run(work);
    } finally {
      _releaseWorkerSlot();
    }
  }

  /// Preserve the existing GCM envelope with bounded 64 KiB file I/O in one
  /// worker. The final player path is published only after full authentication.
  /// >=512 MiB uses the correct legacy implementation because the pinned
  /// streaming library cannot represent that GCM length correctly.
  static Future<void> decryptFile({
    required String encryptedPath,
    required String outputPath,
    required Uint8List key,
  }) async {
    await _inWorker(() => _decryptFileWorker(encryptedPath, outputPath, key));
  }

  static Future<void> _decryptFileWorker(
    String encryptedPath,
    String outputPath,
    Uint8List key,
  ) async {
    if (await File(outputPath).exists()) {
      throw StateError('E2EE destination exists');
    }
    final length = await File(encryptedPath).length();
    if (E2eeStreamingFileCipher.supportsEnvelopeLength(length)) {
      try {
        await E2eeStreamingFileCipher.decrypt(
          encryptedPath: encryptedPath,
          outputPath: outputPath,
          key: key,
        );
      } on InvalidCipherTextException {
        throw SecretBoxAuthenticationError();
      }
      return;
    }
    final temporary = File('$outputPath.partial');
    try {
      final blob = await File(encryptedPath).readAsBytes();
      final plain = await _decrypt(blob, key);
      try {
        await temporary.writeAsBytes(plain, flush: true);
      } finally {
        plain.fillRange(0, plain.length, 0);
      }
      if (await File(outputPath).exists()) {
        throw StateError('E2EE destination exists');
      }
      await temporary.rename(outputPath);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  /// Encrypts an existing native file without materializing it in a byte array.
  /// [iv] exists for interoperability tests; callers must never reuse a nonce
  /// with the same key. Omitting it always generates a fresh secure nonce.
  static Future<void> encryptFile({
    required String plainPath,
    required String outputPath,
    required Uint8List key,
    Uint8List? iv,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (onProgress == null || !_nativeWorkers) {
      if (_nativeWorkers) {
        await _inWorker(() => _encryptFileWorker(plainPath, outputPath, key, iv));
      } else {
        await _encryptFileWorker(
          plainPath,
          outputPath,
          key,
          iv,
          onProgress: onProgress,
        );
      }
      return;
    }

    await _acquireWorkerSlot();
    final port = ReceivePort();
    final completer = Completer<void>();
    final keyCopy = Uint8List.fromList(key);
    final ivCopy = iv != null ? Uint8List.fromList(iv) : null;
    try {
      port.listen((dynamic message) {
        if (message is List) {
          if (message.isNotEmpty && message[0] == 'done') {
            if (!completer.isCompleted) completer.complete();
          } else if (message.length >= 2 && message[0] == 'error') {
            if (!completer.isCompleted) {
              completer.completeError(StateError('${message[1]}'));
            }
          } else if (message.length >= 2 &&
              message[0] is int &&
              message[1] is int) {
            onProgress(message[0] as int, message[1] as int);
          }
        }
      });
      await Isolate.spawn(
        _encryptIsolateEntry,
        (plainPath, outputPath, keyCopy, ivCopy, port.sendPort),
        onError: port.sendPort,
        errorsAreFatal: true,
      );
      await completer.future;
    } finally {
      port.close();
      _releaseWorkerSlot();
    }
  }

  static Future<void> _encryptIsolateEntry(
    (String, String, Uint8List, Uint8List?, SendPort) args,
  ) async {
    final (plainPath, outputPath, key, iv, sendPort) = args;
    int lastSent = -1;
    try {
      await _encryptFileWorker(
        plainPath,
        outputPath,
        key,
        iv,
        onProgress: (processed, total) {
          if (processed == total || lastSent < 0 || processed - lastSent >= 524288) {
            lastSent = processed;
            sendPort.send(<Object>[processed, total]);
          }
        },
      );
      sendPort.send(const <Object>['done']);
    } catch (e) {
      sendPort.send(<Object>['error', e.toString()]);
    }
  }

  static Future<void> _encryptFileWorker(
    String plainPath,
    String outputPath,
    Uint8List key,
    Uint8List? iv, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (await File(outputPath).exists()) {
      throw StateError('E2EE destination exists');
    }
    final random = Random.secure();
    final nonce =
        iv ??
        Uint8List.fromList(
          List<int>.generate(nonceBytes, (_) => random.nextInt(256)),
        );
    if (nonce.length != nonceBytes || key.length != 32) {
      throw ArgumentError('Invalid E2EE file key or nonce length');
    }
    final length = await File(plainPath).length();
    if (!E2eeStreamingFileCipher.supportsPlaintextLength(length)) {
      // Refuse instead of materializing a >=512MiB file in memory (OOM on
      // phones). Decryption keeps a legacy path so old oversized envelopes
      // stay readable.
      throw StateError('E2EE_FILE_TOO_LARGE');
    }
    await E2eeStreamingFileCipher.encrypt(
      plainPath: plainPath,
      outputPath: outputPath,
      key: key,
      nonce: nonce,
      onProgress: onProgress,
    );
  }

  /// Generates a fresh 256-bit file key.
  static Uint8List generateFileKey() {
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  static Future<Uint8List> encrypt(Uint8List plain, Uint8List key) async {
    if (_nativeWorkers && plain.length >= _workerThreshold) {
      return _inWorker(() => _encrypt(plain, key));
    }
    return _encrypt(plain, key);
  }

  static Future<Uint8List> _encrypt(Uint8List plain, Uint8List key) async {
    final SecretBox box = await AesGcm.with256bits().encrypt(
      plain,
      secretKey: SecretKey(key),
    );
    final Uint8List out = Uint8List(
      nonceBytes + box.cipherText.length + box.mac.bytes.length,
    );
    out.setRange(0, nonceBytes, box.nonce);
    out.setRange(
      nonceBytes,
      nonceBytes + box.cipherText.length,
      box.cipherText,
    );
    out.setRange(nonceBytes + box.cipherText.length, out.length, box.mac.bytes);
    return out;
  }

  static Future<Uint8List> decrypt(
    Uint8List blob,
    Uint8List key, {
    Uint8List? iv,
  }) async {
    if (_nativeWorkers && blob.length >= _workerThreshold) {
      return _inWorker(() => _decrypt(blob, key, iv: iv));
    }
    return _decrypt(blob, key, iv: iv);
  }

  static Future<Uint8List> _decrypt(
    Uint8List blob,
    Uint8List key, {
    Uint8List? iv,
  }) async {
    if (iv != null && iv.length == nonceBytes) {
      if (blob.length < macBytes) {
        throw const FormatException('E2EE file blob too short');
      }
      final Uint8List ct = Uint8List.sublistView(
        blob,
        0,
        blob.length - macBytes,
      );
      final Uint8List mac = Uint8List.sublistView(blob, blob.length - macBytes);
      final List<int> clear = await AesGcm.with256bits().decrypt(
        SecretBox(ct, nonce: iv, mac: Mac(mac)),
        secretKey: SecretKey(key),
      );
      return Uint8List.fromList(clear);
    }

    if (blob.length < nonceBytes + macBytes) {
      throw const FormatException('E2EE file blob too short');
    }
    final Uint8List nonce = Uint8List.sublistView(blob, 0, nonceBytes);
    final Uint8List ct = Uint8List.sublistView(
      blob,
      nonceBytes,
      blob.length - macBytes,
    );
    final Uint8List mac = Uint8List.sublistView(blob, blob.length - macBytes);
    final List<int> clear = await AesGcm.with256bits().decrypt(
      SecretBox(ct, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(clear);
  }
}

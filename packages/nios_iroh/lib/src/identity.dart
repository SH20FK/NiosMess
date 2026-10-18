import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:iroh_quic/iroh_quic.dart' as iroh;
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// Persisted Iroh identity, encrypted under an account-owned wrapping key. The
/// caller stores that key in the OS credential store, never alongside this file.
abstract final class IrohIdentityStore {
  static final Map<String, Future<void>> _pending = {};
  static Future<iroh.SecretKey> loadOrCreate({
    required String directory,
    required String accountId,
    required crypto.SecretKey wrappingKey,
  }) async {
    if (accountId.isEmpty || accountId.length > 1024) {
      throw ArgumentError('Invalid identity account');
    }
    await iroh.Iroh.init();
    final root = await Directory(directory).create(recursive: true);
    final canonicalDirectory = await root.resolveSymbolicLinks();
    final name = digest.sha256.convert(utf8.encode(accountId)).toString();
    final file = File(p.join(canonicalDirectory, '$name.iroh-identity'));
    // OS advisory locks may be process-scoped on Unix. Serialize callers in
    // this isolate as well, while still authenticating each call's own key.
    final previous = _pending[file.path] ?? Future<void>.value();
    final loading = previous.then(
      (_) => _loadOrCreate(file, accountId, wrappingKey),
    );
    final tail = loading.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending[file.path] = tail;
    try {
      return await loading;
    } finally {
      if (identical(_pending[file.path], tail)) _pending.remove(file.path);
    }
  }

  static Future<iroh.SecretKey> _loadOrCreate(
    File file,
    String accountId,
    crypto.SecretKey wrappingKey,
  ) async {
    final lock = await File('${file.path}.lock').open(mode: FileMode.append);
    var acquired = false;
    try {
      await lock.lock(FileLock.exclusive);
      acquired = true;
      final aad = utf8.encode(
        jsonEncode(['NiosLink/IrohIdentity', 1, accountId]),
      );
      final cipher = crypto.AesGcm.with256bits();
      if (await file.exists()) {
        if (await file.length() != 60) {
          throw const FormatException('Invalid encrypted Iroh identity');
        }
        final bytes = await file.readAsBytes();
        final key = await cipher.decrypt(
          crypto.SecretBox(
            bytes.sublist(12, 44),
            nonce: bytes.sublist(0, 12),
            mac: crypto.Mac(bytes.sublist(44)),
          ),
          secretKey: wrappingKey,
          aad: aad,
        );
        try {
          return iroh.SecretKey.fromBytes(key);
        } finally {
          key.fillRange(0, key.length, 0);
        }
      }
      final identity = iroh.SecretKey.generate();
      final raw = identity.toBytes();
      try {
        final encrypted = await cipher.encrypt(
          raw,
          secretKey: wrappingKey,
          aad: aad,
        );
        final temporary = File(
          '${file.path}.${Random.secure().nextInt(1 << 32)}.partial',
        );
        try {
          await temporary.writeAsBytes([
            ...encrypted.nonce,
            ...encrypted.cipherText,
            ...encrypted.mac.bytes,
          ], flush: true);
          await temporary.rename(file.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      } finally {
        raw.fillRange(0, raw.length, 0);
      }
      return identity;
    } finally {
      if (acquired) await lock.unlock();
      await lock.close();
    }
  }
}

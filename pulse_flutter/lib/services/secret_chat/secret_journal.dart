import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';

typedef SecretJson = Map<String, dynamic>;

SecretJson secretMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};

SecretJson secretCopy(SecretJson value) =>
    secretMap(jsonDecode(jsonEncode(value)));

/// Injectable durable append log. A successful append includes a disk flush.
abstract interface class SecretJournalBackend {
  Iterable<String> get records;
  Future<void> append(String encryptedRecord);
  Future<void> compact(String encryptedSnapshot);
  Future<void> erase();
  Future<void> close();
}

class HiveSecretJournalBackend implements SecretJournalBackend {
  HiveSecretJournalBackend(this.box);
  final Box<String> box;

  @override
  Iterable<String> get records => box.values;

  @override
  Future<void> append(String encryptedRecord) async {
    await box.add(encryptedRecord);
    await box.flush();
  }

  @override
  Future<void> compact(String encryptedSnapshot) async {
    final id = await box.add(encryptedSnapshot);
    await box.flush(); // The checkpoint is recoverable before removing its log.
    await box.deleteAll(
      box.keys.where((key) => key is int && key < id).toList(),
    );
    await box.flush();
    await box.compact();
  }

  @override
  Future<void> erase() async {
    await box.clear();
    await box.flush();
  }

  @override
  Future<void> close() => box.close();
}

/// A transaction contains the new ratchet state AND its message/cursor changes.
/// No network side effect is allowed until commit completes. Indexes are only
/// projections: after a crash they are rebuilt from authenticated records.
class SecretJournal {
  SecretJournal(this.backend, this.key, {required this.accountId});

  final SecretJournalBackend backend;
  final SecretKey key;
  final int accountId;
  final AesGcm _aes = AesGcm.with256bits();
  final Map<String, SecretJson> _states = {};
  final Map<String, Map<String, SecretJson>> _messages = {};
  Future<void> _tail = Future<void>.value();
  bool _closed = false;
  bool _failed = false;
  int _sequence = 0;

  Iterable<String> get conversations => _states.keys.toList(growable: false);
  SecretJson state(String chat) => secretCopy(_states[chat] ?? {});
  List<SecretJson> messages(String chat) =>
      (_messages[chat]?.values ?? <SecretJson>[]).map(secretCopy).toList();

  List<int> _aad(int sequence) =>
      utf8.encode('NiosMess/secret-journal/1/$accountId/$sequence');

  Future<void> restore() async {
    final records = backend.records.toList();
    final checkpoint = records.lastIndexWhere(
      (record) => record.startsWith('snapshot:'),
    );
    for (final encoded in records.skip(checkpoint < 0 ? 0 : checkpoint)) {
      final snapshot = encoded.startsWith('snapshot:');
      if (snapshot) _sequence = 0;
      final packed = base64Decode(snapshot ? encoded.substring(9) : encoded);
      final box = SecretBox.fromConcatenation(
        packed,
        nonceLength: 12,
        macLength: 16,
      );
      final bytes = await _aes.decrypt(
        box,
        secretKey: key,
        aad: _aad(_sequence),
      );
      final tx = secretMap(jsonDecode(utf8.decode(bytes)));
      if (snapshot) {
        _states.clear();
        _messages.clear();
        for (final raw in tx['conversations'] as List) {
          _apply(secretMap(raw));
        }
      } else {
        _apply(tx);
      }
      _sequence++;
    }
  }

  void _apply(SecretJson tx) {
    final chat = tx['chat'] as String;
    if (tx['erase'] == true) {
      _states.remove(chat);
      _messages.remove(chat);
      return;
    }
    _states[chat] = secretMap(tx['state']);
    final rows = _messages.putIfAbsent(chat, () => {});
    for (final entry in secretMap(tx['messages']).entries) {
      rows[entry.key] = secretMap(entry.value);
    }
    for (final id in (tx['remove'] as List? ?? const [])) {
      rows.remove(id);
    }
  }

  Future<void> commit(
    String chat,
    SecretJson state, {
    Map<String, SecretJson> messages = const {},
    List<String> remove = const [],
    bool erase = false,
  }) {
    // Copy before yielding: a caller must not change an in-flight transaction.
    final tx = secretCopy({
      'chat': chat,
      'state': state,
      'messages': messages,
      'remove': remove,
      'erase': erase,
    });
    final result = _tail.then((_) async {
      if (_closed || _failed) throw StateError('Secret journal is unavailable');
      try {
        final encrypted = await _aes.encrypt(
          utf8.encode(jsonEncode(tx)),
          secretKey: key,
          aad: _aad(_sequence),
        );
        await backend.append(base64Encode(encrypted.concatenation()));
        _apply(tx);
        _sequence++;
        if (_sequence >= 128 ||
            remove.isNotEmpty ||
            messages.values.any(
              (row) => secretMap(row['message'])['is_deleted'] == true,
            )) {
          try {
            final snapshot = {
              'conversations': [
                for (final chat in _states.keys)
                  {
                    'chat': chat,
                    'state': _states[chat],
                    'messages': _messages[chat],
                  },
              ],
            };
            final encryptedSnapshot = await _aes.encrypt(
              utf8.encode(jsonEncode(snapshot)),
              secretKey: key,
              aad: _aad(0),
            );
            await backend.compact(
              'snapshot:${base64Encode(encryptedSnapshot.concatenation())}',
            );
            _sequence = 1;
          } catch (_) {
            // The transaction was accepted. A failed checkpoint requires replay
            // before the next mutation, but must not turn acceptance into loss.
            _failed = true;
          }
        }
      } catch (_) {
        // A failed flush may still have reached disk. Stop, then recover by
        // replay on next open; never advance a possibly divergent ratchet.
        _failed = true;
        rethrow;
      }
    });
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace trace) {},
    );
    return result;
  }

  Future<void> close({bool erase = false}) async {
    _closed = true;
    await _tail;
    if (erase) await backend.erase();
    await backend.close();
    _states.clear();
    _messages.clear();
  }
}

/// Serializes all state transitions for a conversation, including receive,
/// enqueue, handshake and retries. A failure does not poison the mutex.
class SecretSerialExecutor {
  final Map<String, Future<void>> _tails = {};

  Future<T> run<T>(String key, Future<T> Function() operation) {
    final previous = _tails[key] ?? Future<void>.value();
    final next = previous.then((_) => operation());
    final tail = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace trace) {},
    );
    _tails[key] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tails[key], tail)) _tails.remove(key);
      }),
    );
    return next;
  }

  Future<void> drain() => Future.wait(_tails.values.toList());
}

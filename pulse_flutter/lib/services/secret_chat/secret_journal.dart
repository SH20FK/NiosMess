import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';

typedef SecretJson = Map<String, dynamic>;

SecretJson secretMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};

Object? _copyValue(Object? value, {bool freeze = false}) {
  if (value is Map) {
    final copy = <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _copyValue(entry.value, freeze: freeze),
    };
    return freeze ? Map<String, dynamic>.unmodifiable(copy) : copy;
  }
  if (value is List) {
    final copy = value.map((item) => _copyValue(item, freeze: freeze)).toList();
    return freeze ? List<dynamic>.unmodifiable(copy) : copy;
  }
  return value;
}

/// A detached JSON tree without serializing every string/ciphertext twice.
SecretJson secretCopy(SecretJson value) => _copyValue(value) as SecretJson;
SecretJson secretFreeze(SecretJson value) =>
    _copyValue(value, freeze: true) as SecretJson;

bool secretEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.entries.every(
          (e) => b.containsKey(e.key) && secretEqual(e.value, b[e.key]),
        );
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!secretEqual(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

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
  final Map<String, _SecretMessageIndex> _indexes = {};
  final Map<int, String> _chatIds = {};
  final Map<String, int> _messageRevisions = {};
  Future<void> _tail = Future<void>.value();
  bool _closed = false;
  bool _failed = false;
  int _sequence = 0;

  Iterable<String> get conversations => _states.keys.toList(growable: false);
  SecretJson state(String chat) => secretCopy(_states[chat] ?? {});
  SecretJson stateView(String chat) => _states[chat] ?? const {};
  String? findChat(int id) => _chatIds[id];
  int messageRevision(String chat) => _messageRevisions[chat] ?? 0;
  Iterable<SecretJson> messageViews(String chat) =>
      _messages[chat]?.values ?? const <SecretJson>[];
  Iterable<SecretJson> orderedMessageViews(
    String chat, {
    bool reverse = false,
  }) sync* {
    final index = _indexes[chat];
    if (index == null) return;
    if (!reverse) {
      for (final id in index.ordered.keys) {
        yield _messages[chat]![id]!;
      }
    } else {
      var id = index.ordered.lastKey();
      while (id != null) {
        yield _messages[chat]![id]!;
        id = index.ordered.lastKeyBefore(id);
      }
    }
  }

  SecretJson? messageViewByLocalId(String chat, String id) =>
      _messages[chat]?[id];
  SecretJson? messageByLocalId(String chat, String id) {
    final row = messageViewByLocalId(chat, id);
    return row == null ? null : secretCopy(row);
  }

  SecretJson? messageById(String chat, int id) {
    final localId = _indexes[chat]?.byId[id];
    return localId == null ? null : messageByLocalId(chat, localId);
  }

  SecretJson? firstPendingMessage(String chat) {
    final pending = _indexes[chat]?.pending;
    if (pending == null || pending.isEmpty) return null;
    return messageByLocalId(chat, pending[pending.firstKey()]!);
  }

  Iterable<String> pendingInboxIds(String chat) =>
      _indexes[chat]?.inbox.toList(growable: false) ?? const [];
  Set<String> get attachmentIds => {
    for (final index in _indexes.values) ...index.attachmentCounts.keys,
  };
  DateTime? get nextExpiry {
    int? next;
    for (final index in _indexes.values) {
      final deadline = index.expirations.firstKey();
      if (deadline != null && (next == null || deadline < next)) {
        next = deadline;
      }
    }
    return next == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(next, isUtc: true);
  }

  Iterable<String> expiredMessageIds(String chat, DateTime now) sync* {
    final index = _indexes[chat];
    if (index == null) return;
    for (final deadline in index.expirations.keys) {
      if (deadline > now.microsecondsSinceEpoch) break;
      yield* index.expirations[deadline]!;
    }
  }

  bool get hasPendingWork => _states.entries.any(
    (entry) =>
        !const {
          'deleted',
          'keyChanged',
          'invalidSignature',
          'otherDevice',
          'updateRequired',
        }.contains(entry.value['status']) &&
        ((_indexes[entry.key]?.hasRetryableOutbox ?? false) ||
            secretMap(entry.value['controls']).isNotEmpty ||
            entry.value['remote_id'] == null ||
            entry.value['status'] == 'connecting'),
  );
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
        _indexes.clear();
        _chatIds.clear();
        _messageRevisions.clear();
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
      _removeChatIds(chat);
      _states.remove(chat);
      _messages.remove(chat);
      _indexes.remove(chat);
      _messageRevisions.remove(chat);
      return;
    }
    _removeChatIds(chat);
    final state = secretFreeze(secretMap(tx['state']));
    _states[chat] = state;
    for (final id in [state['ui_id'], state['remote_id']]) {
      if (id is int) _chatIds[id] = chat;
    }
    final rows = _messages.putIfAbsent(chat, () => {});
    final index = _indexes.putIfAbsent(chat, () => _SecretMessageIndex(rows));
    var changed = false;
    for (final entry in secretMap(tx['messages']).entries) {
      index.replace(entry.key, secretFreeze(secretMap(entry.value)));
      changed = true;
    }
    for (final id in (tx['remove'] as List? ?? const [])) {
      index.remove(id as String);
      changed = true;
    }
    if (changed) _messageRevisions[chat] = messageRevision(chat) + 1;
  }

  void _removeChatIds(String chat) {
    final old = _states[chat];
    if (old == null) return;
    for (final id in [old['ui_id'], old['remote_id']]) {
      if (id is int && _chatIds[id] == chat) _chatIds.remove(id);
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
            secretMap(tx['state'])['status'] == 'deleted' ||
            (tx['remove'] as List).isNotEmpty ||
            secretMap(tx['messages']).values.any(
              (row) =>
                  secretMap(secretMap(row)['message'])['is_deleted'] == true,
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
    _indexes.clear();
    _chatIds.clear();
    _messageRevisions.clear();
  }
}

/// Rebuildable projections. Payloads stay immutable and journal transactions
/// remain the sole authority for ratchet/message state after a process restart.
class _SecretMessageIndex {
  _SecretMessageIndex(this.rows) {
    ordered = SplayTreeMap<String, bool>((a, b) {
      final left = (rows[a]?['message'] as Map?)?['sent_at'];
      final right = (rows[b]?['message'] as Map?)?['sent_at'];
      final date = '$left'.compareTo('$right');
      return date != 0 ? date : (ordinal[a] ?? 0).compareTo(ordinal[b] ?? 0);
    });
  }
  final Map<String, SecretJson> rows;
  late final SplayTreeMap<String, bool> ordered;
  final Map<String, int> ordinal = {};
  final Map<int, String> byId = {};
  final SplayTreeMap<int, String> pending = SplayTreeMap();
  final Set<String> inbox = {};
  final Map<String, int> attachmentCounts = {};
  final SplayTreeMap<int, Set<String>> expirations = SplayTreeMap();
  final Map<String, int> _expiresById = {};
  int _nextOrdinal = 0;

  bool get hasRetryableOutbox {
    final first = pending.firstKey();
    if (first == null) return false;
    final operations = rows[pending[first]]?['operations'] as List? ?? const [];
    return operations.isNotEmpty && (operations.first as Map)['failed'] != true;
  }

  Iterable<String> _attachments(SecretJson row) sync* {
    for (final body in [
      row['body'],
      ...((row['operations'] as List? ?? const []).map(
        (op) => secretMap(op)['body'],
      )),
    ]) {
      final id = secretMap(secretMap(body)['file'])['attachment_id'];
      if (id is String) yield id;
    }
  }

  void remove(String id, {bool keepOrdinal = false}) {
    final old = rows[id];
    if (old == null) return;
    ordered.remove(id);
    for (final numeric in [
      secretMap(old['message'])['id'],
      old['local_numeric_id'],
    ]) {
      if (byId[numeric] == id) byId.remove(numeric);
    }
    pending.remove(ordinal[id]);
    inbox.remove(id);
    final deadline = _expiresById.remove(id);
    if (deadline != null) {
      final ids = expirations[deadline]!;
      ids.remove(id);
      if (ids.isEmpty) expirations.remove(deadline);
    }
    for (final attachment in _attachments(old)) {
      final remaining = (attachmentCounts[attachment] ?? 1) - 1;
      if (remaining == 0) {
        attachmentCounts.remove(attachment);
      } else {
        attachmentCounts[attachment] = remaining;
      }
    }
    if (!keepOrdinal) {
      rows.remove(id);
      ordinal.remove(id);
    }
  }

  void replace(String id, SecretJson row) {
    remove(id, keepOrdinal: true);
    ordinal.putIfAbsent(id, () => _nextOrdinal++);
    rows[id] = row;
    ordered[id] = true;
    for (final numeric in [
      secretMap(row['message'])['id'],
      row['local_numeric_id'],
    ]) {
      if (numeric is int) byId[numeric] = id;
    }
    if ((row['operations'] as List? ?? const []).isNotEmpty) {
      pending[ordinal[id]!] = id;
    }
    if (row['pending_message'] != null) inbox.add(id);
    final message = row['message'] as Map? ?? const {};
    final expiry = DateTime.tryParse('${message['expires_at']}');
    if (message['is_deleted'] != true && expiry != null) {
      final deadline = expiry.microsecondsSinceEpoch;
      _expiresById[id] = deadline;
      expirations.putIfAbsent(deadline, () => {}).add(id);
    }
    for (final attachment in _attachments(row)) {
      attachmentCounts.update(
        attachment,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
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

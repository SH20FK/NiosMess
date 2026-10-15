part of 'encrypted_message_cache.dart';

/// Persistent backing for ordinary history windows. LazyBox keeps ciphertext on
/// disk. Its sorted keyAt index provides range lookup without a second in-memory
/// list of messages or IDs. Only identity/order metadata is present in keys.
class EncryptedHistoryArchive {
  EncryptedHistoryArchive._(this.accountId, this.chatId, this.generation);
  static const _boxName = 'enc_history_archive_v1';
  static final Map<int, Future<void>> _tails = {};
  final int accountId;
  final int chatId;
  final int generation;
  String get _prefix => 'm:$accountId:$chatId:';
  String _identity(int id) => 'i:$accountId:$chatId:$id';
  String? _clientId(ApiMessage row) =>
      row.clientMessageId ??
      (row.id < 0 ? 'normal:$accountId:$chatId:${row.id}' : null);
  String _clientPointer(String id) => 'c:$accountId:$chatId:$id';
  LazyBox<String> get _box => Hive.lazyBox<String>(_boxName);
  bool get valid =>
      generation == EncryptedMessageCache.accountGeneration(accountId);

  static Future<EncryptedHistoryArchive> open(
    int accountId,
    int chatId, {
    int? generation,
  }) async {
    await HiveBootstrap.ensureInitialized();
    await Hive.openLazyBox<String>(_boxName);
    return EncryptedHistoryArchive._(
      accountId,
      chatId,
      generation ?? EncryptedMessageCache.accountGeneration(accountId),
    );
  }

  static String _number(int value) {
    final digits = value.abs().toString().padLeft(20, '0');
    return value >= 0
        ? '1$digits'
        : '0${digits.split('').map((d) => 9 - int.parse(d)).join()}';
  }

  String orderKey(ApiMessage message) {
    final pending = message.id < 0 || message.isSending;
    return '$_prefix${_number(message.resolvedSentAt.microsecondsSinceEpoch)}:'
        '${pending ? 1 : 0}:${_number(pending ? message.id.abs() : message.id)}:${message.id}';
  }

  int _lowerBound(String key) {
    var lower = 0;
    var upper = _box.length;
    while (lower < upper) {
      final middle = lower + ((upper - lower) >> 1);
      if ((_box.keyAt(middle) as String).compareTo(key) < 0) {
        lower = middle + 1;
      } else {
        upper = middle;
      }
    }
    return lower;
  }

  int get _start => _lowerBound(_prefix);
  int get _end => _lowerBound('$_prefix\uffff');
  int get storedCount => _end - _start;
  bool hasBefore(ApiMessage first) => _lowerBound(orderKey(first)) > _start;
  bool hasAfter(ApiMessage last) =>
      _lowerBound('${orderKey(last)}\u0000') < _end;

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    final previous = _tails[accountId] ?? Future<void>.value();
    late final Future<void> next;
    next = previous
        .then((_) async {
          try {
            if (!valid) throw StateError('history_account_erased');
            result.complete(await operation());
          } catch (error, stack) {
            result.completeError(error, stack);
          }
        })
        .whenComplete(() {
          if (identical(_tails[accountId], next)) _tails.remove(accountId);
        });
    _tails[accountId] = next;
    return result.future;
  }

  static Future<Map<String, String>> _encode(
    Map<String, Map<String, dynamic>> rows,
  ) async {
    final key = await EncryptedMessageCache._getOrCreateKey();
    final bytes = await key.extractBytes();
    return EncryptedMessageCache._runCompute(() async {
      final aes = AesGcm.with256bits();
      final secret = SecretKey(bytes);
      final result = <String, String>{};
      for (final row in rows.entries) {
        final encrypted = await aes.encrypt(
          utf8.encode(jsonEncode(row.value)),
          secretKey: secret,
          aad: utf8.encode(row.key),
        );
        result[row.key] = base64Encode([
          ...encrypted.nonce,
          ...encrypted.cipherText,
          ...encrypted.mac.bytes,
        ]);
      }
      return result;
    });
  }

  static Future<List<ApiMessage>> _decode(Map<String, String> rows) async =>
      (await _decodeJson(rows)).map(ApiMessage.fromJson).toList();

  static Future<List<Map<String, dynamic>>> _decodeJson(
    Map<String, String> rows,
  ) async {
    final key = await EncryptedMessageCache._getOrCreateKey();
    final bytes = await key.extractBytes();
    final decoded = await EncryptedMessageCache._runCompute(() async {
      final aes = AesGcm.with256bits();
      final secret = SecretKey(bytes);
      final result = <Map<String, dynamic>>[];
      for (final row in rows.entries) {
        final data = base64Decode(row.value);
        if (data.length < 28) {
          throw const FormatException('history_archive_record');
        }
        final plain = await aes.decrypt(
          SecretBox(
            data.sublist(12, data.length - 16),
            nonce: data.sublist(0, 12),
            mac: Mac(data.sublist(data.length - 16)),
          ),
          secretKey: secret,
          aad: utf8.encode(row.key),
        );
        result.add(
          Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)) as Map),
        );
      }
      return result;
    });
    return decoded;
  }

  String get _anchorKey => 'a:$accountId:$chatId';

  Future<ChatHistoryAnchor?> readScrollAnchor() async {
    if (!valid) throw StateError('history_account_erased');
    final value = await _box.get(_anchorKey);
    if (value == null) return null;
    ChatHistoryAnchor? anchor;
    try {
      anchor = ChatHistoryAnchor.fromJson(
        (await _decodeJson({_anchorKey: value})).single,
      );
    } catch (_) {
      // A malformed bookmark must never make otherwise intact history unusable.
    }
    if (!valid) throw StateError('history_account_erased');
    return anchor;
  }

  Future<void> writeScrollAnchor(ChatHistoryAnchor? anchor) =>
      _serialized(() async {
        if (anchor == null) {
          await _box.delete(_anchorKey);
        } else {
          final encoded = await _encode({_anchorKey: anchor.toJson()});
          if (!valid) throw StateError('history_account_erased');
          await _box.put(_anchorKey, encoded[_anchorKey]!);
        }
        await _box.flush();
      });

  Future<void> write(List<ApiMessage> messages, {Set<int> remove = const {}}) =>
      _serialized(() => _writeRows(messages, remove: remove));

  Future<void> _writeRows(
    List<ApiMessage> messages, {
    Set<int> remove = const {},
  }) async {
    if (messages.isEmpty && remove.isEmpty) return;
    final rows = <String, Map<String, dynamic>>{
      for (final message in messages)
        orderKey(message): {
          ...message.toJson(),
          // API parsing treats zone-less server timestamps as UTC. Persist a
          // canonical zone so local optimistic timestamps retain their identity.
          'sent_at': message.sentAt.toUtc().toIso8601String(),
          if (_clientId(message) != null)
            'client_message_id': _clientId(message),
        },
    };
    final encoded = await _encode(rows);
    final obsolete = <String>{};
    for (final message in messages) {
      final previous = await _box.get(_identity(message.id));
      if (previous != null && previous != orderKey(message)) {
        obsolete.add(previous);
      }
    }
    for (final id in remove) {
      final previous = await _box.get(_identity(id));
      if (previous != null) obsolete.add(previous);
      obsolete.add(_identity(id));
    }
    if (!valid) throw StateError('history_account_erased');
    final highest = messages.fold<int>(
      await highestServerId,
      (a, m) => m.id > a ? m.id : a,
    );
    await _box.putAll({
      ...encoded,
      for (final message in messages) _identity(message.id): orderKey(message),
      for (final message in messages)
        if (_clientId(message) != null)
          _clientPointer(_clientId(message)!): orderKey(message),
      'h:$accountId:$chatId': '$highest',
    });
    await _box.deleteAll(obsolete);
    await _box.flush();
  }

  bool contains(int id) => _box.containsKey(_identity(id));
  Future<int> get highestServerId async =>
      int.tryParse(await _box.get('h:$accountId:$chatId') ?? '') ?? 0;

  Future<void> markReadBy(int readerId) => _serialized(() async {
    final key = 'r:$accountId:$chatId';
    final previous = await _box.get(key);
    final read = previous == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(previous) as Map);
    read['$readerId'] = await highestServerId;
    if (!valid) return;
    await _box.put(key, jsonEncode(read));
    await _box.flush();
  });

  Future<List<ApiMessage>> _readFlags(List<ApiMessage> messages) async {
    final encoded = await _box.get('r:$accountId:$chatId');
    if (encoded == null) return messages;
    final read = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    return messages.map((message) {
      final seen =
          message.id > 0 &&
          read.entries.any(
            (entry) =>
                message.senderId != int.parse(entry.key) &&
                message.id <= (entry.value as int),
          );
      return seen && !message.isRead ? message.copyWith(isRead: true) : message;
    }).toList();
  }

  Future<List<ApiMessage>> read({
    int limit = 300,
    ApiMessage? before,
    ApiMessage? after,
  }) async {
    if (!valid) throw StateError('history_account_erased');
    final start = after == null
        ? _start
        : _lowerBound('${orderKey(after)}\u0000');
    final end = before == null ? _end : _lowerBound(orderKey(before));
    var cursor = after == null ? end : start;
    final result = <ApiMessage>[];
    final now = DateTime.now().toUtc();
    while (result.length < limit &&
        (after == null ? cursor > start : cursor < end)) {
      final remaining = limit - result.length;
      final lower = after == null
          ? (cursor - remaining).clamp(start, cursor)
          : cursor;
      final upper = after == null
          ? cursor
          : (cursor + remaining).clamp(cursor, end);
      final keys = [
        for (var i = lower; i < upper; i++) _box.keyAt(i) as String,
      ];
      final validRows = <String, String>{};
      for (final key in keys) {
        final id = int.parse(key.substring(key.lastIndexOf(':') + 1));
        // putAll may be interrupted between frames. Only committed identity
        // pointers expose a row; old ciphertext left by a move is an orphan.
        if (await _box.get(_identity(id)) != key) continue;
        final value = await _box.get(key);
        if (value != null) validRows[key] = value;
      }
      final decoded = await _decode(validRows);
      final visible = <ApiMessage>[];
      for (final row in decoded) {
        final logicalId = _clientId(row);
        if (logicalId != null &&
            await _box.get(_clientPointer(logicalId)) != orderKey(row)) {
          continue;
        }
        if (!row.isDeleted &&
            (row.expiresAt == null || row.expiresAt!.isAfter(now))) {
          visible.add(row);
        }
      }
      if (after == null) {
        result.insertAll(0, visible);
        cursor = lower;
      } else {
        result.addAll(visible);
        cursor = upper;
      }
    }
    if (!valid) throw StateError('history_account_erased');
    return _readFlags(result);
  }

  Future<ApiMessage?> message(int id) async {
    if (!valid) throw StateError('history_account_erased');
    final key = await _box.get(_identity(id));
    if (key == null) return null;
    final encoded = await _box.get(key);
    if (encoded == null) return null;
    final row = (await _decode({key: encoded})).single;
    final logicalId = _clientId(row);
    if (logicalId != null && await _box.get(_clientPointer(logicalId)) != key) {
      return null;
    }
    if (!valid) throw StateError('history_account_erased');
    if (row.isDeleted ||
        row.expiresAt?.isBefore(DateTime.now().toUtc()) == true) {
      return null;
    }
    return (await _readFlags([row])).single;
  }

  Future<void> patch(int id, ApiMessage Function(ApiMessage) update) =>
      _serialized(() async {
        final row = await message(id);
        if (row != null) await _writeRows([update(row)]);
      });

  static Future<void> eraseAccount(int accountId) async {
    await (_tails[accountId] ?? Future<void>.value());
    await HiveBootstrap.ensureInitialized();
    final box = await Hive.openLazyBox<String>(_boxName);
    await box.deleteAll(
      box.keys
          .where((key) => RegExp('^[amichr]:$accountId:').hasMatch('$key'))
          .toList(),
    );
    await box.flush();
  }
}

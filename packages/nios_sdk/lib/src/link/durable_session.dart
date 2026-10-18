import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:universal_io/io.dart';

import 'cipher.dart';
import 'models.dart';
import 'transport.dart';
import 'journal_guard.dart';

String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
String _stream(String sender, String session) =>
    _hash(jsonEncode([sender, session]));

/// A device-scoped durable operation journal. Storage is encrypted independently
/// of transport encryption. Successful enqueue means put + flush completed.
class DurableSession {
  // Hive box names are isolate-global. Reserve before the first filesystem await
  // so two callers cannot race the journal key commitment or share a Box handle.
  static final Set<String> _openingJournals = {};

  DurableSession._({
    required this.accountId,
    required this.deviceId,
    required this.cipher,
    required this.transports,
    required this.reducer,
    required Box<String> box,
    required File keyCommitment,
    required this.operationTimeout,
    required this.retryInterval,
  }) : _box = box,
       _keyCommitment = keyCommitment;

  static Future<DurableSession> open({
    required String directory,
    required String accountId,
    required List<int> journalKey,
    required String deviceId,
    required EnvelopeCipher cipher,
    required List<LinkTransport> transports,
    OperationReducer? reducer,
    Duration retryInterval = const Duration(seconds: 2),
    Duration operationTimeout = const Duration(seconds: 20),
    bool autoStart = true,
  }) async {
    if (accountId.isEmpty ||
        deviceId.isEmpty ||
        deviceId.length > 256 ||
        journalKey.length != 32) {
      throw ArgumentError(
        'Account, device and a 256-bit journal key are required',
      );
    }
    if (retryInterval <= Duration.zero || operationTimeout <= Duration.zero) {
      throw ArgumentError('Durations must be positive');
    }
    final name =
        'nios_link_${_hash(jsonEncode([accountId, deviceId])).substring(0, 32)}';
    if (Hive.isBoxOpen(name) || !_openingJournals.add(name)) {
      throw StateError('This account/device journal is already open');
    }
    try {
      await Directory(directory).create(recursive: true);
      final keyCommitment = await verifyJournalKey(
        directory: directory,
        name: name,
        key: journalKey,
      );
      final box = await Hive.openBox<String>(
        name,
        path: directory,
        encryptionCipher: HiveAesCipher(journalKey),
      );
      final session = DurableSession._(
        accountId: accountId,
        deviceId: deviceId,
        cipher: cipher,
        transports: List.unmodifiable(transports),
        reducer: reducer ?? (previous, _) => previous,
        box: box,
        keyCommitment: keyCommitment,
        operationTimeout: operationTimeout,
        retryInterval: retryInterval,
      );
      try {
        session._restore();
      } catch (_) {
        await box.close();
        rethrow;
      }
      if (autoStart) session.start();
      return session;
    } finally {
      _openingJournals.remove(name);
    }
  }

  final String accountId;
  final String deviceId;
  final EnvelopeCipher cipher;
  final List<LinkTransport> transports;
  final OperationReducer reducer;
  final Duration operationTimeout;
  final Duration retryInterval;
  final Box<String> _box;
  final File _keyCommitment;
  final _events = StreamController<LinkEvent>.broadcast();
  final _incomingEvents = StreamController<DurableOperation>.broadcast();
  final Map<String, Map<String, dynamic>> _outgoing = {};
  final Map<String, Map<String, dynamic>> _incoming = {};
  final Set<String> _pendingOutgoingIds = {};
  final Set<String> _pendingAckKeys = {};
  final Map<String, Map<int, String>> _incomingSequences = {};
  final Map<String, int> _nextSequences = {};
  final Map<String, int> _appliedSequences = {};
  final Map<String, Map<String, dynamic>> _states = {};
  final Map<String, Future<void>> _serial = {};
  Timer? _timer;
  Future<void>? _pumping;
  bool _closing = false;
  bool _closed = false;
  bool _storageFault = false;

  Stream<LinkEvent> get events => _events.stream;
  Stream<DurableOperation> get incoming => _incomingEvents.stream;
  bool get isClosed => _closed || _closing;

  void _checkOpen() {
    if (_closed || _closing) throw StateError('Durable session is closed');
    if (_storageFault) {
      throw StateError('Journal write failed; reopen before continuing');
    }
  }

  Map<String, dynamic> _decode(String value) =>
      jsonDecode(value) as Map<String, dynamic>;
  EncryptedEnvelope _envelope(Map<String, dynamic> record) =>
      EncryptedEnvelope.fromJson(record['envelope'] as Map<String, dynamic>);
  EnvelopeContext _context(Map<String, dynamic> record) =>
      record['context'] == null
      ? _envelope(record).context
      : EnvelopeContext.fromJson(record['context'] as Map<String, dynamic>);
  Set<DeliveryFact> _facts(Map<String, dynamic> record) =>
      (record['facts'] as List)
          .map((value) => DeliveryFact.values.byName(value as String))
          .toSet();
  String _inKey(EnvelopeContext context) =>
      'i:${_hash(jsonEncode([context.senderId, context.sessionId, context.operationId]))}';

  void _restore() {
    for (final key in _box.keys) {
      if (key is! String || (!key.startsWith('o:') && !key.startsWith('i:'))) {
        continue;
      }
      final record = _decode(_box.get(key)!);
      final context = _context(record);
      if (key.startsWith('o:')) {
        if (context.senderId != deviceId) {
          throw StateError('Journal device mismatch');
        }
        _outgoing[context.operationId] = record;
        if (!_facts(record).contains(DeliveryFact.recipientApplied)) {
          // Persisted wall clocks can jump between launches. Resume accepted
          // operations immediately instead of waiting for an obsolete deadline.
          record['nextAttemptAt'] = 0;
          _pendingOutgoingIds.add(context.operationId);
        }
        final stream = _stream(context.recipientId, context.sessionId);
        _nextSequences[stream] = max(
          _nextSequences[stream] ?? 1,
          context.sequence + 1,
        );
      } else {
        if (context.recipientId != deviceId) {
          throw StateError('Journal device mismatch');
        }
        _incoming[key] = record;
        if (record['ackPending'] == true) _pendingAckKeys.add(key);
        final stream = _stream(context.senderId, context.sessionId);
        (_incomingSequences[stream] ??= {})[context.sequence] = key;
        if (record['applied'] == true &&
            context.sequence > (_appliedSequences[stream] ?? 0)) {
          _appliedSequences[stream] = context.sequence;
          _states[stream] = record['state'] as Map<String, dynamic>;
        }
      }
    }
  }

  Future<T> _inSequence<T>(String stream, Future<T> Function() action) {
    final previous = _serial[stream] ?? Future<void>.value();
    final result = previous.then((_) {
      _checkOpen();
      return action();
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _serial[stream] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_serial[stream], tail)) _serial.remove(stream);
      }),
    );
    return result;
  }

  Future<void> _persist(String key, Map<String, dynamic> record) async {
    try {
      await _box.put(key, jsonEncode(record));
      await _box.flush();
    } catch (_) {
      _storageFault = true;
      rethrow;
    }
  }

  static String newOperationId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  SavedOperation _saved(Map<String, dynamic> record) => SavedOperation(
    context: _context(record),
    preparedEnvelope: record['envelope'] == null ? null : _envelope(record),
    facts: _facts(record),
    attempts: record['attempts'] as int,
    nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(
      record['nextAttemptAt'] as int,
      isUtc: true,
    ),
    errorCode: record['error'] as String?,
  );

  /// A caller may reuse the ID after a failed network attempt. Reusing an ID for
  /// different content or another peer is rejected, preserving its first meaning.
  Future<SavedOperation> enqueue({
    required String peerId,
    required String sessionId,
    required Map<String, dynamic> payload,
    String? operationId,
    bool prepareImmediately = true,
  }) {
    _checkOpen();
    final id = operationId ?? newOperationId();
    final stream = _stream(peerId, sessionId);
    // Snapshot before any await: later mutation by a caller cannot alter content.
    final encoded = jsonEncode(payload);
    final snapshot = _decode(encoded);
    if (utf8.encode(encoded).length > 1048576) {
      throw ArgumentError('Operation payload is too large');
    }
    return _inSequence(
      'id:$id',
      () => _inSequence('out:$stream', () async {
        final existing = _outgoing[id];
        if (existing != null) {
          final context = _context(existing);
          if (context.recipientId != peerId ||
              context.sessionId != sessionId ||
              jsonEncode(existing['payload']) != encoded) {
            throw StateError(
              'Operation ID already belongs to different content',
            );
          }
          return _saved(existing);
        }
        final context = EnvelopeContext(
          senderId: deviceId,
          recipientId: peerId,
          sessionId: sessionId,
          operationId: id,
          sequence: _nextSequences[stream] ?? 1,
        );
        // Validate fields using the same strict parser as received envelopes.
        EnvelopeContext.fromJson(context.toJson());
        _checkOpen();
        final record = <String, dynamic>{
          'context': context.toJson(),
          'envelope': null,
          'payload': snapshot,
          'facts': [DeliveryFact.localDurable.name],
          'attempts': 0,
          'nextAttemptAt': 0,
          'error': null,
        };
        await _persist('o:$id', record);
        _outgoing[id] = record;
        _pendingOutgoingIds.add(id);
        _nextSequences[stream] = context.sequence + 1;
        _emit(record);
        if (prepareImmediately) {
          try {
            await _prepare(id);
          } catch (_) {
            // The operation is already durably accepted. Key or cipher failure
            // pauses transmission without losing the local payload.
          }
        }
        return _saved(_outgoing[id]!);
      }),
    );
  }

  /// Called under this peer's sequence lock. Preparing an immutable ciphertext
  /// is a second journal commit; no transport sees it before flush succeeds.
  Future<void> _prepare(String id) async {
    final old = _outgoing[id]!;
    if (old['envelope'] != null) return;
    try {
      final context = _context(old);
      final envelope = await cipher
          .seal(context, utf8.encode(jsonEncode(old['payload'])))
          .timeout(operationTimeout);
      _checkOpen();
      final updated = <String, dynamic>{
        ...old,
        'envelope': envelope.toJson(),
        'error': null,
      };
      await _persist('o:$id', updated);
      _outgoing[id] = updated;
      _emit(updated);
    } catch (_) {
      if (!isClosed && !_storageFault) {
        final updated = <String, dynamic>{
          ...old,
          'error': 'keys_or_cipher_unavailable',
        };
        await _persist('o:$id', updated);
        _outgoing[id] = updated;
        _emit(updated);
      }
      rethrow;
    }
  }

  SavedOperation? operation(String id) =>
      _outgoing[id] == null ? null : _saved(_outgoing[id]!);
  Map<String, dynamic>? savedPayload(String id) => _outgoing[id] == null
      ? null
      : _decode(jsonEncode(_outgoing[id]!['payload']));
  List<SavedOperation> get operations =>
      _outgoing.values.map(_saved).toList(growable: false);
  Map<String, dynamic> applicationState({
    required String peerId,
    required String sessionId,
  }) => _decode(
    jsonEncode(_states[_stream(peerId, sessionId)] ?? <String, dynamic>{}),
  );

  List<DurableOperation> get appliedOperations => _incoming.values
      .where((record) => record['applied'] == true)
      .map(
        (record) => DurableOperation(
          context: _envelope(record).context,
          payload: _decode(jsonEncode(record['payload'])),
        ),
      )
      .toList(growable: false);

  void _emit(Map<String, dynamic> record) {
    if (!_events.isClosed) {
      _events.add(
        LinkEvent(
          _context(record).operationId,
          Set.unmodifiable(_facts(record)),
          errorCode: record['error'] as String?,
        ),
      );
    }
  }

  Future<EncryptedEnvelope> _makeAck(
    EncryptedEnvelope original,
    DeliveryFact fact,
  ) => cipher
      .seal(
        EnvelopeContext(
          senderId: deviceId,
          recipientId: original.context.senderId,
          sessionId: original.context.sessionId,
          operationId: original.context.operationId,
          sequence: original.context.sequence,
          kind: 'ack',
        ),
        utf8.encode(jsonEncode({'digest': original.digest, 'fact': fact.name})),
      )
      .timeout(operationTimeout);

  /// Authenticates before storage. Out-of-order operations are stored, then
  /// reduced strictly in sequence. No external effect occurs before the commit.
  Future<EncryptedEnvelope> receive(EncryptedEnvelope envelope) {
    _checkOpen();
    final context = envelope.context;
    EnvelopeContext.fromJson(context.toJson());
    if (context.kind != 'operation' || context.recipientId != deviceId) {
      throw StateError('Invalid operation recipient');
    }
    final stream = _stream(context.senderId, context.sessionId);
    return _inSequence('in:$stream', () async {
      final key = _inKey(context);
      final existing = _incoming[key];
      if (existing != null) {
        if (_envelope(existing).digest != envelope.digest) {
          throw StateError('Operation ID collision');
        }
        await _drain(stream);
        return EncryptedEnvelope.fromJson(
          _incoming[key]!['ack'] as Map<String, dynamic>,
        );
      }
      final sequenceOwner = _incomingSequences[stream]?[context.sequence];
      if (sequenceOwner != null) throw StateError('Sequence collision');
      final plaintext = await cipher.open(envelope).timeout(operationTimeout);
      final payload = _decode(utf8.decode(plaintext));
      final storedAck = await _makeAck(envelope, DeliveryFact.recipientStored);
      _checkOpen();
      final record = <String, dynamic>{
        'envelope': envelope.toJson(),
        'payload': payload,
        'applied': false,
        'state': <String, dynamic>{},
        'ack': storedAck.toJson(),
        'ackPending': true,
      };
      await _persist(key, record);
      _incoming[key] = record;
      _pendingAckKeys.add(key);
      (_incomingSequences[stream] ??= {})[context.sequence] = key;
      await _drain(stream);
      return EncryptedEnvelope.fromJson(
        _incoming[key]!['ack'] as Map<String, dynamic>,
      );
    });
  }

  Future<void> _drain(String stream) async {
    while (true) {
      final next = (_appliedSequences[stream] ?? 0) + 1;
      final key = _incomingSequences[stream]?[next];
      if (key == null) return;
      final old = _incoming[key]!;
      final envelope = _envelope(old);
      final operation = DurableOperation(
        context: envelope.context,
        payload: _decode(jsonEncode(old['payload'])),
      );
      Map<String, dynamic> state;
      try {
        state = _decode(
          jsonEncode(
            reducer(
              _decode(jsonEncode(_states[stream] ?? <String, dynamic>{})),
              operation,
            ),
          ),
        );
      } catch (_) {
        // A failing reducer leaves a durable pending operation, never an ACK of
        // application. Retry/recovery can supply the corrected pure reducer.
        return;
      }
      final ack = await _makeAck(envelope, DeliveryFact.recipientApplied);
      _checkOpen();
      final record = <String, dynamic>{
        ...old,
        'applied': true,
        'state': state,
        'ack': ack.toJson(),
        'ackPending': true,
      };
      await _persist(key, record);
      _incoming[key] = record;
      _pendingAckKeys.add(key);
      _states[stream] = state;
      _appliedSequences[stream] = next;
      if (!_incomingEvents.isClosed) _incomingEvents.add(operation);
    }
  }

  Future<void> acceptAcknowledgement(EncryptedEnvelope acknowledgement) async {
    _checkOpen();
    final context = acknowledgement.context;
    EnvelopeContext.fromJson(context.toJson());
    if (context.kind != 'ack' || context.recipientId != deviceId) {
      throw StateError('Invalid acknowledgement');
    }
    final data = _decode(
      utf8.decode(await cipher.open(acknowledgement).timeout(operationTimeout)),
    );
    final fact = DeliveryFact.values.byName(data['fact'] as String);
    if (!const {
      DeliveryFact.recipientStored,
      DeliveryFact.recipientApplied,
      DeliveryFact.userRead,
    }.contains(fact)) {
      throw StateError('Recipient cannot acknowledge this delivery fact');
    }
    final stream = _stream(context.senderId, context.sessionId);
    await _inSequence('out:$stream', () async {
      final old = _outgoing[context.operationId];
      if (old == null) throw StateError('Unknown acknowledged operation');
      final original = _envelope(old);
      if (original.context.recipientId != context.senderId ||
          original.context.sessionId != context.sessionId ||
          original.context.sequence != context.sequence ||
          original.digest != data['digest']) {
        throw StateError('Acknowledgement does not match operation');
      }
      final facts = _facts(old)..add(DeliveryFact.recipientStored);
      if (fact == DeliveryFact.recipientApplied ||
          fact == DeliveryFact.userRead) {
        facts.add(DeliveryFact.recipientApplied);
      }
      if (fact == DeliveryFact.userRead) facts.add(DeliveryFact.userRead);
      if (facts.length == _facts(old).length) return;
      final updated = <String, dynamic>{
        ...old,
        'facts': facts.map((value) => value.name).toList(),
        'error': null,
      };
      await _persist('o:${context.operationId}', updated);
      _outgoing[context.operationId] = updated;
      if (facts.contains(DeliveryFact.recipientApplied)) {
        _pendingOutgoingIds.remove(context.operationId);
      }
      _emit(updated);
    });
  }

  /// Only the application can assert that a human actually read an operation.
  Future<EncryptedEnvelope> markRead({
    required String peerId,
    required String sessionId,
    required String operationId,
  }) {
    final stream = _stream(peerId, sessionId);
    return _inSequence('in:$stream', () async {
      final key = 'i:${_hash(jsonEncode([peerId, sessionId, operationId]))}';
      final old = _incoming[key];
      if (old == null || old['applied'] != true) {
        throw StateError('Operation is not applied');
      }
      final envelope = _envelope(old);
      final ack = await _makeAck(envelope, DeliveryFact.userRead);
      _checkOpen();
      final updated = <String, dynamic>{
        ...old,
        'ack': ack.toJson(),
        'ackPending': true,
      };
      await _persist(_inKey(envelope.context), updated);
      _incoming[_inKey(envelope.context)] = updated;
      _pendingAckKeys.add(_inKey(envelope.context));
      return ack;
    });
  }

  void start() {
    _checkOpen();
    _timer ??= Timer.periodic(retryInterval, (_) {
      unawaited(pump().catchError((Object _) {}));
    });
    unawaited(pump().catchError((Object _) {}));
  }

  Future<void> retryNow(String operationId) async {
    _checkOpen();
    final old = _outgoing[operationId];
    if (old == null) throw StateError('Unknown operation');
    final context = _context(old);
    await _inSequence(
      'out:${_stream(context.recipientId, context.sessionId)}',
      () async {
        final updated = <String, dynamic>{
          ..._outgoing[operationId]!,
          'nextAttemptAt': 0,
          'error': null,
          'permanent': false,
        };
        await _persist('o:$operationId', updated);
        _outgoing[operationId] = updated;
      },
    );
    await pump();
  }

  Future<void> pump() {
    _checkOpen();
    if (_pumping != null) return _pumping!;
    final future = _pump();
    _pumping = future;
    unawaited(
      future.then<void>(
        (_) {
          _pumping = null;
        },
        onError: (Object _, StackTrace _) {
          _pumping = null;
        },
      ),
    );
    return future;
  }

  Future<void> _pump() async {
    // Recover a durable incoming commit whose reducer/application ACK was
    // interrupted before shutdown, even if the mailbox was already confirmed.
    for (final stream in List<String>.of(_incomingSequences.keys)) {
      if (isClosed || _storageFault) return;
      await _inSequence('in:$stream', () => _drain(stream));
    }
    for (final transport in transports) {
      if (isClosed || _storageFault) return;
      try {
        final envelopes = await transport
            .poll(deviceId)
            .timeout(operationTimeout);
        for (final envelope in envelopes) {
          if (isClosed || _storageFault) return;
          try {
            if (envelope.context.kind == 'ack') {
              await acceptAcknowledgement(envelope);
            } else {
              await receive(envelope);
            }
            await transport.confirmReceived(envelope).timeout(operationTimeout);
          } catch (_) {
            // Invalid peer input is never allowed to advance or erase the journal.
          }
        }
      } catch (_) {
        /* Another route may still be usable. */
      }
    }
    for (final key in List<String>.of(_pendingAckKeys)) {
      if (isClosed || _storageFault) return;
      final old = _incoming[key]!;
      if (old['ackPending'] != true) continue;
      for (final transport in transports) {
        try {
          final ack = EncryptedEnvelope.fromJson(
            old['ack'] as Map<String, dynamic>,
          );
          await transport.publishAcknowledgement(ack).timeout(operationTimeout);
          if (isClosed || _storageFault) return;
          final c = _envelope(old).context;
          await _inSequence('in:${_stream(c.senderId, c.sessionId)}', () async {
            // A concurrent markRead may have replaced this ACK; preserve it.
            if (jsonEncode(_incoming[key]!['ack']) != jsonEncode(old['ack'])) {
              return;
            }
            final updated = <String, dynamic>{
              ..._incoming[key]!,
              'ackPending': false,
            };
            await _persist(key, updated);
            _incoming[key] = updated;
            _pendingAckKeys.remove(key);
          });
          break;
        } catch (_) {
          /* Keep the durable ACK pending. */
        }
      }
    }
    final peers = <String, List<String>>{};
    for (final id in _pendingOutgoingIds) {
      (peers[_context(_outgoing[id]!).recipientId] ??= []).add(id);
    }
    final groups = peers.values.toList(growable: false);
    var nextGroup = 0;
    Future<void> worker() async {
      while (nextGroup < groups.length && !isClosed && !_storageFault) {
        final ids = groups[nextGroup++];
        for (final id in ids) {
          await _sendPending(id);
        }
      }
    }

    await Future.wait(List.generate(min(4, groups.length), (_) => worker()));
  }

  Future<void> _sendPending(String id) async {
    if (isClosed || _storageFault) return;
    final old = _outgoing[id]!;
    if (_facts(old).contains(DeliveryFact.recipientApplied) ||
        (old['nextAttemptAt'] as int) > DateTime.now().millisecondsSinceEpoch ||
        old['permanent'] == true) {
      return;
    }
    final context = _context(old);
    final stream = 'out:${_stream(context.recipientId, context.sessionId)}';
    try {
      await _inSequence(stream, () => _prepare(id));
    } catch (_) {
      if (isClosed || _storageFault) return;
      await _recordAttempt(id, stream, error: 'keys_or_cipher_unavailable');
      return;
    }
    final envelope = _envelope(_outgoing[id]!);
    var delivered = false;
    var error = 'no_route';
    var permanent = transports.isNotEmpty;
    for (final transport in transports) {
      try {
        final receipt = await transport
            .deliver(envelope)
            .timeout(operationTimeout);
        if (isClosed || _storageFault) return;
        if (receipt.acknowledgement != null) {
          await acceptAcknowledgement(receipt.acknowledgement!);
        }
        if (receipt.mailboxStored) {
          await _inSequence(stream, () async {
            final current = _outgoing[id]!;
            final facts = _facts(current)..add(DeliveryFact.mailboxStored);
            final updated = <String, dynamic>{
              ...current,
              'facts': facts.map((value) => value.name).toList(),
            };
            await _persist('o:$id', updated);
            _outgoing[id] = updated;
            _emit(updated);
          });
        }
        delivered = receipt.mailboxStored || receipt.acknowledgement != null;
        if (!delivered) permanent = false;
        if (delivered) break;
      } on LinkTransportException catch (failure) {
        error = failure.code;
        permanent = permanent && failure.permanent;
      } catch (_) {
        error = 'transport_failure';
        permanent = false;
      }
    }
    if (isClosed || _storageFault) return;
    await _recordAttempt(
      id,
      stream,
      error: delivered ? null : error,
      permanent: !delivered && permanent,
    );
  }

  Future<void> _recordAttempt(
    String id,
    String stream, {
    String? error,
    bool permanent = false,
  }) => _inSequence(stream, () async {
    final current = _outgoing[id]!;
    final attempts = (current['attempts'] as int) + 1;
    final seconds = min(60, 1 << min(attempts, 6));
    final updated = <String, dynamic>{
      ...current,
      'attempts': attempts,
      'nextAttemptAt': DateTime.now()
          .add(Duration(seconds: seconds))
          .millisecondsSinceEpoch,
      'error': error,
      'permanent': permanent,
    };
    await _persist('o:$id', updated);
    _outgoing[id] = updated;
    _emit(updated);
  });

  /// Call after key registration or connectivity restoration. Existing prepared
  /// operations retain exactly their original bytes.
  Future<void> wakePeer(String peerId) async {
    _checkOpen();
    for (final id in List<String>.of(_pendingOutgoingIds)) {
      final context = _context(_outgoing[id]!);
      if (context.recipientId != peerId) continue;
      await _inSequence('out:${_stream(peerId, context.sessionId)}', () async {
        final updated = <String, dynamic>{
          ..._outgoing[id]!,
          'nextAttemptAt': 0,
          'permanent': false,
        };
        await _persist('o:$id', updated);
        _outgoing[id] = updated;
      });
    }
    await pump();
  }

  Future<void> close({bool wipe = false}) async {
    if (_closed) return;
    if (_closing) throw StateError('Session close already in progress');
    _closing = true;
    _timer?.cancel();
    _timer = null;
    // In-flight operations check the closing fence before every journal mutation.
    await Future.wait(
      transports.map((transport) async {
        try {
          await transport.close().timeout(operationTimeout);
        } catch (_) {
          // An unavailable transport cannot prevent account storage cleanup.
        }
      }),
    );
    try {
      await _pumping;
    } catch (_) {
      /* Closing cancels work. */
    }
    await Future.wait(List<Future<void>>.of(_serial.values));
    if (wipe) {
      await _box.deleteFromDisk();
      if (await _keyCommitment.exists()) await _keyCommitment.delete();
    } else {
      await _box.close();
    }
    _closed = true;
    _outgoing.clear();
    _incoming.clear();
    _pendingOutgoingIds.clear();
    _pendingAckKeys.clear();
    _states.clear();
    await _events.close();
    await _incomingEvents.close();
  }
}

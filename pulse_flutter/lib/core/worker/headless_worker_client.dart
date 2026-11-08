import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'headless_core_isolate.dart';
import 'worker_protocol.dart';

/// Riverpod provider exposing the singleton [HeadlessWorkerClient].
final headlessWorkerClientProvider = Provider<HeadlessWorkerClient>((ref) {
  final client = HeadlessWorkerClient();
  ref.onDispose(() => unawaited(client.dispose()));
  return client;
});

/// High-performance client that offloads all heavy database I/O, cryptography,
/// and batch parsing to the dedicated background Headless Core Isolate.
final class HeadlessWorkerClient {
  Isolate? _isolate;
  SendPort? _workerSendPort;
  ReceivePort? _uiReceivePort;
  StreamSubscription<dynamic>? _portSubscription;

  int _nextRequestId = 1;
  final Map<int, Completer<WorkerResponse>> _pendingRequests = {};
  final _eventsController = StreamController<WorkerEvent>.broadcast();

  bool _initialized = false;
  bool _closed = false;

  Stream<WorkerEvent> get events => _eventsController.stream;
  bool get isRunning => _initialized && !_closed;

  /// Starts the background headless worker isolate on a dedicated CPU core.
  Future<void> init() async {
    if (_initialized || _closed) return;

    if (kIsWeb) {
      // Web fallback: run without native isolate spawn
      _initialized = true;
      return;
    }

    final handshake = Completer<SendPort>();
    final uiReceivePort = ReceivePort();
    _uiReceivePort = uiReceivePort;

    _portSubscription = uiReceivePort.listen((message) {
      if (!handshake.isCompleted && message is SendPort) {
        handshake.complete(message);
        return;
      }

      if (message is WorkerResponse) {
        final completer = _pendingRequests.remove(message.id);
        completer?.complete(message);
      } else if (message is WorkerEvent) {
        _eventsController.add(message);
      }
    });

    _isolate = await Isolate.spawn(
      niosHeadlessCoreEntryPoint,
      uiReceivePort.sendPort,
      debugName: 'NiosHeadlessCoreWorker',
    );

    _workerSendPort = await handshake.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Headless core isolate handshake timed out'),
    );

    _initialized = true;
  }

  /// Dispatches an RPC command to the background isolate.
  Future<WorkerResponse> execute(
    WorkerAction action, {
    Map<String, dynamic> payload = const <String, dynamic>{},
    TransferableTypedData? bytes,
  }) async {
    if (_closed) throw StateError('HeadlessWorkerClient is closed');
    if (!_initialized) await init();

    if (kIsWeb) {
      // In-process fallback for Web platform
      return _executeWebFallback(action, payload, bytes);
    }

    final id = _nextRequestId++;
    final completer = Completer<WorkerResponse>();
    _pendingRequests[id] = completer;

    final req = WorkerRequest(
      id: id,
      action: action,
      payload: payload,
      transferableBytes: bytes,
    );

    _workerSendPort!.send(req);

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('Worker request $id ($action) timed out');
      },
    );
  }

  /// Checks round-trip responsiveness of the background worker core.
  Future<bool> ping() async {
    final res = await execute(WorkerAction.ping);
    return res.success && res.data?['pong'] == true;
  }

  /// Initializes isolated SQLite database in WAL mode on the background core.
  Future<void> initStorage(String dbPath) async {
    final res = await execute(
      WorkerAction.initStorage,
      payload: {'path': dbPath},
    );
    if (!res.success) throw StateError(res.error ?? 'initStorage failed');
  }

  /// Encrypts bytes in the background core, returning the ciphertext buffer.
  Future<Uint8List> encryptPayload({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List bytes,
    String? aad,
    String algorithm = 'A256GCM',
  }) async {
    final transferable = TransferableTypedData.fromList([bytes]);
    final res = await execute(
      WorkerAction.encryptPayload,
      payload: {
        'key': base64Encode(key),
        'nonce': base64Encode(nonce),
        'aad': aad,
        'algorithm': algorithm,
      },
      bytes: transferable,
    );
    if (!res.success) throw StateError(res.error ?? 'encryptPayload failed');
    return res.materialBytes ?? Uint8List(0);
  }

  /// Decrypts a batch of incoming messages on the background core.
  Future<List<Map<String, dynamic>>> decryptBatch(
    List<Map<String, dynamic>> items,
  ) async {
    final res = await execute(
      WorkerAction.decryptPayloadBatch,
      payload: {'items': items},
    );
    if (!res.success) throw StateError(res.error ?? 'decryptBatch failed');
    final rawList = res.data?['items'] as List<dynamic>? ?? [];
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Hashes large media chunks with SHA-256 in the background core.
  Future<String> hashMedia(Uint8List bytes) async {
    final transferable = TransferableTypedData.fromList([bytes]);
    final res = await execute(
      WorkerAction.hashMediaStream,
      bytes: transferable,
    );
    if (!res.success) throw StateError(res.error ?? 'hashMedia failed');
    return res.data?['sha256'] as String? ?? '';
  }

  /// Performs full-text search across messages in the background core.
  Future<List<dynamic>> searchMessages(
    String query,
    List<dynamic> messages,
  ) async {
    final res = await execute(
      WorkerAction.searchHistory,
      payload: {'query': query, 'messages': messages},
    );
    if (!res.success) throw StateError(res.error ?? 'searchMessages failed');
    return (res.data?['matches'] as List<dynamic>?) ?? [];
  }

  /// Runs an atomic WAL checkpoint in the background core.
  Future<void> walCheckpoint() async {
    final res = await execute(WorkerAction.walCheckpoint);
    if (!res.success) throw StateError(res.error ?? 'walCheckpoint failed');
  }

  Future<WorkerResponse> _executeWebFallback(
    WorkerAction action,
    Map<String, dynamic> payload,
    TransferableTypedData? bytes,
  ) async {
    // Pure in-process mock execution for browsers
    return WorkerResponse.ok(0, data: {'webFallback': true});
  }

  /// Gracefully terminates the background isolate and releases all resources.
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;

    try {
      if (_workerSendPort != null && !kIsWeb) {
        await execute(WorkerAction.shutdown).timeout(
          const Duration(seconds: 2),
          onTimeout: () => WorkerResponse.ok(0),
        );
      }
    } catch (_) {}

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;

    await _portSubscription?.cancel();
    _uiReceivePort?.close();
    await _eventsController.close();

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Worker was disposed'));
      }
    }
    _pendingRequests.clear();
  }
}

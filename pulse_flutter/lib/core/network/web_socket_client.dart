import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'ws_stub.dart'
    if (dart.library.io) 'ws_io.dart'
    if (dart.library.html) 'ws_web.dart';

const int _kCryptoIsolateThresholdBytes = 64 * 1024;

Future<Map<String, dynamic>> _decryptEnvelopeWorker(
  Map<String, dynamic> job,
) async {
  final List<int> ciphertext = base64Decode(job['ciphertext'] as String);
  final List<int> iv = base64Decode(job['iv'] as String);
  final List<int> tag = base64Decode(job['tag'] as String);
  final List<int> decrypted = await AesGcm.with256bits().decrypt(
    SecretBox(ciphertext, nonce: iv, mac: Mac(tag)),
    secretKey: SecretKey(job['key'] as List<int>),
  );
  final String decryptedStr = utf8.decode(decrypted);
  try {
    return jsonDecode(decryptedStr) as Map<String, dynamic>;
  } catch (_) {
    return jsonDecode(utf8.decode(base64Decode(decryptedStr)))
        as Map<String, dynamic>;
  }
}

Future<Map<String, dynamic>> _encryptEnvelopeWorker(
  Map<String, dynamic> job,
) async {
  final String base64Json = base64Encode(utf8.encode(job['json'] as String));
  final SecretBox secretBox = await AesGcm.with256bits().encrypt(
    utf8.encode(base64Json),
    secretKey: SecretKey(job['key'] as List<int>),
  );
  return <String, dynamic>{
    'encrypted': true,
    'data': <String, dynamic>{
      'ciphertext': base64Encode(secretBox.cipherText),
      'iv': base64Encode(secretBox.nonce),
      'tag': base64Encode(secretBox.mac.bytes),
    },
  };
}

class _FrameDecodeGate {
  int _active = 0;
  final _waiting = <Completer<void>>[];
  Future<T> run<T>(Future<T> Function() decode) async {
    if (_active >= 2) {
      final slot = Completer<void>();
      _waiting.add(slot);
      await slot.future;
    } else {
      _active++;
    }
    try {
      return await decode();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }
}

class WebSocketClient {
  WebSocketClient({
    required this.baseUrl,
    required this.readToken,
    this.onUnauthorized,
    this.connectTimeout = const Duration(seconds: 10),
    this.handshakeTimeout = const Duration(seconds: 10),
    this.heartbeatInterval = const Duration(seconds: 25),
    this.heartbeatTimeout = const Duration(seconds: 60),
    this.probeTimeout = const Duration(seconds: 8),
  });

  final String baseUrl;
  final String? Function() readToken;
  final VoidCallback? onUnauthorized;
  final Duration connectTimeout,
      handshakeTimeout,
      heartbeatInterval,
      heartbeatTimeout,
      probeTimeout;
  int _connectionEpoch = 0;
  int _sessionEpoch = 0;
  bool _disposed = false;
  Future<void>? _connectTask;
  Future<void> _incoming = Future<void>.value();
  _FrameDecodeGate _decodeGate = _FrameDecodeGate();
  int _framesInFlight = 0;
  final _clock = Stopwatch()..start();
  int _lastReceivedMs = 0;
  final Map<int, String?> _pendingTokens = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  bool _isConnecting = false;
  bool _isSocketOpen = false;
  bool _closed = false;
  Timer? _reconnectTimer;
  Completer<void>? _connectionReadyCompleter;

  // Encryption
  SecretKey? _secretKey;
  SecretKey? _keyBytesOwner;
  List<int>? _keyBytesCache;

  // Request matching
  final Uuid _uuid = Uuid();
  int _requestIdCounter = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};

  // Push notifications stream
  final StreamController<Map<String, dynamic>> _pushStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<void> _connectedStreamController =
      StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get pushStream => _pushStreamController.stream;
  Stream<void> get onConnected => _connectedStreamController.stream;

  bool get isConnected =>
      !_closed && !_disposed && _isSocketOpen && _secretKey != null;

  String _getWsUrl() {
    final uri = Uri.parse(baseUrl);
    return Uri(
      scheme: uri.scheme == 'https' || uri.scheme == 'wss' ? 'wss' : 'ws',
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/ws',
    ).toString();
  }

  Future<void> connect() {
    if (_disposed) {
      return Future.error(
        const ApiException(statusCode: 0, message: 'WebSocket client closed'),
      );
    }
    _closed = false;
    if (isConnected) return Future.value();
    final current = _connectTask;
    if (current != null) return current;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final epoch = ++_connectionEpoch;
    final task = _openConnection(epoch);
    _connectTask = task;
    task.then<void>(
      (_) {
        if (identical(_connectTask, task)) _connectTask = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_connectTask, task)) _connectTask = null;
      },
    );
    return task;
  }

  Future<void> _openConnection(int epoch) async {
    _isConnecting = true;
    final ready = Completer<void>();
    _connectionReadyCompleter = ready;
    // A transport failure can precede awaiting the handshake future.
    ready.future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    WebSocketChannel? channel;
    try {
      channel = connectWs(Uri.parse(_getWsUrl()));
      _channel = channel;
      await channel.ready.timeout(connectTimeout);
      if (epoch != _connectionEpoch || _closed || _disposed) {
        unawaited(channel.sink.close());
        throw const ApiException(statusCode: 0, message: 'Connection canceled');
      }
      _isSocketOpen = true;
      _lastReceivedMs = _clock.elapsedMilliseconds;
      _incoming = Future<void>.value();
      _decodeGate = _FrameDecodeGate();
      _framesInFlight = 0;
      _channelSubscription = channel.stream.listen(
        (raw) {
          if (epoch != _connectionEpoch || _closed || _disposed) return;
          // Decrypt at most two frames in parallel. Replies bypass slow media
          // frames; pushed edits/messages still commit strictly in wire order.
          final previous = _incoming;
          _framesInFlight++;
          if (_framesInFlight >= 8) _channelSubscription?.pause();
          final frame = _onMessage(raw, epoch, previous, _decodeGate);
          frame.then<void>((_) {
            if (epoch != _connectionEpoch) return;
            _framesInFlight--;
            if (_framesInFlight < 4) _channelSubscription?.resume();
          }, onError: (Object _, StackTrace _) {});
          _incoming = frame.then<void>(
            (_) {},
            onError: (Object _, StackTrace _) {
              _retire(epoch, 'Invalid server frame');
            },
          );
        },
        onError: (Object _) => _retire(epoch, 'Connection to server lost'),
        onDone: () => _retire(epoch, 'Connection to server closed'),
      );
      await ready.future.timeout(handshakeTimeout);
      if (epoch != _connectionEpoch || !isConnected) {
        throw const ApiException(statusCode: 0, message: 'Connection canceled');
      }
    } catch (error) {
      _retire(epoch, 'Connection handshake failed');
      if (error is ApiException) rethrow;
      throw const ApiException(
        statusCode: 0,
        message: 'Connection handshake failed',
      );
    }
  }

  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  Timer? _probeTimer;

  void _startHeartbeat() {
    _stopHeartbeat();
    if (_isBackgroundPaused || _closed || _disposed) return;
    final epoch = _connectionEpoch;
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (epoch != _connectionEpoch || !isConnected) return;
      if (_clock.elapsedMilliseconds - _lastReceivedMs >=
          heartbeatTimeout.inMilliseconds) {
        _retire(epoch, 'Connection heartbeat timed out');
        return;
      }
      _ping();
    });
  }

  void _ping() => sendRaw(
    jsonEncode(<String, dynamic>{
      'action': 'ping',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }),
  );

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  void _retire(int epoch, String reason, {bool reconnect = true}) {
    if (epoch != _connectionEpoch) return;
    ++_connectionEpoch;
    _stopHeartbeat();
    final subscription = _channelSubscription;
    _channelSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    final channel = _channel;
    _channel = null;
    _isSocketOpen = false;
    _secretKey = null;
    _keyBytesOwner = null;
    _keyBytesCache = null;
    _isConnecting = false;
    _connectTask = null;
    _failPendingRequests(reason);
    if (channel != null) {
      unawaited(channel.sink.close().catchError((Object _) {}));
    }
    if (reconnect) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_closed || _disposed || _isBackgroundPaused) return;
    _reconnectAttempts++;
    final backoff = (600 * math.pow(1.7, math.min(_reconnectAttempts - 1, 8)))
        .toInt();
    final delay = math.min(25000, backoff + math.Random().nextInt(250));
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      _reconnectTimer = null;
      if (_closed ||
          _disposed ||
          _isBackgroundPaused ||
          isConnected ||
          _isConnecting) {
        return;
      }
      unawaited(connect().catchError((Object _) {}));
    });
  }

  void reconnectNow() {
    if (_closed || _disposed || _isBackgroundPaused) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    if (isConnected &&
        _clock.elapsedMilliseconds - _lastReceivedMs >=
            heartbeatTimeout.inMilliseconds) {
      _retire(
        _connectionEpoch,
        'Connection stale after resume',
        reconnect: false,
      );
    }
    if (isConnected) {
      final epoch = _connectionEpoch;
      final observed = _lastReceivedMs;
      _ping();
      _probeTimer?.cancel();
      _probeTimer = Timer(probeTimeout, () {
        if (epoch == _connectionEpoch &&
            isConnected &&
            _lastReceivedMs <= observed) {
          _retire(epoch, 'Connection probe timed out');
        }
      });
    } else if (!_isConnecting) {
      unawaited(connect().catchError((Object _) {}));
    }
  }

  void _failPendingRequests(String reason) {
    final List<Completer<Map<String, dynamic>>> pending = _pendingRequests
        .values
        .toList();
    _pendingRequests.clear();
    _pendingTokens.clear();
    for (final Completer<Map<String, dynamic>> c in pending) {
      if (!c.isCompleted) {
        c.completeError(ApiException(statusCode: 0, message: reason));
      }
    }
    if (_connectionReadyCompleter != null &&
        !_connectionReadyCompleter!.isCompleted) {
      _connectionReadyCompleter!.completeError(
        ApiException(statusCode: 0, message: reason),
      );
    }
    _connectionReadyCompleter = null;
  }

  Future<void> _onMessage(
    dynamic rawData,
    int epoch,
    Future<void> previous,
    _FrameDecodeGate gate,
  ) async {
    if (epoch != _connectionEpoch || _closed || _disposed) return;
    try {
      if (rawData is List<int>) {
        // Binary frame — try to decode as UTF-8 string first
        rawData = utf8.decode(rawData);
      }

      if (rawData is! String) {
        debugPrint(
          '[WebSocketClient] Received unknown data type: ${rawData.runtimeType}',
        );
        return;
      }

      // Try to parse as JSON. If it fails, try base64-decode first.
      Map<String, dynamic>? parsedOuter;
      try {
        final dynamic decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) {
          parsedOuter = decoded;
        }
      } catch (_) {
        // Not JSON — maybe base64-encoded JSON or base64-encoded encrypted blob
        try {
          final List<int> bytes = base64Decode(rawData);
          final dynamic decoded = jsonDecode(utf8.decode(bytes));
          if (decoded is Map<String, dynamic>) {
            parsedOuter = decoded;
            debugPrint('[WebSocketClient] Received legacy envelope');
          }
        } catch (e2) {
          debugPrint('[WebSocketClient] Invalid incoming envelope');
          return;
        }
      }

      if (parsedOuter == null) return;
      if (epoch != _connectionEpoch || _closed || _disposed) return;
      _lastReceivedMs = _clock.elapsedMilliseconds;
      _probeTimer?.cancel();
      _probeTimer = null;

      Map<String, dynamic> msg;
      if (parsedOuter['encrypted'] == true) {
        if (_secretKey == null) {
          debugPrint('[WebSocketClient] Got encrypted msg but no key yet!');
          return;
        }
        try {
          msg = await gate.run(() => _decryptMessage(parsedOuter!));
          if (epoch != _connectionEpoch || _closed || _disposed) return;
        } catch (e) {
          _retire(epoch, 'Invalid encrypted server frame');
          return;
        }
      } else {
        msg = parsedOuter;
      }

      final String? action = msg['action'] as String?;
      debugPrint('[WebSocketClient] Received action: $action');

      // Key exchange
      if (action == 'key_exchange') {
        final String? keyStr = msg['key'] as String?;
        if (keyStr != null) {
          final List<int> keyBytes = base64Decode(keyStr);
          debugPrint(
            '[WebSocketClient] Key received: ${keyBytes.length} bytes',
          );
          if (keyBytes.length != 32) {
            _retire(epoch, 'Invalid connection key');
            return;
          }
          _secretKey = SecretKey(keyBytes);
          _isConnecting = false;
          _reconnectAttempts = 0;
          _startHeartbeat();
          debugPrint('[WebSocketClient] Key exchange complete ✓');
          if (_connectionReadyCompleter != null &&
              !_connectionReadyCompleter!.isCompleted) {
            _connectionReadyCompleter!.complete();
          }
          if (!_connectedStreamController.isClosed) {
            _connectedStreamController.add(null);
          }
        }
        return;
      }

      if (action == 'ping' || action == 'pong') {
        return;
      }

      // Server error
      final String? error = msg['error'] as String?;
      final int? requestId = msg['request_id'] is int
          ? msg['request_id'] as int
          : int.tryParse(msg['request_id']?.toString() ?? '');

      if (requestId != null) {
        final Completer<Map<String, dynamic>>? completer = _pendingRequests
            .remove(requestId);
        final sentToken = _pendingTokens.remove(requestId);
        if (completer != null && !completer.isCompleted) {
          if (error != null && error.isNotEmpty) {
            debugPrint('[WebSocketClient] Request $requestId rejected');
            final String? resAction = msg['action'] as String?;
            final bool isAuthAction =
                resAction == 'login' ||
                resAction == 'login_nios_id' ||
                resAction == 'verify_2fa' ||
                resAction == 'register';
            if (sentToken == readToken() &&
                !isAuthAction &&
                (error.toLowerCase().contains('unauthorized') ||
                    error.toLowerCase().contains('invalid token') ||
                    error.toLowerCase().contains('could not validate'))) {
              onUnauthorized?.call();
            }
            completer.completeError(
              ApiException(
                statusCode: 400,
                message: error,
                payload: msg['payload'],
              ),
            );
          } else {
            completer.complete(msg);
          }
        }
      } else {
        // Only stateful pushes wait for older frames. Request acknowledgements
        // above remain responsive while a file response decrypts in an isolate.
        await previous;
        if (epoch != _connectionEpoch || _closed || _disposed) return;
        if (action != null && action.isNotEmpty) {
          _pushStreamController.add(msg);
        }
      }
    } catch (e) {
      debugPrint('[WebSocketClient] Invalid server message');
    } finally {
      await previous;
    }
  }

  bool _safeToRetry(String action) =>
      action.startsWith('get_') ||
      action.startsWith('list_') ||
      action.startsWith('search_') ||
      const {
        'history',
        'search',
        'message_replies',
        'mark_read',
        'ping',
        'heartbeat',
      }.contains(action);

  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    final session = _sessionEpoch;
    final token = readToken();
    var attempts = 0;
    while (true) {
      if (_disposed || session != _sessionEpoch || token != readToken()) {
        throw const ApiException(statusCode: 0, message: 'Request canceled');
      }
      try {
        return await _doRequest(
          action,
          payload: payload,
          timeout: timeout,
          session: session,
          token: token,
        );
      } on ApiException catch (error) {
        if (error.statusCode != 0 ||
            !_safeToRetry(action) ||
            attempts >= maxRetries ||
            session != _sessionEpoch ||
            token != readToken() ||
            _closed ||
            _disposed) {
          rethrow;
        }
        attempts++;
        // A single slow endpoint must not tear down a healthy shared socket.
        await Future<void>.delayed(Duration(milliseconds: 60 * attempts));
      }
    }
  }

  Future<dynamic> _doRequest(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    required int session,
    required String? token,
  }) async {
    await connect();
    if (session != _sessionEpoch || token != readToken()) {
      throw const ApiException(statusCode: 0, message: 'Request canceled');
    }
    final channel = _channel;
    final epoch = _connectionEpoch;
    if (!isConnected || channel == null || _secretKey == null) {
      throw const ApiException(
        statusCode: 0,
        message: 'Encrypted connection unavailable',
      );
    }
    if (_pendingRequests.length >= 100) {
      throw const ApiException(
        statusCode: 429,
        message: 'Too many pending requests',
      );
    }
    final id = ++_requestIdCounter;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;
    _pendingTokens[id] = token;
    final response = completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(id);
        _pendingTokens.remove(id);
        throw const ApiException(
          statusCode: 0,
          message: 'Server response timed out',
        );
      },
    );
    response.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      final request = <String, dynamic>{
        'action': action,
        'payload': payload ?? <String, dynamic>{},
        'request_id': id,
        'message_id': _uuid.v4(),
        if (token != null && token.isNotEmpty) 'token': token,
      };
      final encrypted = await _encryptMessage(request);
      if (epoch != _connectionEpoch ||
          !identical(_channel, channel) ||
          !isConnected) {
        throw const ApiException(statusCode: 0, message: 'Connection replaced');
      }
      channel.sink.add(jsonEncode(encrypted));
    } catch (error, stack) {
      _pendingRequests.remove(id);
      _pendingTokens.remove(id);
      if (!completer.isCompleted) completer.completeError(error, stack);
    }
    return (await response)['payload'];
  }

  Future<List<int>> _secretKeyBytes() async {
    SecretKey? key = _secretKey;
    if (key == null) {
      if (_isConnecting && _connectionReadyCompleter != null) {
        try {
          await _connectionReadyCompleter!.future.timeout(
            const Duration(seconds: 8),
          );
          key = _secretKey;
        } catch (_) {}
      }
      if (key == null) {
        throw ApiException(statusCode: 0, message: 'Connection to server lost');
      }
    }
    final List<int>? cached = _keyBytesCache;
    if (cached != null && identical(_keyBytesOwner, key)) {
      return cached;
    }
    final List<int> bytes = await key.extractBytes();
    _keyBytesOwner = key;
    _keyBytesCache = bytes;
    return bytes;
  }

  Future<Map<String, dynamic>> _encryptMessage(Map<String, dynamic> msg) async {
    final String jsonStr = jsonEncode(msg);
    final Map<String, dynamic> job = <String, dynamic>{
      'key': await _secretKeyBytes(),
      'json': jsonStr,
    };
    if (!kIsWeb && jsonStr.length >= _kCryptoIsolateThresholdBytes) {
      return compute(_encryptEnvelopeWorker, job);
    }
    return _encryptEnvelopeWorker(job);
  }

  Future<Map<String, dynamic>> _decryptMessage(
    Map<String, dynamic> outerMsg,
  ) async {
    final Map<String, dynamic> data = asStringMap(outerMsg['data']);
    final String? ciphertextB64 = data['ciphertext'] as String?;
    final String? ivB64 = data['iv'] as String?;
    final String? tagB64 = data['tag'] as String?;
    if (ciphertextB64 == null || ivB64 == null || tagB64 == null) {
      throw StateError('Missing ciphertext, iv, or tag in encrypted message');
    }

    final Map<String, dynamic> job = <String, dynamic>{
      'key': await _secretKeyBytes(),
      'ciphertext': ciphertextB64,
      'iv': ivB64,
      'tag': tagB64,
    };
    if (!kIsWeb && ciphertextB64.length >= _kCryptoIsolateThresholdBytes) {
      return compute(_decryptEnvelopeWorker, job);
    }
    return _decryptEnvelopeWorker(job);
  }

  void sendRaw(String data) {
    if (!isConnected || _channel == null) return;
    try {
      _channel!.sink.add(data);
    } catch (_) {
      _retire(_connectionEpoch, 'Connection write failed');
    }
  }

  bool _isBackgroundPaused = false;
  bool get isBackgroundPaused => _isBackgroundPaused;

  /// Pauses periodic heartbeat pings and auto-reconnect backoff while the application is in the background.
  void pauseForBackground() {
    if (_isBackgroundPaused) return;
    _isBackgroundPaused = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    debugPrint('[WebSocketClient] Paused for background energy saving.');
  }

  /// Resumes normal WebSocket activity when the application returns to the foreground.
  void resumeFromBackground() {
    if (!_isBackgroundPaused) return;
    _isBackgroundPaused = false;
    if (_closed || _disposed) return;
    if (isConnected) _startHeartbeat();
    reconnectNow();
  }

  void disconnect() {
    _closed = true;
    ++_sessionEpoch;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _retire(_connectionEpoch, 'WebSocket disconnected', reconnect: false);
  }

  void close() {
    if (_disposed) return;
    disconnect();
    _disposed = true;
    _connectedStreamController.close();
    _pushStreamController.close();
  }
}

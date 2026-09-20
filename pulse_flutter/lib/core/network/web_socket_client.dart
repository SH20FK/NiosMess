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
    Map<String, dynamic> job) async {
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
    Map<String, dynamic> job) async {
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

class WebSocketClient {
  WebSocketClient({
    required this.baseUrl,
    required this.readToken,
    this.onUnauthorized,
  });

  final String baseUrl;
  final String? Function() readToken;
  final VoidCallback? onUnauthorized;

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

  bool get isConnected => _isSocketOpen && _secretKey != null;

  String _getWsUrl() {
    final Uri uri = Uri.parse(baseUrl);
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return 'wss://ni-os.ru/ws';
    }
    final String scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final String portPart = (uri.hasPort &&
            !((uri.scheme == 'https' && uri.port == 443) ||
                (uri.scheme == 'http' && uri.port == 80)))
        ? ':${uri.port}'
        : '';
    return '$scheme://${uri.host}$portPart/ws';
  }

  Future<void> connect() async {
    _closed = false;
    if (isConnected) return;
    if (_isConnecting) {
      await _connectionReadyCompleter?.future;
      return;
    }

    _isConnecting = true;
    _connectionReadyCompleter = Completer<void>();

    final String wsUrl = _getWsUrl();
    debugPrint('[WebSocketClient] Connecting to $wsUrl ...');

    try {
      final uri = Uri.parse(wsUrl);
      _channel = connectWs(uri);
      await _channel!.ready.timeout(const Duration(seconds: 10));
      _isSocketOpen = true;
      debugPrint('[WebSocketClient] Socket open, waiting for key exchange...');

      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[WebSocketClient] Connection failed: $e');
      _isConnecting = false;
      _isSocketOpen = false;
      if (_connectionReadyCompleter != null &&
          !_connectionReadyCompleter!.isCompleted) {
        _connectionReadyCompleter!
            .completeError(ApiException(statusCode: 0, message: '$e'));
      }
      _connectionReadyCompleter = null;
      _scheduleReconnect();
      rethrow;
    }

    try {
      await _connectionReadyCompleter!.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      _isConnecting = false;
      _isSocketOpen = false;
      _secretKey = null;
      _channel?.sink.close();
      _channel = null;
      rethrow;
    }
  }

  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (isConnected) {
        sendRaw(jsonEncode(<String, dynamic>{
          'action': 'ping',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _onError(Object error) {
    debugPrint('[WebSocketClient] Socket error: $error');
    _stopHeartbeat();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _failPendingRequests('Connection to server lost');
    _channel?.sink.close();
    _channel = null;
    _isSocketOpen = false;
    _secretKey = null;
    _isConnecting = false;
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WebSocketClient] Socket closed by server.');
    _stopHeartbeat();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _failPendingRequests('Connection to server closed');
    _channel?.sink.close();
    _channel = null;
    _isSocketOpen = false;
    _secretKey = null;
    _isConnecting = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final int backoffMs =
        (1200 * math.pow(1.8, math.min(_reconnectAttempts, 6))).toInt();
    final int jitterMs = math.Random().nextInt(400);
    final int totalDelay = math.min(25000, backoffMs + jitterMs);

    _reconnectTimer = Timer(Duration(milliseconds: totalDelay), () {
      if (!_closed && !isConnected && !_isConnecting) {
        connect().catchError((e) {
          debugPrint('[WebSocketClient] Reconnect error: $e');
        });
      }
    });
  }

  /// Immediately force a reconnection attempt without waiting for backoff.
  /// Used when the application resumes from background or network connectivity is restored.
  void reconnectNow() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    if (!isConnected && !_isConnecting) {
      debugPrint('[WebSocketClient] Immediate reconnect triggered');
      connect().catchError((e) {
        debugPrint('[WebSocketClient] reconnectNow error: $e');
      });
    }
  }

  void _failPendingRequests(String reason) {
    final List<Completer<Map<String, dynamic>>> pending =
        _pendingRequests.values.toList();
    _pendingRequests.clear();
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

  void _onMessage(dynamic rawData) async {
    try {
      if (rawData is List<int>) {
        // Binary frame — try to decode as UTF-8 string first
        rawData = utf8.decode(rawData);
      }

      if (rawData is! String) {
        debugPrint('[WebSocketClient] Received unknown data type: ${rawData.runtimeType}');
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
            debugPrint('[WebSocketClient] Received base64-encoded message (unencrypted): ${parsedOuter['action']} / error: ${parsedOuter['error']}');
          }
        } catch (e2) {
          debugPrint('[WebSocketClient] Could not parse incoming message: $e2');
          return;
        }
      }

      if (parsedOuter == null) return;

      Map<String, dynamic> msg;
      if (parsedOuter['encrypted'] == true) {
        if (_secretKey == null) {
          debugPrint('[WebSocketClient] Got encrypted msg but no key yet!');
          return;
        }
        try {
          msg = await _decryptMessage(parsedOuter);
        } catch (e) {
          debugPrint('[WebSocketClient] Decryption failed: $e');
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
          debugPrint('[WebSocketClient] Key received: ${keyBytes.length} bytes');
          if (keyBytes.length != 32) {
            debugPrint('[WebSocketClient] WARNING: Key is not 32 bytes! Got ${keyBytes.length}');
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
        final Completer<Map<String, dynamic>>? completer =
            _pendingRequests.remove(requestId);
        if (completer != null) {
          if (error != null && error.isNotEmpty) {
            debugPrint('[WebSocketClient] Request $requestId error: $error');
            if (error.toLowerCase().contains('unauthorized') ||
                error.toLowerCase().contains('invalid token') ||
                error.toLowerCase().contains('could not validate')) {
              onUnauthorized?.call();
            }
            completer.completeError(
              ApiException(statusCode: 400, message: error, payload: msg['payload']),
            );
          } else {
            completer.complete(msg);
          }
        }
      } else {
        // Push notification (no request_id)
        if (action != null && action.isNotEmpty) {
          _pushStreamController.add(msg);
        }
      }
    } catch (e, stack) {
      debugPrint('[WebSocketClient] _onMessage error: $e\n$stack');
    }
  }

  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await _doRequest(action, payload: payload, timeout: timeout);
      } on ApiException catch (e) {
        final bool isConnectionFlake = e.statusCode == 0 ||
            e.message.toLowerCase().contains('connection') ||
            e.message.toLowerCase().contains('socket') ||
            e.message.toLowerCase().contains('timed out');
        if (isConnectionFlake && attempts <= maxRetries && !_closed) {
          debugPrint('[WebSocketClient] $action failed with ${e.message}, retrying ($attempts/$maxRetries)...');
          _isSocketOpen = false;
          _secretKey = null;
          _isConnecting = false;
          _channel?.sink.close();
          _channel = null;
          await Future<void>.delayed(Duration(milliseconds: 300 * attempts));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<dynamic> _doRequest(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await connect();

    final int requestId = ++_requestIdCounter;
    final Completer<Map<String, dynamic>> completer =
        Completer<Map<String, dynamic>>();
    if (_pendingRequests.length >= 100) {
      completer.completeError(StateError('Too many pending WebSocket requests'));
      return completer.future;
    }
    _pendingRequests[requestId] = completer;

    final Map<String, dynamic> requestObj = <String, dynamic>{
      'action': action,
      'payload': payload ?? <String, dynamic>{},
      'request_id': requestId,
      'message_id': _uuid.v4(),
    };

    final String? token = readToken();
    if (token != null && token.isNotEmpty) {
      requestObj['token'] = token;
    }

    try {
      final String jsonStr = jsonEncode(requestObj);
      debugPrint('[WebSocketClient] → $action (req=$requestId, ${jsonStr.length} chars)');

      String toSend;
      if (_secretKey != null) {
        final Map<String, dynamic> encryptedMsg =
            await _encryptMessage(requestObj);
        toSend = jsonEncode(encryptedMsg);
      } else {
        // Should not happen after connect() succeeds, but log a warning
        debugPrint('[WebSocketClient] WARNING: Sending without encryption!');
        toSend = jsonStr;
      }

      if (!_isSocketOpen || _channel == null) {
        throw ApiException(statusCode: 0, message: 'Connection to server lost');
      }

      _channel!.sink.add(toSend);
    } catch (e) {
      _pendingRequests.remove(requestId);
      completer.completeError(e);
      return completer.future;
    }

    final Map<String, dynamic> response = await completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw ApiException(
          statusCode: 0,
          message: 'Server response timed out',
        );
      },
    );
    return response['payload'];
  }

  Future<List<int>> _secretKeyBytes() async {
    final SecretKey? key = _secretKey;
    if (key == null) {
      throw ApiException(statusCode: 0, message: 'Connection to server lost');
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

  Future<Map<String, dynamic>> _encryptMessage(
      Map<String, dynamic> msg) async {
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
      Map<String, dynamic> outerMsg) async {
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
    if (_isSocketOpen && _channel != null) {
      _channel!.sink.add(data);
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
    debugPrint('[WebSocketClient] Resumed from background.');
    if (isConnected) {
      _startHeartbeat();
      // Send an immediate keepalive ping to confirm connection viability
      sendRaw(jsonEncode(<String, dynamic>{
        'action': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
    } else if (!_closed && !_isConnecting) {
      connect();
    }
  }

  void disconnect() {
    _closed = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _failPendingRequests('WebSocket disconnected');
    _channel?.sink.close();
    _channel = null;
    _isSocketOpen = false;
    _secretKey = null;
    _isConnecting = false;
  }

  void close() {
    disconnect();
    _closed = true;
    _connectedStreamController.close();
  }
}

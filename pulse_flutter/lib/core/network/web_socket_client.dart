import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'ws_stub.dart'
    if (dart.library.io) 'ws_io.dart'
    if (dart.library.html) 'ws_web.dart';

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
  final AesGcm _algorithm = AesGcm.with256bits();
  SecretKey? _secretKey;

  // Request matching
  final Uuid _uuid = Uuid();
  int _requestIdCounter = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};

  // Push notifications stream
  final StreamController<Map<String, dynamic>> _pushStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get pushStream => _pushStreamController.stream;

  bool get isConnected => _isSocketOpen && _secretKey != null;

  String _getWsUrl() {
    final Uri uri = Uri.parse(baseUrl);
    final String scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final String portPart = (uri.hasPort &&
            !((uri.scheme == 'https' && uri.port == 443) ||
                (uri.scheme == 'http' && uri.port == 80)))
        ? ':${uri.port}'
        : '';
    return '$scheme://${uri.host}$portPart/ws';
  }

  Future<void> connect() async {
    if (_closed) return;
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

    await _connectionReadyCompleter!.future;
  }

  void _onError(Object error) {
    debugPrint('[WebSocketClient] Socket error: $error');
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _failPendingRequests('Ошибка соединения с сервером');
    _channel?.sink.close();
    _channel = null;
    _isSocketOpen = false;
    _secretKey = null;
    _isConnecting = false;
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WebSocketClient] Socket closed by server.');
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _failPendingRequests('Соединение с сервером закрыто');
    _channel?.sink.close();
    _channel = null;
    _isSocketOpen = false;
    _secretKey = null;
    _isConnecting = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_closed && !isConnected && !_isConnecting) {
        connect().catchError((e) {
          debugPrint('[WebSocketClient] Reconnect error: $e');
        });
      }
    });
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
          debugPrint('[WebSocketClient] Key exchange complete ✓');
          if (_connectionReadyCompleter != null &&
              !_connectionReadyCompleter!.isCompleted) {
            _connectionReadyCompleter!.complete();
          }
        }
        return;
      }

      // Server error
      final String? error = msg['error'] as String?;
      final int? requestId = msg['request_id'] as int?;

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
        throw ApiException(statusCode: 0, message: 'Соединение с сервером разорвано');
      }

      _channel!.sink.add(toSend);
    } catch (e) {
      _pendingRequests.remove(requestId);
      completer.completeError(e);
    }

    final Map<String, dynamic> response = await completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw ApiException(
          statusCode: 0,
          message: 'Превышено время ожидания ответа от сервера',
        );
      },
    );
    return response['payload'];
  }

  Future<Map<String, dynamic>> _encryptMessage(
      Map<String, dynamic> msg) async {
    final String jsonStr = jsonEncode(msg);
    // Protocol: server expects base64(json) as AES-GCM plaintext, not raw json.
    final String base64Json = base64Encode(utf8.encode(jsonStr));
    final List<int> messageBytes = utf8.encode(base64Json);

    final SecretBox secretBox = await _algorithm.encrypt(
      messageBytes,
      secretKey: _secretKey!,
    );

    final String ciphertextB64 = base64Encode(secretBox.cipherText);
    final String ivB64 = base64Encode(secretBox.nonce);
    final String tagB64 = base64Encode(secretBox.mac.bytes);

    debugPrint('[WebSocketClient] Encrypted: iv=${ivB64.length}chars, '
        'ct=${ciphertextB64.length}chars, tag=${tagB64.length}chars');

    return <String, dynamic>{
      'encrypted': true,
      'data': <String, dynamic>{
        'ciphertext': ciphertextB64,
        'iv': ivB64,
        'tag': tagB64,
      },
    };
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

    final List<int> ciphertext = base64Decode(ciphertextB64);
    final List<int> iv = base64Decode(ivB64);
    final List<int> tag = base64Decode(tagB64);

    final SecretBox secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac(tag));
    final List<int> decrypted =
        await _algorithm.decrypt(secretBox, secretKey: _secretKey!);

    final String decryptedStr = utf8.decode(decrypted);
    // Protocol: server encrypts base64(json), so decrypted text is a base64 string.
    // Try raw JSON first for forward-compatibility, then base64-decode.
    try {
      return jsonDecode(decryptedStr) as Map<String, dynamic>;
    } catch (_) {
      final String jsonStr = utf8.decode(base64Decode(decryptedStr));
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    }
  }

  void close() {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _failPendingRequests('WebSocket закрыт');
    _channel?.sink.close();
    _channel = null;
    _isSocketOpen = false;
    _secretKey = null;
    _isConnecting = false;
  }
}

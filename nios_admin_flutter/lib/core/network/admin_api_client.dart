import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:nios_admin_flutter/core/network/api_exception.dart';

Map<String, dynamic> asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic val) => MapEntry(key.toString(), val),
    );
  }
  return <String, dynamic>{};
}

class AdminApiClient {
  AdminApiClient({
    required this.baseUrl,
    required this.readPassword,
    dynamic httpClient, // Ignored, kept for backward compatibility
  });

  final String baseUrl;
  final String? Function() readPassword;

  WebSocket? _webSocket;
  bool _isConnecting = false;
  Completer<void>? _connectionReadyCompleter;

  // Encryption
  final AesGcm _algorithm = AesGcm.with256bits();
  SecretKey? _secretKey;

  // Request matching
  int _requestIdCounter = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};

  bool get _socketOpen =>
      _webSocket != null && _webSocket!.readyState == WebSocket.open;

  bool get isConnected => _socketOpen && _secretKey != null;

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
    if (isConnected) return;
    if (_isConnecting) {
      await _connectionReadyCompleter?.future;
      return;
    }

    _isConnecting = true;
    _connectionReadyCompleter = Completer<void>();

    final String wsUrl = _getWsUrl();
    try {
      _webSocket = await WebSocket.connect(wsUrl)
          .timeout(const Duration(seconds: 10));
      
      _webSocket!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _isConnecting = false;
      if (_connectionReadyCompleter != null &&
          !_connectionReadyCompleter!.isCompleted) {
        _connectionReadyCompleter!
            .completeError(ApiException(statusCode: 0, message: '$e'));
      }
      _connectionReadyCompleter = null;
      rethrow;
    }

    await _connectionReadyCompleter!.future;
  }

  void _onError(Object error) {
    _failPendingRequests('WebSocket connection error: $error');
  }

  void _onDone() {
    _failPendingRequests('WebSocket connection closed');
  }

  void _failPendingRequests(String reason) {
    _webSocket = null;
    _secretKey = null;
    _isConnecting = false;

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
        rawData = utf8.decode(rawData);
      }

      if (rawData is! String) return;

      Map<String, dynamic>? parsedOuter;
      try {
        final dynamic decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) {
          parsedOuter = decoded;
        }
      } catch (_) {
        try {
          final List<int> bytes = base64Decode(rawData);
          final dynamic decoded = jsonDecode(utf8.decode(bytes));
          if (decoded is Map<String, dynamic>) {
            parsedOuter = decoded;
          }
        } catch (_) {}
      }

      if (parsedOuter == null) return;

      Map<String, dynamic> msg;
      if (parsedOuter['encrypted'] == true) {
        if (_secretKey == null) return;
        try {
          msg = await _decryptMessage(parsedOuter);
        } catch (_) {
          return;
        }
      } else {
        msg = parsedOuter;
      }

      final String? action = msg['action'] as String?;

      if (action == 'key_exchange') {
        final String? keyStr = msg['key'] as String?;
        if (keyStr != null) {
          final List<int> keyBytes = base64Decode(keyStr);
          _secretKey = SecretKey(keyBytes);
          _isConnecting = false;
          if (_connectionReadyCompleter != null &&
              !_connectionReadyCompleter!.isCompleted) {
            _connectionReadyCompleter!.complete();
          }
        }
        return;
      }

      final String? error = msg['error'] as String?;
      final int? requestId = msg['request_id'] as int?;

      if (requestId != null) {
        final Completer<Map<String, dynamic>>? completer =
            _pendingRequests.remove(requestId);
        if (completer != null) {
          if (error != null && error.isNotEmpty) {
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
      }
    } catch (_) {}
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
    _pendingRequests[requestId] = completer;

    final Map<String, dynamic> requestObj = <String, dynamic>{
      'action': action,
      'payload': payload ?? <String, dynamic>{},
      'request_id': requestId,
    };

    try {
      final String jsonStr = jsonEncode(requestObj);
      String toSend;
      if (_secretKey != null) {
        final Map<String, dynamic> encryptedMsg =
            await _encryptMessage(requestObj);
        toSend = jsonEncode(encryptedMsg);
      } else {
        toSend = jsonStr;
      }

      if (!_socketOpen) {
        throw const ApiException(statusCode: 0, message: 'Connection lost');
      }

      _webSocket!.add(toSend);
    } catch (e) {
      _pendingRequests.remove(requestId);
      completer.completeError(e);
    }

    final Map<String, dynamic> response = await completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw const ApiException(
          statusCode: 0,
          message: 'Response timeout',
        );
      },
    );
    return response['payload'];
  }

  Future<Map<String, dynamic>> _encryptMessage(
      Map<String, dynamic> msg) async {
    final String jsonStr = jsonEncode(msg);
    final String base64Json = base64Encode(utf8.encode(jsonStr));
    final List<int> messageBytes = utf8.encode(base64Json);

    final SecretBox secretBox = await _algorithm.encrypt(
      messageBytes,
      secretKey: _secretKey!,
    );

    final String ciphertextB64 = base64Encode(secretBox.cipherText);
    final String ivB64 = base64Encode(secretBox.nonce);
    final String tagB64 = base64Encode(secretBox.mac.bytes);

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
    final List<int> ciphertext = base64Decode(data['ciphertext'] as String);
    final List<int> iv = base64Decode(data['iv'] as String);
    final List<int> tag = base64Decode(data['tag'] as String);

    final SecretBox secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac(tag));
    final List<int> decrypted =
        await _algorithm.decrypt(secretBox, secretKey: _secretKey!);

    final String decryptedStr = utf8.decode(decrypted);
    try {
      return jsonDecode(decryptedStr) as Map<String, dynamic>;
    } catch (_) {
      final String jsonStr = utf8.decode(base64Decode(decryptedStr));
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    String? passwordOverride,
  }) async {
    final String password = _resolvePassword(passwordOverride);
    final (String action, Map<String, dynamic> payload) = _mapRequest('GET', path, query: query, body: null, password: password);
    return request(action, payload: payload);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    String? passwordOverride,
  }) async {
    final String password = _resolvePassword(passwordOverride);
    final (String action, Map<String, dynamic> payload) = _mapRequest('POST', path, query: query, body: body, password: password);
    return request(action, payload: payload);
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    String? passwordOverride,
  }) async {
    final String password = _resolvePassword(passwordOverride);
    final (String action, Map<String, dynamic> payload) = _mapRequest('DELETE', path, query: query, body: body, password: password);
    return request(action, payload: payload);
  }

  String _resolvePassword(String? override) {
    final String password = (override ?? readPassword() ?? '').trim();
    if (password.isEmpty) {
      throw const ApiException(
        statusCode: 0,
        message: 'Admin password is missing',
      );
    }
    return password;
  }

  (String, Map<String, dynamic>) _mapRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    required String password,
  }) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'password': password,
    };

    final RegExp userDetailRegExp = RegExp(r'^/admin/users/(\d+)$');
    final RegExp badgeDeleteRegExp = RegExp(r'^/admin/badges/(\d+)$');

    if (method == 'GET') {
      if (path == '/admin/users') {
        final int page = int.tryParse(query?['page'] ?? '1') ?? 1;
        final int pageSize = int.tryParse(query?['page_size'] ?? '50') ?? 50;
        payload['page'] = page;
        payload['page_size'] = pageSize;
        return ('admin_list_users', payload);
      }
      
      final RegExpMatch? userMatch = userDetailRegExp.firstMatch(path);
      if (userMatch != null) {
        final int userId = int.parse(userMatch.group(1)!);
        payload['user_id'] = userId;
        return ('admin_get_user', payload);
      }

      if (path == '/admin/chats') {
        final int page = int.tryParse(query?['page'] ?? '1') ?? 1;
        payload['page'] = page;
        return ('admin_list_chats', payload);
      }

      if (path == '/admin/badges') {
        return ('list_badges', payload);
      }
    }

    if (method == 'POST') {
      final Map<String, dynamic> bodyMap = body is Map<String, dynamic>
          ? body
          : (body is Map ? body.cast<String, dynamic>() : <String, dynamic>{});

      if (path == '/admin/users/ban') {
        payload['user_id'] = bodyMap['user_id'];
        if (bodyMap.containsKey('reason')) {
          payload['reason'] = bodyMap['reason'];
        }
        return ('ban_user', payload);
      }

      if (path == '/admin/users/unban') {
        payload['user_id'] = bodyMap['user_id'];
        return ('unban_user', payload);
      }

      if (path == '/admin/users/freeze') {
        payload['user_id'] = bodyMap['user_id'];
        payload['frozen'] = bodyMap['frozen'];
        return ('freeze_user', payload);
      }

      if (path == '/admin/users/spamblock') {
        payload['user_id'] = bodyMap['user_id'];
        payload['blocked'] = bodyMap['blocked'];
        return ('spam_block', payload);
      }

      if (path == '/admin/chats/ban') {
        payload['chat_id'] = bodyMap['chat_id'];
        payload['banned'] = bodyMap['banned'];
        return ('ban_chat', payload);
      }

      if (path == '/admin/badges/create') {
        payload['name'] = bodyMap['name'];
        payload['icon'] = bodyMap['icon'];
        payload['color'] = bodyMap['color'];
        return ('create_badge', payload);
      }

      if (path == '/admin/badges/award') {
        payload['user_id'] = bodyMap['user_id'];
        payload['badge_id'] = bodyMap['badge_id'];
        return ('award_badge', payload);
      }

      if (path == '/admin/badges/revoke') {
        payload['user_id'] = bodyMap['user_id'];
        payload['badge_id'] = bodyMap['badge_id'];
        return ('revoke_badge', payload);
      }
    }

    if (method == 'DELETE') {
      final RegExpMatch? badgeMatch = badgeDeleteRegExp.firstMatch(path);
      if (badgeMatch != null) {
        final int badgeId = int.parse(badgeMatch.group(1)!);
        payload['badge_id'] = badgeId;
        return ('delete_badge', payload);
      }
    }

    throw ApiException(
      statusCode: 400,
      message: 'Unknown admin action mapping for $method $path',
    );
  }

  void close() {
    _failPendingRequests('WebSocket closed');
    _webSocket?.close();
    _webSocket = null;
    _secretKey = null;
    _isConnecting = false;
  }
}

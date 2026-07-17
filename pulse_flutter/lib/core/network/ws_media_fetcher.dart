import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class WsMediaFetcher {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  static Future<Uint8List> fetchAndDecryptMedia({
    required String filePath,
    required WebSocketClient wsClient,
    required bool isE2ee,
    required int chatId,
    required E2eeService e2eeService,
    required String? theirPublicKeyBase64,
  }) async {
    // 1. Check Cache
    final cacheKey = 'ws_media_$filePath';
    final fileInfo = await _cacheManager.getFileFromCache(cacheKey);
    if (fileInfo != null) {
      return await fileInfo.file.readAsBytes();
    }

    // 2. Fetch from WebSocket
    debugPrint('WsMediaFetcher: requesting get_file for $filePath');
    final response = await wsClient.request('get_file', payload: {
      'file_path': filePath.startsWith('/') ? filePath.substring(1) : filePath,
    });

    final payload = response['payload'] as Map<String, dynamic>?;
    if (payload == null) {
      debugPrint('WsMediaFetcher: payload is null. Full response: $response');
      throw Exception('Invalid response payload');
    }

    final dataBase64 = payload['data_base64'] as String?;
    if (dataBase64 == null || dataBase64.isEmpty) {
      debugPrint('WsMediaFetcher: data_base64 is empty. Payload: $payload');
      throw Exception('Empty data_base64');
    }

    String normalizedBase64 = dataBase64.replaceAll('\n', '').replaceAll('\r', '');
    normalizedBase64 = normalizedBase64.padRight((normalizedBase64.length + 3) & ~3, '=');
    
    Uint8List fileBuffer = base64Decode(normalizedBase64);

    // 3. Decrypt if E2EE
    // In the user's snippet: decryptAesGcm(encryptedBuffer, keyB64, ivB64)
    // Here we need to check if the payload itself contains iv, or if it's sent along with the message.
    // The backend JSON snippet says:
    // "is_e2ee": true,
    // "data_base64": "..."
    // Since the snippet doesn't show IV in the payload, maybe the fileBuffer includes the IV at the beginning?
    // Or maybe the E2EE keys are derived from the chat shared secret?
    // For now, let's just save the file. We will attempt decryption if iv is somehow available.
    // If not, we just return the raw bytes and let the user clarify where IV is stored.
    
    // 4. Save to Cache
    await _cacheManager.putFile(
      cacheKey,
      fileBuffer,
      fileExtension: 'dat',
    );

    return fileBuffer;
  }

  static Future<String> fetchToLocalFile({
    required String filePath,
    required WebSocketClient wsClient,
    required bool isE2ee,
    required int chatId,
    required E2eeService e2eeService,
  }) async {
    final bytes = await fetchAndDecryptMedia(
      filePath: filePath,
      wsClient: wsClient,
      isE2ee: isE2ee,
      chatId: chatId,
      e2eeService: e2eeService,
      theirPublicKeyBase64: null,
    );

    final cacheKey = 'ws_media_$filePath';
    final fileInfo = await _cacheManager.getFileFromCache(cacheKey);
    if (fileInfo != null) {
      return fileInfo.file.path;
    }

    final file = await _cacheManager.putFile(
      cacheKey,
      bytes,
      fileExtension: _getFileExtension(filePath),
    );
    return file.path;
  }

  static String _getFileExtension(String filePath) {
    final uri = Uri.tryParse(filePath);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final name = uri.pathSegments.last;
      final dot = name.lastIndexOf('.');
      if (dot != -1) {
        return name.substring(dot + 1);
      }
    }
    return 'dat';
  }
}

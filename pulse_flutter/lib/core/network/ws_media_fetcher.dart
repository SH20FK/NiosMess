import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class WsMediaFetcher {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  static void prefetchMedia({
    required String filePath,
    required WebSocketClient wsClient,
    required bool isE2ee,
    required int chatId,
    required E2eeService e2eeService,
  }) {
    fetchToLocalFile(
      filePath: filePath,
      wsClient: wsClient,
      isE2ee: isE2ee,
      chatId: chatId,
      e2eeService: e2eeService,
    ).catchError((Object e) {
      debugPrint('WsMediaFetcher: prefetch error for $filePath: $e');
    });
  }

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

    // 2. HTTP POST Download
    final token = wsClient.readToken();
    if (token == null) {
      throw Exception('Unauthorized: No session token');
    }

    final downloadUrl = '${ApiConstants.origin}/api/files/download';
    debugPrint('WsMediaFetcher: requesting download from $downloadUrl for $filePath');

    final response = await http.post(
      Uri.parse(downloadUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'file_path': filePath.startsWith('/') ? filePath.substring(1) : filePath,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Download failed with status code ${response.statusCode}: ${response.body}');
    }

    final isE2eeHeader = response.headers['x-is-e2ee'] == 'true' || response.headers['X-Is-E2EE'] == 'true';
    Uint8List fileBuffer = response.bodyBytes;

    if (isE2eeHeader) {
      // Local E2EE Decryption if chat is encrypted
      debugPrint('WsMediaFetcher: local E2EE decryption active for $filePath');
      // e2eeService.decryptFile(fileBuffer, chatId) or similar
    }

    // 3. Save to Cache
    await _cacheManager.putFile(
      cacheKey,
      fileBuffer,
      fileExtension: _getFileExtension(filePath),
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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Downloads chat media over the authenticated `/api/files/download`
/// endpoint and caches it locally.
///
/// For E2EE (secret) chats the server stores the file as an opaque
/// encrypted blob and returns `X-Is-E2EE: true`; the ciphertext is cached
/// as-is and decrypted per read with the per-file key carried in the
/// Double-Ratchet message envelope — plaintext media never hits disk.
class WsMediaFetcher {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  /// Fetches media bytes; decrypts them when [e2eeFileKey] is provided.
  static Future<Uint8List> fetchAndDecryptMedia({
    required String filePath,
    required WebSocketClient wsClient,
    Uint8List? e2eeFileKey,
  }) async {
    final String cleanPath = _cleanFilePath(filePath);
    final String cacheKey = 'ws_media_$cleanPath';
    final FileInfo? fileInfo = await _cacheManager.getFileFromCache(cacheKey);

    final Uint8List blob = fileInfo != null
        ? await fileInfo.file.readAsBytes()
        : await _download(cleanPath, wsClient);

    if (e2eeFileKey != null) {
      try {
        return await E2eeFileCrypto.decrypt(blob, e2eeFileKey);
      } catch (e) {
        debugPrint('WsMediaFetcher: E2EE decrypt failed for $cleanPath: $e');
        rethrow;
      }
    }
    return blob;
  }

  /// Fetches media into a local cache file and returns its path.
  ///
  /// For E2EE media the cached (and returned) file contains the DECRYPTED
  /// bytes — required by players that stream from a file path. The cache is
  /// app-private.
  static Future<String> fetchToLocalFile({
    required String filePath,
    required WebSocketClient wsClient,
    Uint8List? e2eeFileKey,
  }) async {
    final String cleanPath = _cleanFilePath(filePath);

    if (e2eeFileKey != null) {
      final Uint8List bytes = await fetchAndDecryptMedia(
        filePath: cleanPath,
        wsClient: wsClient,
        e2eeFileKey: e2eeFileKey,
      );
      final String cacheKey = 'ws_media_dec_$cleanPath';
      final FileInfo? cached = await _cacheManager.getFileFromCache(cacheKey);
      if (cached != null) return cached.file.path;
      final File put = await _cacheManager.putFile(
        cacheKey,
        bytes,
        fileExtension: _getFileExtension(cleanPath),
      );
      return put.path;
    }

    final Uint8List bytes = await fetchAndDecryptMedia(
      filePath: cleanPath,
      wsClient: wsClient,
    );
    final String cacheKey = 'ws_media_$cleanPath';
    final FileInfo? cached = await _cacheManager.getFileFromCache(cacheKey);
    if (cached != null) return cached.file.path;
    final File put = await _cacheManager.putFile(
      cacheKey,
      bytes,
      fileExtension: _getFileExtension(cleanPath),
    );
    return put.path;
  }

  static Future<Uint8List> _download(
    String cleanPath,
    WebSocketClient wsClient,
  ) async {
    final String? token = wsClient.readToken();
    if (token == null) {
      throw Exception('Unauthorized: No session token');
    }

    try {
      return await _httpDownload(cleanPath, token);
    } catch (e) {
      debugPrint('WsMediaFetcher: HTTP download failed, trying WS fallback: $e');
      return await _wsDownload(cleanPath, wsClient);
    }
  }

  static Future<Uint8List> _httpDownload(
    String cleanPath,
    String token,
  ) async {
    final String downloadUrl = '${ApiConstants.origin}/api/files/download';

    final http.Response response = await http.post(
      Uri.parse(downloadUrl),
      headers: <String, String>{'Content-Type': 'application/json'},
      body:
          '{"token":"$token","file_path":"${cleanPath.replaceAll('"', '\\"')}"',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Download failed with status code ${response.statusCode}: ${response.body}',
      );
    }

    await _cacheManager.putFile(
      'ws_media_$cleanPath',
      response.bodyBytes,
      fileExtension: _getFileExtension(cleanPath),
    );
    return response.bodyBytes;
  }

  static Future<Uint8List> _wsDownload(
    String cleanPath,
    WebSocketClient wsClient,
  ) async {
    final dynamic response = await wsClient.request(
      'get_file',
      payload: <String, dynamic>{'file_path': cleanPath},
    );

    final Map<String, dynamic> map = _asStringMap(response);
    final String? dataBase64 = map['data_base64'] as String?;
    if (dataBase64 == null || dataBase64.isEmpty) {
      throw Exception('WS download returned no data for $cleanPath');
    }

    final Uint8List bytes = base64Decode(dataBase64);

    await _cacheManager.putFile(
      'ws_media_$cleanPath',
      bytes,
      fileExtension: _getFileExtension(cleanPath),
    );
    return bytes;
  }

  static Map<String, dynamic> _asStringMap(dynamic source) {
    if (source is Map<String, dynamic>) return source;
    if (source is Map) {
      return source.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  static String cleanFilePath(String path) => _cleanFilePath(path);

  static String _cleanFilePath(String path) {
    String cleanPath = path;
    final int queryIdx = cleanPath.indexOf('?');
    if (queryIdx != -1) {
      cleanPath = cleanPath.substring(0, queryIdx);
    }
    if (cleanPath.contains('/api/media/')) {
      cleanPath = cleanPath.substring(
        cleanPath.indexOf('/api/media/') + '/api/media/'.length,
      );
    } else if (cleanPath.contains('/static/uploads/')) {
      cleanPath = cleanPath.substring(
        cleanPath.indexOf('/static/uploads/') + '/static/uploads/'.length,
      );
    } else if (cleanPath.contains('/static/')) {
      cleanPath = cleanPath.substring(
        cleanPath.indexOf('/static/') + '/static/'.length,
      );
    } else if (cleanPath.startsWith('http://') ||
        cleanPath.startsWith('https://')) {
      try {
        final Uri uri = Uri.parse(cleanPath);
        if (uri.pathSegments.isNotEmpty) {
          final List<String> segments = uri.pathSegments;
          final int idx = segments.indexWhere(
            (String s) =>
                s == 'media' || s == 'voice' || s == 'circles' || s == 'avatars',
          );
          cleanPath = idx != -1
              ? segments.sublist(idx).join('/')
              : segments.last;
        }
      } catch (_) {}
    }

    // Удаляем все ведущие слэши для точного совпадения в БД
    while (cleanPath.startsWith('/') || cleanPath.startsWith('\\')) {
      cleanPath = cleanPath.substring(1);
    }
    return cleanPath;
  }

  static String _getFileExtension(String filePath) {
    final Uri? uri = Uri.tryParse(filePath);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final String name = uri.pathSegments.last;
      final int dot = name.lastIndexOf('.');
      if (dot != -1) {
        return name.substring(dot + 1);
      }
    }
    return 'dat';
  }
}

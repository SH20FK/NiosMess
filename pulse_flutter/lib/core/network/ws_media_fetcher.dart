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
  static final http.Client _httpClient = http.Client();

  /// In-memory LRU cache for decrypted media bytes, giving 0ms gallery thumbnail display.
  static final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};
  static final List<String> _lruOrder = <String>[];
  static const int _maxMemoryEntries = 120;
  static const int _maxMemoryBytes = 40 * 1024 * 1024; // 40 MB max memory cache
  static const int _maxSingleEntryBytes = 3 * 1024 * 1024; // 3 MB max single entry
  static int _currentMemoryBytes = 0;

  /// In-flight fetch deduplication to prevent redundant concurrent network roundtrips.
  static final Map<String, Future<Uint8List>> _inFlightFetches =
      <String, Future<Uint8List>>{};

  static int _hashKeyBytes(Uint8List bytes) {
    var h = 0x811c9dc5;
    for (var i = 0; i < bytes.length; i++) {
      h = ((h ^ bytes[i]) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  static String _buildMemKey(String cleanPath, Uint8List? e2eeFileKey) {
    if (e2eeFileKey == null || e2eeFileKey.isEmpty) {
      return 'ws_mem_$cleanPath';
    }
    return 'ws_mem_dec_${cleanPath}_${_hashKeyBytes(e2eeFileKey)}';
  }

  static void _touchMemory(String key) {
    _lruOrder.remove(key);
    _lruOrder.add(key);
  }

  static void _putMemory(String key, Uint8List bytes) {
    // Avoid caching oversized individual media in raw memory (let disk cache handle them)
    if (bytes.length > _maxSingleEntryBytes) {
      return;
    }

    final Uint8List? existing = _memoryCache[key];
    if (existing != null) {
      _currentMemoryBytes -= existing.length;
    }

    // Evict oldest entries until within both entry count and byte budget
    while ((_memoryCache.length >= _maxMemoryEntries ||
            (_currentMemoryBytes + bytes.length > _maxMemoryBytes)) &&
        _lruOrder.isNotEmpty) {
      final String oldest = _lruOrder.removeAt(0);
      final Uint8List? evicted = _memoryCache.remove(oldest);
      if (evicted != null) {
        _currentMemoryBytes -= evicted.length;
      }
    }

    _memoryCache[key] = bytes;
    _currentMemoryBytes += bytes.length;
    _lruOrder.remove(key);
    _lruOrder.add(key);
  }

  /// Synchronously returns decoded/decrypted media bytes from memory if present.
  static Uint8List? getMemoryCachedBytes({
    required String filePath,
    Uint8List? e2eeFileKey,
  }) {
    final String cleanPath = _cleanFilePath(filePath);
    if (cleanPath.isEmpty) return null;
    final String memKey = _buildMemKey(cleanPath, e2eeFileKey);
    final Uint8List? cached = _memoryCache[memKey];
    if (cached != null) {
      _touchMemory(memKey);
    }
    return cached;
  }

  /// Puts decrypted media bytes into the in-memory cache directly (for testing and warmups).
  static void putMemoryCachedBytes({
    required String filePath,
    required Uint8List bytes,
    Uint8List? e2eeFileKey,
  }) {
    final String cleanPath = _cleanFilePath(filePath);
    if (cleanPath.isEmpty) return;
    final String memKey = _buildMemKey(cleanPath, e2eeFileKey);
    _putMemory(memKey, bytes);
  }

  /// Current memory cache usage in bytes.
  static int get currentMemoryBytes => _currentMemoryBytes;

  /// Current number of entries stored in memory cache.
  static int get memoryEntryCount => _memoryCache.length;

  /// Clears the in-memory media cache.
  static void clearMemoryCache() {
    _memoryCache.clear();
    _lruOrder.clear();
    _currentMemoryBytes = 0;
  }

  /// Fetches media bytes; decrypts them when [e2eeFileKey] is provided.
  /// Deduplicates in-flight requests and caches decrypted results in memory.
  static Future<Uint8List> fetchAndDecryptMedia({
    required String filePath,
    required WebSocketClient wsClient,
    Uint8List? e2eeFileKey,
  }) async {
    final String cleanPath = _cleanFilePath(filePath);
    if (cleanPath.isEmpty) {
      throw Exception('Empty file path');
    }

    final String memKey = _buildMemKey(cleanPath, e2eeFileKey);

    final Uint8List? cached = _memoryCache[memKey];
    if (cached != null) {
      _touchMemory(memKey);
      return cached;
    }

    if (_inFlightFetches.containsKey(memKey)) {
      return await _inFlightFetches[memKey]!;
    }

    final Future<Uint8List> future = _fetchAndDecryptInternal(
      cleanPath: cleanPath,
      wsClient: wsClient,
      e2eeFileKey: e2eeFileKey,
    );
    _inFlightFetches[memKey] = future;

    try {
      final Uint8List bytes = await future;
      _putMemory(memKey, bytes);
      return bytes;
    } finally {
      _inFlightFetches.remove(memKey);
    }
  }

  static Future<Uint8List> _fetchAndDecryptInternal({
    required String cleanPath,
    required WebSocketClient wsClient,
    Uint8List? e2eeFileKey,
  }) async {
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

  /// Prefetches a batch of media in parallel with a bounded concurrency pool.
  /// Decrypted files are stored in memory and disk cache for instant retrieval.
  static Future<void> prefetchBatch({
    required List<String> filePaths,
    required WebSocketClient wsClient,
    Map<String, Uint8List?>? e2eeFileKeys,
    int concurrency = 8,
  }) async {
    if (filePaths.isEmpty) return;

    final List<String> uniquePaths = filePaths.toSet().toList(growable: false);
    int cursor = 0;

    Future<void> worker() async {
      while (true) {
        final int index = cursor++;
        if (index >= uniquePaths.length) break;
        final String path = uniquePaths[index];
        final Uint8List? key = e2eeFileKeys?[path];
        try {
          await fetchAndDecryptMedia(
            filePath: path,
            wsClient: wsClient,
            e2eeFileKey: key,
          );
        } catch (_) {
          // Graceful fallback for prefetch worker
        }
      }
    }

    final int pool = concurrency.clamp(1, uniquePaths.length);
    final List<Future<void>> workers = List<Future<void>>.generate(
      pool,
      (_) => worker(),
    );
    await Future.wait(workers);
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
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      try {
        final Uri uri = Uri.parse(cleanPath);
        final String originHost = Uri.parse(ApiConstants.origin).host;
        final String devProxyHost = Uri.parse(ApiConstants.devProxyOrigin).host;
        final bool isOwnHost = uri.host == originHost ||
            uri.host == devProxyHost ||
            uri.host == 'ni-os.ru' ||
            uri.host.endsWith('.ni-os.ru');

        final http.Response directResp = await _httpClient.get(
          uri,
          headers: <String, String>{
            if (isOwnHost && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        );
        if (directResp.statusCode == 200 && directResp.bodyBytes.isNotEmpty) {
          await _cacheManager.putFile(
            'ws_media_$cleanPath',
            directResp.bodyBytes,
            fileExtension: _getFileExtension(cleanPath),
          );
          return directResp.bodyBytes;
        }
      } catch (_) {}
    }

    final String downloadUrl = '${ApiConstants.origin}/api/files/download';

    final http.Response response = await _httpClient.post(
      Uri.parse(downloadUrl),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'token': token,
        'file_path': cleanPath,
      }),
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
    String cleanPath = path.trim();
    if (cleanPath.isEmpty) return '';

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
                s == 'media' ||
                s == 'voice' ||
                s == 'circles' ||
                s == 'avatars' ||
                s == 'uploads' ||
                s == 'files',
          );
          cleanPath = idx != -1
              ? segments.sublist(idx).join('/')
              : segments.join('/');
        }
      } catch (_) {}
    }

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

import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:universal_io/io.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/media/media_playback_source.dart';
import 'package:pulse_flutter/core/media/browser_playback_stub.dart'
    if (dart.library.js_interop) 'package:pulse_flutter/core/media/browser_playback_web.dart';

/// Downloads chat media over the authenticated `/api/files/download`
/// endpoint and caches it locally.
///
/// For E2EE (secret) chats the server stores the file as an opaque
/// encrypted blob and returns `X-Is-E2EE: true`; the ciphertext is cached
/// as-is and decrypted with the per-file key carried in the Double-Ratchet
/// envelope. Native players use a separate short-lived private playback cache.
class WsMediaFetcher {
  static Future<Uint8List> Function(String)? secretLocalLoader;
  static Future<String> Function(String)? secretLocalFileLoader;
  static Future<Uint8List> Function(String, Uint8List)? secretStreamLoader;
  static Future<MediaPlaybackSource> Function(String, Uint8List)?
  secretStreamPlaybackLoader;
  static Future<void> Function(
    String,
    Uint8List,
    Future<void> Function(String),
  )?
  secretStreamExportLoader;

  /// Explicit save/share only. The account owner removes its temporary export
  /// after the platform has copied it; ordinary playback never takes this path.
  static Future<void> withSecretStreamExport({
    required String filePath,
    required Uint8List e2eeFileKey,
    required Future<void> Function(String) consume,
  }) {
    final loader = secretStreamExportLoader;
    if (!filePath.startsWith('nios-stream://') || loader == null) {
      throw StateError('Secret stream unavailable');
    }
    return loader(filePath, e2eeFileKey, consume);
  }

  static int _accountGeneration = 0;
  static Future<void>? _cacheClear;
  static final String _stagingSession = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  static const _stagingRootName = 'nios_media_staging_v2';

  static Future<void> clearPrivateCache() async {
    final maxGeneration = _accountGeneration;
    _accountGeneration++;
    releaseBrowserPlayback();
    clearMemoryCache();
    _inFlightFetches.clear();
    _inFlightFiles.clear();
    final previous = _cacheClear;
    final done = Completer<void>();
    final tail = done.future;
    _cacheClear = tail;
    try {
      if (previous != null) await previous;
      await Future.wait([
        _playbackCache.emptyCache(),
        _cacheManager.emptyCache(),
        _purgeStagingDirectories(maxGeneration),
      ]);
    } finally {
      if (identical(_cacheClear, tail)) _cacheClear = null;
      done.complete();
    }
  }

  static BaseCacheManager? _configuredCacheManager;
  static final BaseCacheManager _defaultCacheManager = DefaultCacheManager();
  static BaseCacheManager get _cacheManager =>
      _configuredCacheManager ?? _defaultCacheManager;
  // Players require a path. These short-lived files are kept out of the shared
  // media cache and are purged at account open/close, including crash recovery.
  static BaseCacheManager? _configuredPlaybackCache;
  static BaseCacheManager get _playbackCache =>
      _configuredPlaybackCache ?? _defaultPlaybackCache;
  static final BaseCacheManager _defaultPlaybackCache = CacheManager(
    Config(
      'secret_playback_v2',
      stalePeriod: const Duration(minutes: 10),
      maxNrOfCacheObjects: 20,
    ),
  );
  static http.Client _httpClient = http.Client();
  static Future<Directory> Function() _temporaryDirectory =
      getTemporaryDirectory;
  static final Map<String, Future<String>> _inFlightFiles = {};

  @visibleForTesting
  static VoidCallback debugOverride({
    required BaseCacheManager cacheManager,
    required BaseCacheManager playbackCache,
    required http.Client httpClient,
    required Future<Directory> Function() temporaryDirectory,
  }) {
    final oldCache = _configuredCacheManager;
    final oldPlayback = _configuredPlaybackCache;
    final oldHttp = _httpClient;
    final oldTemporary = _temporaryDirectory;
    _configuredCacheManager = cacheManager;
    _configuredPlaybackCache = playbackCache;
    _httpClient = httpClient;
    _temporaryDirectory = temporaryDirectory;
    return () {
      _configuredCacheManager = oldCache;
      _configuredPlaybackCache = oldPlayback;
      _httpClient = oldHttp;
      _temporaryDirectory = oldTemporary;
    };
  }

  static String _rawCacheKey(String path, int generation) =>
      'ws_media_$generation:$path';

  static void _checkAccount(int generation) {
    if (generation != _accountGeneration) throw StateError('Account changed');
  }

  static Future<void> _waitForPrivateCacheClear(int generation) async {
    final pending = _cacheClear;
    if (pending != null) await pending;
    _checkAccount(generation);
  }

  /// In-memory LRU cache for decrypted media bytes, giving 0ms gallery thumbnail display.
  static final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};
  static final List<String> _lruOrder = <String>[];
  static const int _maxMemoryEntries = 120;
  static const int _maxMemoryBytes = 40 * 1024 * 1024; // 40 MB max memory cache
  static const int _maxSingleEntryBytes =
      3 * 1024 * 1024; // 3 MB max single entry
  static int _currentMemoryBytes = 0;

  /// In-flight fetch deduplication to prevent redundant concurrent network roundtrips.
  static final Map<String, Future<Uint8List>> _inFlightFetches =
      <String, Future<Uint8List>>{};

  static String _hashKeyBytes(Uint8List bytes) =>
      crypto.sha256.convert(bytes).toString();

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
  static final _availability = StreamController<(String, bool)>.broadcast();
  static Stream<(String, bool)> get availabilityChanges => _availability.stream;
  static String mediaIdentity(String value) => _cleanFilePath(value);

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
    final generation = _accountGeneration;
    await _waitForPrivateCacheClear(generation);

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
      if (generation != _accountGeneration) throw StateError('Account changed');
      _putMemory(memKey, bytes);
      _availability.add((cleanPath, true));
      return bytes;
    } catch (_) {
      if (generation == _accountGeneration) _availability.add((cleanPath, false));
      rethrow;
    } finally {
      if (identical(_inFlightFetches[memKey], future)) {
        _inFlightFetches.remove(memKey);
      }
    }
  }

  static Future<Uint8List> _fetchAndDecryptInternal({
    required String cleanPath,
    required WebSocketClient wsClient,
    Uint8List? e2eeFileKey,
  }) async {
    if (cleanPath.startsWith('nios-stream://')) {
      final loader = secretStreamLoader;
      if (loader == null || e2eeFileKey == null) {
        throw StateError('Secret stream unavailable');
      }
      return loader(cleanPath, e2eeFileKey);
    }
    if (cleanPath.startsWith('secret-local://')) {
      final loader = secretLocalLoader;
      if (loader == null || e2eeFileKey == null) {
        throw StateError('Secret attachment unavailable');
      }
      final ciphertext = await loader(
        cleanPath.substring('secret-local://'.length),
      );
      return E2eeFileCrypto.decrypt(ciphertext, e2eeFileKey);
    }
    final path = await _ciphertextFile(cleanPath, wsClient, _accountGeneration);
    final Uint8List blob;
    if (kIsWeb) {
      final cached = await _cacheManager.getFileFromCache(
        _rawCacheKey(cleanPath, _accountGeneration),
      );
      if (cached == null) throw StateError('Media cache entry unavailable');
      blob = await cached.file.readAsBytes();
    } else {
      blob = await File(path).readAsBytes();
    }

    if (e2eeFileKey != null) {
      try {
        return await E2eeFileCrypto.decrypt(blob, e2eeFileKey);
      } catch (e) {
        debugPrint('WsMediaFetcher: SECRET_MEDIA_AUTHENTICATION_FAILED');
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
    final cleanPath = _cleanFilePath(filePath);
    if (cleanPath.isEmpty) throw ArgumentError('Empty file path');
    if (cleanPath.startsWith('nios-stream://')) {
      throw UnsupportedError('Secret streams require a playback lease');
    }
    final generation = _accountGeneration;
    await _waitForPrivateCacheClear(generation);
    final cacheKey = e2eeFileKey == null
        ? _rawCacheKey(cleanPath, generation)
        : '$generation:${_buildMemKey(cleanPath, e2eeFileKey)}';
    final cache = e2eeFileKey == null ? _cacheManager : _playbackCache;

    // A warm player must not read or authenticate the original large blob.
    final cached = await cache.getFileFromCache(cacheKey);
    _checkAccount(generation);
    if (cached != null && await cached.file.exists()) {
      _checkAccount(generation);
      return cached.file.path;
    }
    final existing = _inFlightFiles[cacheKey];
    if (existing != null) return existing;
    final future = _localFile(
      cleanPath,
      wsClient,
      e2eeFileKey,
      generation,
      cacheKey,
    );
    _inFlightFiles[cacheKey] = future;
    try {
      final path = await future;
      if (generation == _accountGeneration) _availability.add((cleanPath, true));
      return path;
    } catch (_) {
      if (generation == _accountGeneration) _availability.add((cleanPath, false));
      rethrow;
    } finally {
      if (identical(_inFlightFiles[cacheKey], future)) {
        _inFlightFiles.remove(cacheKey);
      }
    }
  }

  /// New secret streams use a loopback Range lease; old files retain their
  /// compatible file-backed player path. The caller closes the returned lease.
  static Future<MediaPlaybackSource> acquirePlaybackSource({
    required String filePath,
    required WebSocketClient wsClient,
    Uint8List? e2eeFileKey,
    String? mimeType,
  }) async {
    final cleanPath = _cleanFilePath(filePath);
    final generation = _accountGeneration;
    await _waitForPrivateCacheClear(generation);
    if (kIsWeb) {
      final bytes = await fetchAndDecryptMedia(
        filePath: cleanPath,
        wsClient: wsClient,
        e2eeFileKey: e2eeFileKey,
      );
      _checkAccount(generation);
      final resolvedType = mimeType ?? mediaPlaybackMimeType(cleanPath);
      return browserPlayback(bytes, resolvedType);
    }
    if (cleanPath.startsWith('nios-stream://')) {
      final loader = secretStreamPlaybackLoader;
      if (loader == null || e2eeFileKey == null) {
        throw StateError('Secret stream unavailable');
      }
      final source = await loader(cleanPath, e2eeFileKey);
      if (generation != _accountGeneration) {
        await source.close();
        _checkAccount(generation);
      }
      return source;
    }
    return MediaPlaybackSource.file(
      await fetchToLocalFile(
        filePath: filePath,
        wsClient: wsClient,
        e2eeFileKey: e2eeFileKey,
      ),
    );
  }

  static Future<String> _localFile(
    String cleanPath,
    WebSocketClient wsClient,
    Uint8List? key,
    int generation,
    String cacheKey,
  ) async {
    if (key == null) return _ciphertextFile(cleanPath, wsClient, generation);
    if (kIsWeb) {
      final bytes = await fetchAndDecryptMedia(
        filePath: cleanPath,
        wsClient: wsClient,
        e2eeFileKey: key,
      );
      _checkAccount(generation);
      final file = await _playbackCache.putFile(
        cacheKey,
        bytes,
        fileExtension: _getFileExtension(cleanPath),
      );
      if (generation != _accountGeneration) {
        await _playbackCache.removeFile(cacheKey);
        // CacheManager registers its metadata asynchronously. Do not depend on
        // the database ID being committed to remove a late plaintext write.
        if (await file.exists()) await file.delete();
        throw StateError('Account changed');
      }
      return file.path;
    }
    final directory = await _newStagingDirectory(generation);
    try {
      final String encryptedPath;
      if (cleanPath.startsWith('secret-local://')) {
        final localId = cleanPath.substring('secret-local://'.length);
        if (secretLocalFileLoader != null) {
          encryptedPath = await secretLocalFileLoader!(localId);
        } else {
          final loader = secretLocalLoader;
          if (loader == null) throw StateError('Secret attachment unavailable');
          final encrypted = await loader(localId);
          _checkAccount(generation);
          encryptedPath = '${directory.path}/ciphertext';
          await File(encryptedPath).writeAsBytes(encrypted, flush: true);
        }
      } else {
        encryptedPath = await _ciphertextFile(cleanPath, wsClient, generation);
      }
      _checkAccount(generation);
      final clearPath =
          '${directory.path}/authenticated.${_getFileExtension(cleanPath)}';
      await E2eeFileCrypto.decryptFile(
        encryptedPath: encryptedPath,
        outputPath: clearPath,
        key: key,
      );
      _checkAccount(generation);
      // Only fully authenticated files enter playback cache. putFileStream
      // registers metadata after the complete copy, without a whole-file array.
      final put = await _playbackCache.putFileStream(
        cacheKey,
        File(clearPath).openRead(),
        fileExtension: _getFileExtension(cleanPath),
      );
      if (generation != _accountGeneration) {
        await _playbackCache.removeFile(cacheKey);
        if (await put.exists()) await put.delete();
        throw StateError('Account changed');
      }
      return put.path;
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  static Future<Directory> _newStagingDirectory(int generation) async {
    await _waitForPrivateCacheClear(generation);
    final parent = await _temporaryDirectory();
    _checkAccount(generation);
    final root = Directory(
      '${parent.path}${Platform.pathSeparator}$_stagingRootName',
    );
    await root.create(recursive: true);
    _checkAccount(generation);
    final epoch = Directory(
      '${root.path}${Platform.pathSeparator}$_stagingSession-$generation',
    );
    await epoch.create(recursive: true);
    _checkAccount(generation);
    final work = await epoch.createTemp('work_');
    if (generation != _accountGeneration) {
      await _deleteOwnedDirectory(work, root);
      _checkAccount(generation);
    }
    return work;
  }

  static Future<void> _deleteOwnedDirectory(
    Directory target,
    Directory parent,
  ) async {
    String normalized(String path) {
      final result = path
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'/+$'), '');
      return Platform.isWindows ? result.toLowerCase() : result;
    }

    final root = normalized(parent.absolute.path);
    final path = normalized(target.absolute.path);
    if (!path.startsWith('$root/') || path == root) {
      throw StateError('Invalid media staging cleanup target');
    }
    final type = await FileSystemEntity.type(target.path, followLinks: false);
    if (type != FileSystemEntityType.directory) return;
    try {
      final resolvedRoot = normalized(await parent.resolveSymbolicLinks());
      final resolvedTarget = normalized(await target.resolveSymbolicLinks());
      if (!resolvedTarget.startsWith('$resolvedRoot/') ||
          resolvedTarget == resolvedRoot) {
        throw StateError('Media staging cleanup escaped its owned directory');
      }
      await target.delete(recursive: true);
    } on FileSystemException {
      // A finishing old operation may already have removed this directory.
      if (await target.exists()) rethrow;
    }
  }

  static Future<void> _purgeStagingDirectories(int maxGeneration) async {
    if (kIsWeb) return;
    final parent = await _temporaryDirectory();
    if (!await parent.exists()) return;
    final root = Directory(
      '${parent.path}${Platform.pathSeparator}$_stagingRootName',
    );
    // Recover leftovers made by the earlier pre-owned-root implementation.
    await for (final entry in parent.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
      if (name.startsWith('nios_media_') && name != _stagingRootName) {
        await _deleteOwnedDirectory(entry, parent);
      }
    }
    if (!await root.exists()) return;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
      final parts = name.split('-');
      final generation = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (parts.first == _stagingSession &&
          generation != null &&
          generation > maxGeneration) {
        continue;
      }
      await _deleteOwnedDirectory(entry, root);
    }
  }

  static Future<String> _ciphertextFile(
    String cleanPath,
    WebSocketClient wsClient,
    int generation,
  ) async {
    final cacheKey = _rawCacheKey(cleanPath, generation);
    final cached = await _cacheManager.getFileFromCache(cacheKey);
    _checkAccount(generation);
    if (cached != null && await cached.file.exists()) return cached.file.path;
    final token = wsClient.readToken();
    if (token == null) throw StateError('Unauthorized: No session token');
    final releaseWork = BackgroundService.retainWork();
    try {
      try {
        return await _httpDownloadToFile(
          cleanPath,
          token,
          generation,
          cacheKey,
        );
      } catch (_) {
        _checkAccount(generation);
        debugPrint('WsMediaFetcher: HTTP_MEDIA_FALLBACK');
        final response = await wsClient.request(
          'get_file',
          payload: <String, dynamic>{'file_path': cleanPath},
        );
        _checkAccount(generation);
        final data = _asStringMap(response)['data_base64'] as String?;
        if (data == null || data.isEmpty) throw StateError('Empty WS media');
        final bytes = base64Decode(data);
        final put = await _cacheManager.putFile(
          cacheKey,
          bytes,
          fileExtension: _getFileExtension(cleanPath),
        );
        if (generation != _accountGeneration) {
          await _cacheManager.removeFile(cacheKey);
          throw StateError('Account changed');
        }
        return put.path;
      }
    } finally {
      releaseWork();
    }
  }

  static Future<String> _httpDownloadToFile(
    String cleanPath,
    String token,
    int generation,
    String cacheKey,
  ) async {
    // The authenticated endpoint supports legacy paths and preserves headers
    // without retaining response.bodyBytes for the duration of playback.
    final request =
        http.Request(
            'POST',
            Uri.parse('${ApiConstants.origin}/api/files/download'),
          )
          ..headers['Content-Type'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $token'
          ..body = jsonEncode({'token': token, 'file_path': cleanPath});
    if (kIsWeb) {
      final response = await http.Response.fromStream(
        await _httpClient.send(request),
      );
      if (response.statusCode != 200) {
        throw StateError('MEDIA_HTTP_${response.statusCode}');
      }
      _checkAccount(generation);
      final put = await _cacheManager.putFile(
        cacheKey,
        response.bodyBytes,
        fileExtension: _getFileExtension(cleanPath),
      );
      if (generation != _accountGeneration) {
        await _cacheManager.removeFile(cacheKey);
        throw StateError('Account changed');
      }
      return put.path;
    }
    final directory = await _newStagingDirectory(generation);
    try {
      final response = await _httpClient.send(request);
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw StateError('MEDIA_HTTP_${response.statusCode}');
      }
      final partial = File('${directory.path}/download.partial');
      await response.stream.pipe(partial.openWrite());
      _checkAccount(generation);
      // A failed/aborted stream is never published. Players only see the final
      // name after a complete response and atomic rename on this filesystem.
      final complete = await partial.rename(
        '${directory.path}/download.complete',
      );
      final put = await _cacheManager.putFileStream(
        cacheKey,
        complete.openRead(),
        fileExtension: _getFileExtension(cleanPath),
      );
      if (generation != _accountGeneration) {
        await _cacheManager.removeFile(cacheKey);
        throw StateError('Account changed');
      }
      return put.path;
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
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

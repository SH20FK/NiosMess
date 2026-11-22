import 'package:universal_io/io.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pulse_flutter/features/storage/domain/storage_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:pulse_flutter/features/storage/domain/storage_snapshot.dart';

class LocalStorageSnapshot {
  const LocalStorageSnapshot({
    required this.documentsBytes,
    required this.supportBytes,
    required this.temporaryBytes,
    required this.draftBytes,
    required this.draftCount,
    this.categoryBytes = const <StorageCategory, int>{},
  });

  const LocalStorageSnapshot.empty()
    : documentsBytes = 0,
      supportBytes = 0,
      temporaryBytes = 0,
      draftBytes = 0,
      draftCount = 0,
      categoryBytes = const <StorageCategory, int>{};

  final int documentsBytes;
  final int supportBytes;
  final int temporaryBytes;
  final int draftBytes;
  final int draftCount;
  final Map<StorageCategory, int> categoryBytes;

  int bytesFor(StorageCategory category) => categoryBytes[category] ?? 0;

  int get totalBytes =>
      documentsBytes + supportBytes + temporaryBytes + draftBytes;
}

class LocalStorageHealth {
  const LocalStorageHealth({
    required this.schemaVersion,
    required this.ok,
    required this.issues,
    required this.snapshot,
  });

  final int schemaVersion;
  final bool ok;
  final List<String> issues;
  final LocalStorageSnapshot snapshot;
}

class LocalStorageService {
  const LocalStorageService({
    this.temporaryDirectory,
    this.documentsDirectory,
    this.supportDirectory,
    this.sandboxedDocuments,
  });

  /// Optional directory providers let isolated tests exercise actual filesystem
  /// boundaries without redirecting application-wide platform paths.
  final Future<Directory> Function()? temporaryDirectory;
  final Future<Directory> Function()? documentsDirectory;
  final Future<Directory> Function()? supportDirectory;
  final bool? sandboxedDocuments;

  bool get _hasSandboxedDocuments =>
      sandboxedDocuments ?? (Platform.isAndroid || Platform.isIOS);
  Future<Directory> _temporaryDirectory() =>
      (temporaryDirectory ?? getTemporaryDirectory)();
  Future<Directory> _documentsDirectory() =>
      (documentsDirectory ?? getApplicationDocumentsDirectory)();
  Future<Directory> _supportDirectory() =>
      (supportDirectory ?? getApplicationSupportDirectory)();

  // These exact directories contain downloaded/recreated media, never an
  // outbox, a database, a recording awaiting upload or protected attachments.
  static const _mediaCacheDirectories = <String>{
    'nios_private_media_v1',
    'secret_playback_v2',
    'nios_media_staging_v2',
  };

  Future<List<Directory>> _ownedCacheDirectories() async {
    if (kIsWeb) return const [];
    final temporary = await _temporaryDirectory();
    if (!await temporary.exists()) return const [];
    final root = await temporary.resolveSymbolicLinks();
    final names = <String>{
      ..._mediaCacheDirectories,
      // DefaultCacheManager has a shared name. It is owned by this app only
      // inside Android/iOS's sandbox, not the user's system-wide desktop Temp.
      if (_hasSandboxedDocuments) 'libCachedImageData',
    };
    final result = <Directory>[];
    for (final name in names) {
      final candidate = Directory(p.join(root, name));
      if (await FileSystemEntity.type(candidate.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        continue;
      }
      final resolved = await candidate.resolveSymbolicLinks();
      if (p.equals(p.dirname(resolved), root)) result.add(Directory(resolved));
    }
    return result;
  }

  static const int currentSchemaVersion = 1;
  static const String _schemaVersionKey = 'storage.schemaVersion';
  static const String _draftPrefix = 'draft.';

  static LocalStorageSnapshot? _cachedSnapshot;
  static DateTime? _lastSnapshotTime;
  static const Duration _snapshotTtl = Duration(minutes: 5);

  static void invalidateSnapshotCache() {
    _cachedSnapshot = null;
    _lastSnapshotTime = null;
  }

  Future<int> ensureInitialized() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? existingVersion = prefs.getInt(_schemaVersionKey);
    if (existingVersion == null || existingVersion < currentSchemaVersion) {
      await prefs.setInt(_schemaVersionKey, currentSchemaVersion);
      return currentSchemaVersion;
    }
    return existingVersion;
  }

  Future<LocalStorageSnapshot> snapshot({bool forceRefresh = false}) async {
    final DateTime now = DateTime.now();
    if (!forceRefresh &&
        _cachedSnapshot != null &&
        _lastSnapshotTime != null &&
        now.difference(_lastSnapshotTime!) < _snapshotTtl) {
      return _cachedSnapshot!;
    }

    await ensureInitialized();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Iterable<String> draftKeys = prefs.getKeys().where(
      (String key) => key.startsWith(_draftPrefix),
    );

    int draftBytes = 0;
    int draftCount = 0;
    for (final String key in draftKeys) {
      final String? value = prefs.getString(key);
      if (value == null || value.isEmpty) continue;
      draftCount++;
      draftBytes += value.length * 2;
    }

    final Map<StorageCategory, int> categoryBytes = <StorageCategory, int>{
      for (final StorageCategory cat in StorageCategory.values) cat: 0,
    };
    categoryBytes[StorageCategory.drafts] = draftBytes;

    int documentsBytes = 0;
    int supportBytes = 0;
    int temporaryBytes = 0;

    if (!kIsWeb) {
      final Directory? support = await _tryDirectory(_supportDirectory);
      // Desktop Documents is a user-wide folder, not NiosMess storage.
      final Directory? documents = _hasSandboxedDocuments
          ? await _documentsDirectory()
          : null;
      final List<Directory> caches = await _ownedCacheDirectories();
      final List<String> paths = <String>[
        if (documents != null) documents.path,
        if (support != null) support.path,
        for (final Directory cache in caches) cache.path,
      ];
      if (paths.isNotEmpty) {
        // Thousands of cached files: the walk runs in a background isolate so
        // it does not share the UI isolate with the cold start.
        final scan = await compute(_scanDirectories, paths);
        int next = 0;
        if (documents != null) documentsBytes = scan.totals[next++];
        if (support != null) supportBytes = scan.totals[next++];
        for (; next < scan.totals.length; next++) {
          temporaryBytes += scan.totals[next];
        }
        scan.categoryBytes.forEach((int index, int bytes) {
          final StorageCategory category = StorageCategory.values[index];
          categoryBytes[category] = (categoryBytes[category] ?? 0) + bytes;
        });
      }
    }

    final LocalStorageSnapshot result = LocalStorageSnapshot(
      documentsBytes: documentsBytes,
      supportBytes: supportBytes,
      temporaryBytes: temporaryBytes,
      draftBytes: draftBytes,
      draftCount: draftCount,
      categoryBytes: categoryBytes,
    );

    _cachedSnapshot = result;
    _lastSnapshotTime = now;
    return result;
  }

  Future<LocalStorageHealth> checkIntegrity() async {
    final List<String> issues = <String>[];
    int schemaVersion = currentSchemaVersion;
    LocalStorageSnapshot snapshot = const LocalStorageSnapshot.empty();

    try {
      schemaVersion = await ensureInitialized();
      if (schemaVersion > currentSchemaVersion) {
        issues.add('Storage schema is newer than this app build.');
      }
    } catch (error) {
      issues.add('Could not initialize storage schema: $error');
    }

    try {
      snapshot = await this.snapshot();
    } catch (error) {
      issues.add('Could not calculate storage snapshot: $error');
    }

    try {
      if (!kIsWeb) {
        final Directory documents = await _documentsDirectory();
        final Directory temporary = await _temporaryDirectory();
        if (!await documents.exists()) {
          issues.add('Documents directory is not available.');
        }
        if (!await temporary.exists()) {
          issues.add('Temporary directory is not available.');
        }
      }
    } catch (error) {
      issues.add('Could not inspect app directories: $error');
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> draftKeys = prefs
          .getKeys()
          .where((String key) => key.startsWith(_draftPrefix))
          .toList();
      if (draftKeys.length > 100) {
        issues.add('Excessive draft count: ${draftKeys.length}');
      }
    } catch (error) {
      issues.add('Could not read local draft keys: $error');
    }

    return LocalStorageHealth(
      schemaVersion: schemaVersion,
      ok: issues.isEmpty,
      issues: List<String>.unmodifiable(issues),
      snapshot: snapshot,
    );
  }

  Future<int> clearTemporaryFiles() async {
    await ensureInitialized();
    int deleted = 0;
    for (final directory in await _ownedCacheDirectories()) {
      deleted += await _clearCacheDirectory(directory);
    }
    invalidateSnapshotCache();
    return deleted;
  }

  /// Kept for callers that explicitly clear a media category. Classification
  /// never grants ownership of files outside known recreatable cache roots.
  Future<int> clearCategoryFiles(StorageCategory category) async {
    await ensureInitialized();
    if (category == StorageCategory.drafts) return clearDrafts();
    if (category == StorageCategory.secretChatCache ||
        category == StorageCategory.other) {
      return 0;
    }
    int deleted = 0;
    for (final directory in await _ownedCacheDirectories()) {
      deleted += await _clearCacheDirectory(directory, category: category);
    }
    invalidateSnapshotCache();
    return deleted;
  }

  Future<int> clearDrafts() async {
    await ensureInitialized();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> draftKeys = prefs
        .getKeys()
        .where((String key) => key.startsWith(_draftPrefix))
        .toList(growable: false);
    int deletedBytes = 0;
    for (final String key in draftKeys) {
      final String? value = prefs.getString(key);
      if (value != null) {
        deletedBytes += value.length * 2;
      }
      await prefs.remove(key);
    }
    invalidateSnapshotCache();
    return deletedBytes;
  }

  Future<Directory?> _tryDirectory(Future<Directory> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  Future<int> _clearCacheDirectory(
    Directory directory, {
    StorageCategory? category,
  }) async {
    final root = await directory.resolveSymbolicLinks();
    int deleted = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      // Leave directories, links/junctions and unknown ownership untouched.
      if (entity is! File ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.file) {
        continue;
      }
      final resolved = await entity.resolveSymbolicLinks();
      if (!p.isWithin(root, resolved)) continue;
      if (category != null &&
          StorageCategory.detectFromFilePath(resolved) != category) {
        continue;
      }
      final bytes = await entity.length();
      await entity.delete();
      deleted += bytes;
    }
    return deleted;
  }
}

/// Sizes of [paths] in order, plus bytes per [StorageCategory] index. A path
/// listed twice counts once. Top-level and built from sendable values only:
/// it is the entry point of the scanning isolate.
({List<int> totals, Map<int, int> categoryBytes}) _scanDirectories(
  List<String> paths,
) {
  final Set<String> counted = <String>{};
  final Map<int, int> categoryBytes = <int, int>{};
  final List<int> totals = <int>[];
  for (final String path in paths) {
    final Directory directory = Directory(path);
    int total = 0;
    if (counted.add(directory.absolute.path.toLowerCase()) &&
        directory.existsSync()) {
      for (final FileSystemEntity entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        try {
          final int length = entity.lengthSync();
          total += length;
          final int index = StorageCategory.detectFromFilePath(
            entity.path,
          ).index;
          categoryBytes[index] = (categoryBytes[index] ?? 0) + length;
        } catch (e) {
          debugPrint('[local_storage_service.dart] Error reading length: $e');
        }
      }
    }
    totals.add(total);
  }
  return (totals: totals, categoryBytes: categoryBytes);
}

final Provider<LocalStorageService> localStorageServiceProvider =
    Provider<LocalStorageService>((Ref ref) => const LocalStorageService());

class StorageSnapshotNotifier extends AsyncNotifier<LocalStorageSnapshot> {
  @override
  Future<LocalStorageSnapshot> build() async {
    return ref.watch(localStorageServiceProvider).snapshot();
  }

  Future<void> refresh({bool forceRefresh = true}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(localStorageServiceProvider)
          .snapshot(forceRefresh: forceRefresh),
    );
  }
}

final AsyncNotifierProvider<StorageSnapshotNotifier, LocalStorageSnapshot>
storageSnapshotProvider =
    AsyncNotifierProvider<StorageSnapshotNotifier, LocalStorageSnapshot>(
      StorageSnapshotNotifier.new,
    );

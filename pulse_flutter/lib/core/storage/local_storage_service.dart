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
      final Set<String> countedPaths = <String>{};
      // Desktop Documents is a user-wide folder, not NiosMess storage.
      if (_hasSandboxedDocuments) {
        final documents = await _documentsDirectory();
        documentsBytes = await _scanDirectory(
          documents,
          countedPaths,
          categoryBytes,
        );
      }
      supportBytes = support == null
          ? 0
          : await _scanDirectory(support, countedPaths, categoryBytes);
      for (final cache in await _ownedCacheDirectories()) {
        temporaryBytes += await _scanDirectory(
          cache,
          countedPaths,
          categoryBytes,
        );
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

  Future<int> _scanDirectory(
    Directory directory,
    Set<String> countedPaths,
    Map<StorageCategory, int> categoryBytes,
  ) async {
    final String path = directory.absolute.path.toLowerCase();
    if (!countedPaths.add(path)) return 0;
    if (!await directory.exists()) return 0;

    int total = 0;
    await for (final FileSystemEntity entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          final int length = await entity.length();
          total += length;
          final StorageCategory cat = StorageCategory.detectFromFilePath(
            entity.path,
          );
          categoryBytes[cat] = (categoryBytes[cat] ?? 0) + length;
        } catch (e) {
          debugPrint('[local_storage_service.dart] Error reading length: $e');
        }
      }
    }
    return total;
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

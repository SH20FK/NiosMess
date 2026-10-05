import 'package:universal_io/io.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
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
  const LocalStorageService();

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
      final Directory documents = await getApplicationDocumentsDirectory();
      final Directory temporary = await getTemporaryDirectory();
      final Directory? support = await _tryDirectory(
        getApplicationSupportDirectory,
      );

      final Set<String> countedPaths = <String>{};
      documentsBytes = await _scanDirectory(documents, countedPaths, categoryBytes);
      supportBytes = support == null
          ? 0
          : await _scanDirectory(support, countedPaths, categoryBytes);
      temporaryBytes = await _scanDirectory(temporary, countedPaths, categoryBytes);
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
        final Directory documents = await getApplicationDocumentsDirectory();
        final Directory temporary = await getTemporaryDirectory();
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
      final List<String> draftKeys = prefs.getKeys()
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
    final Directory temporary = await getTemporaryDirectory();
    final int deleted = await _clearDirectoryContents(temporary);
    invalidateSnapshotCache();
    return deleted;
  }

  Future<int> clearCategoryFiles(StorageCategory category) async {
    await ensureInitialized();
    if (category == StorageCategory.drafts) {
      return clearDrafts();
    }
    if (category == StorageCategory.secretChatCache) {
      await EncryptedMessageCache.clearAll();
      invalidateSnapshotCache();
      return 0;
    }

    int deleted = 0;
    if (!kIsWeb) {
      final Directory temporary = await getTemporaryDirectory();
      deleted += await _deleteMatchingCategory(temporary, category);
      final Directory documents = await getApplicationDocumentsDirectory();
      deleted += await _deleteMatchingCategory(documents, category);
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
          final StorageCategory cat = StorageCategory.detectFromFilePath(entity.path);
          categoryBytes[cat] = (categoryBytes[cat] ?? 0) + length;
        } catch (e) {
          debugPrint('[local_storage_service.dart] Error reading length: $e');
        }
      }
    }
    return total;
  }

  Future<int> _deleteMatchingCategory(
    Directory directory,
    StorageCategory target,
  ) async {
    if (!await directory.exists()) return 0;
    int deleted = 0;
    await for (final FileSystemEntity entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        if (StorageCategory.detectFromFilePath(entity.path) == target) {
          try {
            final int len = await entity.length();
            await entity.delete();
            deleted += len;
          } catch (e) {
            debugPrint('[local_storage_service.dart] Error deleting: $e');
          }
        }
      }
    }
    return deleted;
  }

  Future<int> _clearDirectoryContents(Directory directory) async {
    if (!await directory.exists()) return 0;
    int deleted = 0;
    await for (final FileSystemEntity entity in directory.list(
      followLinks: false,
    )) {
      try {
        if (entity is File) {
          deleted += await entity.length();
        } else if (entity is Directory) {
          deleted += await _scanDirectory(entity, <String>{}, <StorageCategory, int>{});
        }
        await entity.delete(recursive: true);
      } catch (e) {
        debugPrint('[local_storage_service.dart] Error: $e');
      }
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
    state = await AsyncValue.guard(() =>
        ref.read(localStorageServiceProvider).snapshot(forceRefresh: forceRefresh));
  }
}

final AsyncNotifierProvider<StorageSnapshotNotifier, LocalStorageSnapshot>
    storageSnapshotProvider =
    AsyncNotifierProvider<StorageSnapshotNotifier, LocalStorageSnapshot>(
  StorageSnapshotNotifier.new,
);

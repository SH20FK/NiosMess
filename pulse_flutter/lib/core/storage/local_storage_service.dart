import 'package:universal_io/io.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageSnapshot {
  const LocalStorageSnapshot({
    required this.documentsBytes,
    required this.supportBytes,
    required this.temporaryBytes,
    required this.draftBytes,
    required this.draftCount,
  });

  const LocalStorageSnapshot.empty()
    : documentsBytes = 0,
      supportBytes = 0,
      temporaryBytes = 0,
      draftBytes = 0,
      draftCount = 0;

  final int documentsBytes;
  final int supportBytes;
  final int temporaryBytes;
  final int draftBytes;
  final int draftCount;

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

  Future<int> ensureInitialized() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? existingVersion = prefs.getInt(_schemaVersionKey);
    if (existingVersion == null || existingVersion < currentSchemaVersion) {
      await prefs.setInt(_schemaVersionKey, currentSchemaVersion);
      return currentSchemaVersion;
    }
    return existingVersion;
  }

  Future<LocalStorageSnapshot> snapshot() async {
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
      documentsBytes = await _directorySizeUnique(documents, countedPaths);
      supportBytes = support == null ? 0 : await _directorySizeUnique(support, countedPaths);
      temporaryBytes = await _directorySizeUnique(temporary, countedPaths);
    }

    return LocalStorageSnapshot(
      documentsBytes: documentsBytes,
      supportBytes: supportBytes,
      temporaryBytes: temporaryBytes,
      draftBytes: draftBytes,
      draftCount: draftCount,
    );
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

  Future<void> clearTemporaryFiles() async {
    await ensureInitialized();
    final Directory temporary = await getTemporaryDirectory();
    await _clearDirectoryContents(temporary);
  }

  Future<int> clearDrafts() async {
    await ensureInitialized();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> draftKeys = prefs
        .getKeys()
        .where((String key) => key.startsWith(_draftPrefix))
        .toList(growable: false);
    for (final String key in draftKeys) {
      await prefs.remove(key);
    }
    return draftKeys.length;
  }

  Future<Directory?> _tryDirectory(Future<Directory> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  Future<int> _directorySizeUnique(
    Directory directory,
    Set<String> countedPaths,
  ) async {
    final String path = directory.absolute.path.toLowerCase();
    if (!countedPaths.add(path)) return 0;
    return _directorySize(directory);
  }

  Future<int> _directorySize(Directory directory) async {
    int total = 0;
    if (!await directory.exists()) return total;
    await for (final FileSystemEntity entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (e) { debugPrint('[local_storage_service.dart] Error: $e'); }
      }
    }
    return total;
  }

  Future<void> _clearDirectoryContents(Directory directory) async {
    if (!await directory.exists()) return;
    await for (final FileSystemEntity entity in directory.list(
      followLinks: false,
    )) {
      try {
        await entity.delete(recursive: true);
      } catch (e) { debugPrint('[local_storage_service.dart] Error: $e'); }
    }
  }
}

final Provider<LocalStorageService> localStorageServiceProvider =
    Provider<LocalStorageService>((Ref ref) => const LocalStorageService());

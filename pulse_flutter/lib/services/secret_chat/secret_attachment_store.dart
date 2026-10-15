import 'dart:async';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:universal_io/io.dart';

/// Ciphertext files are published atomically. Existing LazyBox payloads remain
/// readable without eagerly migrating an account's complete attachment archive.
class SecretAttachmentStore {
  SecretAttachmentStore._(this._box, this._hive, this._directory);
  final LazyBox<Uint8List> _box;
  final HiveInterface _hive;
  final Directory? _directory;
  final Set<String> _fileIds = {};
  final Set<Future<void>> _operations = {};
  final Map<String, Future<void>> _writes = {};
  bool _closed = false;
  Future<void>? _closing;

  static final _safeId = RegExp(r'^[A-Za-z0-9_-]+$');
  static String _id(String id) {
    if (!_safeId.hasMatch(id)) throw ArgumentError.value(id, 'id');
    return id;
  }

  static Future<SecretAttachmentStore> open(
    String name, {
    HiveInterface? hive,
    String? directoryPath,
  }) async {
    final selectedHive = hive ?? Hive;
    final directory = directoryPath == null ? null : Directory(directoryPath);
    final store = SecretAttachmentStore._(
      await selectedHive.openLazyBox<Uint8List>(name),
      selectedHive,
      directory,
    );
    if (directory != null) {
      await directory.create(recursive: true);
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is Directory) {
          await _eraseCipherStaging(entity);
          continue;
        }
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.endsWith('.enc')) {
          final id = name.substring(0, name.length - 4);
          if (_safeId.hasMatch(id)) store._fileIds.add(id);
        } else if (_isPartial(name)) {
          // A crash before atomic publication never accepted the attachment.
          await entity.delete();
        }
      }
    }
    return store;
  }

  static bool _isPartial(String name) {
    var id = name;
    while (id.endsWith('.partial')) {
      id = id.substring(0, id.length - 8);
    }
    return id != name && _safeId.hasMatch(id);
  }

  static Future<void> _eraseCipherStaging(Directory directory) async {
    final name = directory.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (!RegExp(r'^\.nios_gcm_[A-Za-z0-9_-]+$').hasMatch(name)) return;
    await for (final entity in directory.list(followLinks: false)) {
      // The streaming cipher creates just this quarantine file. Unknown files
      // and links are never followed or removed during account collection.
      if (entity is File && entity.uri.pathSegments.last == 'payload.partial') {
        await entity.delete();
      }
    }
    if (await directory.list(followLinks: false).isEmpty) {
      await directory.delete();
    }
  }

  Iterable<String> get ids => {..._box.keys.cast<String>(), ..._fileIds};
  bool get supportsFiles => _directory != null;
  File _file(String id) => File('${_directory!.path}/${_id(id)}.enc');

  Future<T> _track<T>(Future<T> Function() operation) {
    if (_closed) return Future<T>.error(StateError('Secret account is closed'));
    final result = Future<T>.sync(operation);
    final settled = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    _operations.add(settled);
    unawaited(settled.whenComplete(() => _operations.remove(settled)));
    return result;
  }

  Future<void> save(String id, Uint8List ciphertext) {
    _id(id);
    if (_directory != null) {
      return saveFile(id, (path) async {
        await File(path).writeAsBytes(ciphertext, flush: true);
      });
    }
    return _track(() async {
      await _box.put(id, ciphertext);
      await _box.flush();
    });
  }

  /// The writer receives an account-private staging path and must only write
  /// ciphertext. Its source may disappear after this durable future completes.
  Future<void> saveFile(String id, Future<void> Function(String path) writer) {
    _id(id);
    if (_directory == null) {
      return Future.error(UnsupportedError('Native file storage unavailable'));
    }
    final existing = _writes[id];
    if (existing != null) return existing;
    final result = _track(() async {
      final destination = _file(id);
      if (await destination.exists()) {
        throw StateError('Attachment already exists');
      }
      final temporary = File('${_directory.path}/$id.partial');
      try {
        await writer(temporary.path);
        if (_closed) throw StateError('Secret account is closed');
        if (!await temporary.exists() || await temporary.length() == 0) {
          throw StateError('Secret ciphertext unavailable');
        }
        final handle = await temporary.open(mode: FileMode.append);
        try {
          await handle.flush();
        } finally {
          await handle.close();
        }
        if (_closed) throw StateError('Secret account is closed');
        await temporary.rename(destination.path);
        _fileIds.add(id);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    });
    late final Future<void> tracked;
    tracked = result.whenComplete(() {
      if (identical(_writes[id], tracked)) _writes.remove(id);
    });
    _writes[id] = tracked;
    return tracked;
  }

  Future<Uint8List> read(String id) => _track(() async {
    _id(id);
    await _writes[id];
    if (_directory != null && await _file(id).exists()) {
      return _file(id).readAsBytes();
    }
    final bytes = await _box.get(id);
    if (bytes == null) throw StateError('Secret attachment unavailable');
    return bytes;
  });

  Future<String> readFile(String id) => _track(() async {
    _id(id);
    if (_directory == null) {
      throw UnsupportedError('Native file storage unavailable');
    }
    await _writes[id];
    final file = _file(id);
    if (await file.exists()) return file.path;
    final bytes = await _box.get(id);
    if (bytes == null) throw StateError('Secret attachment unavailable');
    // Materialize one legacy ciphertext only when a file-backed player/upload
    // needs it. Retain the original until normal reference-based collection.
    await saveFile(id, (path) async {
      await File(path).writeAsBytes(bytes, flush: true);
    });
    return file.path;
  });

  Future<bool> retain(Set<String> retained) => _track(() async {
    final protected = {...retained, ..._writes.keys};
    final unusedLegacy = _box.keys
        .where((id) => !protected.contains(id))
        .toList();
    final unusedFiles = _fileIds
        .where((id) => !protected.contains(id))
        .toList();
    if (unusedLegacy.isEmpty && unusedFiles.isEmpty) return false;
    if (unusedLegacy.isNotEmpty) {
      await _box.deleteAll(unusedLegacy);
      await _box.flush();
      await _box.compact();
    }
    for (final id in unusedFiles) {
      final file = _file(id);
      if (await file.exists()) await file.delete();
      _fileIds.remove(id);
    }
    return true;
  });

  Future<void> close({bool erase = false}) {
    final closing = _closing;
    if (closing != null) {
      return erase ? closing.then((_) => _eraseClosed()) : closing;
    }
    _closed = true;
    return _closing = _finishClose(erase);
  }

  Future<void> _finishClose(bool erase) async {
    await Future.wait(_operations.toList());
    if (erase) {
      await _box.clear();
      await _box.flush();
    }
    await _box.close();
    if (erase && _directory != null) await eraseFiles(_directory.path);
    _fileIds.clear();
  }

  Future<void> _eraseClosed() async {
    if (await _hive.boxExists(_box.name)) {
      await _hive.deleteBoxFromDisk(_box.name);
    }
    if (_directory != null) await eraseFiles(_directory.path);
  }

  /// Only regular payload/staging files inside the explicitly selected account
  /// directory are removed; never follow links or traverse another account.
  static Future<void> eraseFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is Directory) {
        await _eraseCipherStaging(entity);
        continue;
      }
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if ((name.endsWith('.enc') &&
              _safeId.hasMatch(name.substring(0, name.length - 4))) ||
          _isPartial(name)) {
        await entity.delete();
      }
    }
    if (await directory.list(followLinks: false).isEmpty) {
      await directory.delete();
    }
  }
}

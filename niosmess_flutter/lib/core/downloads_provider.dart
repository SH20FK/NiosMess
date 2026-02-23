import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_usage_provider.dart';
import 'repositories/api_repository.dart';
import 'session_provider.dart';

const _downloadsKey = 'downloads_local_v1';

class DownloadEntry {
  DownloadEntry({
    required this.id,
    required this.filename,
    this.path,
    required this.size,
    required this.ts,
    required this.isLocal,
  });

  final String id;
  final String filename;
  final String? path;
  final int size;
  final double ts;
  final bool isLocal;

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'path': path,
        'size': size,
        'ts': ts,
        'is_local': isLocal,
      };

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
        id: json['id']?.toString() ?? '',
        filename: json['filename']?.toString() ?? '',
        path: json['path']?.toString(),
        size: (json['size'] as num?)?.toInt() ?? 0,
        ts: (json['ts'] as num?)?.toDouble() ?? 0,
        isLocal: json['is_local'] == true || json['is_local']?.toString() == '1',
      );
}

class DownloadsState {
  const DownloadsState({
    required this.local,
    required this.remote,
    this.loading = false,
  });

  final List<DownloadEntry> local;
  final List<DownloadEntry> remote;
  final bool loading;

  DownloadsState copyWith({
    List<DownloadEntry>? local,
    List<DownloadEntry>? remote,
    bool? loading,
  }) {
    return DownloadsState(
      local: local ?? this.local,
      remote: remote ?? this.remote,
      loading: loading ?? this.loading,
    );
  }
}

class DownloadsController extends StateNotifier<DownloadsState> {
  DownloadsController(this._ref)
      : super(const DownloadsState(local: [], remote: [])) {
    _loadLocal();
  }

  final Ref _ref;

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_downloadsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final local = list
          .map((e) => DownloadEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(local: local);
    } catch (_) {}
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _downloadsKey,
      jsonEncode(state.local.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addLocalDownload({
    required String filename,
    required String path,
    int? size,
  }) async {
    int resolvedSize = size ?? 0;
    if (resolvedSize <= 0) {
      try {
        final file = File(path);
        if (await file.exists()) {
          resolvedSize = await file.length();
        }
      } catch (_) {}
    }
    final entry = DownloadEntry(
      id: '${filename}_${DateTime.now().millisecondsSinceEpoch}',
      filename: filename,
      path: path,
      size: resolvedSize,
      ts: DateTime.now().millisecondsSinceEpoch / 1000.0,
      isLocal: true,
    );
    final updated = [entry, ...state.local];
    state = state.copyWith(local: updated);
    await _persistLocal();
    if (resolvedSize > 0) {
      await _ref.read(dataUsageProvider.notifier).record(
            bytes: resolvedSize,
            direction: 'download',
            kind: 'file',
          );
    }
  }

  Future<void> removeLocalDownload(String id, {bool deleteFile = false}) async {
    final entry = state.local.firstWhere(
      (e) => e.id == id,
      orElse: () => DownloadEntry(id: '', filename: '', size: 0, ts: 0, isLocal: true),
    );
    if (entry.id.isEmpty) return;
    if (deleteFile && entry.path != null) {
      try {
        final file = File(entry.path!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    state = state.copyWith(local: state.local.where((e) => e.id != id).toList());
    await _persistLocal();
  }

  Future<void> refreshRemote({int limit = 50}) async {
    final session = _ref.read(sessionProvider);
    if (!session.isAuthed) return;
    state = state.copyWith(loading: true);
    try {
      final api = ApiRepository();
      final items = await api.getDownloads(session.username!, session.token!, limit: limit);
      final remote = items.map((e) {
        return DownloadEntry(
          id: e['id']?.toString() ?? e['filename']?.toString() ?? '',
          filename: e['filename']?.toString() ?? '',
          size: (e['size'] as num?)?.toInt() ?? 0,
          ts: (e['ts'] as num?)?.toDouble() ?? 0,
          isLocal: false,
        );
      }).toList();
      state = state.copyWith(remote: remote, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }
}

final downloadsProvider = StateNotifierProvider<DownloadsController, DownloadsState>(
  (ref) => DownloadsController(ref),
);

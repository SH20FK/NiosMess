import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'repositories/api_repository.dart';
import 'session_provider.dart';

const _usageEntriesKey = 'data_usage_entries_v1';
const _usageLastSyncKey = 'data_usage_last_sync_v1';
const _maxEntries = 600;

class UsageEntry {
  UsageEntry({
    required this.direction,
    required this.bytes,
    required this.kind,
    required this.ts,
  });

  final String direction;
  final int bytes;
  final String kind;
  final double ts;

  Map<String, dynamic> toJson() => {
        'direction': direction,
        'bytes': bytes,
        'kind': kind,
        'ts': ts,
      };

  factory UsageEntry.fromJson(Map<String, dynamic> json) => UsageEntry(
        direction: json['direction']?.toString() ?? 'download',
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        kind: json['kind']?.toString() ?? 'api',
        ts: (json['ts'] as num?)?.toDouble() ?? 0,
      );
}

class UsageBucket {
  const UsageBucket({this.upload = 0, this.download = 0});

  final int upload;
  final int download;

  UsageBucket copyWith({int? upload, int? download}) => UsageBucket(
        upload: upload ?? this.upload,
        download: download ?? this.download,
      );
}

class UsageAggregate {
  const UsageAggregate({
    required this.day,
    required this.week,
    required this.month,
  });

  final UsageBucket day;
  final UsageBucket week;
  final UsageBucket month;
}

class DataUsageState {
  const DataUsageState({
    required this.local,
    this.server,
    this.lastSync,
    this.loading = false,
  });

  final UsageAggregate local;
  final UsageAggregate? server;
  final DateTime? lastSync;
  final bool loading;

  DataUsageState copyWith({
    UsageAggregate? local,
    UsageAggregate? server,
    DateTime? lastSync,
    bool? loading,
  }) {
    return DataUsageState(
      local: local ?? this.local,
      server: server ?? this.server,
      lastSync: lastSync ?? this.lastSync,
      loading: loading ?? this.loading,
    );
  }
}

class DataUsageController extends StateNotifier<DataUsageState> {
  DataUsageController(this._ref)
      : super(
          const DataUsageState(
            local: UsageAggregate(
              day: UsageBucket(),
              week: UsageBucket(),
              month: UsageBucket(),
            ),
          ),
        ) {
    _load();
    _attachInterceptor();
  }

  final Ref _ref;
  final List<UsageEntry> _entries = [];
  bool _interceptorAttached = false;

  void _attachInterceptor() {
    if (_interceptorAttached) return;
    _interceptorAttached = true;
    ApiClient.instance.addInterceptor(_UsageInterceptor(_recordFromInterceptor));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usageEntriesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _entries
          ..clear()
          ..addAll(list.map((e) => UsageEntry.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {}
    }
    final lastSyncRaw = prefs.getDouble(_usageLastSyncKey);
    final lastSync = lastSyncRaw != null ? DateTime.fromMillisecondsSinceEpoch((lastSyncRaw * 1000).toInt()) : null;
    state = state.copyWith(local: _buildAggregate(), lastSync: lastSync);
  }

  UsageAggregate _buildAggregate() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    UsageBucket sumSince(double seconds) {
      int up = 0;
      int down = 0;
      final cutoff = now - seconds;
      for (final entry in _entries) {
        if (entry.ts < cutoff) continue;
        if (entry.direction == 'upload') {
          up += entry.bytes;
        } else {
          down += entry.bytes;
        }
      }
      return UsageBucket(upload: up, download: down);
    }

    return UsageAggregate(
      day: sumSince(86400),
      week: sumSince(86400 * 7),
      month: sumSince(86400 * 30),
    );
  }

  void _recordFromInterceptor(int bytes, bool upload) {
    if (bytes <= 0) return;
    record(bytes: bytes, direction: upload ? 'upload' : 'download', kind: 'api');
  }

  Future<void> record({
    required int bytes,
    required String direction,
    String kind = 'api',
  }) async {
    if (bytes <= 0) return;
    final entry = UsageEntry(
      direction: direction,
      bytes: bytes,
      kind: kind,
      ts: DateTime.now().millisecondsSinceEpoch / 1000.0,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    await _persist();
    state = state.copyWith(local: _buildAggregate());
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _usageEntriesKey,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> refreshServer() async {
    final session = _ref.read(sessionProvider);
    if (!session.isAuthed) return;
    state = state.copyWith(loading: true);
    try {
      final api = ApiRepository();
      final data = await api.getDataUsage(session.username!, session.token!);
      final server = UsageAggregate(
        day: UsageBucket(
          upload: (data['day']?['upload'] as num?)?.toInt() ?? 0,
          download: (data['day']?['download'] as num?)?.toInt() ?? 0,
        ),
        week: UsageBucket(
          upload: (data['week']?['upload'] as num?)?.toInt() ?? 0,
          download: (data['week']?['download'] as num?)?.toInt() ?? 0,
        ),
        month: UsageBucket(
          upload: (data['month']?['upload'] as num?)?.toInt() ?? 0,
          download: (data['month']?['download'] as num?)?.toInt() ?? 0,
        ),
      );
      state = state.copyWith(server: server, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> syncToServer() async {
    final session = _ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final prefs = await SharedPreferences.getInstance();
    final lastSyncRaw = prefs.getDouble(_usageLastSyncKey) ?? 0;
    final pending = _entries.where((e) => e.ts > lastSyncRaw).toList();
    if (pending.isEmpty) return;
    try {
      final api = ApiRepository();
      await api.syncDataUsage(
        session.username!,
        session.token!,
        pending.map((e) => e.toJson()).toList(),
      );
      final maxTs = pending.map((e) => e.ts).fold<double>(lastSyncRaw, (prev, ts) => ts > prev ? ts : prev);
      await prefs.setDouble(_usageLastSyncKey, maxTs);
      state = state.copyWith(lastSync: DateTime.fromMillisecondsSinceEpoch((maxTs * 1000).toInt()));
    } catch (_) {}
  }
}

class _UsageInterceptor extends Interceptor {
  _UsageInterceptor(this.onData);

  final void Function(int bytes, bool upload) onData;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final bytes = _estimateRequestBytes(options);
    if (bytes > 0) onData(bytes, true);
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final bytes = _estimateResponseBytes(response);
    if (bytes > 0) onData(bytes, false);
    super.onResponse(response, handler);
  }

  int _estimateRequestBytes(RequestOptions options) {
    final data = options.data;
    if (data == null) return 0;
    try {
      if (data is FormData) {
        int size = 0;
        for (final file in data.files) {
          size += file.value.length;
        }
        if (data.fields.isNotEmpty) {
          size += utf8.encode(jsonEncode(data.fields)).length;
        }
        return size;
      }
      if (data is String) return utf8.encode(data).length;
      return utf8.encode(jsonEncode(data)).length;
    } catch (_) {
      return 0;
    }
  }

  int _estimateResponseBytes(Response response) {
    final data = response.data;
    if (data == null) return 0;
    try {
      if (data is List<int>) return data.length;
      if (data is String) return utf8.encode(data).length;
      return utf8.encode(jsonEncode(data)).length;
    } catch (_) {
      return 0;
    }
  }
}

final dataUsageProvider = StateNotifierProvider<DataUsageController, DataUsageState>(
  (ref) => DataUsageController(ref),
);

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatDraftEntry {
  const ChatDraftEntry({required this.chatId, required this.text});

  final int chatId;
  final String text;
}

class DraftStorage {
  /// Unscoped access is reserved for the ownership-checked legacy migration.
  const DraftStorage() : accountId = null, _generation = 0;
  DraftStorage.forAccount(this.accountId)
    : _generation = _generations[accountId] ?? 0;
  final int? accountId;
  final int _generation;
  static const _secure = FlutterSecureStorage();
  static final _generations = <int?, int>{};
  static final _writes = <int, Future<void>>{};
  static final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  bool get _valid => _generation == (_generations[accountId] ?? 0);
  String get _key => 'draft.secure.v2.$accountId';
  static const String _prefix = 'draft.';

  Future<Map<String, String>> _read() async {
    if (accountId == null || !_valid) return {};
    final raw = await _secure.read(key: _key);
    if (!_valid || raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('DRAFT_STORAGE_INVALID');
    return {
      for (final item in decoded.entries)
        if (int.tryParse('${item.key}') != null && item.value is String)
          '${item.key}': item.value as String,
    };
  }

  Future<void> _mutate(Future<void> Function() operation) {
    final id = accountId;
    if (id == null || !_valid) {
      return Future.error(StateError('DRAFT_ACCOUNT_CLOSED'));
    }
    final previous = _writes[id] ?? Future<void>.value();
    final next = previous.then((_) async {
      if (!_valid) throw StateError('DRAFT_ACCOUNT_CLOSED');
      await operation();
    });
    final settled = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writes[id] = settled;
    return next;
  }

  Future<void> _store(Map<String, String> drafts) async {
    if (!_valid) throw StateError('DRAFT_ACCOUNT_CLOSED');
    await _secure.write(key: _key, value: jsonEncode(drafts));
    if (!_valid) return;
    _changes.add(null);
  }

  Future<String?> get(int chatId) async {
    if (accountId == null) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_prefix$chatId');
    }
    final drafts = await _read();
    if (drafts.containsKey('$chatId') || !_valid) return drafts['$chatId'];
    // Key ownership does not prove ownership of drafts in shared group chats.
    // Unattributed historical sources remain untouched, never guessed.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('draft.owner.$chatId') != accountId) return null;
    final legacy = prefs.getString('$_prefix$chatId');
    if (legacy == null || legacy.trim().isEmpty || !_valid) return null;
    await _mutate(() async {
      final current = await _read();
      current.putIfAbsent('$chatId', () => legacy);
      await _store(current);
      final verified = await _read();
      if (_valid && verified['$chatId'] == legacy) {
        if (await prefs.remove('$_prefix$chatId')) {
          await prefs.remove('draft.owner.$chatId');
        }
      }
    });
    return (await _read())['$chatId'];
  }

  Future<void> set(int chatId, String text) => _mutate(() async {
    final drafts = await _read();
    if (text.trim().isEmpty) {
      drafts.remove('$chatId');
    } else {
      drafts['$chatId'] = text;
    }
    await _store(drafts);
  });

  /// Apply a remote draft only if no local edit happened while it was fetched.
  Future<bool> compareAndSet(
    int chatId,
    String expected,
    String replacement,
  ) async {
    var changed = false;
    await _mutate(() async {
      final drafts = await _read();
      if ((drafts['$chatId'] ?? '') != expected) return;
      if (replacement.trim().isEmpty) {
        drafts.remove('$chatId');
      } else {
        drafts['$chatId'] = replacement;
      }
      await _store(drafts);
      changed = true;
    });
    return changed;
  }

  Future<void> remove(int chatId) async {
    if (accountId == null) {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.remove('$_prefix$chatId')) {
        throw StateError('Draft storage write failed');
      }
      _changes.add(null);
      return;
    }
    await _mutate(() async {
      final drafts = await _read();
      drafts.remove('$chatId');
      await _store(drafts);
    });
  }

  Future<List<ChatDraftEntry>> list() async {
    // Unowned historical plaintext is not exposed in another account's inbox.
    if (accountId == null) return [];
    final drafts = await _read();
    return [
      for (final entry in drafts.entries)
        if (entry.value.trim().isNotEmpty)
          ChatDraftEntry(chatId: int.parse(entry.key), text: entry.value),
    ];
  }

  Future<Map<int, String>> asMap() async => {
    for (final entry in await list()) entry.chatId: entry.text,
  };

  static Future<void> eraseAccount(int accountId) async {
    _generations[accountId] = (_generations[accountId] ?? 0) + 1;
    final previous = _writes[accountId] ?? Future<void>.value();
    final job = previous.then((_) async {
      await _secure.delete(key: 'draft.secure.v2.$accountId');
      await _secure.delete(key: 'draft.sync.v1.$accountId');
    });
    _writes[accountId] = job.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await job;
    _changes.add(null);
  }
}

final Provider<DraftStorage> draftStorageProvider = Provider<DraftStorage>(
  (Ref ref) => DraftStorage.forAccount(
    ref.watch(authProvider.select((s) => s.session?.userId)),
  ),
);

final FutureProvider<Map<int, String>> draftMapProvider =
    FutureProvider<Map<int, String>>(
      (Ref ref) => ref.read(draftStorageProvider).asMap(),
    );

final liveDraftMapProvider = StreamProvider<Map<int, String>>((ref) async* {
  final accountId = ref.watch(authProvider.select((s) => s.session?.userId));
  if (accountId == null) {
    yield const {};
    return;
  }
  final storage = ref.watch(draftStorageProvider);
  // Subscribe before the first disk read so a concurrent save cannot be missed.
  final pending = StreamController<void>();
  final subscription = storage.changes.listen((_) {
    if (!pending.isClosed) pending.add(null);
  });
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(pending.close());
  });
  yield await storage.asMap();
  await for (final _ in pending.stream) {
    yield await storage.asMap();
  }
});

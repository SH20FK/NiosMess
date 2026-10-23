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
  const DraftStorage();
  static final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  static const String _prefix = 'draft.';

  Future<String?> get(int chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$chatId');
  }

  Future<void> set(int chatId, String text) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String trimmed = text.trim();
    final stored = trimmed.isEmpty
        ? await prefs.remove('$_prefix$chatId')
        : await prefs.setString('$_prefix$chatId', trimmed);
    if (!stored) throw StateError('Draft storage write failed');
    _changed();
  }

  Future<void> remove(int chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove('$_prefix$chatId')) {
      throw StateError('Draft storage write failed');
    }
    _changed();
  }

  Future<List<ChatDraftEntry>> list() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<ChatDraftEntry> drafts = <ChatDraftEntry>[];
    for (final String key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final int? chatId = int.tryParse(key.substring(_prefix.length));
      final String? text = prefs.getString(key);
      if (chatId == null || text == null || text.trim().isEmpty) continue;
      drafts.add(ChatDraftEntry(chatId: chatId, text: text.trim()));
    }
    return drafts;
  }

  Future<Map<int, String>> asMap() async {
    final List<ChatDraftEntry> entries = await list();
    return <int, String>{
      for (final ChatDraftEntry entry in entries) entry.chatId: entry.text,
    };
  }
}

final Provider<DraftStorage> draftStorageProvider = Provider<DraftStorage>(
  (Ref ref) => const DraftStorage(),
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

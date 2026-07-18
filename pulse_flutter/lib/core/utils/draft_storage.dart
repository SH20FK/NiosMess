import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatDraftEntry {
  const ChatDraftEntry({required this.chatId, required this.text});

  final int chatId;
  final String text;
}

class DraftStorage {
  const DraftStorage();

  static const String _prefix = 'draft.';

  Future<String?> get(int chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$chatId');
  }

  Future<void> set(int chatId, String text) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      await prefs.remove('$_prefix$chatId');
    } else {
      await prefs.setString('$_prefix$chatId', trimmed);
    }
  }

  Future<void> remove(int chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$chatId');
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
    return <int, String>{for (final ChatDraftEntry entry in entries) entry.chatId: entry.text};
  }
}

final Provider<DraftStorage> draftStorageProvider = Provider<DraftStorage>(
  (Ref ref) => const DraftStorage(),
);

final FutureProvider<Map<int, String>> draftMapProvider = FutureProvider<Map<int, String>>(
  (Ref ref) => ref.read(draftStorageProvider).asMap(),
);

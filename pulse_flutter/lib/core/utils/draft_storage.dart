import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

final Provider<DraftStorage> draftStorageProvider = Provider<DraftStorage>(
  (Ref ref) => DraftStorage(),
);

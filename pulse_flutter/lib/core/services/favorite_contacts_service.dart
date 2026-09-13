import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages pinned favorite contacts persisted in SharedPreferences.
class FavoriteContactsNotifier extends Notifier<Set<int>> {
  static const String _storageKey = 'favorite_contact_ids';

  @override
  Set<int> build() {
    _loadFromStorage();
    return const <int>{};
  }

  Future<void> _loadFromStorage() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList(_storageKey) ?? <String>[];
      final Set<int> loaded = list
          .map((String s) => int.tryParse(s))
          .whereType<int>()
          .toSet();
      state = loaded;
    } catch (_) {}
  }

  Future<void> toggleFavorite(int userId) async {
    if (userId <= 0) return;
    final Set<int> updated = Set<int>.from(state);
    if (updated.contains(userId)) {
      updated.remove(userId);
    } else {
      updated.add(userId);
    }
    state = updated;
    await _saveToStorage(updated);
  }

  Future<void> addFavorite(int userId) async {
    if (userId <= 0 || state.contains(userId)) return;
    final Set<int> updated = Set<int>.from(state)..add(userId);
    state = updated;
    await _saveToStorage(updated);
  }

  Future<void> removeFavorite(int userId) async {
    if (!state.contains(userId)) return;
    final Set<int> updated = Set<int>.from(state)..remove(userId);
    state = updated;
    await _saveToStorage(updated);
  }

  bool isFavorite(int userId) => state.contains(userId);

  Future<void> _saveToStorage(Set<int> ids) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> stringList =
          ids.map((int id) => id.toString()).toList(growable: false);
      await prefs.setStringList(_storageKey, stringList);
    } catch (_) {}
  }
}

final NotifierProvider<FavoriteContactsNotifier, Set<int>>
    favoriteContactsProvider =
    NotifierProvider<FavoriteContactsNotifier, Set<int>>(
      FavoriteContactsNotifier.new,
    );

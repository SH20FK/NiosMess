import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';

class RecentStickersNotifier extends AsyncNotifier<List<int>> {
  int? _account;
  Future<void> _writes = Future<void>.value();
  String get _key => 'recent_stickers_v1_$_account';
  @override
  Future<List<int>> build() async {
    _account = ref.watch(authProvider.select((a) => a.session?.userId));
    if (_account == null) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonDecode(prefs.getString(_key) ?? '[]');
      return raw is List
          ? raw.whereType<int>().where((id) => id > 0).take(32).toList()
          : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> record(int id) {
    final account = _account;
    return _writes = _writes
        .catchError((Object _) {})
        .then((_) => _record(account, id));
  }

  Future<void> _record(int? account, int id) async {
    if (account == null || id <= 0) return;
    final current = state.value ?? await future;
    if (account != _account) return;
    final updated = [id, ...current.where((v) => v != id)].take(32).toList();
    state = AsyncData(updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (account == _account) await prefs.setString(_key, jsonEncode(updated));
    } catch (_) {
      /* Recently used stickers are optional local UI history. */
    }
  }
}

final recentStickersProvider =
    AsyncNotifierProvider<RecentStickersNotifier, List<int>>(
      RecentStickersNotifier.new,
    );

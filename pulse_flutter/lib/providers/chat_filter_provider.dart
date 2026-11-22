import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChatFilter { all, unread, groups, channels, direct, bots }

/// Type filter of the inbox.
///
/// A chat type (groups, channels, direct, bots) is remembered per account
/// between launches, like the selected folder. "Unread" is not: it is a
/// passing view, and reopening the app into an empty unread list reads as
/// lost chats.
class ChatFilterNotifier extends Notifier<ChatFilter> {
  static const String _prefix = 'chat_filter_v1_';
  int? _account;
  bool _touched = false;

  @override
  ChatFilter build() {
    final int? userId = ref.watch(
      authProvider.select((AuthState a) => a.session?.userId),
    );
    _account = userId;
    _touched = false;
    if (userId != null) unawaited(_restore(userId));
    return ChatFilter.all;
  }

  void updateFilter(ChatFilter filter) {
    _touched = true;
    if (state == filter) return;
    state = filter;
    _persist(filter);
  }

  static bool _remembered(ChatFilter filter) =>
      filter != ChatFilter.all && filter != ChatFilter.unread;

  Future<void> _restore(int userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // A choice made while the store was opening wins over the saved one.
      if (!ref.mounted || _account != userId || _touched) return;
      final String? name = prefs.getString('$_prefix$userId');
      final ChatFilter? saved = ChatFilter.values
          .where((ChatFilter f) => f.name == name)
          .firstOrNull;
      if (saved != null && _remembered(saved)) state = saved;
    } catch (_) {}
  }

  void _persist(ChatFilter filter) {
    final int? userId = _account;
    if (userId == null) return;
    unawaited(() async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        if (_remembered(filter)) {
          await prefs.setString('$_prefix$userId', filter.name);
        } else {
          await prefs.remove('$_prefix$userId');
        }
      } catch (_) {}
    }());
  }
}

final chatFilterProvider = NotifierProvider<ChatFilterNotifier, ChatFilter>(
  ChatFilterNotifier.new,
);

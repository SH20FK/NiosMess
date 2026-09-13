import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMutedNotifier extends AsyncNotifier<bool> {
  ChatMutedNotifier(this._chatId);

  final int _chatId;

  static String _key(int chatId) => 'chat_notifications_muted_$chatId';

  @override
  Future<bool> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(_chatId)) ?? false;
  }

  Future<void> toggle() async {
    final bool current = state.value ?? false;
    final bool next = !current;
    state = AsyncData<bool>(next);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_chatId), next);
  }

  Future<void> setMuted(bool muted) async {
    state = AsyncData<bool>(muted);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_chatId), muted);
  }
}

final chatMutedProvider =
    AsyncNotifierProvider.family<ChatMutedNotifier, bool, int>(
      ChatMutedNotifier.new,
    );

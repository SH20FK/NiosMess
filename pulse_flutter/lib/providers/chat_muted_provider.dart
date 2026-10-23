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

  Future<void> toggle() async => setMuted(!(state.value ?? await future));

  Future<void> setMuted(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_key(_chatId), muted)) {
      throw StateError('Notification preference write failed');
    }
    if (ref.mounted) state = AsyncData<bool>(muted);
  }
}

final chatMutedProvider =
    AsyncNotifierProvider.family<ChatMutedNotifier, bool, int>(
      ChatMutedNotifier.new,
    );

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

class ChatMutedNotifier extends AsyncNotifier<bool> {
  ChatMutedNotifier(this._chatId);

  final int _chatId;

  String _key(int? account) => 'chat_notifications_muted_${account}_$_chatId';

  @override
  Future<bool> build() async {
    final account = ref.watch(authProvider.select((s) => s.session?.userId));
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(account)) ?? false;
  }

  Future<void> toggle() async => setMuted(!(state.value ?? await future));

  Future<void> setMuted(bool muted) async {
    final account = ref.read(authProvider).session?.userId;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_key(account), muted)) {
      throw StateError('Notification preference write failed');
    }
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return;
    }
    state = AsyncData<bool>(muted);
    await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
  }
}

final chatMutedProvider =
    AsyncNotifierProvider.family<ChatMutedNotifier, bool, int>(
      ChatMutedNotifier.new,
    );

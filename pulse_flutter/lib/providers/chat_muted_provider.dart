import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

/// Prefs key of a per-chat notification mute.
///
/// The format is part of the FCM contract: `auth_provider` walks these keys
/// when registering the device token and sends them as `muted_chat_ids`, so
/// renaming the prefix silently breaks server-side mute filtering.
String _key(int? account, int chatId) =>
    'chat_notifications_muted_${account}_$chatId';

/// Account-scoped set of chats whose notifications are muted.
///
/// SharedPreferences stays the persisted mirror (the FCM registration reads the
/// same keys); this hub is the single in-memory state that screens, the
/// delivery path and websocket hints observe. One prefs read per account
/// replaces one read per chat that the inbox ever rendered.
///
/// Server state: the local `server_core` has no per-user notification mute yet
/// (`ChatMember.is_muted` is an admin speak-restriction, and `list_chats` sends
/// no mute field), so prefs is authoritative until the server starts sending
/// one. [applyServerMute] is the ready ingestion point for that field.
class ChatMuteHub extends AsyncNotifier<Set<int>> {
  int? _account;

  @override
  Future<Set<int>> build() async {
    final int? account = ref.watch(
      authProvider.select((AuthState state) => state.session?.userId),
    );
    _account = account;
    if (account == null) return const <int>{};
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || _account != account) return const <int>{};
      final String prefix = 'chat_notifications_muted_${account}_';
      final Set<int> muted = <int>{};
      for (final String key in prefs.getKeys()) {
        if (!key.startsWith(prefix) || prefs.getBool(key) != true) continue;
        final int? chatId = int.tryParse(key.substring(prefix.length));
        if (chatId != null && chatId > 0) muted.add(chatId);
      }
      return muted;
    } catch (error) {
      // Fail open: a broken prefs store must not silence every chat.
      debugPrint('[chat_muted_provider] MUTE_CACHE_UNAVAILABLE: $error');
      return const <int>{};
    }
  }

  Future<void> setMuted(int chatId, bool muted) async {
    if (chatId <= 0) return;
    final int? account = ref.read(authProvider).session?.userId;
    final Set<int> current = await future;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_key(account, chatId), muted)) {
      throw StateError('Notification preference write failed');
    }
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return;
    }
    _emit(muted, chatId, state.value ?? current);
    if (account != null) {
      await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
    }
  }

  /// Mutes or unmutes several chats at once: every preference is written
  /// first, then the device token is registered a single time.
  Future<void> setMutedAll(Iterable<int> chatIds, bool muted) async {
    final int? account = ref.read(authProvider).session?.userId;
    final Set<int> current = await future;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<int> next = <int>{...(state.value ?? current)};
    try {
      for (final int chatId in chatIds) {
        if (chatId <= 0) continue;
        if (!await prefs.setBool(_key(account, chatId), muted)) {
          throw StateError('Notification preference write failed');
        }
        if (muted) {
          next.add(chatId);
        } else {
          next.remove(chatId);
        }
      }
    } finally {
      // A write that failed halfway still leaves the earlier ones on disk:
      // the state follows what was actually stored.
      if (ref.mounted && ref.read(authProvider).session?.userId == account) {
        state = AsyncData<Set<int>>(Set<int>.unmodifiable(next));
      }
    }
    if (account != null &&
        ref.mounted &&
        ref.read(authProvider).session?.userId == account) {
      await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
    }
  }

  /// Applies a mute flag that came from the server (e.g. a `chat_updated`
  /// payload). No-op while the server sends no such field, and no-op when the
  /// value already matches so a stream of pushes cannot re-register the token.
  Future<void> applyServerMute(int chatId, bool muted) async {
    if (chatId <= 0) return;
    final int? account = ref.read(authProvider).session?.userId;
    if (account == null) return;
    final Set<int> current = await future;
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return;
    }
    if (current.contains(chatId) == muted) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_key(account, chatId), muted)) return;
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return;
    }
    _emit(muted, chatId, state.value ?? current);
    await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
  }

  void _emit(bool muted, int chatId, Set<int> current) {
    final Set<int> next = <int>{...current};
    if (muted) {
      next.add(chatId);
    } else {
      next.remove(chatId);
    }
    state = AsyncData<Set<int>>(Set<int>.unmodifiable(next));
  }
}

/// Per-chat facade over [ChatMuteHub].
///
/// Each entry is a pure view over the hub: no SharedPreferences read and no
/// stream subscription per chat. It is *not* auto-disposable on purpose —
/// delivery paths (`call_push_handler`, message sounds) await
/// `chatMutedProvider(id).future`, and an auto-disposed element would be
/// evicted while still loading, which Riverpod reports as
/// "disposed during loading state" and would fail the mute gate open.
class ChatMutedNotifier extends AsyncNotifier<bool> {
  ChatMutedNotifier(this.chatId);

  final int chatId;

  @override
  Future<bool> build() async {
    final Set<int> muted = await ref.watch(chatMuteHubProvider.future);
    return muted.contains(chatId);
  }

  Future<void> toggle() async {
    final Set<int> muted = await ref.read(chatMuteHubProvider.future);
    await setMuted(!muted.contains(chatId));
  }

  Future<void> setMuted(bool muted) async {
    state = AsyncData<bool>(muted);
    try {
      await ref.read(chatMuteHubProvider.notifier).setMuted(chatId, muted);
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError<bool>(error, stack);
      rethrow;
    }
  }
}

final chatMuteHubProvider =
    AsyncNotifierProvider<ChatMuteHub, Set<int>>(ChatMuteHub.new);

final chatMutedProvider =
    AsyncNotifierProvider.family<ChatMutedNotifier, bool, int>(
      ChatMutedNotifier.new,
    );

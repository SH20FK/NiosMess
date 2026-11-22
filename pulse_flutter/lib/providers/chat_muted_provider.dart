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
/// Server state: a server that keeps the inbox state sends
/// `notifications_muted` with every chat, and that account-wide value wins.
/// `ChatsNotifier` feeds it in through [applyServerMutes] and carries local
/// toggles back to the server. Against an older server prefs stays the only
/// record.
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

  /// Applies a mute flag that came from the server. No-op when the value
  /// already matches, so a stream of pushes cannot re-register the token.
  Future<void> applyServerMute(int chatId, bool muted) =>
      applyServerMutes(<int, bool>{chatId: muted});

  /// Reconciles the device preference with the account-wide flags of a server
  /// snapshot, by chat id.
  ///
  /// Until the server is known to hold this device's mutes, a chat muted here
  /// and not there is returned instead of being unmuted: it was muted before
  /// the server kept the flag, and the caller uploads it. Once nothing is left
  /// to upload the server value wins.
  Future<Set<int>> adoptServerMutes(Map<int, bool> values) async {
    final int? account = ref.read(authProvider).session?.userId;
    if (account == null) return const <int>{};
    final Set<int> current = await future;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return const <int>{};
    }
    final String adopted = 'chat_mute_server_adopted_$account';
    Set<int> localOnly = const <int>{};
    if (prefs.getBool(adopted) != true) {
      final Set<int> muted = state.value ?? current;
      localOnly = <int>{
        for (final MapEntry<int, bool> entry in values.entries)
          if (!entry.value && muted.contains(entry.key)) entry.key,
      };
      if (localOnly.isEmpty) await prefs.setBool(adopted, true);
    }
    await applyServerMutes(<int, bool>{
      for (final MapEntry<int, bool> entry in values.entries)
        if (!localOnly.contains(entry.key)) entry.key: entry.value,
    });
    return localOnly;
  }

  /// Applies the mute flags of several chats that came from the server, by
  /// chat id. Only the values that differ are written, and the device token is
  /// registered once for all of them.
  Future<void> applyServerMutes(Map<int, bool> values) async {
    final int? account = ref.read(authProvider).session?.userId;
    if (account == null) return;
    final Set<int> current = await future;
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return;
    }
    final Set<int> next = <int>{...(state.value ?? current)};
    final Map<int, bool> changes = <int, bool>{
      for (final MapEntry<int, bool> entry in values.entries)
        if (entry.key > 0 && next.contains(entry.key) != entry.value)
          entry.key: entry.value,
    };
    if (changes.isEmpty) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    bool changed = false;
    for (final MapEntry<int, bool> entry in changes.entries) {
      if (!await prefs.setBool(_key(account, entry.key), entry.value)) continue;
      if (entry.value) {
        next.add(entry.key);
      } else {
        next.remove(entry.key);
      }
      changed = true;
    }
    if (!changed ||
        !ref.mounted ||
        ref.read(authProvider).session?.userId != account) {
      return;
    }
    state = AsyncData<Set<int>>(Set<int>.unmodifiable(next));
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

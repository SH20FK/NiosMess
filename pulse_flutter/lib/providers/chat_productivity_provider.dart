import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class ChatProductivityRepository {
  ChatProductivityRepository(this.ref);
  final Ref ref;
  final Map<String, ({String fingerprint, Map<String, dynamic> request})>
  _attempts = {};
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    final session = ref.read(authProvider).session;
    if (session == null) throw StateError('Войдите в аккаунт');
    final result = await ref
        .read(webSocketClientProvider)
        .request(action, payload: payload);
    if (!ref.mounted ||
        ref.read(authProvider).session?.userId != session.userId ||
        ref.read(authProvider).session?.accessToken != session.accessToken) {
      throw StateError('Сеанс изменился');
    }
    if (result is! Map) throw StateError('Некорректный ответ сервера');
    if (result['error'] != null) throw StateError(result['error'].toString());
    return Map<String, dynamic>.from(result);
  }

  int? _savedChatId;
  Future<ApiChatSummary>? _savedInFlight;

  /// Last resolved Saved Messages chat id, or `null` while it is unknown.
  int? get cachedSavedChatId => _savedChatId;

  Future<ApiChatSummary> saved() {
    final cachedId = _savedChatId;
    if (cachedId != null) {
      final local = ref.read(chatByIdProvider(cachedId));
      if (local != null && local.isSaved) return Future.value(local);
      _savedChatId = null;
    }
    // Coalesce concurrent taps into a single `open_saved_messages` request.
    return _savedInFlight ??= _openSaved().whenComplete(
      () => _savedInFlight = null,
    );
  }

  Future<ApiChatSummary> _openSaved() async {
    if (!ref.read(webSocketClientProvider).isConnected) {
      final saved = ref
          .read(chatsProvider)
          .value
          ?.where((c) => c.isSaved)
          .firstOrNull;
      if (saved != null) {
        _savedChatId = saved.id;
        return saved;
      }
    }
    final result = ApiChatSummary.fromJson(await call('open_saved_messages'));
    _savedChatId = result.id;
    ref.read(chatsProvider.notifier).upsertChat(result);
    return result;
  }

  Future<void> schedule(
    int chatId,
    String text,
    DateTime due, {
    String? operationId,
    int? replyTo,
    int? sourceChat,
    int? sourceMessage,
  }) async {
    final session = ref.read(authProvider).session;
    if (session == null) throw StateError('Войдите в аккаунт');
    final key = operationId ?? const Uuid().v4();
    final fingerprint = jsonEncode([
      session.userId,
      session.accessToken,
      chatId,
      text,
      due.toUtc().toIso8601String(),
      replyTo,
      sourceChat,
      sourceMessage,
    ]);
    final previous = _attempts[key];
    if (previous != null) {
      if (previous.fingerprint != fingerprint) {
        throw StateError(
          'Проверьте отложенные сообщения перед изменением: предыдущая попытка могла сохраниться',
        );
      }
      await call('schedule_chat_message', previous.request);
      _attempts.remove(key);
      ref.invalidate(scheduledChatMessagesProvider);
      return;
    }
    final chat = ref.read(chatByIdProvider(chatId));
    if (chat == null || chat.isSecret) throw StateError('Выберите обычный чат');
    if (text.trim().isEmpty) throw StateError('Введите сообщение');
    final payload = <String, dynamic>{
      'chat_id': chatId,
      'reply_to_id': ?replyTo,
    };
    final ordinary = ref.read(ordinaryE2eeProvider);
    if (chat.chatType == 'direct' && !chat.isBotChat) {
      if (ordinary == null) {
        throw StateError('Сквозное шифрование ещё не подключено');
      }
      final prepared = await ordinary.prepare(chatId, force: true);
      if (prepared == null) throw StateError('Нужно подключить шифрование');
      payload['e2ee_content'] = await ordinary.encrypt(
        chatId,
        text,
        reply: replyTo,
        preparedContext: prepared,
      );
    } else {
      payload['content'] = text;
    }
    if (!ref.mounted ||
        ref.read(authProvider).session?.userId != session.userId ||
        ref.read(authProvider).session?.accessToken != session.accessToken) {
      throw StateError('Сеанс изменился');
    }
    final request = <String, dynamic>{
      'id': key,
      'due_at': due.toUtc().toIso8601String(),
      'payload': payload,
      'kind': sourceMessage == null ? 'message' : 'reminder',
      'source_chat_id': ?sourceChat,
      'source_message_id': ?sourceMessage,
    };
    if (_attempts.length >= 32) _attempts.remove(_attempts.keys.first);
    _attempts[key] = (fingerprint: fingerprint, request: request);
    await call('schedule_chat_message', request);
    _attempts.remove(key);
    ref.invalidate(scheduledChatMessagesProvider);
  }

  Future<void> saveMessageText(ApiMessage message, String text) async {
    final session = ref.read(authProvider).session;
    final chat = await saved();
    if (!ref.mounted ||
        ref.read(authProvider).session?.userId != session?.userId ||
        ref.read(authProvider).session?.accessToken != session?.accessToken) {
      throw StateError('Сеанс изменился');
    }
    await ref
        .read(chatMessagesProvider(chat.id).notifier)
        .send(text, requestAi: false);
  }
}

final chatProductivityRepositoryProvider = Provider((ref) {
  ref.watch(
    authProvider.select((a) => (a.session?.userId, a.session?.accessToken)),
  );
  return ChatProductivityRepository(ref);
});

void _listenChanges(Ref ref) {
  final ws = ref.read(webSocketClientProvider);
  final connected = ws.onConnected.listen((_) {
    if (ref.mounted) ref.invalidateSelf();
  });
  final push = ws.pushStream.listen((m) {
    if (m['action'] == 'productivity_changed' && ref.mounted) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(connected.cancel);
  ref.onDispose(push.cancel);
}

/// Raised when the server rejects `save_chat_folder` because the folder was
/// modified on another device (`version` mismatch).
class ChatFolderVersionConflict implements Exception {
  const ChatFolderVersionConflict();
  @override
  String toString() => 'ChatFolderVersionConflict';
}

bool _isVersionConflict(String message) {
  final text = message.toLowerCase();
  return text.contains('изменена') ||
      text.contains('version') ||
      text.contains('conflict') ||
      text.contains('409');
}

class ChatFoldersNotifier extends AsyncNotifier<List<ChatFolder>> {
  int? _account;

  /// Incremented by every local mutation so an in-flight [build] fetch cannot
  /// overwrite a fresher server response (classic last-write-wins race).
  int _generation = 0;

  @override
  Future<List<ChatFolder>> build() async {
    final session = ref.watch(
      authProvider.select((a) => (a.session?.userId, a.session?.accessToken)),
    );
    if (_account != session.$1) {
      state = const AsyncData([]);
      _account = session.$1;
    }
    if (session.$1 == null) return [];
    _listenChanges(ref);
    final generation = ++_generation;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || _account != session.$1) return [];
    final key = 'chat_folders_v1_${session.$1}';
    List<ChatFolder> cached = [];
    try {
      cached = (jsonDecode(prefs.getString(key) ?? '[]') as List)
          .whereType<Map>()
          .map((m) => ChatFolder.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {}
    if (cached.isNotEmpty && generation == _generation) {
      state = AsyncData(cached);
    }
    if (!ref.read(webSocketClientProvider).isConnected) return cached;
    try {
      final result = await ref
          .read(chatProductivityRepositoryProvider)
          .call('list_chat_folders');
      final folders = (result['folders'] as List? ?? [])
          .whereType<Map>()
          .map((m) => ChatFolder.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (!ref.mounted || _account != session.$1) return [];
      if (generation != _generation) return state.value ?? folders;
      await prefs.setString(
        key,
        jsonEncode(folders.map((f) => f.toJson()).toList()),
      );
      return folders;
    } catch (_) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  bool _reordering = false;

  List<ChatFolder>? _foldersFrom(Map<String, dynamic> result) {
    final raw = result['folders'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((m) => ChatFolder.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Applies the authoritative folder list returned by every mutation.
  bool _applyFolders(Map<String, dynamic> result) {
    final folders = _foldersFrom(result);
    if (folders == null) return false;
    _generation++;
    state = AsyncData(folders);
    unawaited(_cacheFolders(folders));
    return true;
  }

  Future<void> _cacheFolders(List<ChatFolder> folders) async {
    final account = _account;
    if (account == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'chat_folders_v1_$account',
        jsonEncode(folders.map((f) => f.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> save(ChatFolder folder) async {
    try {
      final result = await ref
          .read(chatProductivityRepositoryProvider)
          .call('save_chat_folder', folder.toJson());
      if (!_applyFolders(result)) ref.invalidateSelf();
    } on StateError catch (error) {
      // The server rejected the write (usually a stale `version`): drop the
      // stale local list so the next edit starts from fresh state.
      ref.invalidateSelf();
      if (_isVersionConflict(error.message)) {
        throw const ChatFolderVersionConflict();
      }
      rethrow;
    }
  }

  /// Persists a new folder order with one round per folder and a single state
  /// update at the end (the server has no batch reorder action).
  Future<void> reorder(List<ChatFolder> ordered) async {
    if (_reordering) return;
    _reordering = true;
    final repo = ref.read(chatProductivityRepositoryProvider);
    try {
      Map<String, dynamic>? last;
      for (var i = 0; i < ordered.length; i++) {
        last = await repo.call('save_chat_folder', {
          ...ordered[i].toJson(),
          'position': i,
        });
      }
      if (last == null || !_applyFolders(last)) ref.invalidateSelf();
    } on StateError catch (error) {
      ref.invalidateSelf();
      if (_isVersionConflict(error.message)) {
        throw const ChatFolderVersionConflict();
      }
      rethrow;
    } finally {
      _reordering = false;
    }
  }

  Future<void> remove(String id) async {
    final result = await ref
        .read(chatProductivityRepositoryProvider)
        .call('delete_chat_folder', {'id': id});
    if (!_applyFolders(result)) ref.invalidateSelf();
  }
}

final chatFoldersProvider =
    AsyncNotifierProvider<ChatFoldersNotifier, List<ChatFolder>>(
      ChatFoldersNotifier.new,
    );

class SelectedChatFolder extends Notifier<String?> {
  static const String _prefix = 'chat_selected_folder_v1_';
  int? _account;

  @override
  String? build() {
    final userId = ref.watch(authProvider.select((a) => a.session?.userId));
    _account = userId;
    // A folder can disappear (deleted on another device), so drop a selection
    // that no longer exists instead of silently showing every chat.
    ref.listen(chatFoldersProvider, (_, next) {
      final folders = next.value;
      if (folders == null) return;
      final current = state;
      if (current != null && !folders.any((f) => f.id == current)) {
        state = null;
        _persist(null);
      }
    });
    if (userId == null) return null;
    _restore(userId);
    return null;
  }

  void select(String? id) {
    state = id;
    _persist(id);
  }

  Future<void> _restore(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || _account != userId) return;
      final id = prefs.getString('$_prefix$userId');
      if (id == null || id.isEmpty) return;
      final folders = ref.read(chatFoldersProvider).value;
      if (!ref.mounted || _account != userId) return;
      if (folders != null && !folders.any((f) => f.id == id)) {
        await prefs.remove('$_prefix$userId');
        return;
      }
      state = id;
    } catch (_) {}
  }

  void _persist(String? id) {
    final userId = _account;
    if (userId == null) return;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (id == null || id.isEmpty) {
          await prefs.remove('$_prefix$userId');
        } else {
          await prefs.setString('$_prefix$userId', id);
        }
      } catch (_) {}
    }());
  }
}

final selectedChatFolderProvider =
    NotifierProvider<SelectedChatFolder, String?>(SelectedChatFolder.new);

final visibleChatsProvider = Provider<AsyncValue<List<ApiChatSummary>>>(
  (ref) => ref.watch(chatsProvider).whenData((all) {
    final children = <int, List<ApiChatSummary>>{};
    for (final chat in all) {
      if (chat.topicParentId != null) {
        (children[chat.topicParentId!] ??= []).add(chat);
      }
    }
    return [
      for (final root in all.where((c) => c.topicParentId == null))
        (() {
          final topics = children[root.id] ?? [];
          var last = root.lastMessage;
          for (final child in topics) {
            final m = child.lastMessage;
            if (m != null && (last == null || m.sentAt.isAfter(last.sentAt))) {
              last = m;
            }
          }
          return root.copyWith(
            unreadCount:
                root.unreadCount +
                topics.fold(0, (sum, c) => sum + c.unreadCount),
            lastMessage: last,
          );
        })(),
    ];
  }),
);

/// Unread total of a folder plus whether any unread chat in it is not muted.
///
/// VK-style pill: the badge is tinted `primary` only when a muted chat is not
/// the sole reason for the count.
typedef ChatFolderUnread = ({int unread, bool alert});

/// Counters of every folder, computed in one pass over the unread chats.
final _chatFolderUnreadMapProvider =
    Provider.autoDispose<Map<String, ChatFolderUnread>>((ref) {
      final folders =
          ref.watch(chatFoldersProvider).value ?? const <ChatFolder>[];
      if (folders.isEmpty) return const <String, ChatFolderUnread>{};
      final chats =
          ref.watch(chatsProvider).value ?? const <ApiChatSummary>[];
      final muted = ref.watch(chatMuteHubProvider).value ?? const <int>{};
      final unread = <String, int>{};
      final alert = <String>{};
      for (final chat in chats) {
        if (chat.unreadCount <= 0) continue;
        for (final folder in folders) {
          if (!folder.includes(chat)) continue;
          unread[folder.id] = (unread[folder.id] ?? 0) + chat.unreadCount;
          if (!muted.contains(chat.id)) alert.add(folder.id);
        }
      }
      return <String, ChatFolderUnread>{
        for (final folder in folders)
          folder.id: (
            unread: unread[folder.id] ?? 0,
            alert: alert.contains(folder.id),
          ),
      };
    });

/// Counter of one folder. A record, so a folder pill is only notified when its
/// own numbers change, not on every presence or preview update of the inbox.
final chatFolderUnreadProvider = Provider.autoDispose
    .family<ChatFolderUnread, String>(
      (ref, folderId) =>
          ref.watch(
            _chatFolderUnreadMapProvider.select((counts) => counts[folderId]),
          ) ??
          (unread: 0, alert: false),
    );

final groupTopicsProvider = FutureProvider.autoDispose.family<GroupTopics, int>(
  (ref, id) async {
    ref.watch(
      authProvider.select((a) => (a.session?.userId, a.session?.accessToken)),
    );
    _listenChanges(ref);
    return GroupTopics.fromJson(
      await ref.read(chatProductivityRepositoryProvider).call(
        'list_group_topics',
        {'chat_id': id},
      ),
    );
  },
);

final scheduledChatMessagesProvider = FutureProvider.autoDispose
    .family<List<ScheduledChatMessage>, int?>((ref, chatId) async {
      final account = ref.watch(
        authProvider.select((a) => (a.session?.userId, a.session?.accessToken)),
      );
      if (account.$1 == null) return [];
      _listenChanges(ref);
      final result = await ref.read(chatProductivityRepositoryProvider).call(
        'list_scheduled_messages',
        {'chat_id': ?chatId},
      );
      final jobs = <ScheduledChatMessage>[];
      for (final raw in (result['jobs'] as List? ?? []).whereType<Map>()) {
        final item = ScheduledChatMessage.fromJson(
          Map<String, dynamic>.from(raw),
        );
        var preview = item.payload['content'] as String? ?? '';
        var previewLocked = false;
        if (item.payload['e2ee_content'] != null) {
          final message = ApiMessage.fromJson({
            'id': 0,
            'chat_id': item.chatId,
            'sender_id': account.$1,
            'content': '',
            'is_e2ee': true,
            'e2ee_content': item.payload['e2ee_content'],
            'reply_to_id': item.payload['reply_to_id'],
            'sent_at': item.dueAt.toUtc().toIso8601String(),
          });
          final decrypted = await ref
              .read(ordinaryE2eeProvider)
              ?.decrypt(message);
          previewLocked = decrypted?.isDecrypted != true;
          preview = previewLocked ? '' : decrypted!.content;
        }
        if (!ref.mounted ||
            ref.read(authProvider).session?.userId != account.$1 ||
            ref.read(authProvider).session?.accessToken != account.$2) {
          throw StateError('Сеанс изменился');
        }
        jobs.add(
          ScheduledChatMessage.fromJson(
            Map<String, dynamic>.from(raw),
            preview: preview,
            previewLocked: previewLocked,
          ),
        );
      }
      return jobs;
    });

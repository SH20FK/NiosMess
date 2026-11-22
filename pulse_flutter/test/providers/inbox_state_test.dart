// Account-wide inbox state of a chat: pin, archive, manual unread and the
// notification mute the server keeps.
// * the summary parses the fields, and pinned chats lead the inbox order;
// * `setInboxState` follows the server's answer and refuses an eleventh pin;
// * a `chat_state_changed` push from another device is applied;
// * a new message returns an archived chat unless it is muted;
// * a mute toggled on the device goes to the server, and a server mute
//   reaches the device.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _myUserId = 1;
const String _pinStamp = '2026-11-22T12:00:00+00:00';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: _myUserId,
      username: 'me',
      displayName: 'Me',
    ),
  );

  @override
  Future<void> refreshFcmTokenRegistration() async {}
}

Map<String, dynamic> _messageJson(int id, int chatId, String sentAt) =>
    <String, dynamic>{
      'id': id,
      'chat_id': chatId,
      'sender_id': 2,
      'sender_username': 'peer',
      'sender_display_name': 'Peer',
      'content': 'Message $id',
      'msg_type': 'text',
      'sent_at': sentAt,
    };

/// A chat whose inbox state the server keeps; `serverMuted: null` is a chat
/// from a server without that state.
ApiChatSummary _chat(
  int id, {
  int unread = 0,
  String sentAt = '2026-11-16T09:00:00Z',
  bool? serverMuted = false,
  DateTime? pinnedAt,
  bool archived = false,
  bool markedUnread = false,
}) => ApiChatSummary(
  id: id,
  chatType: 'direct',
  name: 'Peer $id',
  unreadCount: unread,
  membersCount: 2,
  notificationsMuted: serverMuted,
  pinnedAt: pinnedAt,
  isArchived: archived,
  markedUnread: markedUnread,
  lastMessage: ApiMessage.fromJson(_messageJson(id * 100, id, sentAt)),
);

typedef _StateCall = ({
  List<int> ids,
  bool? pinned,
  bool? archived,
  bool? muted,
  bool? unread,
});

class _Repository extends Fake implements ChatRepository {
  final List<Completer<List<ApiChatSummary>>> requests =
      <Completer<List<ApiChatSummary>>>[];
  final List<_StateCall> stateCalls = <_StateCall>[];

  @override
  Future<List<ApiChatSummary>> listChats({String? publicKey}) {
    final Completer<List<ApiChatSummary>> completer =
        Completer<List<ApiChatSummary>>();
    requests.add(completer);
    return completer.future;
  }

  /// Answers like the server: one state row per chat, in request order.
  @override
  Future<List<Map<String, dynamic>>> setChatState(
    List<int> chatIds, {
    bool? pinned,
    bool? archived,
    bool? muted,
    bool? unread,
  }) async {
    stateCalls.add((
      ids: chatIds,
      pinned: pinned,
      archived: archived,
      muted: muted,
      unread: unread,
    ));
    return <Map<String, dynamic>>[
      for (final int id in chatIds)
        <String, dynamic>{
          'chat_id': id,
          'is_pinned': pinned == true,
          'pinned_at': pinned == true ? _pinStamp : null,
          'is_archived': archived == true,
          'notifications_muted': muted == true,
          'marked_unread': unread == true,
        },
    ];
  }
}

class _Cache extends CacheService {
  @override
  List<ApiChatSummary> getCachedChats({int? accountId}) =>
      const <ApiChatSummary>[];

  @override
  Future<void> saveChats(List<ApiChatSummary> rows, {int? accountId}) async {}
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');

  final StreamController<Map<String, dynamic>> pushes =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> connections = StreamController<void>.broadcast();

  @override
  Stream<Map<String, dynamic>> get pushStream => pushes.stream;

  @override
  Stream<void> get onConnected => connections.stream;

  void push(String action, Map<String, dynamic> payload) =>
      pushes.add(<String, dynamic>{'action': action, 'payload': payload});

  @override
  void close() {
    unawaited(pushes.close());
    unawaited(connections.close());
    super.close();
  }
}

Future<void> _until(bool Function() condition) async {
  for (int i = 0; i < 400 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('summary', () {
    test('parses the inbox state and keeps it through the cache', () {
      final ApiChatSummary chat = ApiChatSummary.fromJson(<String, dynamic>{
        'id': 5,
        'chat_type': 'group',
        'name': 'Team',
        'is_pinned': true,
        'pinned_at': _pinStamp,
        'is_archived': true,
        'notifications_muted': true,
        'marked_unread': true,
      });
      expect(chat.isPinned, isTrue);
      expect(chat.pinnedAt, DateTime.parse(_pinStamp));
      expect(chat.isArchived, isTrue);
      expect(chat.notificationsMuted, isTrue);
      expect(chat.markedUnread, isTrue);
      // No unread messages, yet the row asks for attention.
      expect(chat.unreadCount, 0);
      expect(chat.hasUnread, isTrue);
      expect(chat.hasInboxState, isTrue);

      final ApiChatSummary restored = ApiChatSummary.fromJson(chat.toJson());
      expect(restored.pinnedAt, chat.pinnedAt);
      expect(restored.isArchived, isTrue);
      expect(restored.notificationsMuted, isTrue);
      expect(restored.markedUnread, isTrue);
    });

    test('a summary without the fields keeps no inbox state', () {
      final ApiChatSummary old = ApiChatSummary.fromJson(<String, dynamic>{
        'id': 5,
        'chat_type': 'direct',
        'name': 'Peer',
      });
      expect(old.notificationsMuted, isNull);
      expect(old.hasInboxState, isFalse);
      expect(old.isPinned, isFalse);
      expect(old.isArchived, isFalse);
      expect(old.hasUnread, isFalse);
      // An old cache entry stays an old cache entry.
      expect(ApiChatSummary.fromJson(old.toJson()).notificationsMuted, isNull);

      // Topics and the saved chat have none even on a server that keeps it.
      final ApiChatSummary topic = ApiChatSummary.fromJson(<String, dynamic>{
        'id': 6,
        'chat_type': 'group',
        'name': 'Topic',
        'topic_parent_id': 3,
        'notifications_muted': false,
      });
      final ApiChatSummary saved = ApiChatSummary.fromJson(<String, dynamic>{
        'id': 7,
        'chat_type': 'group',
        'name': 'Saved',
        'is_saved': true,
        'notifications_muted': false,
      });
      expect(topic.hasInboxState, isFalse);
      expect(saved.hasInboxState, isFalse);
    });

    test('pinned chats lead the inbox, newest pin first', () {
      final List<ApiChatSummary> chats = <ApiChatSummary>[
        _chat(1, sentAt: '2026-11-16T12:00:00Z'),
        _chat(2, pinnedAt: DateTime.utc(2026, 11, 20)),
        _chat(3, pinnedAt: DateTime.utc(2026, 11, 21)),
        _chat(4, sentAt: '2026-11-16T08:00:00Z'),
      ]..sort(compareChatRecency);

      expect(chats.map((ApiChatSummary c) => c.id), <int>[3, 2, 1, 4]);
    });

    test('a change of inbox state repaints the row', () {
      final ApiChatSummary base = _chat(1);
      expect(base.sameExceptPresence(base.copyWith(isOnline: true)), isTrue);
      for (final ApiChatSummary changed in <ApiChatSummary>[
        base.copyWith(pinnedAt: DateTime.utc(2026, 11, 20)),
        base.copyWith(isArchived: true),
        base.copyWith(markedUnread: true),
        base.copyWith(notificationsMuted: true),
      ]) {
        expect(base.sameExceptPresence(changed), isFalse);
      }

      final ApiChatSummary pinned = base.copyWith(
        pinnedAt: DateTime.utc(2026, 11, 20),
      );
      // A plain copy keeps the pin; only the explicit flag takes it off.
      expect(pinned.copyWith(unreadCount: 2).isPinned, isTrue);
      expect(pinned.copyWith(clearPin: true).isPinned, isFalse);
    });
  });

  group('inbox', () {
    late _Socket socket;
    late _Repository repo;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      WebSocketPushDispatcher.dispose();
      socket = _Socket();
      repo = _Repository();
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          ordinaryE2eeProvider.overrideWithValue(null),
          bluetoothMeshProvider.overrideWithValue(null),
          secretChatCoordinatorProvider.overrideWith((ref) async => null),
          chatRepositoryProvider.overrideWithValue(repo),
          cacheServiceProvider.overrideWithValue(_Cache()),
          webSocketClientProvider.overrideWithValue(socket),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      WebSocketPushDispatcher.dispose();
      PushNotificationService.setCurrentChat(null);
      socket.close();
    });

    ChatsNotifier notifier() => container.read(chatsProvider.notifier);

    ApiChatSummary chat(int id) => container
        .read(chatsProvider)
        .requireValue
        .firstWhere((ApiChatSummary c) => c.id == id);

    List<int> order() => <int>[
      for (final ApiChatSummary c in container.read(chatsProvider).requireValue)
        c.id,
    ];

    bool deviceMuted(int id) =>
        container.read(chatMuteHubProvider).value?.contains(id) ?? false;

    Future<void> openInbox(List<ApiChatSummary> chats) async {
      final sub = container.listen(chatsProvider, (_, _) {});
      addTearDown(sub.close);
      await _until(() => repo.requests.length == 1);
      repo.requests[0].complete(chats);
      await container.read(chatsProvider.future);
    }

    Future<void> refreshWith(List<ApiChatSummary> chats) async {
      final int index = repo.requests.length;
      final Future<void> refreshing = notifier().refresh();
      await _until(() => repo.requests.length == index + 1);
      repo.requests[index].complete(chats);
      await refreshing;
    }

    /// The device mutes are known to be on the server: from here on a
    /// snapshot decides.
    Future<void> adopted() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _until(
        () => prefs.getBool('chat_mute_server_adopted_$_myUserId') == true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    test('pin and archive follow the server answer and reorder the list', () async {
      await openInbox(<ApiChatSummary>[
        _chat(1, sentAt: '2026-11-16T09:00:00Z'),
        _chat(2, sentAt: '2026-11-16T10:00:00Z'),
      ]);
      expect(order(), <int>[2, 1]);

      await notifier().setInboxState(<ApiChatSummary>[chat(1)], pinned: true);
      expect(repo.stateCalls.single.ids, <int>[1]);
      expect(repo.stateCalls.single.pinned, isTrue);
      expect(repo.stateCalls.single.archived, isNull);
      expect(repo.stateCalls.single.muted, isNull);
      expect(chat(1).pinnedAt, DateTime.parse(_pinStamp));
      expect(order(), <int>[1, 2]);

      await notifier().setInboxState(<ApiChatSummary>[chat(1)], pinned: false);
      expect(chat(1).isPinned, isFalse);
      expect(order(), <int>[2, 1]);

      await notifier().setInboxState(<ApiChatSummary>[chat(2)], archived: true);
      expect(chat(2).isArchived, isTrue);
      expect(chat(1).isArchived, isFalse);

      await notifier().setInboxState(<ApiChatSummary>[chat(1)], unread: true);
      expect(chat(1).markedUnread, isTrue);
      expect(chat(1).hasUnread, isTrue);
      expect(repo.stateCalls, hasLength(4));
    });

    test('an eleventh pin is refused before it reaches the server', () async {
      await openInbox(<ApiChatSummary>[
        for (int id = 1; id <= kMaxPinnedChats; id++)
          _chat(id, pinnedAt: DateTime.utc(2026, 11, id)),
        _chat(99),
      ]);

      await expectLater(
        notifier().setInboxState(<ApiChatSummary>[chat(99)], pinned: true),
        throwsA(isA<ChatPinLimitException>()),
      );
      expect(repo.stateCalls, isEmpty);
      expect(chat(99).isPinned, isFalse);

      // Pinning what is already pinned is not a new pin.
      await notifier().setInboxState(<ApiChatSummary>[chat(1)], pinned: true);
      expect(repo.stateCalls, hasLength(1));
    });

    test('a chat from a server without the state is left alone', () async {
      await openInbox(<ApiChatSummary>[_chat(1, serverMuted: null)]);

      await notifier().setInboxState(
        <ApiChatSummary>[chat(1)],
        pinned: true,
        archived: false,
        unread: true,
      );

      expect(repo.stateCalls, isEmpty);
      expect(chat(1).isPinned, isFalse);
      expect(chat(1).markedUnread, isFalse);
    });

    test('a change made on another device is applied', () async {
      await openInbox(<ApiChatSummary>[_chat(1), _chat(2)]);
      await adopted();

      socket.push('chat_state_changed', <String, dynamic>{
        'chats': <Map<String, dynamic>>[
          <String, dynamic>{
            'chat_id': 1,
            'is_pinned': false,
            'pinned_at': null,
            'is_archived': true,
            'notifications_muted': true,
            'marked_unread': true,
          },
          // A chat this device does not list is ignored.
          <String, dynamic>{'chat_id': 404, 'is_archived': true},
        ],
      });
      await _until(() => chat(1).isArchived);

      expect(chat(1).markedUnread, isTrue);
      expect(chat(1).notificationsMuted, isTrue);
      expect(chat(2).isArchived, isFalse);
      // The mute reaches the device and is not echoed back to the server.
      await _until(() => deviceMuted(1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.stateCalls, isEmpty);
    });

    test('a new message returns an archived chat unless it is muted', () async {
      await openInbox(<ApiChatSummary>[
        _chat(1, archived: true),
        _chat(2, archived: true, serverMuted: true),
        _chat(3, archived: true),
      ]);
      await adopted();

      socket.push('new_message', _messageJson(901, 1, '2026-11-17T10:00:00Z'));
      socket.push('new_message', _messageJson(902, 2, '2026-11-17T10:00:01Z'));
      // The account's own message, sent from another device.
      socket.push('new_message', <String, dynamic>{
        ..._messageJson(903, 3, '2026-11-17T10:00:02Z'),
        'sender_id': _myUserId,
      });
      await _until(
        () =>
            chat(1).lastMessage?.id == 901 &&
            chat(2).lastMessage?.id == 902 &&
            chat(3).lastMessage?.id == 903,
      );

      expect(chat(1).isArchived, isFalse);
      // Archived and muted is a parked chat: it stays where it was put.
      expect(chat(2).isArchived, isTrue);
      expect(chat(3).isArchived, isTrue);
    });

    test('reading the chat takes a manual unread mark back', () async {
      await openInbox(<ApiChatSummary>[_chat(1, markedUnread: true)]);
      expect(chat(1).hasUnread, isTrue);

      socket.push('chat_read', <String, dynamic>{
        'chat_id': 1,
        'user_id': _myUserId,
      });
      await _until(() => !chat(1).markedUnread);

      expect(chat(1).hasUnread, isFalse);
    });

    test('a mute toggled on the device goes to the server once', () async {
      await openInbox(<ApiChatSummary>[_chat(1), _chat(2, serverMuted: null)]);
      await adopted();

      await container.read(chatMuteHubProvider.notifier).setMuted(1, true);
      await _until(() => repo.stateCalls.length == 1);
      expect(repo.stateCalls.single.ids, <int>[1]);
      expect(repo.stateCalls.single.muted, isTrue);
      expect(repo.stateCalls.single.pinned, isNull);
      expect(repo.stateCalls.single.archived, isNull);
      await _until(() => chat(1).notificationsMuted == true);

      // A chat the server keeps no state for stays a device preference.
      await container.read(chatMuteHubProvider.notifier).setMuted(2, true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.stateCalls, hasLength(1));
      expect(deviceMuted(1), isTrue);
      expect(deviceMuted(2), isTrue);
    });

    test('a mute from before the server kept it is uploaded, then the server decides', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'chat_notifications_muted_${_myUserId}_1': true,
      });
      await openInbox(<ApiChatSummary>[_chat(1)]);

      await _until(() => repo.stateCalls.length == 1);
      expect(repo.stateCalls.single.ids, <int>[1]);
      expect(repo.stateCalls.single.muted, isTrue);
      await _until(() => chat(1).notificationsMuted == true);
      expect(deviceMuted(1), isTrue);

      // Nothing is left to upload: the next snapshot closes the migration.
      await refreshWith(<ApiChatSummary>[_chat(1, serverMuted: true)]);
      await adopted();
      expect(deviceMuted(1), isTrue);

      // Unmuted on another device while this one was offline.
      await refreshWith(<ApiChatSummary>[_chat(1)]);
      await _until(() => !deviceMuted(1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.stateCalls, hasLength(1));
    });

    test('a server mute silences the device and the navigation badge', () async {
      await openInbox(<ApiChatSummary>[
        _chat(1, unread: 3),
        _chat(2, unread: 5, archived: true),
        _chat(3, markedUnread: true),
        _chat(4, unread: 7, serverMuted: true),
      ]);

      await _until(() => deviceMuted(4));
      expect(repo.stateCalls, isEmpty);
      // 3 unread messages + one chat marked by hand; the archived and the
      // muted chats keep their counters to themselves.
      expect(container.read(totalUnreadCountProvider), 4);
    });
  });
}

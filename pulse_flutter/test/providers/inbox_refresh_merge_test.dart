import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/status_emoji_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

const int _chatId = 7;
const int _myUserId = 1;

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
}

ApiChatSummary _chat({int unread = 0, int? lastMessageId}) => ApiChatSummary(
  id: _chatId,
  chatType: 'direct',
  name: 'Peer',
  unreadCount: unread,
  membersCount: 2,
  lastMessage: lastMessageId == null
      ? null
      : ApiMessage.fromJson({
          'id': lastMessageId,
          'chat_id': _chatId,
          'sender_id': 2,
          'sender_username': 'peer',
          'content': 'stale snapshot',
          'msg_type': 'text',
          'sent_at': '2026-11-16T09:00:00Z',
        }),
);

ApiMessage _message(int id) => ApiMessage.fromJson({
  'id': id,
  'chat_id': _chatId,
  'sender_id': 2,
  'sender_username': 'peer',
  'sender_display_name': 'Peer',
  'content': 'Message $id',
  'msg_type': 'text',
  'sent_at': '2026-11-16T10:00:00Z',
});

class _Repository extends Fake implements ChatRepository {
  final requests = <Completer<List<ApiChatSummary>>>[];
  @override
  Future<List<ApiChatSummary>> listChats({String? publicKey}) {
    final completer = Completer<List<ApiChatSummary>>();
    requests.add(completer);
    return completer.future;
  }
}

class _Cache extends CacheService {
  final snapshots = <List<ApiChatSummary>>[];
  @override
  List<ApiChatSummary> getCachedChats({int? accountId}) =>
      const <ApiChatSummary>[];
  @override
  Future<void> saveChats(List<ApiChatSummary> rows, {int? accountId}) async {
    snapshots.add(rows);
  }
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final pushes = StreamController<Map<String, dynamic>>.broadcast();
  final connections = StreamController<void>.broadcast();
  @override
  Stream<Map<String, dynamic>> get pushStream => pushes.stream;
  @override
  Stream<void> get onConnected => connections.stream;
  void push(ApiMessage message) =>
      pushes.add({'action': 'new_message', 'payload': message.toJson()});
  @override
  void close() {
    unawaited(pushes.close());
    unawaited(connections.close());
    super.close();
  }
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 400 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Socket socket;
  late _Repository repo;
  late _Cache cache;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WebSocketPushDispatcher.dispose();
    socket = _Socket();
    repo = _Repository();
    cache = _Cache();
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        ordinaryE2eeProvider.overrideWithValue(null),
        bluetoothMeshProvider.overrideWithValue(null),
        secretChatCoordinatorProvider.overrideWith((ref) async => null),
        chatRepositoryProvider.overrideWithValue(repo),
        cacheServiceProvider.overrideWithValue(cache),
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

  ApiChatSummary chat() => container.read(chatsProvider).requireValue.single;

  Future<void> openInbox() async {
    final sub = container.listen(chatsProvider, (_, _) {});
    addTearDown(sub.close);
    await _until(() => repo.requests.length == 1);
    repo.requests[0].complete([_chat()]);
    await container.read(chatsProvider.future);
  }

  test('refresh does not roll back a push received while list_chats was in flight', () async {
    await openInbox();

    final refreshing = container.read(chatsProvider.notifier).refresh();
    await _until(() => repo.requests.length == 2);

    socket.push(_message(500));
    await _until(() => chat().unreadCount == 1);
    expect(chat().lastMessage?.id, 500);

    // The server answered before it saw message 500: the stale snapshot must not
    // resurrect the old preview or drop the unread counter.
    repo.requests[1].complete([_chat()]);
    await refreshing;

    expect(chat().unreadCount, 1);
    expect(chat().lastMessage?.id, 500);

    // The cache mirrors the merged state, not the raw response.
    container.invalidate(chatsProvider);
    await _until(() => cache.snapshots.isNotEmpty);
    expect(cache.snapshots.first.single.unreadCount, 1);
    expect(cache.snapshots.first.single.lastMessage?.id, 500);
  });

  test('an older response never overwrites a newer snapshot', () async {
    await openInbox();

    final first = container.read(chatsProvider.notifier).refresh();
    await _until(() => repo.requests.length == 2);
    final second = container.read(chatsProvider.notifier).refresh();
    await _until(() => repo.requests.length == 3);

    repo.requests[2].complete([_chat(unread: 2, lastMessageId: 600)]);
    await second;
    expect(chat().unreadCount, 2);
    expect(chat().lastMessage?.id, 600);

    repo.requests[1].complete([_chat()]);
    await first;
    expect(chat().unreadCount, 2);
    expect(chat().lastMessage?.id, 600);
  });

  test('a server-side read still clears the badge when no local push raced', () async {
    final sub = container.listen(chatsProvider, (_, _) {});
    addTearDown(sub.close);
    await _until(() => repo.requests.length == 1);
    repo.requests[0].complete([_chat(unread: 5, lastMessageId: 400)]);
    await container.read(chatsProvider.future);
    expect(chat().unreadCount, 5);

    final refreshing = container.read(chatsProvider.notifier).refresh();
    await _until(() => repo.requests.length == 2);
    repo.requests[1].complete([_chat(lastMessageId: 400)]);
    await refreshing;
    expect(chat().unreadCount, 0);
  });

  test('an explicit read wins over a snapshot computed before it', () async {
    final sub = container.listen(chatsProvider, (_, _) {});
    addTearDown(sub.close);
    await _until(() => repo.requests.length == 1);
    repo.requests[0].complete([_chat(unread: 5, lastMessageId: 400)]);
    await container.read(chatsProvider.future);
    expect(chat().unreadCount, 5);

    final refreshing = container.read(chatsProvider.notifier).refresh();
    await _until(() => repo.requests.length == 2);
    // The user reads the chat while list_chats is still in flight.
    container.read(chatsProvider.notifier).markChatAsRead(_chatId);
    expect(chat().unreadCount, 0);

    repo.requests[1].complete([_chat(unread: 5, lastMessageId: 400)]);
    await refreshing;
    expect(chat().unreadCount, 0);
  });

  test('a re-delivered push increments the badge only once', () async {
    await openInbox();

    socket.push(_message(500));
    await _until(() => chat().unreadCount == 1);
    socket.push(_message(500));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(chat().unreadCount, 1);
  });

  test('cached summary keeps blocking, key mismatch and partner fields', () {
    const ApiStatusEmoji emoji = ApiStatusEmoji(
      shortcode: 'wave',
      url: 'https://fixture.invalid/wave.webp',
    );
    final ApiChatSummary source = ApiChatSummary(
      id: 91,
      chatType: 'direct',
      name: 'Blocked peer',
      unreadCount: 4,
      membersCount: 2,
      partnerUserId: 77,
      isBlockedByMe: true,
      isBlockedByUser: true,
      isBlocked: true,
      keyMismatch: true,
      partnerStatusEmoji: emoji,
      lastMessage: _message(500),
    );

    final ApiChatSummary restored = ApiChatSummary.fromJson(source.toJson());
    expect(restored.partnerUserId, 77);
    expect(restored.isBlockedByMe, isTrue);
    expect(restored.isBlockedByUser, isTrue);
    expect(restored.isBlocked, isTrue);
    expect(restored.keyMismatch, isTrue);
    expect(restored.partnerStatusEmoji?.shortcode, 'wave');
    expect(restored.unreadCount, 4);
    expect(restored.lastMessage?.id, 500);

    // Old cache rows without the new keys stay readable and default to false.
    final ApiChatSummary legacy = ApiChatSummary.fromJson({
      'id': 92,
      'chat_type': 'direct',
      'name': 'Legacy',
      'unread_count': 1,
      'members_count': 2,
    });
    expect(legacy.isBlockedByMe, isFalse);
    expect(legacy.isBlockedByUser, isFalse);
    expect(legacy.isBlocked, isFalse);
    expect(legacy.keyMismatch, isFalse);
    expect(legacy.partnerStatusEmoji, isNull);
    expect(legacy.partnerUserId, isNull);
  });

  test('shared comparator orders by activity, then by last message id', () {
    ApiChatSummary at(int id, int minutesAgo) => ApiChatSummary(
      id: id,
      chatType: 'direct',
      name: 'Chat $id',
      unreadCount: 0,
      membersCount: 2,
      lastMessage: ApiMessage.fromJson({
        'id': 100 + id,
        'chat_id': id,
        'sender_id': 2,
        'content': 'x',
        'msg_type': 'text',
        'sent_at': DateTime.utc(
          2026,
          11,
          16,
          12,
          0,
        ).subtract(Duration(minutes: minutesAgo)).toIso8601String(),
      }),
    );
    final List<ApiChatSummary> chats = [at(1, 30), at(2, 5), at(3, 60)]
      ..sort(compareChatRecency);
    expect(chats.map((c) => c.id).toList(), [2, 1, 3]);

    // A chat without any preview never outranks a chat with activity.
    final List<ApiChatSummary> withEmpty = [
      const ApiChatSummary(
        id: 9,
        chatType: 'direct',
        name: 'Empty',
        unreadCount: 0,
        membersCount: 2,
      ),
      at(4, 120),
    ]..sort(compareChatRecency);
    expect(withEmpty.map((c) => c.id).toList(), [4, 9]);
  });
}

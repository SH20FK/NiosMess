// Characterization tests for `lib/screens/chat_detail_screen.dart`.
//
// The screen is a ~2.4k-line State with 61 methods and, until now, no test
// imported it. These tests freeze the behaviour the upcoming controller split
// must preserve: it mounts, renders empty/error states, sends once with the
// typed body, carries and clears reply context, and enters/commits inline edit.
//
// Nothing here touches the network, Hive, secure storage or platform plugins:
// every provider the screen reads that would do so is replaced below.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/screens/chat_detail_screen.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_app_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_empty_state.dart';
import 'package:pulse_flutter/widgets/chat/chat_input_bar.dart';

const int _chatId = 9001;
const int _myUserId = 1;
const int _partnerUserId = 2;

const String _partnerText = 'hello there';
const String _myText = 'original text';

ApiChatSummary _chat({bool isSecret = false}) => ApiChatSummary(
  id: _chatId,
  chatType: 'direct',
  name: 'Тестовый собеседник',
  unreadCount: 0,
  membersCount: 2,
  partnerUserId: _partnerUserId,
  isSecret: isSecret,
  autoDeleteSeconds: isSecret ? 86400 : null,
);

ApiMessage _message({
  required int id,
  required int senderId,
  required String content,
}) => ApiMessage(
  id: id,
  chatId: _chatId,
  senderId: senderId,
  senderUsername: senderId == _myUserId ? 'me' : 'partner',
  senderDisplayName: senderId == _myUserId ? 'Я' : 'Партнёр',
  senderBadges: const [],
  content: content,
  msgType: 'text',
  replyToId: null,
  mediaUrl: null,
  mediaType: null,
  mediaName: null,
  mediaSize: null,
  mediaDuration: null,
  commentsCount: 0,
  reactions: const {},
  sentAt: DateTime.utc(2026, 11, 28, 10),
  editedAt: null,
  isDeleted: false,
);

final List<ApiMessage> _twoMessages = <ApiMessage>[
  _message(id: 10, senderId: _partnerUserId, content: _partnerText),
  _message(id: 11, senderId: _myUserId, content: _myText),
];

/// What the fake message notifier recorded, shared with the test body.
class _Recorded {
  final List<(String, int?)> sends = <(String, int?)>[];
  final List<(int, String)> edits = <(int, String)>[];
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture-token',
      userId: _myUserId,
      username: 'me',
      displayName: 'Я',
    ),
    profile: const ApiProfile(
      id: _myUserId,
      username: 'me',
      displayName: 'Я',
      bio: '',
    ),
  );
}

class _Chats extends ChatsNotifier {
  _Chats(this.chat);

  final ApiChatSummary chat;
  final List<int> readMarks = <int>[];
  final List<int> upserts = <int>[];

  @override
  Future<List<ApiChatSummary>> build() async => <ApiChatSummary>[chat];

  // The inbox's real mutators debounce a cache write on a 2s timer and talk to
  // the cache service; the tests only care that the screen calls them.
  @override
  void markChatAsRead(int chatId) => readMarks.add(chatId);

  @override
  void upsertChat(ApiChatSummary chat) => upserts.add(chat.id);

  @override
  void setChatBlockedByUser(int chatId, bool isBlocked) {}
}

class _Members extends ChatMembersNotifier {
  _Members(super.chatId);

  @override
  Future<List<ApiChatMember>> build() async => const <ApiChatMember>[];
}

/// Keeps `_refreshNow`'s metadata reload off the real HTTP client.
class _Repo extends ChatRepository {
  _Repo(super.ref, this.chat);

  final ApiChatSummary chat;

  @override
  Future<List<ApiChatSummary>> listChats({String? publicKey}) async =>
      <ApiChatSummary>[chat];

  @override
  Future<ApiChatSummary?> getChat(int chatId) async => chat;

  @override
  Future<int> markRead(int chatId) async => 0;

  @override
  Future<List<ApiChatMember>> getMembers(int chatId) async =>
      const <ApiChatMember>[];
}

class _Messages extends ChatMessagesNotifier {
  _Messages(super.chatId, this.recorded, this.rows, {this.failure});

  final _Recorded recorded;
  final List<ApiMessage> rows;
  final Object? failure;

  @override
  Future<List<ApiMessage>> build() async {
    final Object? error = failure;
    if (error != null) throw error;
    return rows;
  }

  @override
  Future<void> send(
    String content, {
    int? replyToId,
    String? uploadId,
    String msgType = 'text',
    bool requestAi = true,
    String? localId,
    String? e2eePlaintext,
    String? e2eeFileKey,
    VoidCallback? onLocalSaved,
  }) async {
    recorded.sends.add((content, replyToId));
    // The real notifier reports a locally persisted row here; the composer
    // uses it to clear the draft and the reply context.
    onLocalSaved?.call();
  }

  @override
  Future<void> editMessage(int messageId, String content) async {
    recorded.edits.add((messageId, content));
  }

  @override
  Future<void> markRead({bool reportFailure = false}) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadNewer({int pageSize = 50}) async {}

  @override
  Future<int> loadOlder({int pageSize = 50}) async => 0;

  @override
  Future<void> jumpToLatest() async {}

  @override
  void setFollowingLatest(bool atBottom) {}

  @override
  Future<bool> loadAround(int messageId) async => true;

  @override
  Future<void> sendCallbackQuery(int messageId, String data) async {}
}

class _UiSettings extends UiSettingsNotifier {
  @override
  UiSettingsState build() =>
      const UiSettingsState.defaults().copyWith(haptics: false);
}

class _Privacy extends PrivacyNotifier {
  @override
  PrivacyState build() => const PrivacyState();
}

/// Typing pings go out over the websocket; the screen only needs the no-op.
class _Typing extends TypingNotifier {
  _Typing(super.chatId);

  @override
  TypingState build() => const TypingState();

  @override
  Future<void> sendTyping() async {}
}

class _DraftStorage extends DraftStorage {
  _DraftStorage() : super();

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<String?> get(int chatId) async => null;

  @override
  Future<void> set(int chatId, String text) async {}

  @override
  Future<void> remove(int chatId) async {}

  @override
  Future<Map<int, String>> asMap() async => const <int, String>{};
}

class _NoopSound extends SoundService {
  @override
  Future<void> playEvent(SoundEvent event, {double? volume}) async {}

  @override
  Future<void> playNotification(SoundEvent event, {double? volume}) async {}
}

List<Override> _overrides({
  required ApiChatSummary chat,
  required _Messages messages,
}) => <Override>[
  authProvider.overrideWith(_Auth.new),
  chatsProvider.overrideWith(() => _Chats(chat)),
  chatMembersProvider(_chatId).overrideWith(() => _Members(_chatId)),
  chatMessagesProvider(_chatId).overrideWith(() => messages),
  chatRepositoryProvider.overrideWith((Ref ref) => _Repo(ref, chat)),
  // Secret delivery, its push stream and the ordinary-E2EE service open
  // sockets, Hive and a 5s polling timer. The screen tolerates `null`.
  secretChatCoordinatorProvider.overrideWith((Ref ref) async => null),
  secretChatRevisionProvider.overrideWith((Ref ref) => Stream<int>.value(0)),
  secretChatEngineProvider.overrideWithValue(null),
  ordinaryE2eeProvider.overrideWithValue(null),
  // Draft storage would hit FlutterSecureStorage / SharedPreferences.
  draftStorageProvider.overrideWith((Ref ref) => _DraftStorage()),
  privacyProvider.overrideWith(_Privacy.new),
  typingProvider(_chatId).overrideWith(() => _Typing(_chatId)),
  uiSettingsProvider.overrideWith(_UiSettings.new),
  // connectivity_plus has no platform implementation under flutter_test.
  connectivityProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  appSoundProvider.overrideWithValue(_NoopSound()),
];

Widget _app({required List<Override> overrides, Widget? home}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(useMaterial3: true),
    home: home ?? const ChatDetailScreen(chatId: '$_chatId'),
  ),
);

/// Mounts the screen and lets the post-frame work (draft restore, refresh,
/// entrances) run. No [WidgetTester.pumpAndSettle] — the screen owns
/// animations that are not guaranteed to end.
Future<void> _pumpChat(
  WidgetTester tester, {
  required ApiChatSummary chat,
  List<ApiMessage> rows = const <ApiMessage>[],
  Object? failure,
  _Recorded? recorded,
  Widget? home,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final _Recorded capture = recorded ?? _Recorded();
  await tester.pumpWidget(
    _app(
      overrides: _overrides(
        chat: chat,
        messages: _Messages(_chatId, capture, rows, failure: failure),
      ),
      home: home,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

/// Lets bottom sheets and size transitions finish without requiring the whole
/// tree to settle.
Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

double _panelHeight(WidgetTester tester, String key) {
  final Finder panel = find.byKey(ValueKey<String>(key));
  if (panel.evaluate().isEmpty) return 0;
  return tester.getSize(panel).height;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ChatDetailScreen)))!;

void main() {
  testWidgets('ordinary chat mounts without exceptions', (tester) async {
    await _pumpChat(tester, chat: _chat());

    expect(tester.takeException(), isNull);
    expect(find.byType(ChatDetailScreen), findsOneWidget);
    expect(find.byType(ChatDetailAppBar), findsOneWidget);
    expect(find.text('Тестовый собеседник'), findsOneWidget);
    expect(find.byType(ChatInputBar), findsOneWidget);
  });

  testWidgets(
    'secret chat mounts without exceptions and shows its empty state',
    (tester) async {
      await _pumpChat(tester, chat: _chat(isSecret: true));

      expect(tester.takeException(), isNull);
      expect(find.byType(ChatDetailScreen), findsOneWidget);
      final ChatEmptyState empty = tester.widget<ChatEmptyState>(
        find.byType(ChatEmptyState),
      );
      expect(empty.variant, ChatEmptyStateVariant.secret);
    },
  );

  testWidgets('empty chat shows the empty state', (tester) async {
    await _pumpChat(tester, chat: _chat());

    expect(tester.takeException(), isNull);
    final ChatEmptyState empty = tester.widget<ChatEmptyState>(
      find.byType(ChatEmptyState),
    );
    expect(empty.variant, ChatEmptyStateVariant.empty);
  });

  testWidgets('history failure shows the reconnect state', (tester) async {
    await _pumpChat(tester, chat: _chat(), failure: StateError('offline'));

    expect(tester.takeException(), isNull);
    final Finder emptyFinder = find.byType(ChatEmptyState);
    expect(emptyFinder, findsOneWidget);
    expect(
      tester.widget<ChatEmptyState>(emptyFinder).variant,
      ChatEmptyStateVariant.error,
    );
  });

  testWidgets('typing shows the send button and sends the body exactly once', (
    tester,
  ) async {
    final _Recorded recorded = _Recorded();
    await _pumpChat(
      tester,
      chat: _chat(),
      rows: _twoMessages,
      recorded: recorded,
    );

    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);

    final Finder field = find.byType(TextField);
    await tester.enterText(field, 'привет');
    await tester.pump();

    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(recorded.sends, hasLength(1));
    expect(recorded.sends.single.$1, 'привет');
    expect(recorded.sends.single.$2, isNull);
    expect(recorded.edits, isEmpty);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reply preview appears, is attached and cleared after send', (
    tester,
  ) async {
    final _Recorded recorded = _Recorded();
    await _pumpChat(
      tester,
      chat: _chat(),
      rows: _twoMessages,
      recorded: recorded,
    );

    expect(_panelHeight(tester, 'reply-context-transition'), 0);

    await tester.longPress(find.text(_partnerText));
    await _settleSheet(tester);
    await tester.tap(find.text(_l10n(tester).chatReply));
    await _settleSheet(tester);

    expect(tester.takeException(), isNull);
    expect(_panelHeight(tester, 'reply-context-transition'), greaterThan(0));
    // The message body and its composer preview.
    expect(find.textContaining(_partnerText), findsNWidgets(2));

    final Finder field = find.byType(TextField);
    await tester.enterText(field, 'ответ');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(recorded.sends, hasLength(1));
    expect(recorded.sends.single, ('ответ', 10));
    expect(_panelHeight(tester, 'reply-context-transition'), 0);
    expect(find.textContaining(_partnerText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode prefills the composer and commits the new text', (
    tester,
  ) async {
    final _Recorded recorded = _Recorded();
    await _pumpChat(
      tester,
      chat: _chat(),
      rows: _twoMessages,
      recorded: recorded,
    );

    await tester.longPress(find.text(_myText));
    await _settleSheet(tester);
    await tester.tap(find.text(_l10n(tester).chatEdit));
    await _settleSheet(tester);

    expect(tester.takeException(), isNull);
    expect(_panelHeight(tester, 'edit-context-transition'), greaterThan(0));
    final Finder field = find.byType(TextField);
    expect(tester.widget<TextField>(field).controller!.text, _myText);
    final Finder commit = find.descendant(
      of: find.byType(ChatInputBar),
      matching: find.byIcon(Icons.check_rounded),
    );
    expect(commit, findsOneWidget);

    await tester.enterText(field, 'edited text');
    await tester.pump();
    await tester.tap(commit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(recorded.edits, <(int, String)>[(11, 'edited text')]);
    expect(recorded.sends, isEmpty);
    expect(_panelHeight(tester, 'edit-context-transition'), 0);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back pops the route and returns to the previous screen', (
    tester,
  ) async {
    var pops = 0;
    await _pumpChat(
      tester,
      chat: _chat(),
      home: _Launcher(onPushed: () => pops++),
    );

    await tester.tap(find.text('open chat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ChatDetailScreen), findsOneWidget);
    expect(_panelHeight(tester, 'reply-context-transition'), 0);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The route is removed in the frame after its exit animation completes.
    await tester.pump(const Duration(milliseconds: 50));

    expect(pops, 1);
    expect(find.byType(ChatDetailScreen), findsNothing);
    expect(find.text('root screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Root route that pushes the screen under test through the real navigator, so
/// the back button has somewhere to pop to.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.onPushed});

  final VoidCallback onPushed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('root screen'),
            TextButton(
              onPressed: () {
                onPushed();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChatDetailScreen(chatId: '$_chatId'),
                  ),
                );
              },
              child: const Text('open chat'),
            ),
          ],
        ),
      ),
    );
  }
}

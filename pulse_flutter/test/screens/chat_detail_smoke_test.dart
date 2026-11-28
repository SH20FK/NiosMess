// Smoke test for `ChatDetailScreen` after the A.12 split (build body + the
// three scopes). It mounts the real screen against fakes and checks only the
// three end-to-end guarantees the split must not break: rows render, typing
// enables send, and Esc leaves the reply mode.
//
// Everything that would touch the network, Hive, secure storage or a platform
// plugin is replaced below; the security channel is mocked because the screen
// arms the native secure flag while it is mounted.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/encrypted_draft_sync_provider.dart';
import 'package:pulse_flutter/providers/inline_query_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/screens/chat_detail_screen.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

const int _chatId = 9101;
const int _myUserId = 1;
const int _partnerUserId = 2;

const MethodChannel _securityChannel = MethodChannel(
  'com.niosmess.pulse/security',
);

const String _firstText = 'первое сообщение';
const String _secondText = 'второе сообщение';
const String _thirdText = 'третье сообщение';

ApiChatSummary _chat() => ApiChatSummary(
  id: _chatId,
  chatType: 'direct',
  name: 'Собеседник',
  unreadCount: 0,
  membersCount: 2,
  partnerUserId: _partnerUserId,
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

final List<ApiMessage> _threeMessages = <ApiMessage>[
  _message(id: 20, senderId: _partnerUserId, content: _firstText),
  _message(id: 21, senderId: _myUserId, content: _secondText),
  _message(id: 22, senderId: _partnerUserId, content: _thirdText),
];

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

  @override
  Future<List<ApiChatSummary>> build() async => <ApiChatSummary>[chat];

  @override
  void markChatAsRead(int chatId) {}

  @override
  void upsertChat(ApiChatSummary chat) {}

  @override
  void setChatBlockedByUser(int chatId, bool isBlocked) {}
}

class _Members extends ChatMembersNotifier {
  _Members(super.chatId);

  @override
  Future<List<ApiChatMember>> build() async => const <ApiChatMember>[];
}

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
  _Messages(super.chatId, this.rows);

  final List<ApiMessage> rows;

  @override
  Future<List<ApiMessage>> build() async => rows;

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
    onLocalSaved?.call();
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

class _Typing extends TypingNotifier {
  _Typing(super.chatId);

  @override
  TypingState build() => const TypingState();

  @override
  Future<void> sendTyping() async {}
}

class _InlineQuery extends InlineQueryNotifier {
  @override
  InlineQueryState build() => const InlineQueryState();

  @override
  void clear() {}
}

class _UploadQueue extends UploadQueueNotifier {
  @override
  Map<String, UploadTask> build() => const <String, UploadTask>{};
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

class _Sock extends WebSocketClient {
  _Sock() : super(baseUrl: 'wss://smoke.invalid', readToken: () => null);
}

List<Override> _overrides() => <Override>[
  authProvider.overrideWith(_Auth.new),
  chatsProvider.overrideWith(() => _Chats(_chat())),
  chatByIdProvider(_chatId).overrideWithValue(_chat()),
  chatMembersProvider(_chatId).overrideWith(() => _Members(_chatId)),
  chatMessagesProvider(
    _chatId,
  ).overrideWith(() => _Messages(_chatId, _threeMessages)),
  chatRepositoryProvider.overrideWith((Ref ref) => _Repo(ref, _chat())),
  uiSettingsProvider.overrideWith(_UiSettings.new),
  privacyProvider.overrideWith(_Privacy.new),
  typingProvider(_chatId).overrideWith(() => _Typing(_chatId)),
  inlineQueryProvider.overrideWith(_InlineQuery.new),
  uploadQueueProvider.overrideWith(_UploadQueue.new),
  draftStorageProvider.overrideWith((Ref ref) => _DraftStorage()),
  encryptedDraftSyncProvider.overrideWithValue(null),
  webSocketClientProvider.overrideWithValue(_Sock()),
  // Secret delivery, its push stream and ordinary E2EE open sockets and Hive;
  // the screen tolerates every one of them being absent.
  secretChatCoordinatorProvider.overrideWith((Ref ref) async => null),
  secretChatRevisionProvider.overrideWith((Ref ref) => Stream<int>.value(0)),
  secretChatEngineProvider.overrideWithValue(null),
  ordinaryE2eeProvider.overrideWithValue(null),
  connectivityProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  appSoundProvider.overrideWithValue(_NoopSound()),
];

Widget _app() => ProviderScope(
  overrides: _overrides(),
  child: MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(useMaterial3: true),
    home: const ChatDetailScreen(chatId: '$_chatId'),
  ),
);

Future<void> _pumpChat(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_app());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

double _panelHeight(WidgetTester tester, String key) {
  final Finder panel = find.byKey(ValueKey<String>(key));
  if (panel.evaluate().isEmpty) return 0;
  return tester.getSize(panel).height;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_securityChannel, (MethodCall call) async {
          return call.method == 'setSecureFlag' ? true : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_securityChannel, null);
  });

  testWidgets('three messages render, typing enables send, Esc clears reply', (
    tester,
  ) async {
    await _pumpChat(tester);

    // 1. Three rows from the messages scope.
    expect(find.byType(ChatDetailScreen), findsOneWidget);
    expect(find.text(_firstText), findsOneWidget);
    expect(find.text(_secondText), findsOneWidget);
    expect(find.text(_thirdText), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 2. Typing swaps the mic for the send button.
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    final Finder field = find.byType(TextField);
    await tester.enterText(field, 'проверка');
    await tester.pump();
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    // 3. Reply mode, then Esc clears it.
    expect(_panelHeight(tester, 'reply-context-transition'), 0);
    await tester.longPress(find.text(_firstText));
    await _settleSheet(tester);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(ChatDetailScreen)),
    )!;
    await tester.tap(find.text(l10n.chatReply));
    await _settleSheet(tester);

    expect(_panelHeight(tester, 'reply-context-transition'), greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_panelHeight(tester, 'reply-context-transition'), 0);
    expect(find.textContaining(_firstText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

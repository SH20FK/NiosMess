import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pulse_flutter/core/ai/ai_action.dart';
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
import 'package:pulse_flutter/screens/chat_detail/chat_media_controller.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/chat/ai_actions_sheet.dart';
import 'package:pulse_flutter/widgets/chat/reaction_picker_sheet.dart';
import 'package:pulse_flutter/widgets/chat/report_message_sheet.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('ru'));

ApiMessage _message({Map<String, int> reactions = const {}}) => ApiMessage(
  id: 77,
  chatId: 9001,
  senderId: 2,
  senderUsername: 'partner',
  senderDisplayName: 'Партнёр',
  senderBadges: const [],
  content: 'привет',
  msgType: 'text',
  replyToId: null,
  mediaUrl: null,
  mediaType: null,
  mediaName: null,
  mediaSize: null,
  mediaDuration: null,
  commentsCount: 0,
  reactions: reactions,
  sentAt: DateTime.utc(2026, 11, 28, 10),
  editedAt: null,
  isDeleted: false,
);

ApiMessage _mediaMessage() => _message().copyWith(
  msgType: 'media',
  mediaUrl: 'https://cdn.test/photo.jpg',
  mediaType: 'image/jpeg',
  mediaName: 'photo.jpg',
);

ChatMediaController _mediaController() => ChatMediaController(
  l10n: () => _l10n,
  messages: () => const <ApiMessage>[],
  push: (String location, {Object? extra}) {},
  forward: (ApiMessage message) async {},
  delete: (ApiMessage message) {},
  wsClient: () => throw UnimplementedError(),
);

/// The media long-press menu, built directly — the controller's sheet takes the
/// screen context plus a dismiss callback, so no modal route is needed.
Widget _mediaMenu({required bool isMine, required bool amAdminOrOwner}) =>
    Builder(
      builder: (BuildContext context) =>
          _mediaController().buildMediaActionsSheet(
            context: context,
            scheme: Theme.of(context).colorScheme,
            dismiss: () {},
            message: _mediaMessage(),
            isMine: isMine,
            amAdminOrOwner: amAdminOrOwner,
          ),
    );

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(useMaterial3: true),
  home: child,
);

/// Hosts a button that opens [open] and records its result.
class _Host extends StatefulWidget {
  const _Host({required this.open});

  final Future<Object?> Function(BuildContext context) open;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Object? result;
  bool closed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final Object? value = await widget.open(context);
            if (!mounted) return;
            setState(() {
              result = value;
              closed = true;
            });
          },
          child: const Text('open sheet'),
        ),
      ),
    );
  }
}

Future<_HostState> _openSheet(
  WidgetTester tester,
  Future<Object?> Function(BuildContext context) open, {
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(600, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: _app(_Host(open: open)),
    ),
  );
  await tester.tap(find.text('open sheet'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return tester.state<_HostState>(find.byType(_Host));
}

Container _emojiCell(WidgetTester tester, String emoji) {
  final Finder cell = find
      .ancestor(of: find.text(emoji), matching: find.byType(Container))
      .first;
  return tester.widget<Container>(cell);
}

void main() {
  group('reaction picker sheet', () {
    test('the catalog is exactly 25 emojis, unique', () {
      expect(allReactionEmojis, hasLength(25));
      expect(allReactionEmojis.toSet(), hasLength(25));
      expect(allReactionEmojis.first, '👍');
      expect(allReactionEmojis.last, '✅');
      expect(allReactionEmojis, contains('❤️'));
      expect(allReactionEmojis, contains('🔥'));
    });

    testWidgets('renders all 25 reactions inside a SafeArea', (tester) async {
      await _openSheet(
        tester,
        (BuildContext context) =>
            showReactionPickerSheet(context, message: _message()),
      );

      expect(find.byType(ReactionPickerSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SafeArea),
          matching: find.byType(InkWell),
        ),
        findsNWidgets(25),
      );
      for (final String emoji in allReactionEmojis) {
        expect(find.text(emoji), findsOneWidget);
      }
      expect(find.text(_l10n.chatReactionsPickerTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('highlight follows message.reactions', (tester) async {
      await _openSheet(
        tester,
        (BuildContext context) => showReactionPickerSheet(
          context,
          message: _message(reactions: const <String, int>{'👍': 2}),
        ),
      );

      final BoxDecoration selected =
          _emojiCell(tester, '👍').decoration! as BoxDecoration;
      final BoxDecoration unselected =
          _emojiCell(tester, '👎').decoration! as BoxDecoration;
      expect(selected.color, isNot(Colors.transparent));
      expect(unselected.color, Colors.transparent);
    });

    testWidgets('tapping an emoji pops with that emoji', (tester) async {
      final _HostState host = await _openSheet(
        tester,
        (BuildContext context) =>
            showReactionPickerSheet(context, message: _message()),
      );

      await tester.tap(find.text('🔥'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(host.result, '🔥');
      expect(host.closed, isTrue);
      expect(find.byType(ReactionPickerSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('report message sheet', () {
    testWidgets('shows the six reasons in a SafeArea', (tester) async {
      await _openSheet(tester, showReportMessageSheet);

      expect(find.byType(ReportMessageSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SafeArea),
          matching: find.byType(ListTile),
        ),
        findsNWidgets(6),
      );
      expect(find.text(_l10n.reportSelectReason), findsOneWidget);
      expect(find.text(_l10n.reportReasonSpam), findsOneWidget);
      expect(find.text(_l10n.reportReasonScam), findsOneWidget);
      expect(find.text(_l10n.reportReasonIllegal), findsOneWidget);
      expect(
        find.text('Нарушение авторских прав (copyright)'),
        findsOneWidget,
      );
      expect(find.text('Доксинг (личные данные)'), findsOneWidget);
      expect(
        find.text('Сваттинг / угрозы безопасности'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    for (final (String title, String reason) in <(String, String)>[
      ('Нарушение авторских прав (copyright)', 'copyright'),
      ('Доксинг (личные данные)', 'doxing'),
      ('Сваттинг / угрозы безопасности', 'swatting'),
    ]) {
      testWidgets('"$title" pops with "$reason"', (tester) async {
        final _HostState host = await _openSheet(
          tester,
          showReportMessageSheet,
        );

        await tester.tap(find.text(title));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(host.result, reason);
        expect(host.closed, isTrue);
        expect(find.byType(ReportMessageSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the spam reason pops with "spam"', (tester) async {
      final _HostState host = await _openSheet(
        tester,
        showReportMessageSheet,
      );

      await tester.tap(find.text(_l10n.reportReasonSpam));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(host.result, 'spam');
    });
  });

  group('ai actions sheet', () {
    testWidgets('hides the quota badge when the profile has no quota', (
      tester,
    ) async {
      await _openSheet(
        tester,
        (BuildContext context) => showAiActionsSheet(context),
        overrides: <Override>[
          authProvider.overrideWith(_AuthWithoutQuota.new),
        ],
      );

      expect(find.byType(AiActionsSheet), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsNothing);
      expect(find.textContaining('символов'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the remaining quota badge', (tester) async {
      await _openSheet(
        tester,
        (BuildContext context) => showAiActionsSheet(context),
        overrides: <Override>[
          authProvider.overrideWith(
            () => _AuthWithQuota(
              const AiQuota(
                limitChars: 1000,
                usedChars: 250,
                remainingChars: 750,
                usedPercent: 25,
                windowHours: 72,
              ),
            ),
          ),
        ],
      );

      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      expect(find.text('75% символов'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the two rewrite cards pop their actions', (tester) async {
      _HostState host = await _openSheet(
        tester,
        (BuildContext context) => showAiActionsSheet(context),
        overrides: <Override>[
          authProvider.overrideWith(_AuthWithoutQuota.new),
        ],
      );
      await tester.tap(find.text(_l10n.chatAiFixErrors));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(host.result, (AiAction.correct, null));

      host = await _openSheet(
        tester,
        (BuildContext context) => showAiActionsSheet(context),
        overrides: <Override>[
          authProvider.overrideWith(_AuthWithoutQuota.new),
        ],
      );
      await tester.tap(find.text(_l10n.chatAiFormal));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(host.result, (AiAction.rewriteFormal, null));
    });

    for (final (String label, String language) in <(String, String)>[
      ('🇬🇧 English', 'en'),
      ('🇪🇸 Español', 'es'),
      ('🇨🇳 中文', 'zh'),
      ('🇷🇺 Русский', 'ru'),
    ]) {
      testWidgets('"$label" pops translate with "$language"', (tester) async {
        final _HostState host = await _openSheet(
          tester,
          (BuildContext context) => showAiActionsSheet(context),
          overrides: <Override>[
            authProvider.overrideWith(_AuthWithoutQuota.new),
          ],
        );

        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(host.result, (AiAction.translate, language));
        expect(host.closed, isTrue);
        expect(find.byType(AiActionsSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the screen does not open the sheet for empty input', (
      tester,
    ) async {
      final ApiChatSummary chat = _screenChat();
      await _pumpScreen(tester, chat);

      await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AiActionsSheet), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'исправь меня');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AiActionsSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('media actions sheet', () {
    testWidgets('five rows, and "Удалить" only with rights', (tester) async {
      tester.view.physicalSize = const Size(600, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _app(Scaffold(body: _mediaMenu(isMine: false, amAdminOrOwner: false))),
      );

      expect(find.byType(ListTile), findsNWidgets(4));
      expect(find.text(_l10n.mediaActionSave), findsOneWidget);
      expect(find.text(_l10n.chatResendTo), findsOneWidget);
      expect(find.text(_l10n.mediaActionCopy), findsOneWidget);
      expect(find.text(_l10n.mediaActionOpenIn), findsOneWidget);
      expect(find.text(_l10n.chatDelete), findsNothing);

      // The owner sees the same four rows plus the destructive one.
      await tester.pumpWidget(
        _app(Scaffold(body: _mediaMenu(isMine: true, amAdminOrOwner: false))),
      );

      expect(find.byType(ListTile), findsNWidgets(5));
      expect(find.text(_l10n.chatDelete), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Screen fixtures for the empty-input guard: the screen reads a dozen
// providers that would hit sockets, Hive or secure storage on their own.
// ---------------------------------------------------------------------------

const int _chatId = 9001;
const int _myUserId = 1;

ApiChatSummary _screenChat() => ApiChatSummary(
  id: _chatId,
  chatType: 'direct',
  name: 'Тестовый собеседник',
  unreadCount: 0,
  membersCount: 2,
  partnerUserId: 2,
  isSecret: false,
  autoDeleteSeconds: null,
);

class _AuthWithoutQuota extends AuthNotifier {
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

class _AuthWithQuota extends AuthNotifier {
  _AuthWithQuota(this.quota);

  final AiQuota quota;

  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture-token',
      userId: _myUserId,
      username: 'me',
      displayName: 'Я',
    ),
    profile: ApiProfile(
      id: _myUserId,
      username: 'me',
      displayName: 'Я',
      bio: '',
      aiUsage: quota,
    ),
  );
}

class _ScreenChats extends ChatsNotifier {
  _ScreenChats(this.chat);

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

class _ScreenMembers extends ChatMembersNotifier {
  _ScreenMembers(super.chatId);

  @override
  Future<List<ApiChatMember>> build() async => const <ApiChatMember>[];
}

class _ScreenRepo extends ChatRepository {
  _ScreenRepo(super.ref, this.chat);

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

class _ScreenMessages extends ChatMessagesNotifier {
  _ScreenMessages(super.chatId);

  @override
  Future<List<ApiMessage>> build() async => const <ApiMessage>[];

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

class _ScreenUiSettings extends UiSettingsNotifier {
  @override
  UiSettingsState build() =>
      const UiSettingsState.defaults().copyWith(haptics: false);
}

class _ScreenPrivacy extends PrivacyNotifier {
  @override
  PrivacyState build() => const PrivacyState();
}

class _ScreenTyping extends TypingNotifier {
  _ScreenTyping(super.chatId);

  @override
  TypingState build() => const TypingState();

  @override
  Future<void> sendTyping() async {}
}

class _ScreenDraftStorage extends DraftStorage {
  _ScreenDraftStorage() : super();

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

class _ScreenSound extends SoundService {
  @override
  Future<void> playEvent(SoundEvent event, {double? volume}) async {}

  @override
  Future<void> playNotification(SoundEvent event, {double? volume}) async {}
}

Future<void> _pumpScreen(WidgetTester tester, ApiChatSummary chat) async {
  tester.view.physicalSize = const Size(600, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authProvider.overrideWith(_AuthWithoutQuota.new),
        chatsProvider.overrideWith(() => _ScreenChats(chat)),
        chatMembersProvider(_chatId).overrideWith(() => _ScreenMembers(_chatId)),
        chatMessagesProvider(_chatId).overrideWith(
          () => _ScreenMessages(_chatId),
        ),
        chatRepositoryProvider.overrideWith((Ref ref) => _ScreenRepo(ref, chat)),
        secretChatCoordinatorProvider.overrideWith((Ref ref) async => null),
        secretChatRevisionProvider.overrideWith(
          (Ref ref) => Stream<int>.value(0),
        ),
        secretChatEngineProvider.overrideWithValue(null),
        ordinaryE2eeProvider.overrideWithValue(null),
        draftStorageProvider.overrideWith((Ref ref) => _ScreenDraftStorage()),
        privacyProvider.overrideWith(_ScreenPrivacy.new),
        typingProvider(_chatId).overrideWith(() => _ScreenTyping(_chatId)),
        uiSettingsProvider.overrideWith(_ScreenUiSettings.new),
        connectivityProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
        appSoundProvider.overrideWithValue(_ScreenSound()),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true),
        home: const ChatDetailScreen(chatId: '$_chatId'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

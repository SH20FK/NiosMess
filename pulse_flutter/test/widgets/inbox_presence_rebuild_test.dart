// An online/offline push repaints the one row that shows it. The inbox list
// itself must not be rebuilt: before this contract every presence push rebuilt
// every visible row.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/chat_list_screen.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    soundEffects: false,
    haptics: false,
  );
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    hydrated: true,
    busy: false,
    pendingIdentifier: null,
    error: null,
    profile: null,
    session: AuthSession(
      accessToken: 'presence-fixture',
      userId: 42,
      username: 'preview',
      displayName: 'Preview',
    ),
  );
}

const List<ApiChatSummary> _initial = <ApiChatSummary>[
  ApiChatSummary(
    id: 1,
    chatType: 'direct',
    name: 'Ирина',
    unreadCount: 0,
    membersCount: 2,
  ),
  ApiChatSummary(
    id: 2,
    chatType: 'direct',
    name: 'Тимур',
    unreadCount: 0,
    membersCount: 2,
  ),
];

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => _initial;

  void _replace(int id, ApiChatSummary Function(ApiChatSummary) change) {
    state = AsyncData<List<ApiChatSummary>>(<ApiChatSummary>[
      for (final ApiChatSummary chat in state.requireValue)
        chat.id == id ? change(chat) : chat,
    ]);
  }

  void setOnline(int id, bool online) =>
      _replace(id, (ApiChatSummary c) => c.copyWith(isOnline: online));

  void setUnread(int id, int unread) =>
      _replace(id, (ApiChatSummary c) => c.copyWith(unreadCount: unread));
}

class _QuietTyping extends TypingNotifier {
  _QuietTyping(super.chatId);
  @override
  TypingState build() => const TypingState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('sameExceptPresence ignores isOnline and nothing else', () {
    const ApiChatSummary chat = ApiChatSummary(
      id: 1,
      chatType: 'direct',
      name: 'Ирина',
      unreadCount: 2,
      membersCount: 2,
    );
    expect(chat.sameExceptPresence(chat.copyWith(isOnline: true)), isTrue);
    expect(chat.sameExceptPresence(chat.copyWith(unreadCount: 3)), isFalse);
    expect(chat.sameExceptPresence(chat.copyWith(name: 'Ира')), isFalse);
    expect(chat.sameExceptPresence(chat.copyWith(keyMismatch: true)), isFalse);
    expect(chat.sameExceptPresence(chat.copyWith(isBlocked: true)), isFalse);
  });

  testWidgets('a presence push repaints its own row and leaves the list alone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        uiSettingsProvider.overrideWith(_Settings.new),
        authProvider.overrideWith(_Auth.new),
        chatsProvider.overrideWith(_Chats.new),
        liveDraftMapProvider.overrideWith(
          (ref) => Stream<Map<int, String>>.value(const <int, String>{}),
        ),
        secretChatEngineProvider.overrideWithValue(null),
        secretChatRevisionProvider.overrideWith((ref) => Stream<int>.value(0)),
        ordinaryE2eeProvider.overrideWithValue(null),
        for (final ApiChatSummary chat in _initial)
          typingProvider(chat.id).overrideWith(() => _QuietTyping(chat.id)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: ChatListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    ChatTile tile(String name) =>
        tester.widget<ChatTile>(find.widgetWithText(ChatTile, name));
    final _Chats chats = container.read(chatsProvider.notifier) as _Chats;
    const ValueKey<String> dot = ValueKey<String>('chat-tile-presence-dot');

    expect(tile('Ирина').isOnline, isFalse);
    expect(find.byKey(dot), findsNothing);
    final ChatTile neighbour = tile('Тимур');

    chats.setOnline(1, true);
    await tester.pump();
    expect(tile('Ирина').isOnline, isTrue);
    expect(find.byKey(dot), findsOneWidget);
    // Same widget instance: the neighbouring row was not rebuilt.
    expect(identical(tile('Тимур'), neighbour), isTrue);

    chats.setOnline(1, false);
    await tester.pump();
    expect(tile('Ирина').isOnline, isFalse);
    expect(find.byKey(dot), findsNothing);
    expect(identical(tile('Тимур'), neighbour), isTrue);

    // Anything else still reaches the list.
    chats.setUnread(2, 3);
    await tester.pump();
    expect(tile('Тимур').unreadCount, 3);
    expect(identical(tile('Тимур'), neighbour), isFalse);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

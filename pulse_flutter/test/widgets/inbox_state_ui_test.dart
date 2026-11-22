// Pin, archive and manual unread on the inbox screen:
// * archived chats live behind the "Архив" row and nowhere else;
// * the chat menu pins, archives and marks unread, and the tile shows it;
// * a chat from a server without that state keeps the old menu and swipe;
// * a swipe towards the start edge archives, with a way back in the toast.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
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
      accessToken: 'inbox-state-fixture',
      userId: 42,
      username: 'preview',
      displayName: 'Preview',
    ),
  );
}

final DateTime _pinnedAt = DateTime.utc(2026, 11, 20);

/// Chats 1-4 come from a server that keeps the inbox state; chat 5 does not.
List<ApiChatSummary> _initial() => <ApiChatSummary>[
  const ApiChatSummary(
    id: 1,
    chatType: 'direct',
    name: 'Ирина',
    unreadCount: 3,
    membersCount: 2,
    notificationsMuted: false,
  ),
  const ApiChatSummary(
    id: 2,
    chatType: 'direct',
    name: 'Тимур',
    unreadCount: 0,
    membersCount: 2,
    notificationsMuted: false,
  ),
  ApiChatSummary(
    id: 3,
    chatType: 'group',
    name: 'Команда',
    unreadCount: 0,
    membersCount: 5,
    notificationsMuted: false,
    pinnedAt: _pinnedAt,
  ),
  const ApiChatSummary(
    id: 4,
    chatType: 'group',
    name: 'Склад',
    unreadCount: 2,
    membersCount: 7,
    notificationsMuted: false,
    isArchived: true,
  ),
  const ApiChatSummary(
    id: 5,
    chatType: 'direct',
    name: 'Старый',
    unreadCount: 0,
    membersCount: 2,
  ),
];

typedef _StateCall = ({Set<int> ids, bool? pinned, bool? archived, bool? unread});

/// Stores the inbox state the way the server does, without a socket.
class _Chats extends ChatsNotifier {
  final List<_StateCall> calls = <_StateCall>[];
  final List<int> read = <int>[];
  Object? refusal;

  @override
  Future<List<ApiChatSummary>> build() async => _initial();

  @override
  Future<void> refresh() async {}

  @override
  Future<void> markReadFromInbox(int chatId) async {
    read.add(chatId);
    _rewrite(
      <int>{chatId},
      (ApiChatSummary chat) =>
          chat.copyWith(unreadCount: 0, markedUnread: false),
    );
  }

  @override
  Future<void> setInboxState(
    Iterable<ApiChatSummary> chats, {
    bool? pinned,
    bool? archived,
    bool? unread,
  }) async {
    final Set<int> ids = <int>{
      for (final ApiChatSummary chat in chats) chat.id,
    };
    calls.add((ids: ids, pinned: pinned, archived: archived, unread: unread));
    final Object? error = refusal;
    if (error != null) throw error;
    _rewrite(ids, (ApiChatSummary chat) {
      ApiChatSummary next = chat;
      if (pinned == true) {
        next = next.copyWith(
          pinnedAt: DateTime.utc(2026, 11, 22),
          isArchived: false,
        );
      } else if (pinned == false) {
        next = next.copyWith(clearPin: true);
      }
      if (archived != null) {
        next = next.copyWith(isArchived: archived, clearPin: archived);
      }
      if (unread != null) next = next.copyWith(markedUnread: unread);
      return next;
    });
  }

  void _rewrite(Set<int> ids, ApiChatSummary Function(ApiChatSummary) change) {
    state = AsyncData<List<ApiChatSummary>>(<ApiChatSummary>[
      for (final ApiChatSummary chat in state.requireValue)
        ids.contains(chat.id) ? change(chat) : chat,
    ]..sort(compareChatRecency));
  }
}

/// Records mute toggles without touching prefs or the push token.
class _Muted extends ChatMuteHub {
  final List<(int, bool)> toggles = <(int, bool)>[];

  @override
  Future<Set<int>> build() async => const <int>{};

  @override
  Future<void> setMuted(int chatId, bool muted) async {
    toggles.add((chatId, muted));
    final Set<int> next = <int>{...?state.value};
    if (muted) {
      next.add(chatId);
    } else {
      next.remove(chatId);
    }
    state = AsyncData<Set<int>>(next);
  }
}

class _Folders extends ChatFoldersNotifier {
  @override
  Future<List<ChatFolder>> build() async => const <ChatFolder>[];
}

class _Repository extends Fake implements ChatRepository {}

class _QuietTyping extends TypingNotifier {
  _QuietTyping(super.chatId);
  @override
  TypingState build() => const TypingState();
}

class _Fixture {
  _Fixture(this.container);

  final ProviderContainer container;

  _Chats get chats => container.read(chatsProvider.notifier) as _Chats;
  _Muted get muted => container.read(chatMuteHubProvider.notifier) as _Muted;
}

const ValueKey<String> _archiveRow = ValueKey<String>('inbox-archive-row');
const ValueKey<String> _pin = ValueKey<String>('chat-tile-pin');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<_Fixture> pumpInbox(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        uiSettingsProvider.overrideWith(_Settings.new),
        authProvider.overrideWith(_Auth.new),
        chatsProvider.overrideWith(_Chats.new),
        chatMuteHubProvider.overrideWith(_Muted.new),
        chatFoldersProvider.overrideWith(_Folders.new),
        chatRepositoryProvider.overrideWithValue(_Repository()),
        liveDraftMapProvider.overrideWith(
          (ref) => Stream<Map<int, String>>.value(const <int, String>{}),
        ),
        secretChatEngineProvider.overrideWithValue(null),
        secretChatRevisionProvider.overrideWith((ref) => Stream<int>.value(0)),
        ordinaryE2eeProvider.overrideWithValue(null),
        for (final ApiChatSummary chat in _initial())
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
    return _Fixture(container);
  }

  Finder row(String name) => find.widgetWithText(ChatTile, name);

  ChatTile tile(WidgetTester tester, String name) =>
      tester.widget<ChatTile>(row(name));

  /// Long press on a row: the action sheet.
  Future<void> openSheet(WidgetTester tester, String name) async {
    await tester.longPress(row(name));
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('archived chats live behind the archive row and nowhere else', (
    tester,
  ) async {
    await pumpInbox(tester);

    expect(find.byKey(_archiveRow), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(_archiveRow), matching: find.text('1 чат')),
      findsOneWidget,
    );
    expect(row('Склад'), findsNothing);
    expect(row('Ирина'), findsOneWidget);
    // A pinned chat with nothing to read carries the pin glyph.
    expect(tile(tester, 'Команда').isPinned, isTrue);
    expect(
      find.descendant(of: row('Команда'), matching: find.byKey(_pin)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(_archiveRow));
    await tester.pumpAndSettle();
    expect(row('Склад'), findsOneWidget);
    expect(row('Ирина'), findsNothing);
    expect(row('Команда'), findsNothing);
    // The same row leads back.
    expect(find.byKey(_archiveRow), findsOneWidget);

    await tester.tap(find.byKey(_archiveRow));
    await tester.pumpAndSettle();
    expect(row('Склад'), findsNothing);
    expect(row('Ирина'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the chat menu pins and marks unread, and the tile shows it', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(tester);

    await openSheet(tester, 'Тимур');
    for (final String label in <String>[
      'Отметить непрочитанным',
      'Закрепить',
      'Отключить уведомления',
      'В архив',
      'В папку',
      'Выбрать',
      'Удалить',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    await tapText(tester, 'Закрепить');
    expect(f.chats.calls.single.ids, <int>{2});
    expect(f.chats.calls.single.pinned, isTrue);
    expect(f.chats.calls.single.archived, isNull);
    expect(f.chats.calls.single.unread, isNull);
    expect(tile(tester, 'Тимур').isPinned, isTrue);
    expect(find.byKey(_pin), findsNWidgets(2));
    // The newest pin leads, the older pin follows, the rest come after.
    final double pinned = tester.getTopLeft(row('Тимур')).dy;
    final double older = tester.getTopLeft(row('Команда')).dy;
    expect(pinned, lessThan(older));
    expect(older, lessThan(tester.getTopLeft(row('Ирина')).dy));

    await openSheet(tester, 'Тимур');
    expect(find.text('Закрепить'), findsNothing);
    await tapText(tester, 'Открепить');
    expect(f.chats.calls.last.pinned, isFalse);
    expect(tile(tester, 'Тимур').isPinned, isFalse);

    await openSheet(tester, 'Тимур');
    await tapText(tester, 'Отметить непрочитанным');
    expect(f.chats.calls.last.ids, <int>{2});
    expect(f.chats.calls.last.unread, isTrue);
    expect(tile(tester, 'Тимур').markedUnread, isTrue);
    expect(tile(tester, 'Тимур').unreadCount, 0);

    // A marked chat offers the way back in the same slot.
    await openSheet(tester, 'Тимур');
    expect(find.text('Отметить непрочитанным'), findsNothing);
    await tapText(tester, 'Отметить прочитанным');
    expect(f.chats.read, <int>[2]);
    expect(tile(tester, 'Тимур').markedUnread, isFalse);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a chat from a server without the state keeps the old menu and swipe', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(tester);

    await openSheet(tester, 'Старый');
    expect(find.text('Закрепить'), findsNothing);
    expect(find.text('В архив'), findsNothing);
    expect(find.text('Отметить непрочитанным'), findsNothing);
    expect(find.text('Отметить прочитанным'), findsOneWidget);
    expect(find.text('Отключить уведомления'), findsOneWidget);
    await closeSheet(tester);

    // Nothing to read and no manual mark on that server: no travel.
    await tester.drag(row('Старый'), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(f.chats.calls, isEmpty);
    expect(f.chats.read, isEmpty);

    // Towards the start edge it still mutes.
    await tester.drag(row('Старый'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(f.muted.toggles, <(int, bool)>[(5, true)]);
    expect(f.chats.calls, isEmpty);
    expect(find.text('Уведомления отключены'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swipe towards the start edge archives, and the toast takes it back', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(tester);

    await tester.drag(row('Ирина'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(f.chats.calls.single.ids, <int>{1});
    expect(f.chats.calls.single.archived, isTrue);
    expect(f.chats.calls.single.pinned, isNull);
    expect(row('Ирина'), findsNothing);
    expect(
      find.descendant(of: find.byKey(_archiveRow), matching: find.text('2 чата')),
      findsOneWidget,
    );
    expect(find.text('Чат убран в архив'), findsOneWidget);

    await tapText(tester, 'Отмена');
    expect(f.chats.calls, hasLength(2));
    expect(f.chats.calls.last.ids, <int>{1});
    expect(f.chats.calls.last.archived, isFalse);
    expect(f.chats.calls.last.pinned, isNull);
    expect(row('Ирина'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('taking an archived pinned chat back returns its pin', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(tester);

    await openSheet(tester, 'Команда');
    await tapText(tester, 'В архив');
    expect(f.chats.calls.single.ids, <int>{3});
    expect(f.chats.calls.single.archived, isTrue);
    expect(row('Команда'), findsNothing);

    await tapText(tester, 'Отмена');
    expect(f.chats.calls.last.archived, isFalse);
    expect(f.chats.calls.last.pinned, isTrue);
    expect(tile(tester, 'Команда').isPinned, isTrue);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swipe towards the end edge reads, or marks unread when there is nothing to read', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(tester);

    await tester.drag(row('Ирина'), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(f.chats.read, <int>[1]);
    expect(f.chats.calls, isEmpty);

    await tester.drag(row('Тимур'), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(f.chats.calls.single.ids, <int>{2});
    expect(f.chats.calls.single.unread, isTrue);
    expect(tile(tester, 'Тимур').markedUnread, isTrue);

    // The mark is read away by the same swipe.
    await tester.drag(row('Тимур'), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(f.chats.read, <int>[1, 2]);
    expect(tile(tester, 'Тимур').markedUnread, isFalse);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the archive closes with its last chat', (tester) async {
    final _Fixture f = await pumpInbox(tester);

    await tester.tap(find.byKey(_archiveRow));
    await tester.pumpAndSettle();
    expect(row('Склад'), findsOneWidget);

    // Inside the archive the menu offers the way back and no pin.
    await openSheet(tester, 'Склад');
    expect(find.text('Закрепить'), findsNothing);
    expect(find.text('В архив'), findsNothing);
    await tapText(tester, 'Вернуть из архива');
    expect(f.chats.calls.single.ids, <int>{4});
    expect(f.chats.calls.single.archived, isFalse);

    expect(find.byKey(_archiveRow), findsNothing);
    expect(row('Склад'), findsOneWidget);
    expect(row('Ирина'), findsOneWidget);
    expect(find.text('Чат возвращён из архива'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a refused pin says why and changes nothing', (tester) async {
    final _Fixture f = await pumpInbox(tester);
    f.chats.refusal = const ChatPinLimitException();

    await openSheet(tester, 'Тимур');
    await tapText(tester, 'Закрепить');

    expect(f.chats.calls.single.pinned, isTrue);
    expect(tile(tester, 'Тимур').isPinned, isFalse);
    expect(find.text('Можно закрепить не больше 10 чатов'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

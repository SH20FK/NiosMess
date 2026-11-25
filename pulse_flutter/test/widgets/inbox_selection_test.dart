// Inbox multi-select and the chat menu around it:
// * "Выбрать" in the chat menu enters the mode with that chat picked; while it
//   is on, any press on a row picks it and the header carries the actions;
// * the bulk actions (read, mute, delete) reach every picked chat;
// * "В папку" adds the chat to a folder's own list and takes it back out;
// * a right click opens the same actions in a menu at the pointer.

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/features/chats/application/inbox_selection_controller.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_list_fab_provider.dart';
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
      accessToken: 'selection-fixture',
      userId: 42,
      username: 'preview',
      displayName: 'Preview',
    ),
  );
}

class _SignedOut extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial();
}

const List<ApiChatSummary> _initial = <ApiChatSummary>[
  ApiChatSummary(
    id: 1,
    chatType: 'direct',
    name: 'Ирина',
    unreadCount: 3,
    membersCount: 2,
  ),
  ApiChatSummary(
    id: 2,
    chatType: 'direct',
    name: 'Тимур',
    unreadCount: 0,
    membersCount: 2,
  ),
  ApiChatSummary(
    id: 3,
    chatType: 'group',
    name: 'Команда',
    unreadCount: 1,
    membersCount: 5,
  ),
];

class _Chats extends ChatsNotifier {
  final List<int> read = <int>[];

  @override
  Future<List<ApiChatSummary>> build() async => _initial;

  @override
  Future<void> markReadFromInbox(int chatId) async {
    read.add(chatId);
  }

  @override
  Future<void> refresh() async {}

  void remove(int id) {
    state = AsyncData<List<ApiChatSummary>>(<ApiChatSummary>[
      for (final ApiChatSummary chat in state.requireValue)
        if (chat.id != id) chat,
    ]);
  }
}

/// Records bulk mutes without touching prefs or the push token.
class _Muted extends ChatMuteHub {
  final List<(Set<int>, bool)> calls = <(Set<int>, bool)>[];

  @override
  Future<Set<int>> build() async => const <int>{};

  @override
  Future<void> setMutedAll(Iterable<int> chatIds, bool muted) async {
    final Set<int> ids = chatIds.toSet();
    calls.add((ids, muted));
    final Set<int> next = <int>{...?state.value};
    if (muted) {
      next.addAll(ids);
    } else {
      next.removeAll(ids);
    }
    state = AsyncData<Set<int>>(next);
  }
}

class _Folders extends ChatFoldersNotifier {
  _Folders(this.initial);

  final List<ChatFolder> initial;
  final List<ChatFolder> saved = <ChatFolder>[];

  @override
  Future<List<ChatFolder>> build() async => initial;

  @override
  Future<void> save(ChatFolder folder) async {
    saved.add(folder);
    state = AsyncData<List<ChatFolder>>(<ChatFolder>[
      for (final ChatFolder f in state.requireValue)
        f.id == folder.id ? folder : f,
    ]);
  }
}

class _Repository extends Fake implements ChatRepository {
  final List<int> left = <int>[];

  @override
  Future<void> leaveChat(int chatId) async {
    left.add(chatId);
  }
}

class _QuietTyping extends TypingNotifier {
  _QuietTyping(super.chatId);
  @override
  TypingState build() => const TypingState();
}

class _Fixture {
  _Fixture(this.container, this.repo);

  final ProviderContainer container;
  final _Repository repo;

  _Chats get chats => container.read(chatsProvider.notifier) as _Chats;
  _Muted get muted => container.read(chatMuteHubProvider.notifier) as _Muted;
  _Folders get folders =>
      container.read(chatFoldersProvider.notifier) as _Folders;
  Set<int> get selection => container.read(inboxSelectionProvider);
}

const ValueKey<String> _bar = ValueKey<String>('inbox-selection-bar');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<_Fixture> pumpInbox(
    WidgetTester tester, {
    List<ChatFolder> folders = const <ChatFolder>[],
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _Repository repo = _Repository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        uiSettingsProvider.overrideWith(_Settings.new),
        authProvider.overrideWith(_Auth.new),
        chatsProvider.overrideWith(_Chats.new),
        chatMuteHubProvider.overrideWith(_Muted.new),
        chatFoldersProvider.overrideWith(() => _Folders(folders)),
        chatRepositoryProvider.overrideWithValue(repo),
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
    return _Fixture(container, repo);
  }

  Finder row(String name) => find.widgetWithText(ChatTile, name);

  ChatTile tile(WidgetTester tester, String name) =>
      tester.widget<ChatTile>(row(name));

  /// Long press on a row: the action sheet outside multi-select.
  Future<void> openSheet(WidgetTester tester, String name) async {
    await tester.longPress(row(name));
    await tester.pumpAndSettle();
  }

  /// Enters multi-select through the sheet with [name] picked.
  Future<void> startSelection(WidgetTester tester, String name) async {
    await openSheet(tester, name);
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('"Выбрать" starts multi-select and every press on a row picks it', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(tester);
    const ValueKey<String> search = ValueKey<String>('inbox-search-open');
    expect(find.byKey(_bar), findsNothing);
    expect(f.container.read(inboxComposerVisibleProvider), isTrue);

    await startSelection(tester, 'Ирина');
    expect(find.byKey(_bar), findsOneWidget);
    expect(find.text('Выбрано: 1'), findsOneWidget);
    expect(tile(tester, 'Ирина').isPicked, isTrue);
    expect(tile(tester, 'Тимур').isPicked, isFalse);
    // The bar takes the place of the title and its actions; the composer
    // button steps aside for the duration of the mode.
    expect(find.byKey(search), findsNothing);
    expect(f.container.read(inboxComposerVisibleProvider), isFalse);

    await tester.tap(row('Тимур'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 2'), findsOneWidget);
    expect(tile(tester, 'Тимур').isPicked, isTrue);

    // A long press picks as well: no second sheet on top of the mode.
    await tester.longPress(row('Команда'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Выбрано: 3'), findsOneWidget);

    await tester.tap(row('Тимур'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 2'), findsOneWidget);
    expect(f.selection, <int>{1, 3});

    // A picked chat that leaves the list leaves the selection too.
    f.chats.remove(3);
    await tester.pumpAndSettle();
    expect(f.selection, <int>{1});
    expect(find.text('Выбрано: 1'), findsOneWidget);

    await tapKey(tester, 'inbox-selection-close');
    expect(f.selection, isEmpty);
    expect(find.byKey(_bar), findsNothing);
    expect(find.byKey(search), findsOneWidget);
    expect(tile(tester, 'Ирина').isPicked, isFalse);
    expect(f.container.read(inboxComposerVisibleProvider), isTrue);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bulk read marks only the picked chats that have unread', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(tester);
    await startSelection(tester, 'Ирина');
    await tester.tap(row('Тимур'));
    await tester.pumpAndSettle();
    await tester.tap(row('Команда'));
    await tester.pumpAndSettle();
    expect(f.selection, <int>{1, 2, 3});

    await tapKey(tester, 'inbox-selection-read');
    // "Тимур" has nothing to read and is left alone.
    expect(f.chats.read, unorderedEquals(<int>[1, 3]));
    expect(f.selection, isEmpty);
    expect(find.byKey(_bar), findsNothing);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bulk mute silences the picked chats in one call, then unmutes', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(tester);
    await startSelection(tester, 'Ирина');
    await tester.tap(row('Команда'));
    await tester.pumpAndSettle();

    await tapKey(tester, 'inbox-selection-mute');
    // One call for the whole selection: the push token is registered once.
    expect(f.muted.calls, hasLength(1));
    expect(f.muted.calls.single.$1, <int>{1, 3});
    expect(f.muted.calls.single.$2, isTrue);
    expect(f.selection, isEmpty);
    expect(find.text('Уведомления отключены'), findsOneWidget);
    expect(tile(tester, 'Ирина').isMuted, isTrue);
    expect(tile(tester, 'Тимур').isMuted, isFalse);

    // Every picked chat is muted already: the same button unmutes them.
    await startSelection(tester, 'Ирина');
    await tester.tap(row('Команда'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'inbox-selection-mute');
    expect(f.muted.calls, hasLength(2));
    expect(f.muted.calls.last.$1, <int>{1, 3});
    expect(f.muted.calls.last.$2, isFalse);
    expect(find.text('Уведомления включены'), findsOneWidget);
    expect(tile(tester, 'Ирина').isMuted, isFalse);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bulk delete asks once and then removes every picked chat', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(tester);
    await startSelection(tester, 'Ирина');
    await tester.tap(row('Команда'));
    await tester.pumpAndSettle();

    await tapKey(tester, 'inbox-selection-delete');
    expect(find.text('Удалить 2 чата?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    // Backing out keeps both the chats and the selection.
    expect(f.repo.left, isEmpty);
    expect(f.selection, <int>{1, 3});

    await tapKey(tester, 'inbox-selection-delete');
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    expect(f.repo.left, unorderedEquals(<int>[1, 3]));
    expect(f.selection, isEmpty);
    expect(find.byKey(_bar), findsNothing);
    expect(find.text('Удалено 2 чата'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('selection controller toggles, drops missing chats and clears', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [authProvider.overrideWith(_SignedOut.new)],
    );
    addTearDown(container.dispose);
    final InboxSelectionNotifier notifier = container.read(
      inboxSelectionProvider.notifier,
    );
    expect(container.read(inboxSelectionProvider), isEmpty);

    notifier
      ..toggle(1)
      ..toggle(2)
      ..toggle(3);
    expect(container.read(inboxSelectionProvider), <int>{1, 2, 3});
    notifier.toggle(2);
    expect(container.read(inboxSelectionProvider), <int>{1, 3});

    notifier.retainAll(<int>{3, 4});
    expect(container.read(inboxSelectionProvider), <int>{3});
    // Nothing to drop: the state object stays, so nobody is notified.
    final Set<int> before = container.read(inboxSelectionProvider);
    notifier.retainAll(<int>{3, 4});
    expect(identical(container.read(inboxSelectionProvider), before), isTrue);

    notifier.clear();
    expect(container.read(inboxSelectionProvider), isEmpty);
  });

  testWidgets('"В папку" adds the chat to a folder list and takes it back out', (
    tester,
  ) async {
    final _Fixture f = await pumpInbox(
      tester,
      folders: const <ChatFolder>[
        ChatFolder(id: 'work', title: 'Работа', chatIds: <int>[2]),
        ChatFolder(id: 'rule', title: 'Групповые', types: <String>['group']),
      ],
    );
    final Finder work = find.byKey(
      const ValueKey<String>('chat-folder-pick-work'),
    );
    final Finder rule = find.byKey(
      const ValueKey<String>('chat-folder-pick-rule'),
    );

    Future<void> openPicker(String name) async {
      await openSheet(tester, name);
      await tester.tap(find.text('В папку').last);
      await tester.pumpAndSettle();
      expect(work, findsOneWidget);
      expect(rule, findsOneWidget);
    }

    // A folder that takes the chat by its type rule is checked and disabled:
    // the rule puts the chat there, not the list.
    await openPicker('Команда');
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: rule, matching: find.byType(InkWell)).first,
          )
          .onTap,
      isNull,
    );
    expect(
      find.descendant(
        of: rule,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(f.folders.saved, isEmpty);

    await openPicker('Ирина');
    expect(
      find.descendant(
        of: work,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsNothing,
    );
    await tester.tap(work);
    await tester.pumpAndSettle();
    expect(f.folders.saved, hasLength(1));
    expect(f.folders.saved.single.id, 'work');
    expect(f.folders.saved.single.title, 'Работа');
    expect(f.folders.saved.single.chatIds, <int>[2, 1]);
    expect(find.text('Добавлено в папку «Работа»'), findsOneWidget);

    // The same row now shows the chat as listed, and takes it back out.
    await openPicker('Ирина');
    expect(
      find.descendant(
        of: work,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(work);
    await tester.pumpAndSettle();
    expect(f.folders.saved, hasLength(2));
    expect(f.folders.saved.last.chatIds, <int>[2]);
    expect(find.text('Убрано из папки «Работа»'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('right click opens the same actions in a menu at the pointer', (
    tester,
  ) async {
    // A window with room to the right of the pointer: the test font draws
    // every glyph as a square, so the menu is about 350 dp wide here, and a
    // phone-wide window would push it back from the pointer to stay on screen.
    final _Fixture f = await pumpInbox(tester, size: const Size(700, 844));

    Future<Offset> rightClick(String name) async {
      final Offset point = tester.getTopLeft(row(name)) + const Offset(40, 38);
      final TestGesture gesture = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();
      return point;
    }

    Finder item(String action) =>
        find.byKey(ValueKey<String>('chat-cursor-menu-$action'));

    final Offset point = await rightClick('Тимур');
    // A menu, not the sheet a long press opens.
    expect(find.byType(BottomSheet), findsNothing);
    for (final String action in <String>[
      'markRead',
      'toggleMute',
      'addToFolder',
      'select',
      'leave',
    ]) {
      expect(item(action), findsOneWidget, reason: action);
    }
    // It hangs from the pointer, not from the middle of the window.
    final Rect first = tester.getRect(item('markRead'));
    expect(first.left, inInclusiveRange(point.dx - 1, point.dx + 40));
    expect(first.top, inInclusiveRange(point.dy - 1, point.dy + 40));
    // "Тимур" has nothing to read: the row is listed but disabled.
    expect(
      tester
          .widget<MenuItemButton>(
            find.descendant(
              of: item('markRead'),
              matching: find.byType(MenuItemButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(item('select'));
    await tester.pumpAndSettle();
    expect(item('select'), findsNothing);
    expect(f.selection, <int>{2});
    expect(find.byKey(_bar), findsOneWidget);

    // While chats are being picked a right click picks, like any other press.
    await rightClick('Ирина');
    expect(item('markRead'), findsNothing);
    expect(f.selection, <int>{1, 2});

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

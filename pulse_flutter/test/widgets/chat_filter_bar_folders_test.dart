import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_filter_bar.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';

class _Chats extends ChatsNotifier {
  _Chats(this.initial);
  final List<ApiChatSummary> initial;

  @override
  Future<List<ApiChatSummary>> build() async => initial;
}

class _Folders extends ChatFoldersNotifier {
  @override
  Future<List<ChatFolder>> build() async => const <ChatFolder>[
    ChatFolder(id: 'work', title: 'Работа', chatIds: <int>[1]),
    ChatFolder(id: 'quiet', title: 'Тихие', chatIds: <int>[2]),
  ];
}

class _Muted extends ChatMuteHub {
  @override
  Future<Set<int>> build() async => const <int>{2};
}

const List<ApiChatSummary> _chats = <ApiChatSummary>[
  ApiChatSummary(
    id: 1,
    chatType: 'direct',
    name: 'Ирина',
    unreadCount: 5,
    membersCount: 2,
  ),
  ApiChatSummary(
    id: 2,
    chatType: 'direct',
    name: 'Тихий чат',
    unreadCount: 2,
    membersCount: 2,
  ),
];

Widget _app(Widget child) => ProviderScope(
  overrides: [
    chatsProvider.overrideWith(() => _Chats(_chats)),
    chatFoldersProvider.overrideWith(_Folders.new),
    chatMuteHubProvider.overrideWith(_Muted.new),
  ],
  child: MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: child),
  ),
);

Color _badgeColor(WidgetTester tester, Key pillKey) {
  final Container badge = tester
      .widgetList<Container>(
        find.descendant(
          of: find.byKey(pillKey),
          matching: find.byType(Container),
        ),
      )
      .firstWhere((Container c) => c.decoration is BoxDecoration);
  return (badge.decoration! as BoxDecoration).color!;
}

void main() {
  const allKey = ValueKey<String>('chat-filter-all');
  const moreKey = ValueKey<String>('chat-filter-more');
  const workKey = ValueKey<String>('chat-filter-folder-work');
  const quietKey = ValueKey<String>('chat-filter-folder-quiet');

  testWidgets('folders replace the base types in the single row', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ChatFilterBar()));
    await tester.pumpAndSettle();

    for (final key in <Key>[allKey, workKey, quietKey, moreKey]) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }
    // Chat types are menu-only while folders exist.
    expect(
      find.byKey(const ValueKey<String>('chat-filter-unread')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-filter-groups')),
      findsNothing,
    );
    expect(find.text('Работа'), findsOneWidget);
    expect(find.text('Тихие'), findsOneWidget);
  });

  testWidgets('folder pill counts unread VK-style: muted only stays neutral', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ChatFilterBar()));
    await tester.pumpAndSettle();

    final ColorScheme scheme = Theme.of(
      tester.element(find.byType(ChatFilterBar)),
    ).colorScheme;

    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // Unmuted unread chat -> tinted primary badge.
    expect(_badgeColor(tester, workKey), scheme.primary);
    // Only a muted chat is unread -> neutral badge.
    expect(_badgeColor(tester, quietKey), scheme.surfaceContainerHighest);

    await tester.tap(find.byKey(workKey));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedContainer>(
            find
                .descendant(
                  of: find.byKey(workKey),
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          )
          .decoration,
      isA<ShapeDecoration>().having(
        (ShapeDecoration d) => d.color,
        'fill',
        scheme.secondaryContainer,
      ),
    );
  });

  testWidgets('long press on a folder opens folder management', (tester) async {
    await tester.pumpWidget(_app(const ChatFilterBar()));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(workKey));
    await tester.pumpAndSettle();

    expect(find.byType(ChatFoldersScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the overflow menu keeps types and folder management', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ChatFilterBar()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(moreKey));
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemButton), findsNWidgets(7));
    expect(find.widgetWithText(MenuItemButton, 'Каналы'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Личные'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Боты'), findsOneWidget);

    await tester.tap(find.widgetWithText(MenuItemButton, 'Папки чатов'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatFoldersScreen), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_filter_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_search_bar.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';

class MockChatsNotifier extends ChatsNotifier {
  MockChatsNotifier(this._initial);
  final List<ApiChatSummary> _initial;

  @override
  Future<List<ApiChatSummary>> build() async {
    return _initial;
  }
}

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier(this._profile);
  final ApiProfile? _profile;

  @override
  AuthState build() {
    return AuthState(
      hydrated: true,
      busy: false,
      session: null,
      pendingIdentifier: null,
      error: null,
      profile: _profile,
    );
  }
}

Widget _buildTestApp({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Milestone 1: ChatListTile / ChatTile Tests', () {
    testWidgets('renders title, subtitle, formatted time and avatar', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          child: ChatTile(
            title: 'Alice Cooper',
            subtitle: 'Hey there!',
            formattedTime: '12:45',
            unreadCount: 0,
            avatarText: 'Alice Cooper',
            avatarColor: const Color(0xFF6750A4),
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Cooper'), findsOneWidget);
      expect(find.text('Hey there!'), findsOneWidget);
      expect(find.text('12:45'), findsOneWidget);

      await tester.tap(find.byType(ChatTile));
      expect(tapped, isTrue);
    });

    testWidgets('renders expressive unread badge when unreadCount > 0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: ChatTile(
            title: 'Bob Dylan',
            subtitle: 'New track dropped',
            formattedTime: '14:20',
            unreadCount: 5,
            avatarText: 'Bob Dylan',
            avatarColor: const Color(0xFF6750A4),
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('renders 99+ for large unread count', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: ChatTile(
            title: 'Group Chat',
            subtitle: 'Busy discussion',
            formattedTime: '15:00',
            unreadCount: 150,
            avatarText: 'Group Chat',
            avatarColor: const Color(0xFF6750A4),
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets(
      'renders online status indicator cutout when isOnline is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            child: ChatTile(
              title: 'Charlie Online',
              subtitle: 'Active now',
              formattedTime: 'Now',
              unreadCount: 0,
              isOnline: true,
              avatarText: 'Charlie Online',
              avatarColor: const Color(0xFF6750A4),
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ChatTile), findsOneWidget);
      },
    );
  });

  group('Milestone 1: ChatFilterBar Tests', () {
    const allKey = ValueKey<String>('chat-filter-all');
    const unreadKey = ValueKey<String>('chat-filter-unread');
    const groupsKey = ValueKey<String>('chat-filter-groups');
    const moreKey = ValueKey<String>('chat-filter-more');

    ShapeDecoration pillDecoration(WidgetTester tester, Key key) =>
        tester
                .widget<AnimatedContainer>(
                  find
                      .descendant(
                        of: find.byKey(key),
                        matching: find.byType(AnimatedContainer),
                      )
                      .first,
                )
                .decoration!
            as ShapeDecoration;

    testWidgets('renders one 40 dp row of pills without an overflow menu', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(child: const ChatFilterBar()));
      await tester.pumpAndSettle();

      for (final key in <Key>[allKey, unreadKey, groupsKey]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      // Types are shown directly in the row; the old "⋯" menu is gone.
      expect(find.byKey(moreKey), findsNothing);
      // The legacy second row ("Тип чата") is gone: no chips, no type control.
      expect(find.byType(FilterChip), findsNothing);
      expect(find.text('Chat type'), findsNothing);
      expect(find.text('Тип чата'), findsNothing);

      // One row only: every visible control shares the same vertical centre.
      final double centerY = tester.getCenter(find.byKey(allKey)).dy;
      for (final key in <Key>[unreadKey, groupsKey]) {
        expect(tester.getCenter(find.byKey(key)).dy, centerY, reason: '$key');
      }
      expect(tester.getSize(find.byKey(allKey)).height, 40);
      // Pills and the app bar share the 16 dp text column.
      expect(tester.getTopLeft(find.byKey(allKey)).dx, 16);
    });

    testWidgets('selection swaps the fill and keeps the pill width stable', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(child: const ChatFilterBar()));
      await tester.pumpAndSettle();

      final ColorScheme scheme = Theme.of(
        tester.element(find.byType(ChatFilterBar)),
      ).colorScheme;
      final double widthBefore = tester.getSize(find.byKey(unreadKey)).width;
      expect(
        pillDecoration(tester, unreadKey).color,
        scheme.surfaceContainerLow,
      );
      expect(pillDecoration(tester, allKey).color, scheme.secondaryContainer);

      await tester.tap(find.byKey(unreadKey));
      await tester.pumpAndSettle();

      expect(
        pillDecoration(tester, unreadKey).color,
        scheme.secondaryContainer,
      );
      expect(pillDecoration(tester, allKey).color, scheme.surfaceContainerLow);
      // The selected weight is constant (w600), so the row never reflows.
      expect(tester.getSize(find.byKey(unreadKey)).width, widthBefore);
    });

    testWidgets(
      'filter honors reduced motion and large text on a narrow screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _buildTestApp(
            child: const MediaQuery(
              data: MediaQueryData(
                disableAnimations: true,
                textScaler: TextScaler.linear(2),
              ),
              child: ChatFilterBar(),
            ),
          ),
        );
        expect(
          tester
              .widget<AnimatedContainer>(
                find
                    .descendant(
                      of: find.byKey(unreadKey),
                      matching: find.byType(AnimatedContainer),
                    )
                    .first,
              )
              .duration,
          Duration.zero,
        );
        await tester.tap(find.byKey(unreadKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows every chat type as a pill in the row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(child: const ChatFilterBar()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(groupsKey));
      await tester.pumpAndSettle();
      final ColorScheme scheme = Theme.of(
        tester.element(find.byType(ChatFilterBar)),
      ).colorScheme;
      expect(
        pillDecoration(tester, groupsKey).color,
        scheme.secondaryContainer,
      );

      // The overflow menu is gone: the remaining types are pills in the row.
      expect(find.byKey(moreKey), findsNothing);
      const channelsKey = ValueKey<String>('chat-filter-channels');
      await tester.ensureVisible(find.byKey(channelsKey));
      await tester.tap(find.byKey(channelsKey));
      await tester.pumpAndSettle();
      expect(
        pillDecoration(tester, groupsKey).color,
        scheme.surfaceContainerLow,
      );
      expect(
        pillDecoration(tester, channelsKey).color,
        scheme.secondaryContainer,
      );
    });

    testWidgets('does not duplicate global unread counts in filters', (
      WidgetTester tester,
    ) async {
      final mockChats = <ApiChatSummary>[
        const ApiChatSummary(
          id: 1,
          chatType: 'direct',
          name: 'Alice',
          unreadCount: 3,
          membersCount: 2,
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            chatsProvider.overrideWith(() => MockChatsNotifier(mockChats)),
          ],
          child: const ChatFilterBar(),
        ),
      );
      await tester.pumpAndSettle();

      // Chat scope pills never echo the global unread total: only folder pills
      // (absent here) carry a VK-style counter.
      expect(find.text('3'), findsNothing);
    });
  });

  group('Milestone 1: ChatSearchBar Tests', () {
    testWidgets('renders floating search bar with embedded profile avatar', (
      WidgetTester tester,
    ) async {
      bool avatarTapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          child: ChatSearchBar(onAvatarTap: () => avatarTapped = true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatSearchBar), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      final avatarFinder = find.descendant(
        of: find.byType(ChatSearchBar),
        matching: find.byType(GestureDetector),
      );
      expect(avatarFinder, findsWidgets);

      await tester.tap(avatarFinder.last);
      expect(avatarTapped, isTrue);
    });
  });
}

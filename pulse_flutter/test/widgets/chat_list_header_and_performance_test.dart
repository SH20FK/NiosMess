import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_header.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';

Widget _buildTestHarness({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('ChatListHeader M3 Expressive Tests', () {
    testWidgets('renders title text without grey container wrapper', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          overrides: [totalUnreadCountProvider.overrideWith((ref) => 0)],
          child: const Scaffold(appBar: ChatListHeader()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Чаты'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('header actions fit 320 dp at 200%: $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(useMaterial3: true, brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: const Scaffold(appBar: ChatListHeader()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.search_rounded).hitTestable(), findsOneWidget);
        expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('inbox-people')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps the header clear when there are unread messages', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          overrides: [totalUnreadCountProvider.overrideWith((ref) => 12)],
          child: const Scaffold(appBar: ChatListHeader()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Чаты'), findsOneWidget);
      expect(find.text('12'), findsNothing);
    });

    testWidgets('does not repeat a large unread count in the header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          overrides: [totalUnreadCountProvider.overrideWith((ref) => 1500)],
          child: const Scaffold(appBar: ChatListHeader()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('999+'), findsNothing);
    });

    testWidgets('bar is 64 dp tall with a 16 dp title column and w700 title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          overrides: [totalUnreadCountProvider.overrideWith((ref) => 0)],
          child: const Scaffold(appBar: ChatListHeader()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppBar)).height, 64);
      expect(tester.getTopLeft(find.text('Чаты')).dx, 16);
      expect(
        tester.widget<Text>(find.text('Чаты')).style?.fontWeight,
        FontWeight.w700,
      );
      // 24 dp glyph inside a 48 dp target, 4 dp gutter -> 16 dp right inset.
      final people = find.byKey(const ValueKey<String>('inbox-people'));
      expect(tester.getSize(people), const Size(48, 48));
      final peopleGlyph = find.descendant(
        of: people,
        matching: find.byType(Icon),
      );
      final double screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getSize(peopleGlyph), const Size(24, 24));
      expect(screenWidth - tester.getTopRight(peopleGlyph).dx, 16);
      // Settings has its own tab: the header does not repeat it.
      expect(
        find.byKey(const ValueKey('inbox-profile-settings')),
        findsNothing,
      );
    });

    testWidgets('scrim and hairline fade in once the list is scrolled', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [totalUnreadCountProvider.overrideWith((ref) => 0)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
            theme: ThemeData(useMaterial3: true),
            home: const Scaffold(appBar: ChatListHeader()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      BoxDecoration scrim() =>
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(ChatListHeader),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;

      expect(scrim().color?.a ?? 0, 0);
      expect(scrim().border!.bottom.color.a, 0);

      container.read(chatListScrolledProvider.notifier).setScrolled(true);
      await tester.pumpAndSettle();

      final ColorScheme scheme = Theme.of(
        tester.element(find.byType(ChatListHeader)),
      ).colorScheme;
      expect(scrim().color, scheme.surface);
      expect(scrim().border!.bottom.width, 1);
      expect(scrim().border!.bottom.color.a, closeTo(0.22, 0.001));

      container.read(chatListScrolledProvider.notifier).setScrolled(false);
      await tester.pumpAndSettle();
      expect(scrim().color?.a ?? 0, 0);
    });
  });

  group('ChatTile rendering & performance Tests', () {
    testWidgets('renders title, preview and unread badge without throwing', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        _buildTestHarness(
          child: ChatTile(
            title: 'Тестовый чат',
            subtitle: 'Привет мир',
            formattedTime: '12:00',
            unreadCount: 3,
            avatarText: 'ТЧ',
            avatarColor: Colors.blue,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тестовый чат'), findsOneWidget);
      expect(find.text('Привет мир'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byType(ChatTile));
      expect(tapped, isTrue);
    });
  });
}

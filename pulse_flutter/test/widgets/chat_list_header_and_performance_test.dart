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
          overrides: [
            totalUnreadCountProvider.overrideWith((ref) => 0),
          ],
          child: const Scaffold(
            appBar: ChatListHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Чаты'), findsOneWidget);
    });

    testWidgets('renders unread badge when total unread count > 0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          overrides: [
            totalUnreadCountProvider.overrideWith((ref) => 12),
          ],
          child: const Scaffold(
            appBar: ChatListHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Чаты'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('caps unread badge text at 999+ for huge unread counts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          overrides: [
            totalUnreadCountProvider.overrideWith((ref) => 1500),
          ],
          child: const Scaffold(
            appBar: ChatListHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('999+'), findsOneWidget);
    });
  });

  group('ChatTile Lazy Animation & Performance Tests', () {
    testWidgets('renders normally when animateEntrance is false without throwing', (
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
            animateEntrance: false,
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

    testWidgets('animates correctly when animateEntrance is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHarness(
          child: ChatTile(
            title: 'Анимированный чат',
            subtitle: 'Новое сообщение',
            formattedTime: '12:30',
            unreadCount: 0,
            avatarText: 'АЧ',
            avatarColor: Colors.purple,
            animateEntrance: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Анимированный чат'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChatTile),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );
    });
  });
}

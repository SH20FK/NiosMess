import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_header.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

Widget _app(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('ru'),
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

Widget _scaled(Widget child, double scale) {
  return Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    ),
  );
}

ChatTile _tile({
  String? draftLabel,
  int unreadCount = 0,
  bool isMuted = false,
  List<ApiBadge> partnerBadges = const <ApiBadge>[],
  String subtitle = 'Короткое превью сообщения',
}) {
  return ChatTile(
    title: 'Ирина',
    subtitle: subtitle,
    formattedTime: '12:45',
    unreadCount: unreadCount,
    avatarText: 'Ирина',
    avatarColor: const Color(0xFF6750A4),
    draftLabel: draftLabel,
    isMuted: isMuted,
    partnerBadges: partnerBadges,
    onTap: () {},
  );
}

Widget _narrow(Widget child) =>
    Center(child: SizedBox(width: 320, child: child));

void main() {
  testWidgets(
    'long draft label is ellipsized instead of overflowing the tile',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          _narrow(
            _tile(
              draftLabel: 'Черновик: ${'длинный текст ' * 500}',
              unreadCount: 4,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Короткое превью сообщения'), findsOneWidget);
    },
  );

  testWidgets('long draft label survives a 200% text scale without overflow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _narrow(
          _scaled(
            _tile(
              draftLabel: 'Черновик: ${'длинный текст ' * 500}',
              unreadCount: 2,
            ),
            2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Короткое превью сообщения'), findsOneWidget);
  });

  testWidgets('muted unread badge uses the neutral surface tone', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_narrow(_tile(unreadCount: 7, isMuted: true))),
    );
    await tester.pumpAndSettle();

    final ColorScheme scheme = Theme.of(
      tester.element(find.byType(ChatTile)),
    ).colorScheme;
    final Container badge = tester.widget<Container>(
      find.byKey(const ValueKey<String>('7_true')),
    );
    expect(
      (badge.decoration! as BoxDecoration).color,
      scheme.surfaceContainerHighest,
    );
  });

  testWidgets('active unread badge keeps the primary accent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile(unreadCount: 3))));
    await tester.pumpAndSettle();

    final ColorScheme scheme = Theme.of(
      tester.element(find.byType(ChatTile)),
    ).colorScheme;
    final Container badge = tester.widget<Container>(
      find.byKey(const ValueKey<String>('3_false')),
    );
    expect((badge.decoration! as BoxDecoration).color, scheme.primary);
  });

  testWidgets('status badge icon follows the badge type, not a fixed check', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _narrow(
          _tile(
            partnerBadges: const <ApiBadge>[
              ApiBadge(id: 1, name: 'Admin', icon: 'shield', color: 'primary'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsNothing);

    await tester.pumpWidget(
      _app(
        _narrow(
          _tile(
            partnerBadges: const <ApiBadge>[
              ApiBadge(id: 2, name: 'Bot', icon: 'bot', color: 'primary'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
  });

  testWidgets('tile exposes a single labelled semantics node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_narrow(_tile(unreadCount: 2))));
    await tester.pumpAndSettle();

    final Semantics semantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(ChatTile),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.label, contains('Ирина'));
    expect(semantics.properties.label, contains('2'));
    expect(semantics.excludeSemantics, isTrue);
    expect(semantics.properties.onTap, isNotNull);
    // Exactly one semantics node carries the title: a duplicate child label
    // would make TalkBack read the row twice.
    expect(find.bySemanticsLabel(RegExp('Ирина')), findsOneWidget);

    handle.dispose();
  });

  testWidgets('secondary tap reports the pointer without firing long press', (
    WidgetTester tester,
  ) async {
    Offset? pointer;
    bool longPressed = false;
    await tester.pumpWidget(
      _app(
        Center(
          child: SizedBox(
            width: 240,
            height: 72,
            child: TouchContainer(
              onTap: () {},
              onLongPress: () => longPressed = true,
              onSecondaryTapDown: (Offset position) => pointer = position,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(TouchContainer)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(pointer, isNotNull);
    expect(longPressed, isFalse);
  });

  testWidgets('header height grows with the text scale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_scaled(const Scaffold(appBar: ChatListHeader()), 2)),
    );
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('Чаты'));
    expect(ChatListHeader.heightFor(context), greaterThan(kToolbarHeight));
  });
}

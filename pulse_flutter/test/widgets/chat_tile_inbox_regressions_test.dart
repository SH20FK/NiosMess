import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_header.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

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

Widget _reducedMotion(Widget child) {
  return Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    ),
  );
}

ChatTile _tile({
  String? draftLabel,
  int unreadCount = 0,
  bool isMuted = false,
  bool isSelected = false,
  bool isPinned = false,
  bool isSecret = false,
  bool isSaved = false,
  bool isOnline = false,
  bool compact = false,
  bool keyMismatch = false,
  bool isTyping = false,
  List<String>? typingNames,
  IconData? deliveryIcon,
  String? deliveryLabel,
  String formattedTime = '12:45',
  List<ApiBadge> partnerBadges = const <ApiBadge>[],
  String subtitle = 'Короткое превью сообщения',
}) {
  return ChatTile(
    title: 'Ирина',
    subtitle: subtitle,
    formattedTime: formattedTime,
    unreadCount: unreadCount,
    avatarText: 'Ирина',
    avatarColor: const Color(0xFF6750A4),
    draftLabel: draftLabel,
    isMuted: isMuted,
    isSelected: isSelected,
    isPinned: isPinned,
    isSecret: isSecret,
    isSaved: isSaved,
    isOnline: isOnline,
    compact: compact,
    keyMismatch: keyMismatch,
    isTyping: isTyping,
    typingNames: typingNames,
    deliveryIcon: deliveryIcon,
    deliveryLabel: deliveryLabel,
    partnerBadges: partnerBadges,
    onTap: () {},
  );
}

Widget _narrow(Widget child) =>
    Center(child: SizedBox(width: 320, child: child));

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ChatTile))).colorScheme;

BoxDecoration _surface(WidgetTester tester) =>
    tester
            .widget<AnimatedContainer>(
              find.byKey(const ValueKey<String>('chat-tile-surface')),
            )
            .decoration!
        as BoxDecoration;

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

  // --- State levels (resting / hover / selected) ---------------------------

  testWidgets(
    'resting unread row is transparent: unread is weight + pill only',
    (WidgetTester tester) async {
      await tester.pumpWidget(_app(_narrow(_tile(unreadCount: 3))));
      await tester.pumpAndSettle();

      expect(_surface(tester).color, Colors.transparent);
      // The two remaining unread signals: weight and the counter pill.
      expect(find.byKey(const ValueKey<String>('3_false')), findsOneWidget);
    },
  );

  testWidgets('hover paints surfaceContainerHigh at 100% opacity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile())));
    await tester.pumpAndSettle();

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(ChatTile)));
    await tester.pumpAndSettle();

    expect(_surface(tester).color, _scheme(tester).surfaceContainerHigh);
  });

  testWidgets('selected row is secondaryContainer and shows the indicator', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_narrow(_tile(isSelected: true, unreadCount: 4))),
    );
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    expect(_surface(tester).color, scheme.secondaryContainer);
    // No alpha wash: the selected tone must be measurable against the row.
    expect(_surface(tester).color!.a, 1);

    final AnimatedOpacity indicator = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey<String>('chat-tile-selected-indicator')),
    );
    expect(indicator.opacity, 1);
  });

  testWidgets('selected and hovered row keeps its selected tone', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile(isSelected: true))));
    await tester.pumpAndSettle();

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(ChatTile)));
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    final Color expected = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.05),
      scheme.secondaryContainer,
    );
    expect(_surface(tester).color, expected);
    expect(_surface(tester).color, isNot(scheme.secondaryContainer));
  });

  testWidgets('unselected row hides the leading indicator', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile())));
    await tester.pumpAndSettle();

    final AnimatedOpacity indicator = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey<String>('chat-tile-selected-indicator')),
    );
    expect(indicator.opacity, 0);
  });

  // --- Key mismatch -------------------------------------------------------

  testWidgets('key mismatch renders the error lock, warning and frame', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_narrow(_tile(isSecret: true, keyMismatch: true))),
    );
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    expect(find.byIcon(Icons.gpp_maybe_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
    expect(find.text('Ключи не совпадают'), findsOneWidget);
    expect(find.text('Короткое превью сообщения'), findsNothing);

    final BoxBorder? border = _surface(tester).border;
    expect(border, isA<Border>());
    expect(
      (border! as Border).top.color,
      scheme.error.withValues(alpha: 0.35),
    );
    expect(border.top.width, 1);
  });

  testWidgets('healthy secret chat keeps the primary lock and no frame', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile(isSecret: true))));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.gpp_maybe_rounded), findsNothing);
    expect(_surface(tester).border, isNull);
  });

  // --- Row height / delivery status slot ----------------------------------

  testWidgets('sending status lives in the time slot and keeps the row at 76', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile())));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ChatTile)).height, ChatTile.rowHeight);

    await tester.pumpWidget(
      _app(
        _narrow(
          _tile(
            deliveryIcon: Icons.schedule_rounded,
            deliveryLabel: 'Отправляется…',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ChatTile)).height, ChatTile.rowHeight);
    // Status replaces the timestamp instead of adding a third line.
    expect(find.text('Отправляется…'), findsOneWidget);
    expect(find.text('12:45'), findsNothing);
  });

  testWidgets('failed delivery status is error-tinted in the time slot', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _narrow(
          _tile(
            deliveryIcon: Icons.error_outline_rounded,
            deliveryLabel: 'Не отправлено',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    final Text status = tester.widget<Text>(find.text('Не отправлено'));
    expect(status.style?.color, scheme.error);
    // labelSmall, i.e. the same 11sp as the timestamp it replaces.
    expect(
      status.style?.fontSize,
      Theme.of(tester.element(find.byType(ChatTile))).textTheme.labelSmall?.fontSize,
    );
  });

  testWidgets('compact tiles keep their 64dp height with a status label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _narrow(
          _tile(
            compact: true,
            deliveryIcon: Icons.schedule_rounded,
            deliveryLabel: 'Отправляется…',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(ChatTile)).height,
      ChatTile.compactRowHeight,
    );
  });

  // --- Time slot ----------------------------------------------------------

  testWidgets('time slot caps by text scale, not by screen width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_narrow(_scaled(_tile(formattedTime: '12.11.2025'), 2))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final Text time = tester.widget<Text>(find.text('12.11.2025'));
    expect(time.style?.fontSize, 12);
    expect(time.style?.color, _scheme(tester).onSurfaceVariant);
    expect(time.style?.fontWeight, FontWeight.w400);
    expect(
      time.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );

    // 320 tile - 24 padding - 48 avatar - 12 gap = 236dp of content: the cap is
    // min(72 * textScale, 236 * 0.42) instead of the old screenWidth * 0.32.
    final ConstrainedBox cap = tester.widget<ConstrainedBox>(
      find
          .ancestor(
            of: find.text('12.11.2025'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(
      cap.constraints.maxWidth,
      closeTo(math.min(2 * 72, 236 * 0.42), 0.01),
    );
  });

  testWidgets('time is never the accent on an unread row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile(unreadCount: 5))));
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    final Text time = tester.widget<Text>(find.text('12:45'));
    expect(time.style?.color, scheme.onSurfaceVariant);
    expect(time.style?.color, isNot(scheme.primary));
  });

  // --- Typography ---------------------------------------------------------

  testWidgets('title is titleMedium 16/24 and unread flips it to w700', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile())));
    await tester.pumpAndSettle();

    AnimatedDefaultTextStyle title = tester
        .widget<AnimatedDefaultTextStyle>(
          find
              .descendant(
                of: find.byType(ChatTile),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        );
    expect(title.style.fontSize, 16);
    expect(title.duration, const Duration(milliseconds: 150));
    expect(title.style.fontWeight, FontWeight.w600);

    await tester.pumpWidget(_app(_narrow(_tile(unreadCount: 2))));
    await tester.pumpAndSettle();

    title = tester.widget<AnimatedDefaultTextStyle>(
      find
          .descendant(
            of: find.byType(ChatTile),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    );
    expect(title.style.fontWeight, FontWeight.w700);
  });

  testWidgets('preview is bodyMedium 14 with unread weight', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile(unreadCount: 1))));
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    final Text preview = tester.widget<Text>(
      find.text('Короткое превью сообщения'),
    );
    expect(preview.style?.fontSize, 14);
    expect(preview.style?.color, scheme.onSurface);
    expect(preview.style?.fontWeight, FontWeight.w500);
    expect(preview.style?.letterSpacing, lessThanOrEqualTo(0.25));
  });

  // --- Typing -------------------------------------------------------------

  testWidgets('typing preview is primary-tinted with three dots', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_narrow(_tile(isTyping: true, subtitle: 'печатает...'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final ColorScheme scheme = _scheme(tester);
    // The literal dots are dropped: the animated dots follow the copy.
    expect(find.text('печатает...'), findsNothing);
    final Text typing = tester.widget<Text>(find.text('печатает'));
    expect(typing.style?.color, scheme.primary);
    expect(typing.style?.fontWeight, FontWeight.w500);
    expect(
      find.byKey(const ValueKey<String>('chat-tile-typing-dots')),
      findsOneWidget,
    );
    for (int i = 0; i < 3; i++) {
      expect(
        find.byKey(ValueKey<String>('chat-typing-dot-$i')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);

    // Unmount so the repeating ticker does not leak into the next test.
    await tester.pumpWidget(_app(const SizedBox.shrink()));
  });

  testWidgets('typing dots stay static under reduced motion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _reducedMotion(_narrow(_tile(isTyping: true, subtitle: 'печатает...'))),
      ),
    );
    await tester.pumpAndSettle();

    final Opacity dot = tester.widget<Opacity>(
      find.byKey(const ValueKey<String>('chat-typing-dot-0')),
    );
    expect(dot.opacity, 0.55);
  });

  testWidgets('group typing uses the shared multiple-typing copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _narrow(
          _tile(
            isTyping: true,
            subtitle: 'Игнорируется',
            typingNames: const <String>['Аня', 'Тимур'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Несколько человек печатают'), findsOneWidget);
    expect(find.text('Игнорируется'), findsNothing);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
  });

  // --- Badges, icons, avatar ----------------------------------------------

  testWidgets('muted unread badge uses a tonal pill with an outline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_narrow(_tile(unreadCount: 7, isMuted: true))),
    );
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    final Container badge = tester.widget<Container>(
      find.byKey(const ValueKey<String>('7_true')),
    );
    final BoxDecoration decoration = badge.decoration! as BoxDecoration;
    expect(decoration.color, scheme.surfaceContainerHigh);
    expect(decoration.border, isA<Border>());
    expect((decoration.border! as Border).top.color, scheme.outlineVariant);

    // Muted avatars recede to 90% instead of being tinted like unread rows.
    final Opacity dimmed = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byType(PulseAvatar),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(dimmed.opacity, 0.9);
  });

  testWidgets('active unread badge keeps the primary accent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile(unreadCount: 3))));
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
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

  testWidgets('title markers share one 16dp size and their state colors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_narrow(_tile(isSecret: true, isMuted: true, isPinned: true))),
    );
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    for (final IconData icon in <IconData>[
      Icons.lock_rounded,
      Icons.notifications_off_outlined,
      Icons.push_pin_rounded,
    ]) {
      final Icon widgetIcon = tester.widget<Icon>(find.byIcon(icon));
      expect(widgetIcon.size, 16, reason: '$icon must be 16dp');
    }
    expect(
      tester.widget<Icon>(find.byIcon(Icons.lock_rounded)).color,
      scheme.primary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.push_pin_rounded)).color,
      scheme.onSurfaceVariant,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.notifications_off_outlined)).color,
      scheme.onSurfaceVariant,
    );
  });

  testWidgets('presence dot is 14dp and cut out of the row background', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile(isOnline: true))));
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    final Finder dotFinder = find.byKey(
      const ValueKey<String>('chat-tile-presence-dot'),
    );
    expect(tester.getSize(dotFinder), const Size(14, 14));

    final Container dot = tester.widget<Container>(dotFinder);
    final BoxDecoration decoration = dot.decoration! as BoxDecoration;
    // Resting rows are transparent, so the cutout is the list surface.
    expect((decoration.border! as Border).top.color, scheme.surface);
    expect((decoration.border! as Border).top.width, 2);
  });

  testWidgets('saved shortcut is a 48dp primaryContainer circle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile(isSaved: true))));
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    final Finder circleFinder = find.byKey(
      const ValueKey<String>('chat-tile-saved-avatar'),
    );
    expect(tester.getSize(circleFinder), const Size(48, 48));

    final BoxDecoration decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: circleFinder,
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, scheme.primaryContainer);
  });

  // --- Delivery ticks -----------------------------------------------------

  testWidgets('delivered stays neutral, read takes the primary accent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_narrow(_tile(deliveryIcon: Icons.done_rounded))),
    );
    await tester.pumpAndSettle();
    final ColorScheme scheme = _scheme(tester);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.done_rounded)).color,
      scheme.onSurfaceVariant,
    );

    await tester.pumpWidget(
      _app(_narrow(_tile(deliveryIcon: Icons.done_all_rounded))),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Icon>(find.byIcon(Icons.done_all_rounded)).color,
      scheme.primary,
    );
  });

  // --- Semantics ----------------------------------------------------------

  testWidgets('tile exposes a single labelled semantics node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        _narrow(
          _tile(
            unreadCount: 2,
            isPinned: true,
            isMuted: true,
            isSecret: true,
            isSelected: true,
            deliveryIcon: Icons.done_all_rounded,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Semantics semantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(ChatTile),
            matching: find.byType(Semantics),
          )
          .first,
    );
    final String label = semantics.properties.label ?? '';
    expect(label, contains('Ирина'));
    expect(label, contains('2'));
    expect(label, contains('выбран'));
    expect(label, contains('закреплён'));
    expect(label, contains('без звука'));
    expect(label, contains('Прочитано'));
    expect(semantics.properties.selected, isTrue);
    expect(semantics.excludeSemantics, isTrue);
    expect(semantics.properties.onTap, isNotNull);
    // Exactly one semantics node carries the title: a duplicate child label
    // would make TalkBack read the row twice.
    expect(find.bySemanticsLabel(RegExp('Ирина')), findsOneWidget);

    handle.dispose();
  });

  testWidgets('key mismatch is announced to screen readers', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(_narrow(_tile(isSecret: true, keyMismatch: true))),
    );
    await tester.pumpAndSettle();

    final Semantics semantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(ChatTile),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.label, contains('Ключи не совпадают'));

    handle.dispose();
  });

  // --- Touch state layer --------------------------------------------------

  testWidgets('pressed tile paints the M3 8% onSurface state layer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_narrow(_tile())));
    await tester.pumpAndSettle();

    final ColorScheme scheme = _scheme(tester);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(ChatTile)),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final AnimatedContainer pressed = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byType(TouchContainer),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final BoxDecoration layer = pressed.foregroundDecoration! as BoxDecoration;
    expect(layer.color, scheme.onSurface.withValues(alpha: 0.08));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedContainer>(
            find
                .descendant(
                  of: find.byType(TouchContainer),
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          )
          .foregroundDecoration,
      isNull,
    );
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

// Contract tests for the shell's navigation chrome (bottom bar and side rail):
// * M3 Expressive bar: 64dp, a 56x32 tonal indicator, labels always shown,
//   horizontal destinations from 600dp;
// * unread badge: 16dp, error tone, capped at `99+`, on the icon's top-end
//   corner, visible on the selected destination and on the rail as well;
// * muted chats stay out of the counter.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_item.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_rail.dart';

class _NavSettings extends UiSettingsNotifier {
  @override
  UiSettingsState build() =>
      const UiSettingsState.defaults().copyWith(soundEffects: false);
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const <ApiChatSummary>[
    ApiChatSummary(
      id: 1,
      chatType: 'direct',
      name: 'Loud',
      unreadCount: 5,
      membersCount: 2,
    ),
    ApiChatSummary(
      id: 2,
      chatType: 'group',
      name: 'Muted group',
      unreadCount: 2,
      membersCount: 9,
      topicsEnabled: true,
    ),
    ApiChatSummary(
      id: 3,
      chatType: 'group',
      name: 'Topic of the muted group',
      unreadCount: 4,
      membersCount: 9,
      topicParentId: 2,
    ),
  ];
}

class _Muted extends ChatMuteHub {
  @override
  Future<Set<int>> build() async => const <int>{2};
}

const ValueKey<String> _badgeKey = ValueKey<String>('nav-unread-badge');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHost(
    WidgetTester tester, {
    required int unread,
    required Size size,
    required Widget Function() home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        uiSettingsProvider.overrideWith(_NavSettings.new),
        totalUnreadCountProvider.overrideWithValue(unread),
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
          theme: AppTheme.themed(
            const UiSettingsState.defaults().visualTheme,
            Brightness.light,
          ),
          home: home(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> pumpNav(
    WidgetTester tester, {
    required int unread,
    int index = 1,
    Size size = const Size(390, 844),
    ValueChanged<int>? onTap,
    bool Function(int index)? onReselect,
  }) => pumpHost(
    tester,
    unread: unread,
    size: size,
    home: () => Scaffold(
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        hapticsEnabled: false,
        onTap: onTap ?? (_) {},
        onReselect: onReselect,
      ),
    ),
  );

  ColorScheme schemeOf(WidgetTester tester, Type host) =>
      Theme.of(tester.element(find.byType(host))).colorScheme;

  testWidgets('bar is 64dp tall with a 56x32 tonal indicator and labels', (
    tester,
  ) async {
    await pumpNav(tester, unread: 0);

    expect(tester.getSize(find.byType(AppBottomNav)).height, 64);
    final List<AppNavItem> items = tester
        .widgetList<AppNavItem>(find.byType(AppNavItem))
        .toList();
    expect(items, hasLength(3));
    expect(
      items.every((AppNavItem i) => i.layout == AppNavItemLayout.vertical),
      isTrue,
    );
    for (final String label in <String>['Чаты', 'Лента', 'Настройки']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester
          .widgetList<TabMorphIcon>(find.byType(TabMorphIcon))
          .every((TabMorphIcon icon) => icon.size == 24),
      isTrue,
    );

    // The selected destination (no badge on this one, so the only fade under
    // it is the indicator).
    final Finder indicator = find.descendant(
      of: find.byKey(const ValueKey<String>('nav-item-niosgram')),
      matching: find.byType(FadeTransition),
    );
    expect(indicator, findsOneWidget);
    expect(tester.getSize(indicator), const Size(56, 32));
    expect(tester.widget<FadeTransition>(indicator).opacity.value, 1);

    final ColorScheme scheme = schemeOf(tester, AppBottomNav);
    TextStyle labelStyle(String text) =>
        DefaultTextStyle.of(tester.element(find.text(text))).style;
    expect(labelStyle('Лента').color, scheme.secondary);
    expect(labelStyle('Чаты').color, scheme.onSurfaceVariant);
    // The active label is not bolder: a weight change would shift neighbours.
    expect(labelStyle('Лента').fontWeight, labelStyle('Чаты').fontWeight);
  });

  testWidgets('from 600dp destinations are horizontal with a 40dp indicator', (
    tester,
  ) async {
    await pumpNav(tester, unread: 3, size: const Size(700, 900));

    expect(tester.getSize(find.byType(AppBottomNav)).height, 64);
    expect(
      tester
          .widgetList<AppNavItem>(find.byType(AppNavItem))
          .every((AppNavItem i) => i.layout == AppNavItemLayout.horizontal),
      isTrue,
    );
    final Finder indicator = find.descendant(
      of: find.byKey(const ValueKey<String>('nav-item-niosgram')),
      matching: find.byType(FadeTransition),
    );
    expect(tester.getSize(indicator).height, 40);
    // The icon sits beside its label, inside the indicator.
    final Rect icon = tester.getRect(find.byType(TabMorphIcon).at(1));
    final Rect label = tester.getRect(find.text('Лента'));
    expect(label.left, greaterThan(icon.right));
    expect(tester.getRect(indicator).contains(label.center), isTrue);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('unread badge is a capped 16dp error pill on the icon corner', (
    tester,
  ) async {
    await pumpNav(tester, unread: 128, index: 1);

    final Finder label = find.text('99+');
    expect(label, findsOneWidget);
    expect(find.text('128'), findsNothing);
    expect(tester.getSize(find.byKey(_badgeKey)).height, 16);

    final ColorScheme scheme = schemeOf(tester, AppBottomNav);
    final DecoratedBox pill = tester.widget<DecoratedBox>(
      find.ancestor(of: label, matching: find.byType(DecoratedBox)).first,
    );
    expect((pill.decoration as ShapeDecoration).color, scheme.error);
    expect(tester.widget<Text>(label).style?.color, scheme.onError);

    final Rect badge = tester.getRect(find.byKey(_badgeKey));
    final Rect icon = tester.getRect(find.byType(TabMorphIcon).first);
    // Top-end corner of the icon: it starts past the glyph's centre and never
    // reaches down over it.
    expect(badge.left, greaterThan(icon.center.dx));
    expect(badge.top, lessThan(icon.top));
    expect(badge.bottom, lessThan(icon.bottom));
    // And it stays inside its own destination.
    final Rect item = tester.getRect(
      find.byKey(const ValueKey<String>('nav-item-chats')),
    );
    expect(badge.right, lessThan(item.right));
  });

  testWidgets('badge stays visible on the selected destination', (
    tester,
  ) async {
    await pumpNav(tester, unread: 128, index: 0);

    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('small unread counts render as a number, zero renders nothing', (
    tester,
  ) async {
    await pumpNav(tester, unread: 7, index: 1);
    expect(find.text('7'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpNav(tester, unread: 0, index: 1);
    expect(find.byKey(_badgeKey), findsNothing);
  });

  testWidgets('tapping the active destination reselects instead of navigating', (
    tester,
  ) async {
    final List<int> taps = <int>[];
    final List<int> reselects = <int>[];
    await pumpNav(
      tester,
      unread: 0,
      index: 0,
      onTap: taps.add,
      onReselect: (int index) {
        reselects.add(index);
        return true;
      },
    );

    await tester.tap(find.byType(AppNavItem).first);
    expect(reselects, <int>[0]);
    expect(taps, isEmpty);

    await tester.tap(find.byType(AppNavItem).last);
    expect(taps, <int>[2]);
    expect(reselects, <int>[0]);
  });

  testWidgets('side rail is 96dp wide, labelled, and carries the same badge', (
    tester,
  ) async {
    final List<int> taps = <int>[];
    await pumpHost(
      tester,
      unread: 128,
      size: const Size(1200, 800),
      home: () => Scaffold(
        body: Row(
          children: <Widget>[
            AppNavRail(
              currentIndex: 0,
              hapticsEnabled: false,
              onTap: taps.add,
            ),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppNavRail)), const Size(96, 800));
    for (final String label in <String>['Чаты', 'Лента', 'Настройки']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('99+'), findsOneWidget);
    final List<AppNavItem> items = tester
        .widgetList<AppNavItem>(find.byType(AppNavItem))
        .toList();
    expect(items.map((AppNavItem i) => i.selected).toList(), <bool>[
      true,
      false,
      false,
    ]);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('nav-item-chats'))),
      const Size(96, 64),
    );

    await tester.tap(find.text('Настройки'));
    expect(taps, <int>[2]);
  });

  test('the counter leaves muted chats and their topics out', () async {
    final container = ProviderContainer(
      overrides: [
        chatsProvider.overrideWith(_Chats.new),
        chatMuteHubProvider.overrideWith(_Muted.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(chatsProvider.future);
    await container.read(chatMuteHubProvider.future);

    expect(container.read(totalUnreadCountProvider), 5);
  });
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/widgets/chat/chat_actions_modal.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
    ),
    home: Scaffold(body: child),
  );
}

Widget _opener({int unreadCount = 0}) {
  return Builder(
    builder: (BuildContext context) => Center(
      child: TextButton(
        onPressed: () => ChatActionsModal.show(
          context,
          chat: ApiChatSummary(
            id: 1,
            name: 'Саша',
            chatType: 'direct',
            unreadCount: unreadCount,
            membersCount: 2,
          ),
          avatarColor: const Color(0xFF6750A4),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  testWidgets('header aligns the avatar at 16 and the name at 72', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_opener()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final Rect avatar = tester.getRect(find.byType(PulseAvatar).first);
    final Rect name = tester.getRect(find.text('Саша'));
    expect(avatar.width, 44);
    // 44dp avatar + 12dp gap: the name starts exactly on the label column.
    expect(name.left - avatar.left, 56);
  });

  testWidgets('mark read is listed but disabled without unread messages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_opener()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final ColorScheme scheme = Theme.of(
      tester.element(find.text('Отметить прочитанным')),
    ).colorScheme;
    final Finder row = find.byKey(
      const ValueKey<ChatActionResult>(ChatActionResult.markRead),
    );
    expect(tester.getSize(row).height, 48);

    final Text label = tester.widget<Text>(find.text('Отметить прочитанным'));
    expect(label.style?.color, scheme.onSurface.withValues(alpha: 0.38));
    expect(label.style?.fontSize, 14);
    expect(
      tester.widget<InkWell>(
        find.descendant(of: row, matching: find.byType(InkWell)).first,
      ).onTap,
      isNull,
    );
  });

  testWidgets('enabled rows are 48dp tall with a single labelLarge typeface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_opener(unreadCount: 4)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final ColorScheme scheme = Theme.of(
      tester.element(find.text('Удалить')),
    ).colorScheme;

    for (final String text in <String>[
      'Отметить прочитанным',
      'Отключить уведомления',
      'Удалить',
    ]) {
      final Finder row = find
          .ancestor(of: find.text(text), matching: find.byType(SizedBox))
          .first;
      expect(tester.getSize(row).height, 48, reason: text);
      final Text label = tester.widget<Text>(find.text(text));
      expect(label.style?.fontSize, 14, reason: text);
      expect(label.style?.letterSpacing, 0.1, reason: text);
    }

    // The destructive row is error-tinted only: no fill, no outline.
    final Text delete = tester.widget<Text>(find.text('Удалить'));
    expect(delete.style?.color, scheme.error);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Material && widget.color == scheme.errorContainer,
      ),
      findsNothing,
    );
  });

  testWidgets('a hairline divider separates the destructive action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_opener(unreadCount: 1)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final ColorScheme scheme = Theme.of(
      tester.element(find.text('Удалить')),
    ).colorScheme;
    final Divider divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.thickness, 1);
    expect(divider.indent, 12);
    expect(divider.endIndent, 12);
    expect(divider.color, scheme.outlineVariant.withValues(alpha: 0.22));

    // The divider sits between the mute row and the destructive row.
    final double dividerY = tester.getCenter(find.byType(Divider)).dy;
    expect(
      dividerY,
      greaterThan(tester.getCenter(find.text('Отключить уведомления')).dy),
    );
    expect(dividerY, lessThan(tester.getCenter(find.text('Удалить')).dy));
  });

  testWidgets('folder and select rows are safe actions above the divider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_opener(unreadCount: 1)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final double dividerY = tester.getCenter(find.byType(Divider)).dy;
    for (final ChatActionResult result in <ChatActionResult>[
      ChatActionResult.addToFolder,
      ChatActionResult.select,
    ]) {
      final Finder row = find.byKey(ValueKey<ChatActionResult>(result));
      expect(row, findsOneWidget, reason: '$result');
      expect(tester.getSize(row).height, 48, reason: '$result');
      expect(tester.getCenter(row).dy, lessThan(dividerY), reason: '$result');
    }
    expect(find.text('В папку'), findsOneWidget);
    expect(find.text('Выбрать'), findsOneWidget);
  });

  testWidgets('rows use the M3 control shape, not hardcoded 12dp corners', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_opener(unreadCount: 1)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final InkWell row = tester.widget<InkWell>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey<ChatActionResult>(ChatActionResult.toggleMute),
            ),
            matching: find.byType(InkWell),
          )
          .first,
    );
    final ShapeBorder? border = row.customBorder;
    expect(border, isA<RoundedSuperellipseBorder>());
    expect(
      ((border! as RoundedSuperellipseBorder).borderRadius as BorderRadius)
          .topLeft
          .x,
      AppShape.control,
    );
  });
}

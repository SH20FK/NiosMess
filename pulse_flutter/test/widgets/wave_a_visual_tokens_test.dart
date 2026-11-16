import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_surfaces.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/empty_state_widget.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';

ThemeData _theme(Brightness brightness) => AppTheme.themed(
  const VisualThemeSettings(
    seedColor: Color(0xFF6750A4),
    themeMode: ThemeMode.light,
    useSystemDynamic: false,
    predictiveBackEnabled: false,
  ),
  brightness,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme(brightness),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('AppSurfaces tonal ladder', () {
    test('light container ladder is separated by at least 3 L*', () {
      final ColorScheme scheme = AppSurfaces.neutralize(
        ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      );
      final List<Color> ladder = <Color>[
        scheme.surface,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ];
      for (int i = 1; i < ladder.length; i++) {
        expect(
          _lStar(ladder[i - 1]) - _lStar(ladder[i]),
          greaterThanOrEqualTo(1.0),
          reason: 'step $i must stay visibly darker than the previous one',
        );
      }
      for (int i = 2; i < ladder.length; i++) {
        expect(
          _lStar(ladder[i - 1]) - _lStar(ladder[i]),
          greaterThanOrEqualTo(3.0),
          reason: 'container steps must be at least 3 L* apart',
        );
      }
      // The old ladder topped out at ~1.02 CR against the page surface, i.e.
      // the deepest container was indistinguishable from the background.
      expect(
        _contrast(scheme.surface, scheme.surfaceContainerHighest),
        closeTo(1.39, 0.03),
      );
      expect(
        _contrast(scheme.surface, scheme.surfaceContainerLow),
        closeTo(1.03, 0.02),
      );
    });

    test('dark ladder keeps the AMOLED surface and opens the same way', () {
      final ColorScheme scheme = AppSurfaces.neutralize(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      );
      expect(scheme.surface, const Color(0xFF1A1A1A));
      expect(
        _contrast(scheme.surface, scheme.surfaceContainerLow),
        greaterThan(1.05),
      );
      expect(
        _contrast(scheme.surface, scheme.surfaceContainerHighest),
        greaterThan(1.6),
      );
    });
  });

  group('ChatListSkeleton metrics', () {
    testWidgets('row mirrors ChatTile: 76dp tall, 48dp avatar, 22dp inset, '
        '2dp gap, 28x12 timestamp pinned to the top-right', (tester) async {
      await _pump(tester, const ChatListSkeleton(count: 2, outerInset: 0));

      final Finder row0 = find.byKey(
        const ValueKey<String>('chat_skeleton_row_0'),
      );
      final Finder row1 = find.byKey(
        const ValueKey<String>('chat_skeleton_row_1'),
      );
      expect(row0, findsOneWidget);
      expect(row1, findsOneWidget);

      expect(tester.getSize(row0).height, 76);
      expect(tester.getSize(row1).height, 76);

      final Rect rowRect = tester.getRect(row0);
      expect(tester.getTopLeft(row1).dy - rowRect.bottom, 2);

      final Finder avatar = find
          .descendant(of: row0, matching: find.byType(Container))
          .first;
      expect(tester.getSize(avatar), const Size(48, 48));
      // Real rows sit at 10 (list padding) + 12 (tile padding) = 22dp horizontally
      // and 14dp vertically around the avatar.
      expect(tester.getTopLeft(avatar).dx, rowRect.left + 22);
      expect(tester.getTopLeft(avatar).dy, rowRect.top + 14);

      final Finder timestamp = find.descendant(
        of: row0,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 28 &&
              widget.constraints?.maxHeight == 12,
        ),
      );
      expect(timestamp, findsOneWidget);
      final Rect timeRect = tester.getRect(timestamp);
      expect(timeRect.top, rowRect.top + 14); // same 14dp vertical padding
      expect(timeRect.right, rowRect.right - 22);
    });

    testWidgets('pulse runs by default and is static with reduced motion', (
      tester,
    ) async {
      await _pump(tester, const ChatListSkeleton(count: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await _pump(
        tester,
        const ChatListSkeleton(count: 1),
        disableAnimations: true,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('EmptyStateWidget', () {
    testWidgets('iconColor overrides the brand accent (error state)', (
      tester,
    ) async {
      const Color errorColor = Color(0xFFB3261E);
      await _pump(
        tester,
        const EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Ошибка',
          iconColor: errorColor,
        ),
      );
      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, errorColor);
    });

    testWidgets('busy action keeps the idle button width', (tester) async {
      await _pump(
        tester,
        const EmptyStateWidget(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Пусто',
          actionLabel: 'Повторить',
          onAction: _noop,
        ),
      );
      final Size idle = tester.getSize(find.byType(FilledButton));

      await _pump(
        tester,
        const EmptyStateWidget(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Пусто',
          actionLabel: 'Повторить',
          onAction: _noop,
          isBusy: true,
        ),
      );
      expect(tester.getSize(find.byType(FilledButton)).width, idle.width);
    });
  });
}

void _noop() {}

double _linearChannel(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color color) =>
    0.2126 * _linearChannel(color.r) +
    0.7152 * _linearChannel(color.g) +
    0.0722 * _linearChannel(color.b);

/// CIELAB lightness of an opaque color (0 = black, 100 = white).
double _lStar(Color color) {
  final double y = _relativeLuminance(color);
  return y > 0.008856 ? 116 * math.pow(y, 1 / 3).toDouble() - 16 : 903.3 * y;
}

double _contrast(Color a, Color b) {
  final double la = _relativeLuminance(a);
  final double lb = _relativeLuminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

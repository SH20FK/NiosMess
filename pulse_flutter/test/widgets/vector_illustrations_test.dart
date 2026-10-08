import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/empty_feed_widget.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

Widget _wrapWithMaterial(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: brightness,
      ),
      useMaterial3: true,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vector Illustrations Suite', () {
    testWidgets('EmptyFeedIllustration renders without errors in animated mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const EmptyFeedIllustration(size: 200, animate: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EmptyFeedIllustration), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('EmptyFeedIllustration renders statically when animate=false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const EmptyFeedIllustration(
            size: 160,
            primaryColor: Colors.blue,
            accentColor: Colors.teal,
            animate: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EmptyFeedIllustration), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('MediaPlaceholderIllustration renders shimmering vector container', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const MediaPlaceholderIllustration(
            width: 300,
            height: 200,
            animate: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MediaPlaceholderIllustration), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('MediaPlaceholderIllustration renders static mode without animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const MediaPlaceholderIllustration(
            width: 300,
            height: 200,
            animate: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MediaPlaceholderIllustration), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('MediaErrorIllustration renders error graphic, message, and retry button', (
      WidgetTester tester,
    ) async {
      bool retried = false;

      await tester.pumpWidget(
        _wrapWithMaterial(
          MediaErrorIllustration(
            width: 320,
            height: 220,
            message: 'Не удалось загрузить видео',
            onRetry: () {
              retried = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MediaErrorIllustration), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Не удалось загрузить видео'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);

      await tester.tap(find.text('Повторить'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('SettingsHeaderIllustration renders all 9 categories properly', (
      WidgetTester tester,
    ) async {
      for (final SettingsIllustrationCategory cat in SettingsIllustrationCategory.values) {
        await tester.pumpWidget(
          _wrapWithMaterial(
            SettingsHeaderIllustration(category: cat, size: 64),
          ),
        );
        await tester.pump();

        expect(find.byType(SettingsHeaderIllustration), findsOneWidget);
        expect(find.byType(SvgPicture), findsOneWidget);
      }
    });

    testWidgets('EmptyFeedWidget renders EmptyFeedIllustration by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const EmptyFeedWidget(
            title: 'Лента пуста',
            description: 'Здесь пока нет записей',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EmptyFeedWidget), findsOneWidget);
      expect(find.byType(EmptyFeedIllustration), findsOneWidget);
      expect(find.text('Лента пуста'), findsOneWidget);
      expect(find.text('Здесь пока нет записей'), findsOneWidget);
    });

    testWidgets('EmptyFeedWidget renders custom illustration when passed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const EmptyFeedWidget(
            title: 'Заголовок',
            description: 'Описание',
            illustration: Text('CUSTOM_ILLUSTRATION'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CUSTOM_ILLUSTRATION'), findsOneWidget);
      expect(find.byType(EmptyFeedIllustration), findsNothing);
    });

    testWidgets('EmptyFeedWidget renders M3Container with icon when icon is explicitly set', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const EmptyFeedWidget(
            title: 'Заголовок',
            description: 'Описание',
            icon: Icons.lock_outline_rounded,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byType(EmptyFeedIllustration), findsNothing);
    });

    testWidgets('SettingsNavBanner displays SettingsHeaderIllustration when illustrationCategory is provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const SettingsNavBanner(
            illustrationCategory: SettingsIllustrationCategory.account,
            title: 'Аккаунт',
            subtitle: 'Управление Nios ID',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SettingsNavBanner), findsOneWidget);
      expect(find.byType(SettingsHeaderIllustration), findsOneWidget);
      expect(find.text('Аккаунт'), findsOneWidget);
      expect(find.text('Управление Nios ID'), findsOneWidget);
    });
  });
}

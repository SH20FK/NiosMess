import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_app_bar.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(
  Widget body, {
  Locale locale = const Locale('ru'),
  Brightness brightness = Brightness.dark,
}) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    theme: ThemeData(useMaterial3: true, brightness: brightness),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(2), disableAnimations: true),
      child: child!,
    ),
    home: body,
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in ['ru', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'automatic language and zone preserve icons and selected semantics $locale $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              _app(
                const SettingsLanguageRegionScreen(),
                locale: Locale(locale),
                brightness: brightness,
              ),
            );
            await tester.pumpAndSettle();
            final l = AppLocalizations.of(
              tester.element(find.byType(SettingsLanguageRegionScreen)),
            )!;
            final automatic = find.widgetWithText(
              ChoiceChip,
              l.commonAutomatic,
            );
            expect(automatic, findsNWidgets(2));
            for (final element in automatic.evaluate()) {
              final chip = element.widget as ChoiceChip;
              expect(chip.selected, isTrue);
              expect(
                chip.showCheckmark,
                isFalse,
                reason:
                    'Semantic icon must remain visible, without a painted check overlay',
              );
              expect(chip.avatar, isA<Icon>());
              expect(
                tester
                    .getSemantics(find.byWidget(chip))
                    .flagsCollection
                    .isSelected,
                Tristate.isTrue,
              );
            }
            expect(find.byIcon(Icons.language_rounded), findsOneWidget);
            expect(find.byIcon(Icons.gps_fixed_rounded), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  for (final online in [false, true]) {
    testWidgets(
      'saved chat has no presence or fallback badge in list/header (server online=$online)',
      (tester) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              appBar: ChatDetailAppBar(
                chatId: 1,
                isDesktopSplit: false,
                title: 'Избранное',
                headerIcon: Icons.person_rounded,
                typingSubtitle: const Text('Личные заметки'),
                isSaved: true,
                isOnline: online,
                onBack: () {},
              ),
              body: ChatTile(
                title: 'Избранное',
                subtitle: 'Заметка',
                formattedTime: '',
                unreadCount: 0,
                avatarText: 'Избранное',
                avatarColor: const Color(0xff719384),
                isSaved: true,
                isOnline: online,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProductivityIcon), findsNWidgets(2));
        for (final element in find.byType(ProductivityIcon).evaluate()) {
          final avatar = element.findAncestorWidgetOfExactType<Stack>()!;
          expect(avatar.children.whereType<Positioned>(), isEmpty);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ordinary direct chat retains online indicator', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ChatTile(
            title: 'Собеседник',
            subtitle: 'Сообщение',
            formattedTime: '',
            unreadCount: 0,
            avatarText: 'Собеседник',
            avatarColor: const Color(0xff719384),
            isOnline: true,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                AppColors.statusOnline,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
